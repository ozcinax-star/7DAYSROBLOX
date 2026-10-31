--!strict
-- LootService: loot bags on the ground (7DTD loot bags) and searchable furniture in town buildings
-- (7DTD loot containers). A dying zombie drops a bag now and then (Shared/Loot), and other services
-- drop items that have no room in an inventory in one. Holding the interact key on a bag or a
-- container searches it: everything that fits goes into the inventory and the rest stays inside.
-- A bag vanishes when it is empty, after Config.Loot.BagSeconds (or its own lifetime), or when too
-- many bags exist (the oldest goes first; bags with their own lifetime, death bags, are kept).
-- A container is filled on its first search and again Config.Loot.ContainerRespawnDays in-game days
-- after it was last filled; all players share it. What bags and containers hold is server-only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Inventory = require(Shared.Inventory)
local Localization = require(Shared.Localization)
local Loot = require(Shared.Loot)
local Types = require(Shared.Types)

local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local DayNightService = require(script.Parent.DayNightService)
local InventoryService = require(script.Parent.InventoryService)
local MapService = require(script.Parent.MapService)
local ZombieService = require(script.Parent.ZombieService)

local LC = Config.Loot
-- A search may come from slightly further than the prompt's range (the character moves on the server).
local SEARCH_TOLERANCE = 2
-- The hold reaches the server late on both ends; accept a search after this share of the hold time.
local HOLD_TOLERANCE = 0.75
-- The ground is looked for from this far above the drop point down to this far below it (studs).
local GROUND_UP = 2
local GROUND_DOWN = 40
-- Looks: a fabric sack with a tied neck.
local SACK_SIZE = 1.4
local NECK_SIZE = Vector3.new(0.5, 0.6, 0.6)
local SACK_COLOR = Color3.fromRGB(78, 62, 44)
local TIE_COLOR = Color3.fromRGB(150, 128, 92)

type Bag = {
	model: Model,
	sack: BasePart,
	inventory: Inventory.Inventory,
	-- The despawn timer, cancelled when the bag goes earlier.
	expiry: thread?,
	-- Has its own lifetime and is never removed by the bag cap (death bags).
	kept: boolean,
}

type Container = {
	model: Model,
	-- Where the prompt sits and searches are measured from (just above the furniture).
	point: Attachment,
	prompt: ProximityPrompt,
	kind: string,
	-- The Loot attribute of the building it stands in.
	buildingLoot: string?,
	inventory: Inventory.Inventory?,
	filledDay: number,
}

local LootService = {}

-- Oldest first.
local bags: { Bag } = {}
local containers: { Container } = {}
local holdStarted: { [Player]: number } = {}
local folder: Folder
local groundParams: RaycastParams
local searchLimiter: RateLimiter.RateLimiter
local random = Random.new()

local function rand(): number
	return random:NextNumber()
end

local function remove(bag: Bag)
	local index = table.find(bags, bag)
	if index == nil then
		return
	end
	table.remove(bags, index)
	local expiry = bag.expiry
	if expiry and coroutine.running() ~= expiry then
		task.cancel(expiry)
	end
	bag.model:Destroy()
end

local function isEmpty(inventory: Inventory.Inventory): boolean
	for _, slot in inventory.slots do
		if slot then
			return false
		end
	end
	return true
end

-- The ground under `position`: terrain, floors and upper storeys; grass, bushes and zombies are skipped.
local function groundAt(position: Vector3): Vector3
	local origin = position + Vector3.new(0, GROUND_UP, 0)
	local result = Workspace:Raycast(origin, Vector3.new(0, -(GROUND_UP + GROUND_DOWN), 0), groundParams)
	return if result then result.Position else position
end

local function part(model: Model, name: string, shape: Enum.PartType, size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Fabric
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = model
	return p
end

-- Whether a finished hold on a prompt at `position` is a valid search: the hold lasted, the player
-- is alive, near and under the rate limit.
local function canSearch(player: Player, position: Vector3): boolean
	local started = holdStarted[player]
	holdStarted[player] = nil
	if not searchLimiter:allow(player) then
		return false
	end
	if started == nil or os.clock() - started < LC.SearchSeconds * HOLD_TOLERANCE then
		return false
	end
	local character = player.Character
	local root = character and character.PrimaryPart
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root == nil or humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	return (root.Position - position).Magnitude <= LC.SearchDistance + SEARCH_TOLERANCE
end

-- Moves everything that fits from `inventory` into the player's.
local function takeAll(player: Player, inventory: Inventory.Inventory)
	local slots = inventory.slots
	for index, slot in slots do
		if slot then
			local left = InventoryService.give(player, slot.id, slot.count, slot.source, slot.durability)
			if left <= 0 then
				slots[index] = false
			else
				slot.count = left
			end
		end
	end
end

local function onSearch(player: Player, bag: Bag)
	if table.find(bags, bag) == nil or not canSearch(player, bag.sack.Position) then
		return
	end
	takeAll(player, bag.inventory)
	if isEmpty(bag.inventory) then
		remove(bag)
	end
end

-- A hold-to-search prompt (the server re-checks the hold time and the distance).
local function newPrompt(objectText: string, onTriggered: (Player) -> ()): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Localization.get("LootSearch")
	prompt.ObjectText = objectText
	prompt.HoldDuration = LC.SearchSeconds
	prompt.MaxActivationDistance = LC.SearchDistance
	prompt.RequiresLineOfSight = false
	prompt.PromptButtonHoldBegan:Connect(function(player)
		holdStarted[player] = os.clock()
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player)
		-- Released before the end: the next search starts its own hold.
		task.defer(function()
			holdStarted[player] = nil
		end)
	end)
	prompt.Triggered:Connect(onTriggered)
	return prompt
