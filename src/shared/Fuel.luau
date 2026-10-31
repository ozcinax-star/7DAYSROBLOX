--!strict
-- Fuel: fuel arithmetic of fire stations (StationService). Fuel is seconds of burning; each fuel item
-- is worth its Config.Stations.FuelSeconds.

local Config = require("./Config")

local Fuel = {}

-- What one "Add fuel" press takes: up to `perAdd` items, in the station's fuel order, without going
-- past its MaxFuel. Returns the items to take and the seconds they add.
function Fuel.feed(
	fuel: number,
	def: Config.StationDef,
	fuelSeconds: { [string]: number },
	perAdd: number,
	countOf: (id: string) -> number
): ({ [string]: number }, number)
	local takes: { [string]: number } = {}
	local added = 0
	local left = perAdd
	for _, id in def.Fuels do
		if left <= 0 then
			break
		end
		local seconds = fuelSeconds[id]
		local fits = math.floor((def.MaxFuel - fuel - added) / seconds)
		local count = math.min(countOf(id), fits, left)
		if count > 0 then
			takes[id] = count
			added += count * seconds
			left -= count
		end
	end
	return takes, added
end

-- True when not one more item of any of the station's fuels fits.
function Fuel.full(fuel: number, def: Config.StationDef, fuelSeconds: { [string]: number }): boolean
	for _, id in def.Fuels do
		if fuel + fuelSeconds[id] <= def.MaxFuel then
			return false
		end
	end
	return true
end

-- Fuel seconds as "m:ss", rounded up so a burning fire never shows 0:00.
function Fuel.clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

return Fuel
