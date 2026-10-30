--!strict
-- Terrain height, surface material and region for any (x, z), computed from WorldLayout.
-- Pure Luau: the server builds terrain voxels from it, zombies walk on it, and Lune tests check it.

local Noise = require("./Noise")
local WorldLayout = require("./WorldLayout")

local HeightField = {}

export type Surface =
	"Grass"
	| "LeafyGrass"
	| "Ground"
	| "Mud"
	| "Asphalt"
	| "Pavement"
	| "Pebble"
	| "Sand"
	| "Rock"
	| "Slate"
	| "Snow"

local L = WorldLayout
local SEED = L.Seed
local HILLS = L.Hills
local FADE = L.FlattenFade
local TOWN = L.Town
local LAKE = L.Lake
local QUARRY = L.Quarry
local HILL = L.RadioHill

-- Seed offsets for independent noise layers.
local MOUNTAIN_SEED = SEED + 50
local PATCH_SEED = SEED + 90
local MOUNTAIN_ROUGHNESS = 40
local MOUNTAIN_NOISE_SCALE = 90
local PATCH_SCALE = 60
-- Lake shore blends from the water edge to the surrounding ground over this ellipse fraction.
local SHORE_BLEND = 0.2
local SHORE_SAND = 1.1
local LAKE_MUD = 0.8
-- Heights above which mountain surfaces turn to rock / snow.
local ROCK_HEIGHT = 30
local SNOW_HEIGHT = 130
local MOUNTAIN_ROCK_T = 0.15

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function fade(distance: number, fadeLength: number): number
	-- 1 inside (distance <= 0), fading to 0 at fadeLength.
	if distance <= 0 then
		return 1
	end
	return 1 - smoothstep(distance / fadeLength)
end

