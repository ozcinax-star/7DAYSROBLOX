--!strict
-- DigService: digging the ground (7DTD terrain blocks). A swing that hits the terrain damages the
-- 4-stud column it hit by the tool's block damage for the column's material (Config.Dig). The yield is
-- paid while the column is hit, like a harvest (Shared/Harvest), and at full damage the column's
-- surface drops one voxel (4 studs). Only the top of a column is dug: there are no tunnels (PLAN). A
-- column goes at most Config.Dig.MaxStep below its side neighbours, so a deep hole has to be wide.
-- Dirt from the hand fills a dug column back in, one voxel per use, up to the height it had before it
-- was dug (7DTD places dirt anywhere; ours only refills holes, PLAN), never onto a player or zombie.
--
-- Roads and paving, building footprints, the shore, the ground under trees, rocks, props and placed
-- blocks, and the last voxel above the terrain bottom (bedrock) cannot be dug. Grass standing on a dug
-- column sinks with it. Holes keep their zombie navigation cells: zombies follow the ground height into
-- a hole and out of it.
--
-- Each dug column's voxel height is kept here. Roblox meshes holes rounder than the voxels: the height
-- grid gets the meshed surface at the column centres, read with a ray a frame after the voxels change,
-- and MapService reads heights around a hole with a ray, so zombies stand on what players see.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Harvest = require(Shared.Harvest)
local HeightField = require(Shared.World.HeightField)
local Types = require(Shared.Types)

local TerrainBuilder = require(script.Parent.Parent.World.TerrainBuilder)
local InventoryService = require(script.Parent.InventoryService)
local LootService = require(script.Parent.LootService)
local MapService = require(script.Parent.MapService)
local ThreatService = require(script.Parent.ThreatService)
local ToolService = require(script.Parent.ToolService)
local ZombieService = require(script.Parent.ZombieService)

local DC = Config.Dig
-- Dug items count as found in the world.
local SOURCE: Types.ItemSource = "Loot"
-- Terrain voxels and height-grid columns are 4 studs.
local VOXEL = 4
-- The surface ray starts this far above a column's voxel height.
local RAY_ABOVE = 20
-- Heights within this of each other are the same voxel level.
local LEVEL_TOLERANCE = 1e-3
local SIDES = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- A column being dug: its material is fixed by the first hit, its damage is shared by everyone.
type Column = { node: Config.HarvestNode, damage: number }

local DigService = {}

local columns: { [number]: Column } = {}
-- Voxel surface height of every column dug or next to one; the others still have it in the grid.
local levels: { [number]: number } = {}
-- Voxel surface height of every dug column before its first dig: dirt fills it back up to that.
local originals: { [number]: number } = {}
local nextFillAt: { [Player]: number } = {}
local random = Random.new()
local overlap: OverlapParams
local characterOverlap: OverlapParams
local terrainParams: RaycastParams
local map: Folder
local structures: Instance
local floorHeight: number

-- The column `dx`, `dz` columns away from `index`, or nil off the grid.
local function neighbour(grid: TerrainBuilder.HeightGrid, index: number, dx: number, dz: number): number?
	local cx, cz = index % grid.columns + dx, index // grid.columns + dz
	if cx < 0 or cz < 0 or cx >= grid.columns or cz >= grid.columns then
		return nil
	end
	return cz * grid.columns + cx
end

local function levelOf(grid: TerrainBuilder.HeightGrid, index: number): number
	return levels[index] or TerrainBuilder.heightOf(grid, index)
end

local function insideBuilding(x: number, z: number): boolean
	local m = DC.BuildingMargin + VOXEL / 2
	for _, info in MapService.getBuildings() do
		if x > info.minX - m and x < info.maxX + m and z > info.minZ - m and z < info.maxZ + m then
			return true
		end
	end
	return false
end

-- Water does not flow into a hole, so the columns at and next to water keep their ground.
local function nearWater(x: number, z: number): boolean
	for dz = -1, 1 do
		for dx = -1, 1 do
			if HeightField.isWater(x + dx * VOXEL, z + dz * VOXEL) then
				return true
			end
		end
	end
	return false
end

-- Whether lowering column `index` to `level` keeps it within MaxStep of its side neighbours.
local function withinStep(grid: TerrainBuilder.HeightGrid, index: number, level: number): boolean
	for _, side in SIDES do
		local other = neighbour(grid, index, side[1], side[2])
		if other and level < levelOf(grid, other) - DC.MaxStep then
			return false
		end
	end
	return true
end

