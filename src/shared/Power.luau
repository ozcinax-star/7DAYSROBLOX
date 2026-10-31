--!strict
-- Power: pure generator math (7DTD generator bank and lights, without wires). Plain numbers only, so
-- the Lune tests can run it.

local Config = require("./Config")

export type Point = { x: number, y: number, z: number }
export type Source = { x: number, y: number, z: number, watts: number }

local Power = {}

-- Gas `watts` in use burn over `seconds` (Config.Power: per watt per in-game day).
function Power.burn(watts: number, seconds: number): number
	return watts * Config.Power.FuelPerWattDay * seconds / Config.DayNight.CycleSeconds
end

-- Gas one refuel pours into a generator holding `fuel` from `carried` gas: one step at most, never
-- past the tank.
function Power.refuel(fuel: number, carried: number): number
	local room = math.floor(Config.Power.FuelCapacity - fuel)
	return math.max(0, math.min(Config.Power.RefuelStep, room, carried))
end

-- Which source lights each lamp: lamp index -> source index. Lamps are taken in order; each goes to
-- the nearest source within `radius` that still has `lampWatts` to spare, until `maxLit` lamps burn.
function Power.assign(
	sources: { Source },
	lamps: { Point },
	radius: number,
	lampWatts: number,
	maxLit: number
): { [number]: number }
	local spare: { number } = {}
	for index, source in sources do
		spare[index] = source.watts
	end
	local lit: { [number]: number } = {}
	local count = 0
	local limit = radius * radius
	for lampIndex, lamp in lamps do
		if count >= maxLit then
			break
		end
		local best: number? = nil
		local bestDistance = math.huge
		for index, source in sources do
			local dx, dy, dz = source.x - lamp.x, source.y - lamp.y, source.z - lamp.z
			local distance = dx * dx + dy * dy + dz * dz
			if spare[index] >= lampWatts and distance <= limit and distance < bestDistance then
				best = index
				bestDistance = distance
			end
		end
		if best then
			spare[best] -= lampWatts
			lit[lampIndex] = best
			count += 1
		end
	end
	return lit
end

return Power
