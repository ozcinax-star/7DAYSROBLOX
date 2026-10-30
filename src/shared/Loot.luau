--!strict
-- Loot: pure loot-bag rolls (7DTD LootDropProb and loot groups, docs/REFERENCE_7DTD.md Part A 4).
-- Randomness comes from the caller (a uniform number in [0, 1)), so tests can seed it.

local Config = require("./Config")
local Inventory = require("./Inventory")

local LC = Config.Loot

export type Rand = () -> number

local Loot = {}

-- A whole number from `min` to `max`, both included.
local function integer(rand: Rand, min: number, max: number): number
	return math.min(max, min + math.floor(rand() * (max - min + 1)))
end

-- One entry of `picks`, chosen by weight.
function Loot.pick(rand: Rand, picks: { Config.LootPick }): Config.LootPick
	local total = 0
	for _, entry in picks do
		total += entry.Weight
	end
	local roll = rand() * total
	for _, entry in picks do
		roll -= entry.Weight
		if roll < 0 then
			return entry
		end
	end
	return picks[#picks]
end

-- What a dying zombie drops: nil for no bag, otherwise the stacks in the bag.
function Loot.rollZombie(rand: Rand): { Inventory.Stack }?
	if rand() >= LC.ZombieBagChance then
		return nil
	end
	local common = Loot.pick(rand, LC.ZombieCommon)
	local stacks: { Inventory.Stack } = {
		{ id = common.Id, count = integer(rand, common.Min, common.Max), source = "Loot" },
	}
	if rand() < LC.ZombieToolChance then
		local id = LC.ZombieTools[integer(rand, 1, #LC.ZombieTools)]
		local max = Config.Items[id].Durability or 1
		local share = LC.ToolDurabilityMin + rand() * (LC.ToolDurabilityMax - LC.ToolDurabilityMin)
		local durability = math.clamp(math.floor(max * share), 1, max)
		table.insert(stacks, { id = id, count = 1, source = "Loot", durability = durability })
	end
	return stacks
end

return Loot
