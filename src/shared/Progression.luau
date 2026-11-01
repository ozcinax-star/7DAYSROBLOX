--!strict
-- Experience, levels and perks (PLAN MVP: Scavenger, Builder, Combat, three tiers each). Pure Luau:
-- the server owns the state, the client only reads it, and Lune tests the rules.
local Config = require("./Config")

local PC = Config.Progression

export type State = {
	-- Experience gathered toward the next level.
	xp: number,
	level: number,
	-- Unspent perk points.
	points: number,
	perks: { [string]: number },
}

local Progression = {}

function Progression.new(): State
	local perks: { [string]: number } = {}
	for id in PC.Perks do
		perks[id] = 0
	end
	return { xp = 0, level = 1, points = 0, perks = perks }
end

-- Experience needed to go from `level` to the next one.
function Progression.xpToNext(level: number): number
	return math.floor(PC.LevelBase * PC.LevelGrowth ^ (level - 1) + 0.5)
end

-- Adds experience; levels up as often as it reaches the next level (one perk point each). Returns
-- how many levels were gained.
function Progression.addXp(state: State, amount: number): number
	if amount ~= amount or amount <= 0 or amount == math.huge then
		return 0
	end
	state.xp += amount
	local gained = 0
	while state.level < PC.MaxLevel and state.xp >= Progression.xpToNext(state.level) do
		state.xp -= Progression.xpToNext(state.level)
		state.level += 1
		state.points += PC.PointsPerLevel
		gained += 1
	end
	if state.level >= PC.MaxLevel then
		state.xp = 0
	end
	return gained
end

-- Whether `perkId` can take its next tier now, and if not, why ("Unknown", "Max", "Points", "Level").
function Progression.canUpgrade(state: State, perkId: string): (boolean, string?)
	local def = PC.Perks[perkId]
	if def == nil then
		return false, "Unknown"
	end
	local tier = state.perks[perkId] or 0
	if tier >= #def.TierLevels then
		return false, "Max"
	end
	if state.points < 1 then
		return false, "Points"
	end
	if state.level < def.TierLevels[tier + 1] then
		return false, "Level"
	end
	return true, nil
end

function Progression.upgrade(state: State, perkId: string): boolean
	if not Progression.canUpgrade(state, perkId) then
		return false
	end
	state.points -= 1
	state.perks[perkId] = (state.perks[perkId] or 0) + 1
	return true
end

-- Effects of a perk tier.
function Progression.damageShare(state: State): number
	return 1 + (state.perks.Combat or 0) * PC.Perks.Combat.Step
end

function Progression.lootShare(state: State): number
	return 1 + (state.perks.Scavenger or 0) * PC.Perks.Scavenger.Step
end

function Progression.costShare(state: State): number
	return math.max(0, 1 - (state.perks.Builder or 0) * PC.Perks.Builder.Step)
end

-- Rebuilds a state from saved data, keeping only valid, consistent values (never trusted).
function Progression.fromSaved(data: any): State
	local state = Progression.new()
	if type(data) ~= "table" then
		return state
	end
	local function whole(value: any, low: number, high: number): boolean
		return type(value) == "number" and value == value and value % 1 == 0 and value >= low and value <= high
	end
	if whole(data.Level, 1, PC.MaxLevel) then
		state.level = data.Level
	end
	if type(data.Xp) == "number" and data.Xp == data.Xp then
		state.xp = math.clamp(data.Xp, 0, Progression.xpToNext(state.level))
	end
	local spent = 0
	if type(data.Perks) == "table" then
		for id, def in PC.Perks do
			local tier = data.Perks[id]
			if whole(tier, 0, #def.TierLevels) then
				state.perks[id] = tier
				spent += tier
			end
		end
	end
	-- Points can never exceed what the level earned minus what was spent.
	local earned = (state.level - 1) * PC.PointsPerLevel
	state.points = if whole(data.Points, 0, earned) then math.min(data.Points, math.max(0, earned - spent)) else 0
	return state
end

function Progression.toSaved(state: State): any
	local perks = {}
	for id, tier in state.perks do
		perks[id] = tier
	end
	return { Xp = state.xp, Level = state.level, Points = state.points, Perks = perks }
end

return Progression
