--!strict
-- BuildService: player-built blocks on the 4-stud grid (Shared/BuildGrid), 7DTD style. A frame, a
-- ladder, a door or a farm plot in the hand is placed with "use" (ToolService hands it over with the
-- head position and the aim). A door takes its cell and the one above, hangs on the side its builder
-- stood on and opens and closes with the interact key; closed, it is a wall zombies path through and
-- break, open, they walk through it (7DTD zombies never open doors). A farm plot is a low slab crops
-- grow on (FarmService); it blocks nobody. Generators, lamps and storage crates are smaller boxes on
-- the floor of their cell (PowerService and StorageService give them their prompts); lamps let
-- zombies by. The stone axe upgrades a frame to a wood block (3 hits, 4 Lumber) and repairs damaged
-- blocks with wood; other tools and the fist damage them.
-- Zombies path through the weakest wall and break it (ZombieService structure cells); blocks that
-- lose their way to the ground fall.
--
-- Placement is checked on the server: the held item, the reach, a free cell (no block, map part,
-- character or zombie; a block may sink into the floor or kerb it stands on), playable dry ground,
-- only the ground storey inside town buildings (players fortify houses; upper floors keep their own
-- zombie paths), and support from the ground or a neighbouring block. Blocks are not saved yet
-- (persistence step).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildGrid = require(Shared.BuildGrid)
local Config = require(Shared.Config)
local Harvest = require(Shared.Harvest)
local HeightField = require(Shared.World.HeightField)

local Localization = require(Shared.Localization)

local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local BuildingKit = require(script.Parent.Parent.World.BuildingKit)
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
	-- Doors: the key of the cell above (it maps to the same block), the side the panel hangs on and
	-- whether it is open.
	top: number?,
	side: number,
	open: boolean,
	prompt: ProximityPrompt?,
}

local BuildService = {}

local folder: Folder
local blocks: { [number]: Block } = {}
local count = 0
local nextPlaceAt: { [Player]: number } = {}
local groundParams: RaycastParams
local mapOverlap: OverlapParams
local doorLimiter: RateLimiter.RateLimiter
local removedCallbacks: { (key: number) -> () } = {}
local placedCallbacks: { (key: number, kind: string, part: BasePart) -> () } = {}

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

-- Ladders, open doors, farm plots and lamps let zombies through.
local function passable(block: Block): boolean
	local def = BC.Blocks[block.kind]
	return def.Climbable == true or def.Plot == true or def.Passable == true or block.open
end

-- Recomputes whether the column (cx, cz) blocks zombies and how costly it is to path through.
local function updateColumn(cx: number, cz: number)
	local x, _, z = BuildGrid.center(cx, 0, cz)
	local ground = MapService.groundAt(x, z)
	local health = 0
	local blocking = false
	-- A door fills two cells but counts once.
	local counted: { [Block]: boolean } = {}
	for cy = math.floor((ground - SIZE) / SIZE), math.floor((ground + BC.BodyHeight) / SIZE) do
		local block = blocks[BuildGrid.key(cx, cy, cz)]
		if block and not passable(block) and not counted[block] and BuildGrid.obstructs(cy * SIZE, ground) then
			counted[block] = true
			blocking = true
			health += block.health
		end
	end
	ZombieService.setStructure(x, z, if blocking then BuildGrid.pathCost(health) else nil)
end

local function removeBlock(block: Block)
	if blocks[block.key] ~= block then
		return
	end
	for _, callback in removedCallbacks do
		task.spawn(callback, block.key)
	end
	blocks[block.key] = nil
	if block.top then
		blocks[block.top] = nil
	end
	count -= 1
	block.part:Destroy()
	updateColumn(block.cx, block.cz)
end

-- Destroys a block, then every block that no longer reaches the ground (they fall and break).
local function destroyBlock(block: Block)
	removeBlock(block)
	for _, removed in { block.key, block.top } do
		for _, key in BuildGrid.unsupported(blocks :: any, removed) do
			local falling = blocks[key]
			if falling then
				removeBlock(falling)
			end
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

