--!strict
-- BuildService: player-built blocks on the 4-stud grid (Shared/BuildGrid), 7DTD style. A frame or a
-- ladder in the hand is placed with "use" (ToolService hands it over with the head position and the
-- aim). The stone axe upgrades a frame to a wood block (3 hits, 4 Lumber) and repairs damaged blocks
-- with wood; other tools and the fist damage them. Zombies path through the weakest wall and break it
-- (ZombieService structure cells); blocks that lose their way to the ground fall.
--
-- Placement is checked on the server: the held item, the reach, a free cell (no block, map part,
-- character or zombie), the playable ground outside town buildings, and support from the ground or a
-- neighbouring block. Blocks are not saved yet (persistence step).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildGrid = require(Shared.BuildGrid)
local Config = require(Shared.Config)
local Harvest = require(Shared.Harvest)
local HeightField = require(Shared.World.HeightField)

local InventoryService = require(script.Parent.InventoryService)
local MapService = require(script.Parent.MapService)
local ThreatService = require(script.Parent.ThreatService)
local ToolService = require(script.Parent.ToolService)
local ZombieService = require(script.Parent.ZombieService)

local BC = Config.Build
local SIZE = BC.GridSize
local TRACE_SOURCE = "Build"
-- Zombie hit volume around its root, for keeping blocks out of zombies (Config.Melee).
local ZOMBIE_RADIUS = Config.Melee.HitRadius

type Block = {
	key: number,
	cx: number,
	cy: number,
	cz: number,
	kind: string,
	health: number,
	grounded: boolean,
	-- Stone axe hits toward the next tier.
	upgrade: number,
	part: BasePart,
}

local BuildService = {}

local folder: Folder
local blocks: { [number]: Block } = {}
local count = 0
local nextPlaceAt: { [Player]: number } = {}
local groundParams: RaycastParams
local mapOverlap: OverlapParams

local function setTrace()
	ThreatService.setTraceSource(TRACE_SOURCE, count * Config.Threat.Trace.PerBuildPart)
end

local function blockOf(instance: Instance): Block?
	if instance.Parent ~= folder then
		return nil
	end
	local key = instance:GetAttribute("Key")
	return if typeof(key) == "number" then blocks[key] else nil
end

local function styleBlock(block: Block)
	local def = BC.Blocks[block.kind]
	local part = block.part
	part.Name = block.kind
	part.Material = (Enum.Material :: any)[def.Material]
	part.Color = Color3.new(def.Color[1], def.Color[2], def.Color[3])
	part.Transparency = def.Transparency or 0
	part:SetAttribute("Kind", block.kind)
	part:SetAttribute("Health", block.health)
	part:SetAttribute("MaxHealth", def.Health)
end

-- Recomputes whether the column (cx, cz) blocks zombies and how costly it is to path through.
local function updateColumn(cx: number, cz: number)
	local x, _, z = BuildGrid.center(cx, 0, cz)
	local ground = MapService.groundAt(x, z)
	local health = 0
	local blocking = false
	for cy = math.floor((ground - SIZE) / SIZE), math.floor((ground + BC.BodyHeight) / SIZE) do
		local block = blocks[BuildGrid.key(cx, cy, cz)]
		if block and not BC.Blocks[block.kind].Climbable and BuildGrid.obstructs(cy * SIZE, ground) then
			blocking = true
			health += block.health
		end
	end
	ZombieService.setStructure(x, z, if blocking then BuildGrid.pathCost(health) else nil)
end

local function removeBlock(block: Block)
	blocks[block.key] = nil
	count -= 1
	block.part:Destroy()
	updateColumn(block.cx, block.cz)
end

-- Destroys a block, then every block that no longer reaches the ground (they fall and break).
local function destroyBlock(block: Block)
	removeBlock(block)
	for _, key in BuildGrid.unsupported(blocks :: any, block.key) do
		local falling = blocks[key]
		if falling then
			removeBlock(falling)
		end
	end
	setTrace()
end

local function damageBlock(block: Block, amount: number)
	block.health -= amount
	if block.health <= 0 then
		destroyBlock(block)
		return
	end
	block.part:SetAttribute("Health", block.health)
	updateColumn(block.cx, block.cz)
