--!strict
-- MapService: builds the MVP map (PLAN: Forest + Small Town) from WorldLayout at server start:
-- terrain, enterable buildings, props, street dressing and the forest. Characters are only loaded
-- once the world exists, so nobody falls through a half-built map.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HeightField = require(ReplicatedStorage.Shared.World.HeightField)
local Noise = require(ReplicatedStorage.Shared.World.Noise)
local WorldLayout = require(ReplicatedStorage.Shared.World.WorldLayout)

local World = script.Parent.Parent.World
local BuildingKit = require(World.BuildingKit)
local PropKit = require(World.PropKit)
local TerrainBuilder = require(World.TerrainBuilder)

local MapService = {}

-- Street dressing spacing (studs).
local LAMP_SPACING = 40
local LAMP_SIDE_OFFSET = 4
local POLE_SPACING = 64
local POLE_SIDE_OFFSET = 18
-- A lamp that would stand in front of a doorway moves along the road by one of these offsets.
local LAMP_SHIFTS = { 0, 8, -8 }
-- Street furniture keeps this distance from the cell in front of an exterior doorway, so the
-- doorway stays open for players and the zombie navigation grid.
local DOOR_CLEARANCE = 6
-- Distance of the mailbox / bin from the house front and from its centre line.
local FRONT_OFFSET = 4
local MAILBOX_SIDE = 8
-- Props sink slightly into the ground so slopes never show a gap.
local GROUND_SINK = 0.3
-- Trees and rocks keep this distance from buildings (added to half the footprint diagonal).
local BUILDING_CLEARANCE = 8
local PROP_CLEARANCE = 10
-- Trees grow up to this far into the mountain band (0-1).
local FOREST_MOUNTAIN_LIMIT = 0.45
local LAKE_TREE_CLEARANCE = 1.3
-- Objects created between yields while building.
local BATCH = 150
local SPAWN_SIZE = Vector3.new(8, 1, 8)

-- Terrain surfaces that stay as they are under a building's apron.
local KEEP_SURFACES = { Asphalt = true, Pavement = true }
-- Column size of the height grid.
local COLUMN = 4

local mapFolder: Folder? = nil
local heightGrid: TerrainBuilder.HeightGrid? = nil
-- Ground-floor walking height per height-grid column inside building footprints.
local floorTops: { [number]: number } = {}
local ready = false

type Circle = { x: number, z: number, radius: number }

-- One entry per placed building, for systems that need to know where buildings and their doors are
-- (zombies walking in and out, indoor spawns, loot).
export type BuildingInfo = {
	name: string,
	template: string,
	model: Model,
	region: string,
	-- Footprint rectangle in world studs (walls included).
	minX: number,
	minZ: number,
	maxX: number,
	maxZ: number,
	baseY: number,
	floors: number,
	-- World centre of the navigation cell in front of every exterior ground-floor doorway.
	doorFronts: { Vector3 },
}

local doorFronts: { Circle } = {}
local buildings: { BuildingInfo } = {}

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Terrain height at (x, z).
function MapService.heightAt(x: number, z: number): number
	return TerrainBuilder.heightAt(assert(heightGrid, "MapService not initialized"), x, z)
end

-- Walking height at (x, z): the terrain, or a building's ground floor where one stands.
function MapService.groundAt(x: number, z: number): number
	local grid = assert(heightGrid, "MapService not initialized")
	local ground = TerrainBuilder.heightAt(grid, x, z)
	local column = TerrainBuilder.columnAt(grid, x, z)
	local floorTop = if column then floorTops[column] else nil
	if floorTop and floorTop > ground then
		return floorTop
	end
	return ground
end

local function yieldEvery(counter: number)
	if counter % BATCH == 0 then
		task.wait()
	end
end