local function characterInside(center: CFrame, size: Vector3): boolean
	local characters = OverlapParams.new()
	characters.FilterType = Enum.RaycastFilterType.Include
	local list: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(list, other.Character)
		end
	end
	characters.FilterDescendantsInstances = list
	return #Workspace:GetPartBoundsInBox(center, size, characters) > 0
end

local function setDoorOpen(block: Block, open: boolean)
	block.open = open
	block.part.CFrame = BuildGrid.doorCFrame(block.cx, block.cy, block.cz, block.side, open, BC.DoorThickness)
	if block.prompt then
		block.prompt.ActionText = Localization.get(if open then "DoorClose" else "DoorOpen")
	end
	updateColumn(block.cx, block.cz)
end

-- The interact key on a door: opens it, or closes it unless someone stands in its way.
local function onDoorTriggered(player: Player, block: Block)
	if not doorLimiter:allow(player) or blocks[block.key] ~= block then
		return
	end
	local character = player.Character
	local root = character and character.PrimaryPart
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	local x, y, z = BuildGrid.center(block.cx, block.cy, block.cz)
	-- The prompt sits on the panel; the server measures to the doorway's centre with some slack.
	if (root.Position - Vector3.new(x, y + SIZE / 2, z)).Magnitude > BC.DoorReach + SIZE then
		return
	end
	if block.open then
		local inner = Vector3.new(SIZE, SIZE * 2, SIZE) - Vector3.one * BC.OverlapInset * 2
		local center = CFrame.new(x, y + SIZE / 2, z)
		if characterInside(center, inner) or zombieInside(x, y, z) or zombieInside(x, y + SIZE, z) then
			return
		end
	end
	setDoorOpen(block, not block.open)
end

local function createBlock(cx: number, cy: number, cz: number, kind: string, grounded: boolean, side: number)
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
	if def.Door then
		part.Size = Vector3.new(SIZE, SIZE * 2, BC.DoorThickness)
		part.CFrame = BuildGrid.doorCFrame(cx, cy, cz, side, false, BC.DoorThickness)
	elseif def.Plot then
		part.Size = Vector3.new(SIZE, BC.PlotHeight, SIZE)
		part.CFrame = BuildGrid.plotCFrame(cx, cy, cz, MapService.groundAt(x, z), BC.PlotHeight)
	elseif def.Size then
		part.Size = Vector3.new(def.Size[1], def.Size[2], def.Size[3])
		part.CFrame = BuildGrid.plotCFrame(cx, cy, cz, MapService.groundAt(x, z), def.Size[2])
	else
		part.Size = Vector3.one * SIZE
		part.CFrame = CFrame.new(x, y, z)
	end
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
		top = if def.Door then BuildGrid.key(cx, cy + 1, cz) else nil,
		side = side,
		open = false,
		prompt = nil,
	}
	styleBlock(block)
	if def.Door then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = Localization.get("DoorOpen")
		prompt.ObjectText = Localization.get(`Item{kind}`)
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = BC.DoorReach
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function(player)
			onDoorTriggered(player, block)
		end)
		prompt.Parent = part
		block.prompt = prompt
	end
	part.Parent = folder
	blocks[key] = block
	if block.top then
		blocks[block.top] = block
	end
	count += 1
	updateColumn(cx, cz)
	setTrace()
	for _, callback in placedCallbacks do
		task.spawn(callback, key, kind, part)
	end
end

-- The highest cell floor that takes blocks inside a town building: its ground storey only.
local function buildTop(info: MapService.BuildingInfo): number
	return info.baseY + BuildingKit.FloorTop + (BC.IndoorCells - 1) * SIZE
end

