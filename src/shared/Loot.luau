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

-- A tool found as loot: worn to a random share of its durability.
local function toolStack(rand: Rand, id: string): Inventory.Stack
	local max = Config.Items[id].Durability or 1
	local share = LC.ToolDurabilityMin + rand() * (LC.ToolDurabilityMax - LC.ToolDurabilityMin)
	local durability = math.clamp(math.floor(max * share), 1, max)
	return { id = id, count = 1, source = "Loot", durability = durability }
end

-- The stack one picked entry gives.
local function stackOf(rand: Rand, entry: Config.LootPick): Inventory.Stack
	if Config.Items[entry.Id].Durability then
		return toolStack(rand, entry.Id)
	end
	return { id = entry.Id, count = integer(rand, entry.Min, entry.Max), source = "Loot" }
end

-- What a dying zombie drops: nil for no bag, otherwise the stacks in the bag.
function Loot.rollZombie(rand: Rand): { Inventory.Stack }?
	if rand() >= LC.ZombieBagChance then
		return nil
	end
	local stacks: { Inventory.Stack } = { stackOf(rand, Loot.pick(rand, LC.ZombieCommon)) }
	if rand() < LC.ZombieToolChance then
		table.insert(stacks, toolStack(rand, LC.ZombieTools[integer(rand, 1, #LC.ZombieTools)]))
	end
	return stacks
end

-- What a container of kind `kind` holds when it is filled, in a building whose Loot attribute is
-- `buildingLoot` (nil outside buildings). May be empty.
function Loot.rollContainer(rand: Rand, kind: string, buildingLoot: string?): { Inventory.Stack }
	local def = LC.Containers[kind]
	local stacks: { Inventory.Stack } = {}
	if def == nil then
		return stacks
	end
	local rolls = def.Rolls + (if def.Bonus and def.Bonus == buildingLoot then 1 else 0)
	for _ = 1, rolls do
		if rand() >= def.EmptyChance then
			table.insert(stacks, stackOf(rand, Loot.pick(rand, def.Picks)))
		end
	end
	return stacks
end

return Loot
