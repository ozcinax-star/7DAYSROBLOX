--!strict
-- StorageService: storage crates (7DTD wooden storage). A crate is a build block (BuildService); this
-- service gives it its slots and the "Open" prompt. Opening sends the crate's slots to that player
-- (StorageUpdate) and keeps them as a viewer while they stay in reach and alive; every change goes to
-- every viewer. A viewer takes a crate stack into their inventory, stores one of their own stacks
-- (into a chosen slot or wherever it fits), takes everything or closes it (StorageAction). A broken
-- crate spills its contents into a loot bag. Crates are shared by everyone and not saved yet
-- (persistence step).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Inventory = require(Shared.Inventory)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local BuildService = require(script.Parent.BuildService)
local InventoryService = require(script.Parent.InventoryService)
local LootService = require(script.Parent.LootService)

local SC = Config.Storage
local BC = Config.Build

type Crate = {
	key: number,
	part: BasePart,
	inventory: Inventory.Inventory,
	viewers: { [Player]: boolean },
}

local StorageService = {}

local crates: { [number]: Crate } = {}
local opened: { [Player]: Crate } = {}
local updateRemote: RemoteEvent
local limiter: RateLimiter.RateLimiter
local nextCheckAt = 0

local function isIndex(value: unknown, max: number): boolean
	return typeof(value) == "number" and value == value and value % 1 == 0 and value >= 1 and value <= max
end

-- Whether the player is alive and within reach of the crate.
local function inReach(player: Player, crate: Crate): boolean
	local character = player.Character
	local root = character and character.PrimaryPart
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root == nil or humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	return (root.Position - crate.part.Position).Magnitude <= SC.Reach + BC.GridSize
end

local function close(player: Player)
	local crate = opened[player]
	if crate then
		opened[player] = nil
		crate.viewers[player] = nil
		updateRemote:FireClient(player, false)
	end
end

local function broadcast(crate: Crate)
	local slots = Inventory.copySlots(crate.inventory)
	for viewer in crate.viewers do
		updateRemote:FireClient(viewer, slots)
	end
end

local function onOpen(player: Player, crate: Crate)
	if crates[crate.key] ~= crate or not limiter:allow(player) or not inReach(player, crate) then
		return
	end
	if opened[player] and opened[player] ~= crate then
		close(player)
	end
	opened[player] = crate
	crate.viewers[player] = true
	updateRemote:FireClient(player, Inventory.copySlots(crate.inventory))
end

local function onAction(player: Player, action: unknown, a: unknown, b: unknown)
	if not limiter:allow(player) or typeof(action) ~= "string" then
		return
	end
	local crate = opened[player]
	if crate == nil then
		return
	end
	if action == "Close" then
		close(player)
		return
	end
	if crates[crate.key] ~= crate or not inReach(player, crate) then
		close(player)
		return
	end
	local inventory = InventoryService.get(player)
	if inventory == nil then
		return
	end
	local moved = 0
	if action == "Take" and isIndex(a, SC.Slots) then
		moved = Inventory.transfer(crate.inventory, a :: number, inventory, nil)
	elseif action == "Put" and isIndex(a, #inventory.slots) then
		local target = if isIndex(b, SC.Slots) then b :: number else nil
		moved = Inventory.transfer(inventory, a :: number, crate.inventory, target)
	elseif action == "TakeAll" then
		for index = 1, SC.Slots do
			moved += Inventory.transfer(crate.inventory, index, inventory, nil)
		end
	end
	if moved > 0 then
		InventoryService.changed(player)
		broadcast(crate)
	end
end

local function onPlaced(key: number, kind: string, part: BasePart)
	if not BC.Blocks[kind].Storage then
		return
	end
	local crate: Crate = { key = key, part = part, inventory = Inventory.new(0, SC.Slots), viewers = {} }
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Localization.get("StorageOpen")
	prompt.ObjectText = Localization.get(`Item{kind}`)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = SC.Reach
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player)
		onOpen(player, crate)
	end)
	prompt.Parent = part
	crates[key] = crate
end

-- A broken crate: its viewers are closed and its contents drop in a bag where it stood.
local function onRemoved(key: number)
	local crate = crates[key]
	if crate == nil then
		return
	end
	crates[key] = nil
	for viewer in crate.viewers do
		close(viewer)
	end
	local stacks: { Inventory.Stack } = {}
	for _, slot in crate.inventory.slots do
		if slot then
			table.insert(stacks, slot)
		end
	end
	if #stacks > 0 then
		LootService.drop(crate.part.Position, stacks, false)
	end
end

-- Debug and tests: how many items crate `key` holds, or nil without a crate.
function StorageService.itemCount(key: number): number?
	local crate = crates[key]
	if crate == nil then
		return nil
	end
	local total = 0
	for _, slot in crate.inventory.slots do
		if slot then
			total += slot.count
		end
	end
	return total
end

function StorageService.init()
	updateRemote = Net.event("StorageUpdate")
	limiter = RateLimiter.new(Config.Remotes.StorageRequestsPerSecond)
end

function StorageService.start()
	Net.event("StorageAction").OnServerEvent:Connect(onAction)
	BuildService.onPlaced(onPlaced)
	BuildService.onRemoved(onRemoved)
	Players.PlayerRemoving:Connect(function(player)
		local crate = opened[player]
		if crate then
			crate.viewers[player] = nil
		end
		opened[player] = nil
	end)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextCheckAt then
			return
		end
		nextCheckAt = now + SC.CheckSeconds
		for player, crate in opened do
			if crates[crate.key] ~= crate or not inReach(player, crate) then
				close(player)
			end
		end
	end)
end

return StorageService