local function indoorBlocked(cx: number, cy: number, cz: number): boolean
	for _, info in MapService.getBuildings() do
		if BuildGrid.indoorBlocked(cx, cy, cz, info.minX, info.minZ, info.maxX, info.maxZ, buildTop(info)) then
			return true
		end
	end
	return false
end

-- Whether cell (cx, cy, cz) is free for a block: no block, map part, character or zombie in it (it may
-- sink into the surface it stands on), on playable dry ground, and inside a town building only on the
-- ground storey.
local function cellFree(cx: number, cy: number, cz: number): boolean
	if blocks[BuildGrid.key(cx, cy, cz)] then
		return false
	end
	local x, y, z = BuildGrid.center(cx, cy, cz)
	if not HeightField.isPlayable(x, z) or HeightField.isWater(x, z) or indoorBlocked(cx, cy, cz) then
		return false
	end
	local rx, ry, rz, length = BuildGrid.sinkRay(cx, cy, cz)
	local surface = Workspace:Raycast(Vector3.new(rx, ry, rz), Vector3.new(0, -length, 0), groundParams)
	local bottom, top = BuildGrid.clearSpan(cy, if surface then surface.Position.Y else nil)
	local inner = Vector3.new(SIZE - BC.OverlapInset * 2, top - bottom, SIZE - BC.OverlapInset * 2)
	local center = CFrame.new(x, (bottom + top) / 2, z)
	-- Map parts (walls, trunks, props) and characters may not end up inside a block.
	if #Workspace:GetPartBoundsInBox(center, inner, mapOverlap) > 0 then
		return false
	end
	return not characterInside(center, inner) and not zombieInside(x, y, z)
end

-- Whether a block may go into cell (cx, cy, cz); the second value tells if the ground carries it.
local function canPlace(cx: number, cy: number, cz: number): (boolean, boolean)
	if count >= BC.MaxPartsPerWorld or not cellFree(cx, cy, cz) then
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
	if ok and def.Door then
		ok = cellFree(cx, cy + 1, cz)
	end
	if ok and InventoryService.consumeHeld(player, 1) then
		createBlock(cx, cy, cz, itemId, grounded, BuildGrid.sideToward(cx, cz, origin.X, origin.Z))
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
		if block and not passable(block) and BuildGrid.obstructs(cy * SIZE, ground) then
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

-- The key of the farm plot `instance` belongs to and the centre of its top face, or nil.
function BuildService.plotOf(instance: Instance): (number?, Vector3?)
	local block = blockOf(instance)
	if block == nil or not BC.Blocks[block.kind].Plot then
		return nil, nil
	end
	local part = block.part
	return block.key, part.Position + Vector3.new(0, part.Size.Y / 2, 0)
end

-- The key and kind of the block `instance` is, or nil.
function BuildService.blockAt(instance: Instance): (number?, string?)
	local block = blockOf(instance)
	if block == nil then
		return nil, nil
	end
	return block.key, block.kind
end

-- Registers a listener for placed blocks: key, kind and part.
function BuildService.onPlaced(callback: (key: number, kind: string, part: BasePart) -> ())
	table.insert(placedCallbacks, callback)
end

-- Registers a listener for blocks that are removed (destroyed, fallen or cleared), by block key.
function BuildService.onRemoved(callback: (key: number) -> ())
	table.insert(removedCallbacks, callback)
end

-- Debug: removes every block.
function BuildService.clear()
	for _, block in blocks do
		removeBlock(block)
	end
	setTrace()
end

function BuildService.init()
	doorLimiter = RateLimiter.new(BC.DoorTogglesPerSecond)
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
	for _, info in MapService.getBuildings() do
		info.model:SetAttribute("BuildMin", Vector2.new(info.minX, info.minZ))
		info.model:SetAttribute("BuildMax", Vector2.new(info.maxX, info.maxZ))
		info.model:SetAttribute("BuildTop", buildTop(info))
		CollectionService:AddTag(info.model, BC.BuildingTag)
	end
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
