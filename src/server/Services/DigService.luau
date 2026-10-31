--!strict
-- DigService: digging the ground (7DTD terrain blocks). A swing that hits the terrain damages the
-- 4-stud column it hit by the tool's block damage for the column's material (Config.Dig). The yield is
-- paid while the column is hit, like a harvest (Shared/Harvest), and at full damage the column's
-- surface drops one voxel (4 studs). Only the top of a column is dug: there are no tunnels (PLAN). A
-- column goes at most Config.Dig.MaxStep below its side neighbours, so a deep hole has to be wide.
--
-- Roads and paving, building footprints, the shore, the ground under trees, rocks, props and placed
-- blocks, and the last voxel above the terrain bottom (bedrock) cannot be dug. Grass standing on a dug
-- column sinks with it. Holes keep their zombie navigation cells: zombies follow the ground height into
-- a hole and out of it.
--
-- Each dug column's voxel height is kept here. Roblox meshes holes rounder than the voxels: the height
-- grid gets the meshed surface at the column centres, read with a ray a frame after the voxels change,
-- and MapService reads heights around a hole with a ray, so zombies stand on what players see.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Harvest = require(Shared.Harvest)
local HeightField = require(Shared.World.HeightField)
local Types = require(Shared.Types)

local TerrainBuilder = require(script.Parent.Parent.World.TerrainBuilder)
local LootService = require(script.Parent.LootService)
local MapService = require(script.Parent.MapService)
local ThreatService = require(script.Parent.ThreatService)
local ToolService = require(script.Parent.ToolService)

local DC = Config.Dig
-- Dug items count as found in the world.
local SOURCE: Types.ItemSource = "Loot"
-- Terrain voxels and height-grid columns are 4 studs.
local VOXEL = 4
-- The surface ray starts this far above a column's voxel height.
local RAY_ABOVE = 20
local SIDES = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- A column being dug: its material is fixed by the first hit, its damage is shared by everyone.
type Column = { node: Config.HarvestNode, damage: number }

local DigService = {}

local columns: { [number]: Column } = {}
-- Voxel surface height of every column dug or next to one; the others still have it in the grid.
local levels: { [number]: number } = {}
local random = Random.new()
local overlap: OverlapParams
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

-- What stands on the column centred at (x, z) with its surface at `level`: nil when a placed block or a
-- collidable map part (tree, rock, prop) keeps it from being dug, otherwise the loose map models
-- (grass) standing on it.
local function looseOn(x: number, z: number, level: number): { Model }?
	local inset = DC.OverlapInset
	local bottom = level - VOXEL / 2
	local top = level + DC.ClearanceHeight
	local size = Vector3.new(VOXEL - inset * 2, top - bottom, VOXEL - inset * 2)
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
	levels[index] = level - VOXEL
	TerrainBuilder.writeColumn(grid, index, level, level - VOXEL, Enum.Material.Ground)
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
	terrainParams = RaycastParams.new()
	terrainParams.FilterType = Enum.RaycastFilterType.Include
	terrainParams.FilterDescendantsInstances = { Workspace.Terrain }
	ToolService.onWorldHit(onWorldHit)
end

return DigService
