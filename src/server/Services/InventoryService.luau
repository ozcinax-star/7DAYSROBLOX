--!strict
-- InventoryService: owns every player's inventory (toolbelt + backpack, PLAN: server authoritative).
-- Each player receives a copy of their own inventory after it changes (batched once per frame), and
-- may only ask to move items between their own slots or pick the active toolbelt slot; both requests
-- are validated and rate limited. Other services (gathering, crafting, loot) change inventories
-- only through this API. The item in the active slot is shown in the character's right hand.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Inventory = require(Shared.Inventory)
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local HeldItems = require(script.Parent.Parent.Modules.HeldItems)
local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)

local IC = Config.Inventory

type PlayerState = {
	inventory: Inventory.Inventory,
	-- Active toolbelt slot (1..toolbelt).
	selected: number,
	dirty: boolean,
	-- Item id currently shown in the hand, and its model.
	heldId: string?,
	heldModel: Model?,
}

export type HeldChangedCallback = (player: Player, stack: Inventory.Stack?) -> ()
export type ChangedCallback = (player: Player) -> ()

local InventoryService = {}

local states: { [Player]: PlayerState } = {}
local limiter: RateLimiter.RateLimiter
local updateRemote: RemoteEvent
local gainRemote: RemoteEvent
local heldCallbacks: { HeldChangedCallback } = {}
local changedCallbacks: { ChangedCallback } = {}

local function isSlotIndex(value: unknown, max: number): boolean
	return typeof(value) == "number" and value == value and value % 1 == 0 and value >= 1 and value <= max
end

local function heldStack(state: PlayerState): Inventory.Stack?
	local slot = state.inventory.slots[state.selected]
	return if slot then slot else nil
end

-- Shows the active slot's item in the right hand (R15 RightHand, or R6 Right Arm).
local function refreshHeld(player: Player, state: PlayerState)
	local stack = heldStack(state)
	local id = if stack then stack.id else nil
	local character = player.Character
	local current = state.heldModel
	local shown = current ~= nil and character ~= nil and current:IsDescendantOf(character)
	if id == state.heldId and (id == nil or shown) then
		return
	end
	if current then
		current:Destroy()
		state.heldModel = nil
	end
	state.heldId = id
	if id and character then
		local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
		if hand and hand:IsA("BasePart") then
			local attachment = hand:FindFirstChild("RightGripAttachment")
			local grip = if attachment and attachment:IsA("Attachment")
				then attachment.CFrame
				else CFrame.new(0, -hand.Size.Y / 2, 0)
			local model = HeldItems.build(id, hand, grip)
			model.Parent = character
			state.heldModel = model
		end
	end
	for _, callback in heldCallbacks do
		task.spawn(callback, player, stack)
	end
end

local function markDirty(player: Player)
	local state = states[player]
	if state then
		state.dirty = true
	end
end

local function flush()
	for player, state in states do
		if state.dirty then
			state.dirty = false
			updateRemote:FireClient(player, Inventory.copySlots(state.inventory), state.selected)
			refreshHeld(player, state)
			for _, callback in changedCallbacks do
				task.spawn(callback, player)
			end
		end
	end
end

local function onMove(player: Player, from: unknown, to: unknown, count: unknown)
	local state = states[player]
	if state == nil or not limiter:allow(player) then
		return
	end
	local size = #state.inventory.slots
	if not isSlotIndex(from, size) or not isSlotIndex(to, size) then
		return
	end
	if count ~= nil and not isSlotIndex(count, math.huge) then
		return
	end
	if Inventory.move(state.inventory, from :: number, to :: number, count :: number?) then
		markDirty(player)
	end
end

local function onSelect(player: Player, index: unknown)
	local state = states[player]
	if state == nil or not limiter:allow(player) then
		return
	end
	if not isSlotIndex(index, state.inventory.toolbelt) then
		return
	end
	state.selected = index :: number
	markDirty(player)
end

local function onPlayerAdded(player: Player)
	local state: PlayerState = {
		inventory = Inventory.new(IC.ToolbeltSlots, IC.BackpackSlots),
		selected = 1,
		dirty = true,
		heldId = nil,
		heldModel = nil,
	}
	-- The starting kit fills the last toolbelt slots, so the active first slot stays an empty hand.
	local first = IC.ToolbeltSlots - #IC.StartingItems
	for offset, entry in IC.StartingItems do
		local stack = { id = entry.Id, count = entry.Count, source = "Loot" :: Types.ItemSource }
		Inventory.putSlot(state.inventory, first + offset, stack)
	end
	states[player] = state
	player.CharacterAdded:Connect(function()
		-- The new character has an empty hand; show the active item again once it is assembled.
		state.heldId = nil
		state.heldModel = nil
		task.defer(markDirty, player)
	end)
end

function InventoryService.init()
	limiter = RateLimiter.new(Config.Remotes.InventoryRequestsPerSecond)
	updateRemote = Net.event("InventoryUpdate")
	gainRemote = Net.event("InventoryGain")
	Net.event("InventoryMove")
	Net.event("InventorySelect")
