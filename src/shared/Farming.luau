--!strict
-- Farming: pure crop math (7DTD 3.2 cropsGrowingMaster and plantedX3HarvestPlayer). Plain numbers
-- only, so the Lune tests can run it.

local Config = require("./Config")

local Farming = {}

-- Seconds one growth stage takes: 7DTD's 63 real minutes against its 60-minute day become the same
-- share of an in-game day here.
function Farming.stageSeconds(): number
	return Config.Farming.StageDays * Config.DayNight.CycleSeconds
end

-- Seconds from planting to ripe.
function Farming.ripeSeconds(): number
	return Farming.stageSeconds() * (Config.Farming.Stages - 1)
end

-- Growth stage (1 = just planted, Config.Farming.Stages = ripe) `elapsed` seconds after planting.
function Farming.stageAt(elapsed: number): number
	local stages = Config.Farming.Stages
	return math.clamp(1 + math.floor(math.max(0, elapsed) / Farming.stageSeconds()), 1, stages)
end

-- Produce a ripe crop pays: its fixed count plus one more when `roll` (0-1) is under its bonus chance.
function Farming.harvestCount(crop: Config.CropDef, roll: number): number
	return crop.Count + (if roll < crop.BonusChance then 1 else 0)
end

return Farming