-- What stands on the column centred at (x, z) with its surface at `level`: nil when a placed block, a
-- loot bag or a collidable map part (tree, rock, prop) keeps it from being dug, otherwise the loose map
-- models (grass) standing on it.
local function looseOn(x: number, z: number, level: number): { Model }?
	local inset = DC.OverlapInset
	local bottom = level - VOXEL / 2
	local top = level + DC.ClearanceHeight
	local size = Vector3.new(VOXEL - inset * 2, top - bottom, VOXEL - inset * 2)
	if LootService.bagInSquare(x, z, VOXEL / 2) then
		return nil
	end
	local loose: { Model } = {}
	for _, part in Workspace:GetPartBoundsInBox(CFrame.new(x, (bottom + top) / 2, z), size, overlap) do
		if part.CanCollide or part:IsDescendantOf(structures) then
			return nil
		end
		local model = part:FindFirstAncestorWhichIsA("Model")
		if model and model:IsDescendantOf(map) and not table.find(loose, model) then
			local pivot = model:GetPivot().Position
			if math.abs(pivot.X - x) <= VOXEL / 2 and math.abs(pivot.Z - z) <= VOXEL / 2 then
				table.insert(loose, model)
			end
		end
	end
	return loose
end

-- Reads the meshed surface of column `index` and its eight neighbours into the height grid (Roblox
-- meshes changed voxels by the next frame) and marks them rough, then lets the loose models follow the
-- ground down.
local function settle(index: number, loose: { Model })
	local grid = MapService.getHeightGrid()
	local before = table.create(#loose)
	for i, model in loose do
		local pivot = model:GetPivot().Position
		before[i] = MapService.heightAt(pivot.X, pivot.Z)
	end
	task.wait()
	for dz = -1, 1 do
		for dx = -1, 1 do
			local other = neighbour(grid, index, dx, dz)
			if other then
				local level = levelOf(grid, other)
				levels[other] = level
				local x, z = TerrainBuilder.columnCentre(grid, other)
				local hit = Workspace:Raycast(
					Vector3.new(x, level + RAY_ABOVE, z),
					Vector3.new(0, -RAY_ABOVE - VOXEL, 0),
					terrainParams
				)
				if hit then
					TerrainBuilder.setHeight(grid, other, hit.Position.Y)
				end
				MapService.markRough(other)
			end
		end
	end
	for i, model in loose do
		local pivot = model:GetPivot()
		local drop = before[i] - MapService.heightAt(pivot.Position.X, pivot.Position.Z)
		model:PivotTo(pivot - Vector3.new(0, drop, 0))
	end
end

-- Takes one voxel off the top of column `index`.
local function lower(index: number, level: number, loose: { Model })
	local grid = MapService.getHeightGrid()
	if originals[index] == nil then
		originals[index] = level
	end
	levels[index] = level - VOXEL
	TerrainBuilder.writeColumn(grid, index, level, level - VOXEL, Enum.Material.Ground)
	task.spawn(settle, index, loose)
end

-- Whether a player or a zombie stands in the column centred at (x, z) between `bottom` and `top`.
local function bodyInside(x: number, z: number, bottom: number, top: number): boolean
	local list: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(list, other.Character)
		end
	end
	characterOverlap.FilterDescendantsInstances = list
	local centre = Vector3.new(x, (bottom + top) / 2, z)
	local size = Vector3.new(VOXEL, top - bottom, VOXEL)
	if #Workspace:GetPartBoundsInBox(CFrame.new(centre), size, characterOverlap) > 0 then
		return true
	end
	local half = VOXEL / 2 + Config.Melee.HitRadius
	for _, body in ZombieService.bodiesNear(centre, VOXEL * 2) do
		local feet = body.y + Config.Melee.HitBottom
		local head = body.y + Config.Melee.HitTop
		if math.abs(body.x - x) < half and math.abs(body.z - z) < half and feet < top and head > bottom then
			return true
		end
	end
	return false
end

-- Whether column `index` was dug and can take one voxel back without rising above its old height or
-- more than MaxStep above a side neighbour.
local function canRaise(grid: TerrainBuilder.HeightGrid, index: number): boolean
	local original = originals[index]
	local raised = levelOf(grid, index) + VOXEL
	if original == nil or raised > original + LEVEL_TOLERANCE then
		return false
	end
	for _, side in SIDES do
		local other = neighbour(grid, index, side[1], side[2])
		if other and levelOf(grid, other) < raised - DC.MaxStep then
			return false
		end
	end
	return true
end

-- The dug column a fill aimed at `p` goes into: the column at `p`, or else the nearest side neighbour
-- that can take it (Roblox rounds a hole's rim over onto the columns beside it).
local function fillTarget(grid: TerrainBuilder.HeightGrid, p: Vector3): number?
	local index = TerrainBuilder.columnAt(grid, p.X, p.Z)
	if index == nil or canRaise(grid, index) then
		return index
	end
	local best: number? = nil
	local bestDistance = math.huge
	for _, side in SIDES do
		local other = neighbour(grid, index, side[1], side[2])
		if other and canRaise(grid, other) then
			local x, z = TerrainBuilder.columnCentre(grid, other)
			local distance = (x - p.X) ^ 2 + (z - p.Z) ^ 2
			if distance < bestDistance then
				best, bestDistance = other, distance
			end
		end
	end
	return best
end

-- Dirt from the hand: raises the dug column the aim points into by one voxel.
local function onFill(player: Player, origin: Vector3, direction: Vector3, itemId: string)
	local now = os.clock()
	if now < (nextFillAt[player] or 0) then
		return
	end
	nextFillAt[player] = now + Config.Build.PlaceCooldown * (1 - Config.Melee.CooldownTolerance)
	local fill = Config.Items[itemId] and Config.Items[itemId].Fill
	if fill == nil then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignored: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignored, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignored
	params.IgnoreWater = true
	params.RespectCanCollide = true
	local result = Workspace:Raycast(origin, direction * Config.Build.MaxPlaceDistance, params)
	if result == nil or result.Instance ~= Workspace.Terrain then
		return
	end
	-- In front of the face hit: a hole's floor, or the hole beside a wall.
	local grid = MapService.getHeightGrid()
	local index = fillTarget(grid, result.Position + result.Normal * DC.SurfaceOffset)
	if index == nil or not canRaise(grid, index) then
		return
	end
	local level = levelOf(grid, index)
	local raised = level + VOXEL
	local x, z = TerrainBuilder.columnCentre(grid, index)
	local loose = looseOn(x, z, level)
	if loose == nil or bodyInside(x, z, level - VOXEL / 2, raised + VOXEL / 2) then
		return
	end
	if not InventoryService.consumeHeld(player, 1) then
		return
	end
	columns[index] = nil
	levels[index] = raised
	TerrainBuilder.writeColumn(grid, index, level, raised, (Enum.Material :: any)[fill])
	task.spawn(settle, index, loose)
end

local function onWorldHit(player: Player, result: RaycastResult, _toolId: string, tool: Config.ToolDef)
	if result.Instance ~= Workspace.Terrain then
		return
	end
	local node = DC.Materials[result.Material.Name]
	if node == nil then
		return
	end
	local grid = MapService.getHeightGrid()
	local p = result.Position - result.Normal * DC.SurfaceOffset
	local index = TerrainBuilder.columnAt(grid, p.X, p.Z)
	if index == nil then
		return
	end
	local x, z = TerrainBuilder.columnCentre(grid, index)
	local level = levelOf(grid, index)
	if p.Y < level - DC.TopReach or level - VOXEL < floorHeight or not withinStep(grid, index, level - VOXEL) then
		return
	end
	if not HeightField.isPlayable(x, z) or nearWater(x, z) or insideBuilding(x, z) then
		return
	end
	local loose = looseOn(x, z, level)
	if loose == nil then
		return
	end

	local column = columns[index]
	if column == nil then
		column = { node = node, damage = 0 }
		columns[index] = column
	end
	local def = column.node
	-- Digging stone is heard like mining; digging earth is not (HarvestService).
	if def.Material == "Stone" then
		ThreatService.emit("Harvest", result.Position, player)
	end
	local before = column.damage
	local after = math.min(def.Health, before + Harvest.blockDamage(tool.BlockDamage, tool.Materials[def.Material]))
	column.damage = after
	for _, drop in def.Harvest do
		local count = Harvest.payout(random:NextInteger(drop.Min, drop.Max), def.Health, before, after)
		LootService.giveOrDrop(player, drop.Id, count, SOURCE)
	end
	if after < def.Health then
		return
	end
	columns[index] = nil
	for _, drop in def.Destroy do
		LootService.giveOrDrop(player, drop.Id, random:NextInteger(drop.Min, drop.Max), SOURCE)
	end
	lower(index, level, loose)
end

function DigService.init() end

function DigService.start()
	map = MapService.getMap()
	structures = Workspace:WaitForChild(Config.Build.FolderName)
	floorHeight = TerrainBuilder.floorHeight(DC.BedrockLayers)
	overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { map, structures }
	overlap.RespectCanCollide = false
	characterOverlap = OverlapParams.new()
	characterOverlap.FilterType = Enum.RaycastFilterType.Include
	terrainParams = RaycastParams.new()
	terrainParams.FilterType = Enum.RaycastFilterType.Include
	terrainParams.FilterDescendantsInstances = { Workspace.Terrain }
	ToolService.onWorldHit(onWorldHit)
	for id, item in Config.Items do
		if item.Fill then
			ToolService.onUse(id, onFill)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		nextFillAt[player] = nil
	end)
end

return DigService