end

local function newBag(ground: Vector3, seconds: number, kept: boolean): Bag
	local model = Instance.new("Model")
	model.Name = "LootBag"
	local center = ground + Vector3.new(0, SACK_SIZE * 0.42, 0)
	local yaw = CFrame.Angles(0, random:NextNumber() * math.pi * 2, 0)
	local sack = part(model, "Sack", Enum.PartType.Ball, Vector3.one * SACK_SIZE, SACK_COLOR)
	sack.CFrame = CFrame.new(center) * yaw
	local neck = part(model, "Neck", Enum.PartType.Cylinder, NECK_SIZE, SACK_COLOR)
	neck.CFrame = CFrame.new(center + Vector3.new(0, SACK_SIZE * 0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local tie = part(model, "Tie", Enum.PartType.Cylinder, NECK_SIZE * Vector3.new(0.3, 1.15, 1.15), TIE_COLOR)
	tie.CFrame = neck.CFrame * CFrame.new(-NECK_SIZE.X * 0.2, 0, 0)
	model.PrimaryPart = sack

	local bag: Bag =
		{ model = model, sack = sack, inventory = Inventory.new(0, LC.BagSlots), expiry = nil, kept = kept }
	local prompt = newPrompt(Localization.get("LootBag"), function(player)
		onSearch(player, bag)
	end)
	prompt.Parent = sack

	model.Parent = folder
	bag.expiry = task.delay(seconds, remove, bag)
	table.insert(bags, bag)
	-- Over the cap the oldest bag goes, unless it is kept.
	local index = 1
	while #bags > LC.MaxBags and index <= #bags do
		if bags[index].kept then
			index += 1
		else
			remove(bags[index])
		end
	end
	return bag
end

-- The bag closest to `position` within `distance` studs, or nil.
local function bagNear(position: Vector3, distance: number): Bag?
	local best: Bag? = nil
	local bestDistance = distance
	for _, bag in bags do
		local d = (bag.sack.Position - position).Magnitude
		if d <= bestDistance then
			best = bag
			bestDistance = d
		end
	end
	return best
end

-- Puts `stacks` in a bag on the ground below `position`. With `merge`, a bag within
-- Config.Loot.MergeDistance is topped up first. A new bag lasts Config.Loot.BagSeconds; given its own
-- `seconds`, it lasts that long and the bag cap never removes it. Returns how many items did not fit.
function LootService.drop(position: Vector3, stacks: { Inventory.Stack }, merge: boolean, seconds: number?): number
	local ground = groundAt(position)
	local bag = if merge then bagNear(ground, LC.MergeDistance) else nil
	local lost = 0
	for _, stack in stacks do
		local left = stack.count
		if bag then
			left = Inventory.add(bag.inventory, stack.id, left, stack.source, stack.durability)
		end
		if left > 0 then
			bag = newBag(ground, seconds or LC.BagSeconds, seconds ~= nil)
			left = Inventory.add(bag.inventory, stack.id, left, stack.source, stack.durability)
		end
		lost += left
	end
	return lost
end

-- Gives `count` of `id` to the player; what has no room drops in a bag at their feet (7DTD drops it on
-- the ground).
function LootService.giveOrDrop(player: Player, id: string, count: number, source: Types.ItemSource)
	if count <= 0 then
		return
	end
	local left = InventoryService.give(player, id, count, source)
	local character = player.Character
	local root = character and character.PrimaryPart
	if left > 0 and root then
		LootService.drop(root.Position, { { id = id, count = left, source = source } }, true)
	end
end

-- Whether a bag lies within the square of half-width `half` around (x, z) (digging leaves its ground).
function LootService.bagInSquare(x: number, z: number, half: number): boolean
	for _, bag in bags do
		local p = bag.sack.Position
		if math.abs(p.X - x) <= half and math.abs(p.Z - z) <= half then
			return true
		end
	end
	return false
end

-- Number of bags on the ground (debug overlay, tests).
function LootService.count(): number
	return #bags
end

-- Number of searchable furniture pieces (tests).
function LootService.containerCount(): number
	return #containers
end

local function containerName(container: Container): string
	local name = Localization.get(`Container{container.kind}`)
	if container.inventory and isEmpty(container.inventory) then
		return Localization.get("ContainerEmpty", { name = name })
	end
	return name
end

-- Whether nothing solid but the furniture itself stands between the player's head and the point a
-- container is searched from (no searching through walls).
local function inSight(player: Player, container: Container): boolean
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if character == nil or head == nil or not head:IsA("BasePart") then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, container.model }
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local offset = container.point.WorldPosition - head.Position
	return Workspace:Raycast(head.Position, offset, params) == nil
end

-- What the container holds, rolled first when it was never filled or is due a refill.
local function fill(container: Container): Inventory.Inventory
	local day = DayNightService.getState().day
	if container.inventory == nil or day - container.filledDay >= LC.ContainerRespawnDays then
		local inventory = Inventory.new(0, LC.BagSlots)
		for _, stack in Loot.rollContainer(rand, container.kind, container.buildingLoot) do
			Inventory.add(inventory, stack.id, stack.count, stack.source, stack.durability)
		end
		container.inventory = inventory
		container.filledDay = day
	end
	return container.inventory :: Inventory.Inventory
end

local function onSearchContainer(player: Player, container: Container)
	if not canSearch(player, container.point.WorldPosition) or not inSight(player, container) then
		return
	end
	takeAll(player, fill(container))
	container.prompt.ObjectText = containerName(container)
end

-- Forgets the container furniture `model` and drops what it holds in a bag where it was searched from
-- (HarvestService breaks furniture; a broken 7DTD container drops its contents). Breaking pays what
-- searching would have. Does nothing for furniture that is not a container.
function LootService.spillContainer(model: Model)
	for index, container in containers do
		if container.model ~= model then
			continue
		end
		table.remove(containers, index)
		local stacks: { Inventory.Stack } = {}
		for _, slot in fill(container).slots do
			if slot then
				table.insert(stacks, slot)
			end
		end
		if #stacks > 0 then
			LootService.drop(container.point.WorldPosition, stacks, true)
		end
		return
	end
end

-- The Loot attribute of the building model `model` stands in.
local function buildingLootOf(model: Model): string?
	local parent = model.Parent
	while parent and parent ~= Workspace do
		local loot = parent:GetAttribute("Loot")
		if typeof(loot) == "string" then
			return loot
		end
		parent = parent.Parent
	end
	return nil
end

-- Gives every searchable piece of furniture on the map its prompt.
local function addContainers(map: Instance)
	for _, model in map:GetDescendants() do
		local furniture = model:GetAttribute("Furniture")
		local kind = if typeof(furniture) == "string" then LC.ContainerFurniture[furniture] else nil
		if kind == nil or not model:IsA("Model") then
			continue
		end
		local base = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		if base == nil then
			continue
		end
		-- Furniture pivots face their front (-Z): the prompt floats just in front of it, where the head
		-- of a player in the room sees it. Prompts skip the line-of-sight check (a third-person camera
		-- behind a window would hide them); the server checks the head's view instead.
		local box, size = model:GetBoundingBox()
		local front = (box * CFrame.new(0, 0, -size.Z / 2 - LC.ContainerPromptGap)).Position
		local floor = box.Position.Y - size.Y / 2
		local point = Instance.new("Attachment")
		point.Name = "SearchPoint"
		point.Parent = base
		point.WorldPosition =
			Vector3.new(front.X, floor + math.min(size.Y / 2, LC.ContainerPromptMaxHeight), front.Z)
		local container: Container? = nil
		local prompt = newPrompt(Localization.get(`Container{kind}`), function(player)
			if container then
				onSearchContainer(player, container)
			end
		end)
		container = {
			model = model,
			point = point,
			prompt = prompt,
			kind = kind,
			buildingLoot = buildingLootOf(model),
			inventory = nil,
			filledDay = 0,
		}
		prompt.Parent = point
		table.insert(containers, container :: Container)
	end
end

function LootService.init()
	searchLimiter = RateLimiter.new(LC.SearchesPerSecond)
	folder = Instance.new("Folder")
	folder.Name = "LootBags"
	folder.Parent = Workspace
end

function LootService.start()
	groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Include
	groundParams.FilterDescendantsInstances = {
		MapService.getMap(),
		Workspace.Terrain,
		Workspace:WaitForChild(Config.Build.FolderName),
	}
	groundParams.RespectCanCollide = true
	addContainers(MapService.getMap())
	ZombieService.onDied(function(x, y, z)
		local stacks = Loot.rollZombie(rand)
		if stacks then
			LootService.drop(Vector3.new(x, y, z), stacks, false)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		holdStarted[player] = nil
	end)
end

return LootService
