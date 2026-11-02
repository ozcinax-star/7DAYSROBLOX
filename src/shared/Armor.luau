--!strict
-- Armor: pure armour maths (Config.Armor). What a player wears is one stack (or false) per equipment
-- slot; the rating is the sum of the pieces that are not broken, and a hit is cut by the rating's
-- share (capped). ArmorService owns the worn pieces; tests seed them directly.

local Config = require("./Config")
local Inventory = require("./Inventory")

local AC = Config.Armor

export type Worn = { [string]: Inventory.Stack | false }

local Armor = {}

-- An empty set of equipment slots.
function Armor.empty(): Worn
	local worn: Worn = {}
	for _, slot in AC.Slots do
		worn[slot] = false
	end
	return worn
end

-- The armour slot item `id` is worn in, or nil when it is not armour.
function Armor.slotOf(id: string): string?
	local item = Config.Items[id]
	local def = item and item.Armor
	return if def then def.Slot else nil
end

-- Whether a piece still protects (pieces without durability never break).
local function intact(stack: Inventory.Stack): boolean
	return stack.durability == nil or stack.durability > 0
end

-- Total rating of the pieces that are not broken.
function Armor.rating(worn: Worn): number
	local total = 0
	for _, stack in worn do
		if stack and intact(stack) then
			local def = Config.Items[stack.id].Armor
			if def then
				total += def.Rating
			end
		end
	end
	return total
end

-- Share of a hit the rating takes off (0 to Config.Armor.MaxReduction).
function Armor.reduction(rating: number): number
	return math.clamp(rating * AC.ReductionPerPoint, 0, AC.MaxReduction)
end

-- What is left of a hit of `damage` against `worn`; every piece that still protects loses
-- Config.Armor.WearPerHit durability. Returns the damage and whether a piece broke.
function Armor.absorb(worn: Worn, damage: number): (number, boolean)
	local left = damage * (1 - Armor.reduction(Armor.rating(worn)))
	local broke = false
	for _, stack in worn do
		if stack and intact(stack) and stack.durability then
			stack.durability = math.max(0, stack.durability - AC.WearPerHit)
			broke = broke or stack.durability == 0
		end
	end
	return left, broke
end

return Armor
