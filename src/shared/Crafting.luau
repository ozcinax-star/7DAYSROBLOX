--!strict
-- Crafting: pure 7DTD backpack crafting math (docs/REFERENCE_7DTD.md Part A 3 and 1.7). Craft time,
-- ingredient totals, how many crafts the player can afford, the ingredient pool a queued job keeps
-- for refunds, and repair units.

local Config = require("./Config")
local Inventory = require("./Inventory")

local CC = Config.Crafting

local Crafting = {}

-- Seconds for one craft: the recipe's own time, otherwise each ingredient's count times its
-- ingredient time (7DTD: wood, stone and fibres 0.2 s; anything else 1 s).
function Crafting.unitSeconds(recipe: Config.Recipe): number
	if recipe.Seconds then
		return recipe.Seconds
	end
	local seconds = 0
	for _, ingredient in recipe.Ingredients do
		seconds += ingredient.Count * (CC.IngredientSeconds[ingredient.Id] or CC.DefaultIngredientSeconds)
	end
	return seconds
end

-- { [id] = count } of every ingredient for `count` crafts.
function Crafting.costs(recipe: Config.Recipe, count: number): { [string]: number }
	local costs: { [string]: number } = {}
	for _, ingredient in recipe.Ingredients do
		costs[ingredient.Id] = (costs[ingredient.Id] or 0) + ingredient.Count * count
	end
	return costs
end

-- How many crafts the ingredients on hand pay for, capped at Config.Crafting.MaxCount.
function Crafting.maxCount(recipe: Config.Recipe, countOf: (id: string) -> number): number
	local most = CC.MaxCount
	for id, cost in Crafting.costs(recipe, 1) do
		most = math.min(most, countOf(id) // cost)
	end
	return most
end

-- Removes `costs` from the ingredient pool a job keeps (stacks with their sources, as taken from the
-- inventory), first stacks first. The rest of the pool is what a cancel gives back.
function Crafting.draw(pool: { Inventory.Stack }, costs: { [string]: number })
	for id, cost in costs do
		local left = cost
		local index = 1
		while left > 0 and index <= #pool do
			local stack = pool[index]
			if stack.id == id then
				local used = math.min(left, stack.count)
				stack.count -= used
				left -= used
				if stack.count == 0 then
					table.remove(pool, index)
					continue
				end
			end
			index += 1
		end
	end
end

-- Repair items needed to restore `missing` durability at `amount` per item.
function Crafting.repairUnits(missing: number, amount: number): number
	return math.ceil(missing / amount)
end

return Crafting
