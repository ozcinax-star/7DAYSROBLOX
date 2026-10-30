--!strict
-- DayClock: pure day / night clock. Time is counted in real seconds from the dawn of day 1; one cycle
-- is a day phase (Config.DayNight.DayFraction of the cycle) followed by a night phase. The in-game
-- clock runs from DayStartClockTime to NightStartClockTime by day and on to the next dawn by night,
-- so a long night and a short day still show sensible hours. Every HordeEvery-th night is a horde
-- night (7DTD blood moon; PLAN: default 7).

local Config = require("./Config")
local Types = require("./Types")

local DC = Config.DayNight

export type State = {
	-- Day number, from 1. A night belongs to the day it starts on.
	day: number,
	phase: Types.DayPhase,
	-- In-game hour, 0-24 (Lighting.ClockTime).
	clockTime: number,
	-- Real seconds until the current phase ends.
	phaseLeft: number,
}

local DayClock = {}

local function lengths(): (number, number)
	local day = DC.CycleSeconds * DC.DayFraction
	return day, DC.CycleSeconds - day
end

-- Real seconds from the dawn of day 1 to `clockTime` on day 1 (a daytime hour).
function DayClock.secondsAt(clockTime: number): number
	local dayLength = lengths()
	return (clockTime - DC.DayStartClockTime) / (DC.NightStartClockTime - DC.DayStartClockTime) * dayLength
end

-- The clock `elapsed` real seconds after the dawn of day 1.
function DayClock.at(elapsed: number): State
	local dayLength, nightLength = lengths()
	local t = math.max(0, elapsed)
	local day = t // DC.CycleSeconds + 1
	local into = t % DC.CycleSeconds
	if into < dayLength then
		local share = into / dayLength
		return {
			day = day,
			phase = "Day",
			clockTime = DC.DayStartClockTime + share * (DC.NightStartClockTime - DC.DayStartClockTime),
			phaseLeft = dayLength - into,
		}
	end
	local share = (into - dayLength) / nightLength
	local nightHours = 24 - DC.NightStartClockTime + DC.DayStartClockTime
	return {
		day = day,
		phase = "Night",
		clockTime = (DC.NightStartClockTime + share * nightHours) % 24,
		phaseLeft = DC.CycleSeconds - into,
	}
end

-- True when the night of `day` is a horde night.
function DayClock.isHordeDay(day: number, every: number): boolean
	return every > 0 and day % every == 0
end

return DayClock
