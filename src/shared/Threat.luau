--!strict
-- Threat: pure math of the threat system (PLAN, Tehdit sistemi) and of the zombie population it drives.
-- Noise fades fast; Trace follows what the players have built and fades only a few points a day.
-- Threat = Trace + Noise * NoiseWeight, split into five tiers, and the first days are capped. The tier
-- raises the ambient zombie count; the horde stays ZombiesPerPlayer per player (PLAN rule 5).

local Config = require("./Config")
local Types = require("./Types")

local TC = Config.Threat
local PC = Config.Population
local HC = Config.Horde

-- One horde wave: seconds into the night when it comes, and how many zombies it brings.
export type Wave = { at: number, count: number }

local Threat = {}

-- Noise left after `dt` seconds: DecayPerSecond of the value is lost every second.
function Threat.decayNoise(noise: number, dt: number): number
	return noise * (1 - TC.Noise.DecayPerSecond) ^ math.max(0, dt)
end

-- Noise after an event adds `amount`, capped at the meter's maximum.
function Threat.addNoise(noise: number, amount: number): number
	return math.clamp(noise + amount, 0, TC.Noise.Max)
end

-- Trace after `days` in-game days. It rises at once to what the players have (`target`) and, when they
-- have less, falls only DecayPerDay points a day.
function Threat.stepTrace(trace: number, target: number, days: number): number
	local goal = math.clamp(target, 0, TC.Trace.Max)
	if goal >= trace then
		return goal
	end
	return math.max(goal, trace - TC.Trace.DecayPerDay * math.max(0, days))
end

function Threat.level(trace: number, noise: number): number
	return trace + noise * TC.NoiseWeight
end

-- Tier 1-5 of a threat level on `day`. The first EarlyGameDays never go above EarlyGameMaxTier.
function Threat.tier(level: number, day: number): number
	local tier = 1
	for index, threshold in TC.TierThresholds do
		if level >= threshold then
			tier = index
		end
	end
	if day <= TC.EarlyGameDays then
		tier = math.min(tier, TC.EarlyGameMaxTier)
	end
	return tier
end

-- Ambient zombies kept around `players` living players in `phase` at threat `tier`.
function Threat.ambientTarget(players: number, phase: Types.DayPhase, tier: number): number
	if players <= 0 then
		return 0
	end
	local perPlayer = if phase == "Night" then PC.NightPerPlayer else PC.DayPerPlayer
	local multiplier = PC.TierMultipliers[math.clamp(tier, 1, #PC.TierMultipliers)]
	return math.min(PC.Max, math.round(players * perPlayer * multiplier))
end

-- The horde of `players` players over a night of `nightSeconds`: WavesPerNight waves of equal size
-- (the last may be smaller), the first at nightfall and the last WaveSpreadFraction into the night.
function Threat.hordeWaves(players: number, nightSeconds: number): { Wave }
	local waves: { Wave } = {}
	local total = math.max(0, math.floor(players)) * HC.ZombiesPerPlayer
	if total <= 0 then
		return waves
	end
	local count = math.max(1, HC.WavesPerNight)
	local size = math.ceil(total / count)
	local gap = if count > 1 then math.max(0, nightSeconds) * HC.WaveSpreadFraction / (count - 1) else 0
	local left = total
	while left > 0 do
		local n = math.min(size, left)
		table.insert(waves, { at = #waves * gap, count = n })
		left -= n
	end
	return waves
end

return Threat
