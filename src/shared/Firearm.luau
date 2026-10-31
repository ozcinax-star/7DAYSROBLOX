--!strict
-- Shared, pure firearm invariants. The server owns cartridges and reload deadlines.
local Firearm = {}

function Firearm.reloadCount(capacity: number, loaded: number, reserve: number): number
	return math.max(0, math.min(capacity - loaded, reserve))
end

function Firearm.canFire(loaded: number, reloadEnds: number, nextShot: number, now: number): boolean
	return loaded > 0 and reloadEnds == 0 and now >= nextShot
end

function Firearm.progress(started: number, ends: number, now: number): number
	if ends <= started then return 0 end
	return math.clamp((now - started) / (ends - started), 0, 1)
end

return Firearm
