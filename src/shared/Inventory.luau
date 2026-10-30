--!strict
-- Slot inventory: the toolbelt (slots 1..toolbelt) followed by the backpack. Pure Luau, so the server
-- (which owns every inventory) and the Lune tests run the same code; clients only display copies.
--
-- A slot is `false` (empty) or an item stack. Stackable items share a stack up to their item's
-- `Stack` size; tools never stack and carry their own durability. Every stack keeps its source
-- (PLAN: an item bought or crafted must survive when the same item from a lapsed pass is taken
-- back), so stacks of the same item with different sources are kept apart.

local Config = require("./Config")
local Types = require("./Types")

export type Stack = {
	id: string,
	count: number,
	source: Types.ItemSource,
	-- Tools only: remaining uses; 0 means broken (kept, but unusable until repaired).
	durability: number?,
}

export type Slot = Stack | false

export type Inventory = {
	toolbelt: number,
	slots: { Slot },
}

local Inventory = {}

function Inventory.new(toolbelt: number, backpack: number): Inventory
	local slots: { Slot } = table.create(toolbelt + backpack, false)
	return { toolbelt = toolbelt, slots = slots }
end

function Inventory.def(id: string): Config.ItemDef?
	return Config.Items[id]
end

function Inventory.isTool(id: string): boolean
	local def = Config.Items[id]
	return def ~= nil and def.Durability ~= nil
end

function Inventory.stackSize(id: string): number
	local def = Config.Items[id]
	return if def then def.Stack else 0
end

local function canMerge(stack: Stack, id: string, source: Types.ItemSource): boolean
	return stack.id == id and stack.source == source and stack.durability == nil
end

-- Order in which new items look for room: existing stacks anywhere first, then empty slots in the
-- order given by Config.Inventory.FillToolbeltFirst.
local function emptySlotOrder(inv: Inventory): { number }
	local order = {}
	local size = #inv.slots
	if Config.Inventory.FillToolbeltFirst then
		for index = 1, size do
			table.insert(order, index)
		end
	else
		for index = inv.toolbelt + 1, size do
			table.insert(order, index)
		end
		for index = 1, inv.toolbelt do
			table.insert(order, index)
		end
	end
	return order
end

local function isCount(value: number): boolean
	return value == value and value % 1 == 0 and value >= 1 and value < math.huge
end

-- Adds `count` of `id`; returns how many did not fit. Tools are added one per slot at full
-- durability unless `durability` is given. Counts are whole numbers: callers that earn fractions
-- (per-hit harvest yields) keep the remainder themselves. Anything else adds nothing and returns 0.
function Inventory.add(
	inv: Inventory,
	id: string,
	count: number,
	source: Types.ItemSource,
	durability: number?
): number
	local def = Config.Items[id]
	if not isCount(count) then
		return 0
	end
	if def == nil then
		return count
	end
	local left = count
	local slots = inv.slots
	if def.Durability == nil then
		for _, slot in slots do
			if left == 0 then
				break
			end
			if slot and canMerge(slot, id, source) and slot.count < def.Stack then
				local moved = math.min(left, def.Stack - slot.count)
				slot.count += moved
				left -= moved
			end
		end
	end
	for _, index in emptySlotOrder(inv) do
		if left == 0 then
			break
		end
		if slots[index] == false then
			if def.Durability ~= nil then
				slots[index] = { id = id, count = 1, source = source, durability = durability or def.Durability }
				left -= 1
			else
				local moved = math.min(left, def.Stack)
				slots[index] = { id = id, count = moved, source = source }
				left -= moved
			end
		end
	end
	return left
end

-- How many of `count` would fit, without changing anything.
function Inventory.room(inv: Inventory, id: string, source: Types.ItemSource): number
	local def = Config.Items[id]
	if def == nil then
		return 0
	end
	local room = 0
	for _, slot in inv.slots do
		if slot == false then
			room += if def.Durability ~= nil then 1 else def.Stack
		elseif def.Durability == nil and canMerge(slot, id, source) then
			room += math.max(0, def.Stack - slot.count)
		end
	end
	return room
end

