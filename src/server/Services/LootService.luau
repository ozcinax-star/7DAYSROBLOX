--!strict
-- LootService: loot bags on the ground (7DTD loot bags). A dying zombie drops one now and then
-- (Shared/Loot), and other services drop items that have no room in an inventory in one. Holding the
-- interact key on a bag searches it: everything that fits goes into the inventory and the rest stays
-- in the bag. A bag vanishes when it is empty, after Config.Loot.BagSeconds, or when too many bags
-- exist (the oldest goes first). What a bag holds is known only to the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Inventory = require(Shared.Inventory)
local Localization = require(Shared.Localization)
local Loot = require(Shared.Loot)

local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
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
}

local LootService = {}

-- Oldest first.
local bags: { Bag } = {}
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

local function isEmpty(bag: Bag): boolean
	for _, slot in bag.inventory.slots do
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

local function onSearch(player: Player, bag: Bag)
	local started = holdStarted[player]
	holdStarted[player] = nil
	if not searchLimiter:allow(player) or table.find(bags, bag) == nil then
		return
	end
	if started == nil or os.clock() - started < LC.SearchSeconds * HOLD_TOLERANCE then
		return
	end
	local character = player.Character
	local root = character and character.PrimaryPart
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	if (root.Position - bag.sack.Position).Magnitude > LC.SearchDistance + SEARCH_TOLERANCE then
		return
	end
	local slots = bag.inventory.slots
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
	if isEmpty(bag) then
		remove(bag)
	end
end

local function newBag(ground: Vector3): Bag
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

	local bag: Bag = { model = model, sack = sack, inventory = Inventory.new(0, LC.BagSlots), expiry = nil }
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Localization.get("LootSearch")
	prompt.ObjectText = Localization.get("LootBag")
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
	prompt.Triggered:Connect(function(player)
		onSearch(player, bag)
	end)
	prompt.Parent = sack

	model.Parent = folder
	bag.expiry = task.delay(LC.BagSeconds, remove, bag)
	table.insert(bags, bag)
	while #bags > LC.MaxBags do
		remove(bags[1])
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
-- Config.Loot.MergeDistance is topped up first. Returns how many items did not fit in any bag.
function LootService.drop(position: Vector3, stacks: { Inventory.Stack }, merge: boolean): number
	local ground = groundAt(position)
	local bag = if merge then bagNear(ground, LC.MergeDistance) else nil
	local lost = 0
	for _, stack in stacks do
		local left = stack.count
		if bag then
			left = Inventory.add(bag.inventory, stack.id, left, stack.source, stack.durability)
		end
		if left > 0 then
			bag = newBag(ground)
			left = Inventory.add(bag.inventory, stack.id, left, stack.source, stack.durability)
		end
		lost += left
	end
	return lost
end

-- Number of bags on the ground (debug overlay, tests).
function LootService.count(): number
	return #bags
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
	groundParams.FilterDescendantsInstances = { MapService.getMap(), Workspace.Terrain }
	groundParams.RespectCanCollide = true
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