-- Calls visit(column) for every height-grid column whose centre lies in the placement's footprint.
local function forFootprint(placement: WorldLayout.BuildingPlacement, visit: (number) -> ())
	local grid = assert(heightGrid, "MapService not initialized")
	local width, depth = BuildingKit.footprint(placement.template, placement.rotation)
	for z = placement.z + COLUMN / 2, placement.z + depth, COLUMN do
		for x = placement.x + COLUMN / 2, placement.x + width, COLUMN do
			local column = TerrainBuilder.columnAt(grid, x, z)
			if column then
				visit(column)
			end
		end
	end
end

-- Bare ground (or pavement) under every building, so terrain grass never grows through a floor.
local function layAprons(grid: TerrainBuilder.HeightGrid)
	for _, placement in WorldLayout.Buildings do
		local apron = BuildingKit.apron(placement.template)
		forFootprint(placement, function(column)
			if not KEEP_SURFACES[grid.surfaces[column + 1]] then
				grid.surfaces[column + 1] = apron
			end
		end)
	end
end

local function buildBuildings(parent: Instance, keepOut: { Circle })
	local count = 0
	for _, placement in WorldLayout.Buildings do
		local width, depth = BuildingKit.footprint(placement.template, placement.rotation)
		local cx, cz = placement.x + width / 2, placement.z + depth / 2
		local baseY = MapService.heightAt(cx, cz)
		local model, fronts = BuildingKit.build(placement, baseY, parent)
		for _, front in fronts do
			table.insert(doorFronts, { x = front.X, z = front.Z, radius = DOOR_CLEARANCE })
		end
		local region = HeightField.regionAt(cx, cz)
		model:SetAttribute("Region", region)
		table.insert(buildings, {
			name = placement.name,
			template = placement.template,
			model = model,
			region = region,
			minX = placement.x,
			minZ = placement.z,
			maxX = placement.x + width,
			maxZ = placement.z + depth,
			baseY = baseY,
			floors = model:GetAttribute("Floors") :: number,
			doorFronts = fronts,
		})
		forFootprint(placement, function(column)
			floorTops[column] = baseY + BuildingKit.FloorTop
		end)
		table.insert(keepOut, {
			x = cx,
			z = cz,
			radius = math.sqrt(width * width + depth * depth) / 2 + BUILDING_CLEARANCE,
		})
		count += 1
		yieldEvery(count)
	end
end

-- Mailbox and trash bin in front of every house.
local function buildHouseFronts(parent: Instance)
	for _, placement in WorldLayout.Buildings do
		if string.find(placement.template, "House") then
			local width, depth = BuildingKit.footprint(placement.template, placement.rotation)
			local x, z = placement.x, placement.z
			local fx, fz, sx, sz
			local r = placement.rotation % 4
			if r == 0 then
				fx, fz, sx, sz = x + width / 2, z - FRONT_OFFSET, 1, 0
			elseif r == 1 then
				fx, fz, sx, sz = x + width + FRONT_OFFSET, z + depth / 2, 0, 1
			elseif r == 2 then
				fx, fz, sx, sz = x + width / 2, z + depth + FRONT_OFFSET, 1, 0
			else
				fx, fz, sx, sz = x - FRONT_OFFSET, z + depth / 2, 0, 1
			end
			local mx, mz = fx + sx * MAILBOX_SIDE, fz + sz * MAILBOX_SIDE
			PropKit.build("Mailbox", mx, MapService.heightAt(mx, mz), mz, r * 90, 1, placement.name, parent)
			local bx, bz = fx - sx * MAILBOX_SIDE, fz - sz * MAILBOX_SIDE
			PropKit.build("TrashBin", bx, MapService.heightAt(bx, bz), bz, 0, 1, placement.name, parent)
		end
	end
end

local function buildLayoutProps(parent: Instance, keepOut: { Circle })
	local count = 0
	for index, prop in WorldLayout.Props do
		local onWater = prop.kind == "Dock" or prop.kind == "Boat"
		local y = if onWater then HeightField.waterLevel() else MapService.heightAt(prop.x, prop.z) - GROUND_SINK
		PropKit.build(prop.kind, prop.x, y, prop.z, prop.yaw or 0, prop.scale or 1, `{prop.kind}{index}`, parent)
		table.insert(keepOut, { x = prop.x, z = prop.z, radius = (prop.scale or 0) / 2 + PROP_CLEARANCE })
		count += 1
		yieldEvery(count)
	end
