--!strict
-- Vitals: pure math of a player's survival stats (7DTD playerMale, buffStatusHungry01-03 and
-- buffStatusThirsty01-03; docs/REFERENCE_7DTD.md part B section 6). Health is the Humanoid's and comes
-- in and out through `step`'s result; stamina, food and water live here. Food and water drain per
-- in-game day like 7DTD at its default day length; stamina and starvation run in real seconds.

local Config = require("./Config")

local SC = Config.Survival

export type Stats = {
	stamina: number,
	food: number,
	water: number,
	-- Hunger and thirst stage, 0 (fine) to #Config.Survival.Stages (starving / dehydrated).
	hunger: number,
	thirst: number,
	-- Seconds toward the next starvation or dehydration damage.
	starveClock: number,
	-- Eaten food still going in (7DTD buffHealFood: Config.Survival.FoodPerSecond).
	foodPending: number,
	-- Healing still to come from food and medicine, and its rate in health per second.
	healPending: number,
	healRate: number,
}

-- What the server saw of the character this tick.
export type Input = {
	health: number,
	maxHealth: number,
	-- Moving faster than walking with sprint on (7DTD drains only while not idle).
	sprinting: boolean,
	-- Real seconds of one in-game day.
	daySeconds: number,
}

local LAST_STAGE = #SC.Stages

local Vitals = {}

Vitals.LAST_STAGE = LAST_STAGE

function Vitals.new(): Stats
	return {
		stamina = SC.MaxStamina,
		food = SC.MaxFood,
		water = SC.MaxWater,
		hunger = 0,
		thirst = 0,
		starveClock = 0,
		foodPending = 0,
		healPending = 0,
		healRate = 0,
	}
end

-- The stage for a stat at `share` of its max, from the `current` stage: a stage is reached at or below
-- its Enter share and left only above its Leave share (7DTD's 2 % margins).
function Vitals.stage(current: number, share: number): number
	local stage = 0
	for index, def in SC.Stages do
		local limit = if index <= current then def.Leave else def.Enter
		if share <= limit then
			stage = index
		end
	end
	return stage
end

-- Regeneration factor of the water band (7DTD EntityStats.GetWaterPercent): nothing at all when empty.
function Vitals.waterFactor(water: number): number
	if water <= 0 then
		return 0
	end
	local share = water / SC.MaxWater
	for _, band in SC.WaterBands do
		if share >= band.Min then
			return band.Factor
		end
	end
	return 0
end

-- Most stamina the bar can hold: hunger and thirst each block a share of the max and add up.
function Vitals.staminaCap(stats: Stats): number
	local blocked = 0
	if stats.hunger > 0 then
		blocked += SC.Stages[stats.hunger].Block
	end
	if stats.thirst > 0 then
		blocked += SC.Stages[stats.thirst].Block
	end
	return math.max(SC.MinStaminaCap, SC.MaxStamina * (1 - blocked))
end

local function restage(stats: Stats)
	stats.hunger = Vitals.stage(stats.hunger, stats.food / SC.MaxFood)
	stats.thirst = Vitals.stage(stats.thirst, stats.water / SC.MaxWater)
	stats.stamina = math.min(stats.stamina, Vitals.staminaCap(stats))
end

-- Advances `stats` by `dt` real seconds. Returns the health to add (regeneration, food and medicine)
-- and the health to take (starvation and dehydration).
function Vitals.step(stats: Stats, dt: number, input: Input): (number, number)
	local days = dt / input.daySeconds
	local eaten = math.min(stats.foodPending, SC.FoodPerSecond * dt)
	stats.foodPending -= eaten
	stats.food = math.clamp(stats.food + eaten - SC.FoodPerDay * days, 0, SC.MaxFood)
	stats.water = math.max(0, stats.water - SC.WaterPerDay * days)
	restage(stats)

	local factor = Vitals.waterFactor(stats.water)
	local cap = Vitals.staminaCap(stats)
	if input.sprinting then
		stats.stamina = math.max(0, stats.stamina - SC.SprintDrain * dt)
	elseif stats.stamina < cap then
		local cut = if stats.hunger == LAST_STAGE then SC.StarveRegenCut else 0
		local gained = math.min(cap - stats.stamina, SC.StaminaRegen * factor * (1 - cut) * dt)
		stats.stamina += gained
		stats.food = math.max(0, stats.food - gained * SC.FoodPerStamina)
		stats.water = math.max(0, stats.water - gained * SC.WaterPerStamina)
	end

	local starving = (if stats.hunger == LAST_STAGE then 1 else 0) + (if stats.thirst == LAST_STAGE then 1 else 0)
	-- Food and medicine heal at their own rate, starving or not; natural regeneration needs both
	-- stats above their last stage and some water.
	local treated = math.min(stats.healPending, stats.healRate * dt)
	stats.healPending -= treated
	if stats.healPending <= 0 then
		stats.healRate = 0
	end
	local natural = if starving == 0 then SC.HealthPerDay * days * factor else 0
	local healed = 0
	if input.health > 0 then
		healed = math.clamp(input.maxHealth - input.health, 0, treated + natural)
		stats.water = math.max(0, stats.water - healed * SC.WaterPerHealth)
	end
	local damage = 0
	if starving > 0 then
		stats.starveClock += dt
		while stats.starveClock >= SC.StarveInterval do
			stats.starveClock -= SC.StarveInterval
			damage += SC.StarveDamage * starving
		end
	else
		stats.starveClock = 0
	end
	restage(stats)
	return healed, damage
end

-- Whether the bar holds `amount` (7DTD: no swing below its stamina cost).
function Vitals.canSpend(stats: Stats, amount: number): boolean
	return stats.stamina >= amount
end

-- Takes `amount` stamina, never below zero.
function Vitals.spend(stats: Stats, amount: number)
	stats.stamina = math.max(0, stats.stamina - amount)
end

-- Eating or drinking: water goes in at once (negative takes), food over time, and `heal` health at
-- `healRate` per second. Healing from several items adds up and runs at the fastest of their rates.
function Vitals.consume(stats: Stats, food: number, water: number, heal: number, healRate: number)
	stats.foodPending += math.max(0, food)
	stats.water = math.clamp(stats.water + water, 0, SC.MaxWater)
	if heal > 0 and healRate > 0 then
		stats.healPending += heal
		stats.healRate = math.max(stats.healRate, healRate)
	end
	restage(stats)
end

return Vitals