end

local function createBlock(cx: number, cy: number, cz: number, kind: string, grounded: boolean)
	local x, y, z = BuildGrid.center(cx, cy, cz)
	local def = BC.Blocks[kind]
	local part: BasePart
	if def.Climbable then
		-- Roblox characters climb trusses by themselves.
		local truss = Instance.new("TrussPart")
		truss.Style = Enum.Style.AlternatingSupports
		part = truss
	else
		part = Instance.new("Part")
	end
	part.Anchored = true
	part.Size = Vector3.one * SIZE
	part.CFrame = CFrame.new(x, y, z)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local key = BuildGrid.key(cx, cy, cz)
	part:SetAttribute("Key", key)
	part:SetAttribute("CellX", cx)
	part:SetAttribute("CellY", cy)
	part:SetAttribute("CellZ", cz)
	local block: Block = {
		key = key,
		cx = cx,
		cy = cy,
		cz = cz,
		kind = kind,
		health = def.Health,
		grounded = grounded,
		upgrade = 0,
		part = part,
	}
	styleBlock(block)
	part.Parent = folder
	blocks[key] = block
	count += 1
	updateColumn(cx, cz)
	setTrace()
end

local function insideBuilding(cx: number, cz: number): boolean
	local minX, minZ = cx * SIZE, cz * SIZE
	local maxX, maxZ = minX + SIZE, minZ + SIZE
	local m = BC.BuildingMargin
	for _, info in MapService.getBuildings() do
		if maxX > info.minX - m and minX < info.maxX + m and maxZ > info.minZ - m and minZ < info.maxZ + m then
			return true
		end
	end
	return false
end

local function zombieInside(x: number, y: number, z: number): boolean
	local half = SIZE / 2 + ZOMBIE_RADIUS
	for _, body in ZombieService.bodiesNear(Vector3.new(x, y, z), SIZE * 2) do
		local feet = body.y + Config.Melee.HitBottom
		local head = body.y + Config.Melee.HitTop
		local overlapsXZ = math.abs(body.x - x) < half and math.abs(body.z - z) < half
		if overlapsXZ and feet < y + SIZE / 2 and head > y - SIZE / 2 then
			return true
		end
	end
	return false
end

-- Whether a block may go into cell (cx, cy, cz); the second value tells if the ground carries it.
local function canPlace(cx: number, cy: number, cz: number): (boolean, boolean)
	if blocks[BuildGrid.key(cx, cy, cz)] or count >= BC.MaxPartsPerWorld then
		return false, false
	end
	local x, y, z = BuildGrid.center(cx, cy, cz)
	if not HeightField.isPlayable(x, z) or HeightField.isWater(x, z) or insideBuilding(cx, cz) then
		return false, false
	end
	local inner = Vector3.one * (SIZE - BC.OverlapInset * 2)
	local center = CFrame.new(x, y, z)
	-- Map parts (walls, trunks, props) and characters may not end up inside a block.
	if #Workspace:GetPartBoundsInBox(center, inner, mapOverlap) > 0 then
		return false, false
	end
	local characters = OverlapParams.new()
	characters.FilterType = Enum.RaycastFilterType.Include
	local list: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(list, other.Character)
		end
	end
	characters.FilterDescendantsInstances = list
	if #Workspace:GetPartBoundsInBox(center, inner, characters) > 0 or zombieInside(x, y, z) then
		return false, false
	end
	local gx, gy, gz, length = BuildGrid.groundRay(cx, cy, cz)
	local grounded = Workspace:Raycast(Vector3.new(gx, gy, gz), Vector3.new(0, -length, 0), groundParams) ~= nil
	if grounded then
		return true, true
	end
	for _, step in BuildGrid.NEIGHBOURS do
		if blocks[BuildGrid.key(cx + step[1], cy + step[2], cz + step[3])] then
			return true, false
		end
	end
	return false, false
end