end

function InventoryService.start()
	Net.event("InventoryMove").OnServerEvent:Connect(onMove)
	Net.event("InventorySelect").OnServerEvent:Connect(onSelect)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		if states[player] == nil then
			onPlayerAdded(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	RunService.Heartbeat:Connect(flush)
end

-- The player's inventory (server copy). Call `changed` after modifying it directly.
function InventoryService.get(player: Player): Inventory.Inventory?
	local state = states[player]
	return if state then state.inventory else nil
end

function InventoryService.changed(player: Player)
	markDirty(player)
end

-- Gives items and tells the player what was added (7DTD's pickup feed); returns how many did not fit.
function InventoryService.give(
	player: Player,
	id: string,
	count: number,
	source: Types.ItemSource,
	durability: number?
): number
	local state = states[player]
	if state == nil then
		return count
	end
	local left = Inventory.add(state.inventory, id, count, source, durability)
	if left < count then
		markDirty(player)
	end
	if Config.Items[id] and count > 0 then
		gainRemote:FireClient(player, id, count - left, left)
	end
	return left
end

-- How many of `id` would still fit.
function InventoryService.room(player: Player, id: string, source: Types.ItemSource): number
	local state = states[player]
	return if state then Inventory.room(state.inventory, id, source) else 0
end

-- Takes every { [id] = count } entry, all or nothing; returns the removed stacks for refunds.
function InventoryService.take(player: Player, costs: { [string]: number }): (boolean, { Inventory.Stack })
	local state = states[player]
	if state == nil then
		return false, {}
	end
	local ok, removed = Inventory.removeAll(state.inventory, costs)
	if ok then
		markDirty(player)
	end
	return ok, removed
end

-- The stack in slot `index` (a copy), or nil for an empty or invalid slot.
function InventoryService.peekSlot(player: Player, index: number): Inventory.Stack?
	local state = states[player]
	if state == nil or not isSlotIndex(index, #state.inventory.slots) then
		return nil
	end
	local slot = state.inventory.slots[index]
	return if slot then table.clone(slot) else nil
end

-- Empties slot `index` and returns its stack (a tool going into the repair queue), or nil.
function InventoryService.takeSlot(player: Player, index: number): Inventory.Stack?
	local state = states[player]
	if state == nil or not isSlotIndex(index, #state.inventory.slots) then
		return nil
	end
	local stack = Inventory.takeSlot(state.inventory, index)
	if stack then
		markDirty(player)
	end
	return stack
end

-- Puts `stack` back into slot `index` if it is still empty; false otherwise.
function InventoryService.putSlot(player: Player, index: number, stack: Inventory.Stack): boolean
	local state = states[player]
	if state == nil or not Inventory.putSlot(state.inventory, index, stack) then
		return false
	end
	markDirty(player)
	return true
end

-- Gives a cancelled job's stacks back, all or nothing (Inventory.addAll). When they do not all fit,
-- nothing changes, the player is told what had no room, and false is returned.
function InventoryService.giveBack(player: Player, returns: { Inventory.Return }): boolean
	local state = states[player]
	if state == nil then
		return false
	end
	local ok, id, left = Inventory.addAll(state.inventory, returns)
	if not ok then
		gainRemote:FireClient(player, id, 0, left)
		return false
	end
	markDirty(player)
	for _, entry in returns do
		gainRemote:FireClient(player, entry.stack.id, entry.stack.count, 0)
	end
	return true
end

function InventoryService.count(player: Player, id: string): number
	local state = states[player]
	return if state then Inventory.count(state.inventory, id) else 0
end

-- The stack in the active toolbelt slot (nil for an empty hand) and the slot index.
function InventoryService.getHeld(player: Player): (Inventory.Stack?, number)
	local state = states[player]
	if state == nil then
		return nil, 0
	end
	return heldStack(state), state.selected
end

-- Uses up `count` of the held stack (a placed block); false when the hand holds fewer.
function InventoryService.consumeHeld(player: Player, count: number): boolean
	local state = states[player]
	if state == nil or not Inventory.consume(state.inventory, state.selected, count) then
		return false
	end
	markDirty(player)
	return true
end

-- Wears the held tool by `amount`; returns the durability left, or nil when no tool is held.
function InventoryService.wearHeld(player: Player, amount: number): number?
	local state = states[player]
	if state == nil then
		return nil
	end
	local left = Inventory.wear(state.inventory, state.selected, amount)
	if left then
		markDirty(player)
	end
	return left
end

-- Registers a listener for changes of the item in a player's hand.
-- Calls `callback` after a player's inventory changed (at most once a frame, after the client copy).
function InventoryService.onChanged(callback: ChangedCallback)
	table.insert(changedCallbacks, callback)
end

function InventoryService.onHeldChanged(callback: HeldChangedCallback)
	table.insert(heldCallbacks, callback)
end

return InventoryService