local function distanceToSegment(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
	local dx, dz = bx - ax, bz - az
	local lengthSq = dx * dx + dz * dz
	local t = if lengthSq > 0 then math.clamp(((px - ax) * dx + (pz - az) * dz) / lengthSq, 0, 1) else 0
	local cx, cz = ax + dx * t - px, az + dz * t - pz
	return math.sqrt(cx * cx + cz * cz)
end

-- Precomputed road bounding boxes (expanded by the flatten fade) to skip far roads quickly.
type RoadBox = { road: WorldLayout.Road, minX: number, maxX: number, minZ: number, maxZ: number }
local roadBoxes: { RoadBox } = {}
for _, road in L.Roads do
	local margin = road.width / 2 + FADE.Road
	local box = { road = road, minX = math.huge, maxX = -math.huge, minZ = math.huge, maxZ = -math.huge }
	for _, p in road.points do
		box.minX = math.min(box.minX, p[1] - margin)
		box.maxX = math.max(box.maxX, p[1] + margin)
		box.minZ = math.min(box.minZ, p[2] - margin)
		box.maxZ = math.max(box.maxZ, p[2] + margin)
	end
	table.insert(roadBoxes, box)
end

-- Distance from (x, z) to the nearest road edge (negative = on the road) and that road.
function HeightField.nearestRoad(x: number, z: number): (number, WorldLayout.Road?)
	local best, bestRoad = math.huge, nil
	for _, box in roadBoxes do
		if x >= box.minX and x <= box.maxX and z >= box.minZ and z <= box.maxZ then
			local road = box.road
			local points = road.points
			for i = 1, #points - 1 do
				local a, b = points[i], points[i + 1]
				local d = distanceToSegment(x, z, a[1], a[2], b[1], b[2]) - road.width / 2
				if d < best then
					best = d
					bestRoad = road
				end
			end
		end
	end
	return best, bestRoad
end

function HeightField.isInTown(x: number, z: number): boolean
	return x >= TOWN.minX and x <= TOWN.maxX and z >= TOWN.minZ and z <= TOWN.maxZ
end

local function townDistance(x: number, z: number): number
	local dx = math.max(TOWN.minX - x, 0, x - TOWN.maxX)
	local dz = math.max(TOWN.minZ - z, 0, z - TOWN.maxZ)
	return math.sqrt(dx * dx + dz * dz)
end

-- Nearest pad whose radius contains (x, z), if any.
function HeightField.padAt(x: number, z: number): WorldLayout.Pad?
	for _, pad in L.Pads do
		local dx, dz = x - pad.x, z - pad.z
		if dx * dx + dz * dz <= pad.radius * pad.radius then
			return pad
		end
	end
	return nil
end

local function lakeEllipse(x: number, z: number): number
	local dx = (x - LAKE.x) / LAKE.radiusX
	local dz = (z - LAKE.z) / LAKE.radiusZ
	return math.sqrt(dx * dx + dz * dz)
end

-- 0..1, how much the rolling hills are flattened at (x, z).
local function flattenMask(x: number, z: number): number
	local mask = fade(townDistance(x, z), FADE.Town)
	if mask >= 1 then
		return 1
	end
	local roadDistance = HeightField.nearestRoad(x, z)
	mask = math.max(mask, fade(roadDistance, FADE.Road))
	for _, pad in L.Pads do
		local dx, dz = x - pad.x, z - pad.z
		mask = math.max(mask, fade(math.sqrt(dx * dx + dz * dz) - pad.radius, FADE.Pad))
	end
	local qx, qz = x - QUARRY.x, z - QUARRY.z
	mask = math.max(mask, fade(math.sqrt(qx * qx + qz * qz) - QUARRY.radius, FADE.Pad))
	mask = math.max(mask, fade((lakeEllipse(x, z) - 1) * LAKE.radiusX, FADE.Pad))
	return mask
end

-- 0..1, how far into the outer mountain band (x, z) is.
local function mountainFactor(x: number, z: number): number
	local edgeDistance = L.HalfSize - math.max(math.abs(x), math.abs(z))
	return math.clamp((L.MountainBand - edgeDistance) / L.MountainBand, 0, 1)
end

function HeightField.heightAt(x: number, z: number): number
	local hills = (Noise.fractal(x / HILLS.Scale, z / HILLS.Scale, SEED, HILLS.Octaves) - HILLS.Offset)
		* HILLS.Height
	local h = L.BaseHeight + hills * (1 - flattenMask(x, z))

	-- Radio hill with a flat top.
	local hx, hz = x - HILL.x, z - HILL.z
	local hillDistance = math.sqrt(hx * hx + hz * hz)
	if hillDistance < HILL.radius then
		local t = if hillDistance <= HILL.plateauRadius
			then 1
			else smoothstep(1 - (hillDistance - HILL.plateauRadius) / (HILL.radius - HILL.plateauRadius))
		h += HILL.height * t
	end

	-- Outer mountains.
	local m = mountainFactor(x, z)
	if m > 0 then
		local rough = Noise.fractal(x / MOUNTAIN_NOISE_SCALE, z / MOUNTAIN_NOISE_SCALE, MOUNTAIN_SEED, 3) - 0.5
		h += m * m * L.MountainHeight + rough * MOUNTAIN_ROUGHNESS * m
	end

	-- Quarry pit with sloped walls.
	local qx, qz = x - QUARRY.x, z - QUARRY.z
	local quarryDistance = math.sqrt(qx * qx + qz * qz)
	if quarryDistance < QUARRY.radius then
		h -= QUARRY.depth * smoothstep((QUARRY.radius - quarryDistance) / QUARRY.rimWidth)
	end

	-- Lake basin.
	local e = lakeEllipse(x, z)
	local shoreHeight = LAKE.waterLevel - 0.5
	if e < 1 then
		h = shoreHeight - LAKE.depth * (1 - e * e)
	elseif e < 1 + SHORE_BLEND then
		h = shoreHeight + (h - shoreHeight) * smoothstep((e - 1) / SHORE_BLEND)
	end

	return h
end

function HeightField.isWater(x: number, z: number): boolean
	return lakeEllipse(x, z) < 1
end

function HeightField.waterLevel(): number
	return LAKE.waterLevel
end

function HeightField.isPlayable(x: number, z: number): boolean
	return math.abs(x) <= L.PlayableHalfSize and math.abs(z) <= L.PlayableHalfSize
end

function HeightField.regionAt(x: number, z: number): "Town" | "Forest"
	return if HeightField.isInTown(x, z) then "Town" else "Forest"
end

local padSurfaces: { [string]: Surface } = {
	Dirt = "Ground",
	Gravel = "Pebble",
	Grass = "Grass",
}

-- Terrain surface material at (x, z) with ground height h.
function HeightField.surfaceAt(x: number, z: number, h: number): Surface
	local m = mountainFactor(x, z)
	if m > MOUNTAIN_ROCK_T then
		if h > SNOW_HEIGHT then
			return "Snow"
		elseif h > ROCK_HEIGHT then
			return "Rock"
		end
	end

	local e = lakeEllipse(x, z)
	if e < 1 then
		return if e < LAKE_MUD then "Mud" else "Sand"
	elseif e < SHORE_SAND then
		return "Sand"
	end

	local qx, qz = x - QUARRY.x, z - QUARRY.z
	local quarryDistance = math.sqrt(qx * qx + qz * qz)
	if quarryDistance < QUARRY.radius then
		return if quarryDistance < QUARRY.radius - QUARRY.rimWidth then "Slate" else "Rock"
	end

	local roadDistance, road = HeightField.nearestRoad(x, z)
	if road and roadDistance <= 0 then
		return if road.surface == "Asphalt" then "Asphalt" else "Ground"
	end

	if HeightField.isInTown(x, z) then
		if road and road.surface == "Asphalt" and roadDistance <= TOWN.sidewalkWidth then
			return "Pavement"
		end
		return "Grass"
	end

	local farm = L.Farm
	if x >= farm.fieldMinX and x <= farm.fieldMaxX and z >= farm.fieldMinZ and z <= farm.fieldMaxZ then
		return "Ground"
	end

	local pad = HeightField.padAt(x, z)
	if pad then
		return padSurfaces[pad.surface]
	end

	local hx, hz = x - HILL.x, z - HILL.z
	if hx * hx + hz * hz < HILL.plateauRadius * HILL.plateauRadius then
		return "Pebble"
	end

	-- Forest floor with patches.
	local patch = Noise.value(x / PATCH_SCALE, z / PATCH_SCALE, PATCH_SEED)
	if patch > 0.75 then
		return "Grass"
	elseif patch < 0.15 then
		return "Mud"
	end
	return "LeafyGrass"
end

return HeightField