local function onPlace(player: Player, origin: Vector3, direction: Vector3, itemId: string)
	local now = os.clock()
	if now < (nextPlaceAt[player] or 0) then
		return
	end
	nextPlaceAt[player] = now + BC.PlaceCooldown * (1 - Config.Melee.CooldownTolerance)
	local def = BC.Blocks[itemId]
	if def == nil or not def.Placeable then
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
	local result = Workspace:Raycast(origin, direction * BC.MaxPlaceDistance, params)
	if result == nil then
		return
	end
	local hit = blockOf(result.Instance)
	local p, n = result.Position, result.Normal
	local cx, cy, cz =
		BuildGrid.target(p.X, p.Y, p.Z, n.X, n.Y, n.Z, if hit then { hit.cx, hit.cy, hit.cz } else nil)
	local ok, grounded = canPlace(cx, cy, cz)
	if ok and InventoryService.consumeHeld(player, 1) then
		createBlock(cx, cy, cz, itemId, grounded)
	end
end

-- Stone axe on a block: repair it when damaged, otherwise work on its upgrade.
local function work(player: Player, block: Block)
	local def = BC.Blocks[block.kind]
	if block.health < def.Health then
		local repaired = math.min(BC.RepairPerHit, def.Health - block.health)
		-- 7DTD charges Repair.Count for a full repair; a hit pays its share, rounded up.
		local cost = math.ceil(repaired * def.Repair.Count / def.Health)
		if InventoryService.take(player, { [def.Repair.Id] = cost }) then
			block.health += repaired
			block.part:SetAttribute("Health", block.health)
			updateColumn(block.cx, block.cz)
		end
		return
	end
	local nextKind = def.UpgradeTo
	local upgrade = def.Upgrade
	if nextKind == nil or upgrade == nil or InventoryService.count(player, upgrade.Id) < upgrade.Count then
		return
	end
	block.upgrade += 1
	if block.upgrade < BC.UpgradeHits then
		return
	end
	if InventoryService.take(player, { [upgrade.Id] = upgrade.Count }) then
		block.kind = nextKind
		block.health = BC.Blocks[nextKind].Health
		block.upgrade = 0
		styleBlock(block)
		updateColumn(block.cx, block.cz)
	end
end

local function onWorldHit(player: Player, result: RaycastResult, toolId: string, tool: Config.ToolDef)
	local block = blockOf(result.Instance)
	if block == nil then
		return
	end
	if toolId == BC.UpgradeTool then
		work(player, block)
	else
		damageBlock(block, Harvest.blockDamage(tool.BlockDamage, tool.Materials[BC.HarvestMaterial]))
	end
end

-- A zombie breaking through the column at (x, z): it hits the weakest block in its way.
local function onStructureHit(x: number, z: number, damage: number)
	local cx, _, cz = BuildGrid.cellOf(x, 0, z)
	local ground = MapService.groundAt(x, z)
	local weakest: Block? = nil
	for cy = math.floor((ground - SIZE) / SIZE), math.floor((ground + BC.BodyHeight) / SIZE) do
		local block = blocks[BuildGrid.key(cx, cy, cz)]
		if block and not BC.Blocks[block.kind].Climbable and BuildGrid.obstructs(cy * SIZE, ground) then
			if weakest == nil or block.health < weakest.health then
				weakest = block
			end
		end
	end
	if weakest then
		damageBlock(weakest, damage)
	end
end

function BuildService.getCount(): number
	return count
end

-- Debug: removes every block.
function BuildService.clear()
	for _, block in blocks do
		removeBlock(block)
	end
	setTrace()
end

function BuildService.init()
	folder = Instance.new("Folder")
	folder.Name = BC.FolderName
	folder.Parent = Workspace
end

function BuildService.start()
	groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Include
	groundParams.FilterDescendantsInstances = { MapService.getMap(), Workspace.Terrain }
	groundParams.RespectCanCollide = true
	mapOverlap = OverlapParams.new()
	mapOverlap.FilterType = Enum.RaycastFilterType.Include
	mapOverlap.FilterDescendantsInstances = { MapService.getMap() }
	mapOverlap.RespectCanCollide = true
	for id, def in BC.Blocks do
		if def.Placeable then
			ToolService.onUse(id, onPlace)
		end
	end
	ToolService.onWorldHit(onWorldHit)
	ZombieService.onStructureHit(onStructureHit)
	Players.PlayerRemoving:Connect(function(player)
		nextPlaceAt[player] = nil
	end)
end

return BuildService