-- Total count of `id` across all slots (broken tools included).
function Inventory.count(inv: Inventory, id: string): number
	local total = 0
	for _, slot in inv.slots do
		if slot and slot.id == id then
			total += slot.count
		end
	end
	return total
end

-- True when every { [id] = count } entry is available.
function Inventory.has(inv: Inventory, costs: { [string]: number }): boolean
	for id, count in costs do
		if Inventory.count(inv, id) < count then
			return false
		end
	end
	return true
end

-- Removes `count` of `id`, backpack first and from the end, so the toolbelt keeps what the player
-- placed there. All or nothing: returns false and changes nothing when there is not enough.
-- Returns the removed stacks (with their sources) for refunds.
function Inventory.remove(inv: Inventory, id: string, count: number): (boolean, { Stack })
	if count <= 0 then
		return true, {}
	end
	if Inventory.count(inv, id) < count then
		return false, {}
	end
	local removed: { Stack } = {}
	local left = count
	local slots = inv.slots
	local size = #slots
	local order = {}
	for index = size, inv.toolbelt + 1, -1 do
		table.insert(order, index)
	end
	for index = inv.toolbelt, 1, -1 do
		table.insert(order, index)
	end
	for _, index in order do
		if left == 0 then
			break
		end
		local slot = slots[index]
		if slot and slot.id == id then
			local taken = math.min(left, slot.count)
			table.insert(removed, { id = id, count = taken, source = slot.source, durability = slot.durability })
			slot.count -= taken
			left -= taken
			if slot.count == 0 then
				slots[index] = false
			end
		end
	end
	return true, removed
end

-- Removes every { [id] = count } entry, all or nothing.
function Inventory.removeAll(inv: Inventory, costs: { [string]: number }): (boolean, { Stack })
	if not Inventory.has(inv, costs) then
		return false, {}
	end
	local removed: { Stack } = {}
	for id, count in costs do
		local _, stacks = Inventory.remove(inv, id, count)
		for _, stack in stacks do
			table.insert(removed, stack)
		end
	end
	return true, removed
end

local function isIndex(inv: Inventory, index: number): boolean
	return index == index and index % 1 == 0 and index >= 1 and index <= #inv.slots
end

-- Moves `count` items (the whole stack when nil) from one slot to another: into an empty slot,
-- onto a stack of the same item and source, or, for a whole stack, swapping with a different one.
-- Returns false when the move is not possible.
function Inventory.move(inv: Inventory, from: number, to: number, count: number?): boolean
	if not isIndex(inv, from) or not isIndex(inv, to) or from == to then
		return false
	end
	local slots = inv.slots
	local source = slots[from]
	if source == false then
		return false
	end
	local amount = count or source.count
	if amount ~= amount or amount % 1 ~= 0 or amount < 1 or amount > source.count then
		return false
	end
	local target = slots[to]
	if target == false then
		if amount == source.count then
			slots[to] = source
			slots[from] = false
		else
			slots[to] = { id = source.id, count = amount, source = source.source }
			source.count -= amount
		end
		return true
	end
	if source.durability == nil and canMerge(target, source.id, source.source) then
		local moved = math.min(amount, Inventory.stackSize(source.id) - target.count)
		if moved <= 0 then
			return false
		end
		target.count += moved
		source.count -= moved
		if source.count == 0 then
			slots[from] = false
		end
		return true
	end
	if amount ~= source.count then
		return false
	end
	slots[from], slots[to] = target, source
	return true
end

-- Uses up `amount` durability of the tool in `index`; returns the durability left, or nil when the
-- slot holds no tool.
function Inventory.wear(inv: Inventory, index: number, amount: number): number?
	local slot = inv.slots[index]
	if slot == false or slot == nil or slot.durability == nil then
		return nil
	end
	local left = math.max(0, slot.durability - amount)
	slot.durability = left
	return left
end

-- A copy safe to send over a remote or keep as a snapshot.
function Inventory.copySlots(inv: Inventory): { Slot }
	local copy: { Slot } = table.create(#inv.slots, false)
	for index, slot in inv.slots do
		if slot then
			copy[index] = { id = slot.id, count = slot.count, source = slot.source, durability = slot.durability }
		end
	end
	return copy
end

return Inventory