end

-- Walks a polyline and calls place(x, z, dirX, dirZ) every `spacing` studs.
local function alongRoad(road: WorldLayout.Road, spacing: number, place: (number, number, number, number) -> ())
	local carry = 0
	for i = 1, #road.points - 1 do
		local a, b = road.points[i], road.points[i + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local length = math.sqrt(dx * dx + dz * dz)
		local ux, uz = dx / length, dz / length
		local t = carry
		while t < length do
			place(a[1] + ux * t, a[2] + uz * t, ux, uz)
			t += spacing
		end
		carry = t - length
	end
end

local function insideAny(circles: { Circle }, x: number, z: number): boolean
	for _, c in circles do
		local dx, dz = x - c.x, z - c.z
		if dx * dx + dz * dz < c.radius * c.radius then
			return true
		end
	end
	return false
end

local function placeRoadside(kind: string, x: number, z: number, yaw: number, parent: Instance): boolean
	-- Skip spots that land on another road, in the lake, outside the playable area or in front of a
	-- doorway.
	if
		not HeightField.isPlayable(x, z)
		or HeightField.isWater(x, z)
		or HeightField.nearestRoad(x, z) < 1
		or insideAny(doorFronts, x, z)
	then
		return false
	end
	PropKit.build(kind, x, MapService.heightAt(x, z) - GROUND_SINK, z, yaw, 1, kind, parent)
	return true
end

local function buildStreetDressing(parent: Instance)
	local count = 0
	for _, road in WorldLayout.Roads do
		if road.surface == "Asphalt" then
			-- Street lamps on both sides inside town; the arm (local -Z) points at the road.
			alongRoad(road, LAMP_SPACING, function(x, z, ux, uz)
				if not HeightField.isInTown(x, z) then
					return
				end
				for _, side in { -1, 1 } do
					local offset = road.width / 2 + LAMP_SIDE_OFFSET
					local yaw = math.deg(math.atan2(-uz * side, ux * side))
					for _, shift in LAMP_SHIFTS do
						local px = x - uz * offset * side + ux * shift
						local pz = z + ux * offset * side + uz * shift
						if placeRoadside("StreetLamp", px, pz, yaw, parent) then
							count += 1
							yieldEvery(count)
							break
						end
					end
				end
			end)
		end
		if road.name == "Highway" then
			-- Power poles along the highway outside town.
			alongRoad(road, POLE_SPACING, function(x, z, ux, uz)
				if HeightField.isInTown(x, z) then
					return
				end
				local px, pz = x - uz * POLE_SIDE_OFFSET, z + ux * POLE_SIDE_OFFSET
				if placeRoadside("PowerPole", px, pz, math.deg(math.atan2(-uz, ux)), parent) then
					count += 1
					yieldEvery(count)
				end
			end)
		end
	end
end

local function canGrow(x: number, z: number, keepOut: { Circle }): boolean
	local forest = WorldLayout.Forest
	if not HeightField.isPlayable(x, z) or HeightField.isInTown(x, z) then
		return false
	end
	local edgeDistance = WorldLayout.HalfSize - math.max(math.abs(x), math.abs(z))
	if edgeDistance < WorldLayout.MountainBand * (1 - FOREST_MOUNTAIN_LIMIT) then
		return false
	end
	local lake = WorldLayout.Lake
	local lx, lz = (x - lake.x) / lake.radiusX, (z - lake.z) / lake.radiusZ
	if lx * lx + lz * lz < LAKE_TREE_CLEARANCE * LAKE_TREE_CLEARANCE then
		return false
	end
	local quarry = WorldLayout.Quarry
	local qx, qz = x - quarry.x, z - quarry.z
	if qx * qx + qz * qz < (quarry.radius + forest.PadClearance) ^ 2 then
		return false
	end
	local hill = WorldLayout.RadioHill
	local hx, hz = x - hill.x, z - hill.z
	if hx * hx + hz * hz < (hill.plateauRadius + forest.PadClearance) ^ 2 then
		return false
	end
	for _, pad in WorldLayout.Pads do
		local px, pz = x - pad.x, z - pad.z
		if px * px + pz * pz < (pad.radius + forest.PadClearance) ^ 2 then
			return false
		end
	end
	local roadDistance = HeightField.nearestRoad(x, z)
	if roadDistance < forest.RoadClearance then
		return false
	end
	return not insideAny(keepOut, x, z)
end

local function buildForest(parent: Instance, keepOut: { Circle })
	local forest = WorldLayout.Forest
	local seed = WorldLayout.Seed
	local cell = forest.CellSize
	local limit = WorldLayout.PlayableHalfSize
	local count = 0
	for gz = -limit, limit, cell do
		for gx = -limit, limit, cell do
			local ix, iz = gx // cell, gz // cell
			local x = gx + (Noise.hash(ix, iz, seed + 1) - 0.5) * cell * forest.Jitter
			local z = gz + (Noise.hash(ix, iz, seed + 2) - 0.5) * cell * forest.Jitter
			local density = Noise.fractal(x / forest.DensityScale, z / forest.DensityScale, seed + 3, 2)
			if density > forest.Threshold and canGrow(x, z, keepOut) then
				local roll = Noise.hash(ix, iz, seed + 4)
				local scale = 0.8 + Noise.hash(ix, iz, seed + 5) * 0.5
				local yaw = Noise.hash(ix, iz, seed + 6) * 360
				local kind
				if roll < forest.RockChance then
					kind = "Rock"
				elseif roll < forest.RockChance + forest.LogChance then
					kind = "FallenLog"
				elseif roll < forest.RockChance + forest.LogChance + forest.BushChance then
					kind = "Bush"
				elseif Noise.hash(ix, iz, seed + 7) < forest.PineChance then
					kind = "Pine"
				else
					kind = "Oak"
				end
				PropKit.build(kind, x, MapService.heightAt(x, z) - GROUND_SINK, z, yaw, scale, kind, parent)
				count += 1
				yieldEvery(count)
			end
		end
	end
end

function MapService.init()
	Players.CharacterAutoLoads = false

	local existing = Workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = Workspace
	mapFolder = map

	local grid = TerrainBuilder.sample()
	heightGrid = grid
	layAprons(grid)
	TerrainBuilder.build(grid)

	local keepOut: { Circle } = {}
	buildBuildings(folder("Buildings", map), keepOut)
	local props = folder("Props", map)
	buildLayoutProps(props, keepOut)
	buildHouseFronts(props)
	buildStreetDressing(props)
	buildForest(folder("Forest", map), keepOut)

	local spawnPoint = WorldLayout.Spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = SPAWN_SIZE
	spawn.Position = Vector3.new(
		spawnPoint.x,
		MapService.heightAt(spawnPoint.x, spawnPoint.z) + SPAWN_SIZE.Y / 2,
		spawnPoint.z
	)
	spawn.Neutral = true
	spawn.Parent = map
	ready = true
end

function MapService.start()
	Players.CharacterAutoLoads = true
	for _, player in Players:GetPlayers() do
		if player.Character == nil then
			task.spawn(player.LoadCharacter, player)
		end
	end
end

function MapService.isReady(): boolean
	return ready
end

function MapService.getMap(): Folder
	return assert(mapFolder, "MapService not initialized")
end

function MapService.getBuildings(): { BuildingInfo }
	return buildings
end

function MapService.getHeightGrid(): TerrainBuilder.HeightGrid
	return assert(heightGrid, "MapService not initialized")
end

return MapService
