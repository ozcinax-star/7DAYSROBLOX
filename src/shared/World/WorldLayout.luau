--!strict
-- Level data for the MVP map (PLAN: two regions, Forest + Small Town). Pure data, no Roblox APIs.
-- All positions are world studs; the map is centred on the origin. Building corners sit on the 4-stud
-- build grid so walls line up with the zombie navigation cells.

export type Road = {
	name: string,
	points: { { number } },
	width: number,
	surface: "Asphalt" | "Dirt",
}

export type Pad = {
	name: string,
	x: number,
	z: number,
	radius: number,
	surface: "Dirt" | "Grass" | "Gravel",
}

export type BuildingPlacement = {
	template: string,
	name: string,
	-- Minimum world corner of the rotated footprint (multiples of 4).
	x: number,
	z: number,
	-- Quarter turns; 0 = front (door side) faces -Z, 1 = +X, 2 = +Z, 3 = -X.
	rotation: number,
	-- Loot category for the loot system that comes later (PLAN: region/building -> loot type).
	loot: string,
}

export type PropPlacement = {
	kind: string,
	x: number,
	z: number,
	-- Rotation around Y in degrees.
	yaw: number?,
	-- Kind-specific size or count.
	scale: number?,
}

local WorldLayout = {}

WorldLayout.Seed = 7

-- Map is 2048 x 2048. Mountains rise in the outer band and form the natural border.
WorldLayout.HalfSize = 1024
WorldLayout.MountainBand = 150
WorldLayout.MountainHeight = 170
-- Beyond this distance from the centre (on either axis) nobody can walk.
WorldLayout.PlayableHalfSize = 930

WorldLayout.BaseHeight = 0
-- Terrain is filled from this depth up to the surface.
WorldLayout.TerrainBottom = -24

WorldLayout.Hills = {
	Scale = 260,
	Height = 22,
	-- Noise value that maps to height 0 (below it dips slightly).
	Offset = 0.35,
	Octaves = 3,
}

-- Flattening around roads, pads and the town fades out over these distances.
WorldLayout.FlattenFade = {
	Road = 30,
	Pad = 40,
	Town = 60,
}

WorldLayout.Town = {
	minX = 60,
	maxX = 540,
	minZ = -60,
	maxZ = 420,
	sidewalkWidth = 4,
}

WorldLayout.Spawn = { x = -40, z = 130, radius = 70 }

WorldLayout.Lake = {
	x = -480,
	z = 420,
	radiusX = 130,
	radiusZ = 95,
	waterLevel = -1,
	depth = 12,
}

WorldLayout.Quarry = {
	x = -540,
	z = -470,
	radius = 110,
	depth = 24,
	-- Width of the sloped rim (studs); depth / rimWidth is the wall slope.
	rimWidth = 50,
}

WorldLayout.RadioHill = {
	x = -720,
	z = 720,
	radius = 160,
	height = 55,
	plateauRadius = 26,
}

WorldLayout.Farm = {
	fieldMinX = 640,
	fieldMaxX = 820,
	fieldMinZ = 700,
	fieldMaxZ = 780,
	rowSpacing = 8,
}

WorldLayout.Roads = {
	-- Highway crossing the whole map; it is the town's main street.
	{
		name = "Highway",
		width = 24,
		surface = "Asphalt",
		points = { { -930, 180 }, { -300, 180 }, { 60, 180 }, { 540, 180 }, { 930, 180 } },
	},
	-- Town grid
	{ name = "FirstStreet", width = 16, surface = "Asphalt", points = { { 180, -60 }, { 180, 420 } } },
	{ name = "SecondStreet", width = 16, surface = "Asphalt", points = { { 300, -60 }, { 300, 420 } } },
	{ name = "ThirdStreet", width = 16, surface = "Asphalt", points = { { 420, -60 }, { 420, 420 } } },
	{ name = "NorthAvenue", width = 16, surface = "Asphalt", points = { { 60, 60 }, { 540, 60 } } },
	{ name = "SouthAvenue", width = 16, surface = "Asphalt", points = { { 60, 300 }, { 540, 300 } } },
	-- Dirt roads to the forest points of interest
	{
		name = "SawmillRoad",
		width = 12,
		surface = "Dirt",
		points = { { -40, 180 }, { -110, -100 }, { -160, -400 } },
	},
	{
		name = "QuarryRoad",
		width = 12,
		surface = "Dirt",
		points = { { -300, 180 }, { -400, -150 }, { -420, -380 } },
	},
	{ name = "JunkyardRoad", width = 12, surface = "Dirt", points = { { 420, -60 }, { 520, -200 }, { 600, -300 } } },
	{ name = "CampRoad", width = 10, surface = "Dirt", points = { { 180, -60 }, { 200, -350 }, { 225, -620 } } },
	{ name = "LakeRoad", width = 10, surface = "Dirt", points = { { -250, 180 }, { -300, 330 }, { -320, 420 } } },
	{ name = "RangerRoad", width = 10, surface = "Dirt", points = { { -600, 180 }, { -660, 60 }, { -680, 0 } } },
	{ name = "FarmRoad", width = 12, surface = "Dirt", points = { { 540, 300 }, { 680, 450 }, { 710, 590 } } },
	{
		name = "RadioTrail",
		width = 8,
		surface = "Dirt",
		points = { { -320, 420 }, { -420, 560 }, { -600, 640 }, { -705, 705 } },
	},
} :: { Road }

-- Flat clearings around points of interest.
WorldLayout.Pads = {
	{ name = "SpawnMeadow", x = -40, z = 130, radius = 70, surface = "Grass" },
	{ name = "Sawmill", x = -170, z = -440, radius = 70, surface = "Dirt" },
	{ name = "QuarryYard", x = -400, z = -380, radius = 34, surface = "Gravel" },
	{ name = "Junkyard", x = 620, z = -340, radius = 75, surface = "Gravel" },
	{ name = "Campsite", x = 230, z = -670, radius = 55, surface = "Dirt" },
	{ name = "FishingCabin", x = -318, z = 440, radius = 34, surface = "Dirt" },
	{ name = "RangerStation", x = -690, z = -30, radius = 48, surface = "Dirt" },
	{ name = "Farm", x = 730, z = 680, radius = 120, surface = "Grass" },
} :: { Pad }

WorldLayout.Buildings = {
	-- Main street, north side (fronts face +Z toward the highway)
	{ template = "Market", name = "Market", x = 196, z = 120, rotation = 2, loot = "Food" },
	{ template = "Diner", name = "Diner", x = 252, z = 132, rotation = 2, loot = "Food" },
	{ template = "Clinic", name = "Clinic", x = 316, z = 124, rotation = 2, loot = "Medical" },
	{ template = "Hardware", name = "HardwareStore", x = 368, z = 128, rotation = 2, loot = "Metal" },
	{ template = "HouseLarge", name = "House01", x = 436, z = 132, rotation = 2, loot = "Fabric" },
	{ template = "HouseSmall", name = "House02", x = 484, z = 136, rotation = 2, loot = "Fabric" },
	{ template = "GasShop", name = "GasStation", x = 100, z = 92, rotation = 2, loot = "Food" },
	-- Main street, south side (fronts face -Z)
	{ template = "TownHall", name = "TownHall", x = 196, z = 196, rotation = 0, loot = "Fabric" },
	{ template = "HouseSmall", name = "House03", x = 252, z = 196, rotation = 0, loot = "Fabric" },
	{ template = "HouseTwoStory", name = "House04", x = 316, z = 196, rotation = 0, loot = "Fabric" },
	{ template = "HouseLarge", name = "House05", x = 364, z = 196, rotation = 0, loot = "Food" },
	{ template = "HouseSmall", name = "House06", x = 72, z = 196, rotation = 0, loot = "Fabric" },
	{ template = "HouseTwoStory", name = "House07", x = 120, z = 196, rotation = 0, loot = "Food" },
	{ template = "HouseLarge", name = "House08", x = 436, z = 196, rotation = 0, loot = "Fabric" },
	{ template = "HouseSmall", name = "House09", x = 492, z = 196, rotation = 0, loot = "Food" },
	-- South avenue, north side (fronts face +Z)
	{ template = "HouseSmall", name = "House10", x = 252, z = 260, rotation = 2, loot = "Fabric" },
	{ template = "HouseSmall", name = "House11", x = 372, z = 260, rotation = 2, loot = "Food" },
	-- South avenue, south side (fronts face -Z)
	{ template = "HouseSmall", name = "House12", x = 196, z = 316, rotation = 0, loot = "Fabric" },
	{ template = "HouseLarge", name = "House13", x = 240, z = 316, rotation = 0, loot = "Food" },
	{ template = "HouseTwoStory", name = "House14", x = 316, z = 316, rotation = 0, loot = "Fabric" },
	{ template = "HouseSmall", name = "House15", x = 372, z = 316, rotation = 0, loot = "Fabric" },
	{ template = "HouseLarge", name = "House16", x = 72, z = 316, rotation = 0, loot = "Food" },
	{ template = "HouseSmall", name = "House17", x = 128, z = 316, rotation = 0, loot = "Fabric" },
	{ template = "HouseTwoStory", name = "House18", x = 436, z = 316, rotation = 0, loot = "Food" },
	-- North avenue, north side (fronts face +Z)
	{ template = "HouseLarge", name = "House19", x = 196, z = 16, rotation = 2, loot = "Fabric" },
	{ template = "HouseSmall", name = "House20", x = 252, z = 20, rotation = 2, loot = "Food" },
	{ template = "HouseTwoStory", name = "House21", x = 316, z = 12, rotation = 2, loot = "Fabric" },
	{ template = "HouseSmall", name = "House22", x = 372, z = 20, rotation = 2, loot = "Fabric" },
	{ template = "Warehouse", name = "Warehouse", x = 448, z = -4, rotation = 2, loot = "Metal" },
	-- Forest points of interest
	{ template = "SawmillShed", name = "Sawmill", x = -212, z = -476, rotation = 1, loot = "Wood" },
	{ template = "Shack", name = "SawmillOffice", x = -128, z = -468, rotation = 3, loot = "Tools" },
	{ template = "Shack", name = "QuarryOffice", x = -412, z = -392, rotation = 3, loot = "Stone" },
	{ template = "Shack", name = "JunkyardOffice", x = 596, z = -404, rotation = 0, loot = "Metal" },
	{ template = "Cabin", name = "FishingCabin", x = -320, z = 428, rotation = 3, loot = "Food" },
	{ template = "Cabin", name = "RangerStation", x = -708, z = -48, rotation = 1, loot = "Medical" },
	{ template = "FarmHouse", name = "FarmHouse", x = 660, z = 600, rotation = 0, loot = "Food" },
	{ template = "Barn", name = "Barn", x = 732, z = 584, rotation = 0, loot = "Food" },
} :: { BuildingPlacement }

WorldLayout.Props = {
	-- Gas station
	{ kind = "GasCanopy", x = 112, z = 148 },
	{ kind = "GasPump", x = 100, z = 148 },
	{ kind = "GasPump", x = 124, z = 148 },
	-- Abandoned cars around town
	{ kind = "Car", x = 230, z = 176, yaw = 8 },
	{ kind = "Car", x = 360, z = 184, yaw = 172 },
	{ kind = "Car", x = 300, z = 96, yaw = 95 },
	{ kind = "Car", x = 420, z = 250, yaw = 270 },
	{ kind = "Car", x = 140, z = 300, yaw = 5 },
	{ kind = "Car", x = -150, z = 178, yaw = 20 },
	{ kind = "Car", x = 700, z = 186, yaw = 160 },
	{ kind = "Barricade", x = 552, z = 180, yaw = 90 },
	{ kind = "Barricade", x = 552, z = 168, yaw = 90 },
	{ kind = "Barricade", x = 552, z = 192, yaw = 90 },
	-- Town square in front of the town hall
	{ kind = "Bench", x = 210, z = 244, yaw = 0 },
	{ kind = "Bench", x = 232, z = 244, yaw = 0 },
	{ kind = "Fountain", x = 220, z = 262 },
	-- Sawmill
	{ kind = "LogPile", x = -150, z = -420, yaw = 0 },
	{ kind = "LogPile", x = -150, z = -400, yaw = 0 },
	{ kind = "LogPile", x = -230, z = -400, yaw = 90 },
	{ kind = "Truck", x = -130, z = -390, yaw = 200 },
	-- Quarry
	{ kind = "StonePile", x = -540, z = -470 },
	{ kind = "StonePile", x = -510, z = -500 },
	{ kind = "StonePile", x = -575, z = -440 },
	{ kind = "Crane", x = -470, z = -420, yaw = 45 },
	-- Junkyard
	{ kind = "ScrapStack", x = 600, z = -330 },
	{ kind = "ScrapStack", x = 640, z = -300 },
	{ kind = "ScrapStack", x = 660, z = -360 },
	{ kind = "ScrapStack", x = 580, z = -290 },
	{ kind = "JunkFence", x = 620, z = -340, scale = 70 },
	-- Campsite
	{ kind = "Tent", x = 210, z = -660, yaw = 30 },
	{ kind = "Tent", x = 250, z = -690, yaw = 200 },
	{ kind = "Tent", x = 240, z = -645, yaw = 120 },
	{ kind = "Campfire", x = 232, z = -668 },
	{ kind = "PicnicTable", x = 212, z = -690, yaw = 0 },
	{ kind = "Outhouse", x = 268, z = -650, yaw = 270 },
	-- Lake
	{ kind = "Dock", x = -372, z = 420, yaw = 90, scale = 44 },
	{ kind = "Boat", x = -410, z = 400, yaw = 70 },
	-- Ranger station
	{ kind = "WatchTower", x = -660, z = -40 },
	-- Farm
	{ kind = "Silo", x = 800, z = 600 },
	{ kind = "CropField", x = 730, z = 740 },
	{ kind = "Tractor", x = 700, z = 660, yaw = 30 },
	-- Radio hill
	{ kind = "RadioMast", x = -720, z = 720 },
	{ kind = "Shed", x = -735, z = 705 },
	-- Spawn meadow (first base spot): a few logs and a burnt-out car for cover
	{ kind = "FallenLog", x = -10, z = 100, yaw = 30 },
	{ kind = "Car", x = -80, z = 150, yaw = 120 },
} :: { PropPlacement }

-- Forest scatter: one candidate per cell, kept when the density noise allows.
WorldLayout.Forest = {
	CellSize = 26,
	Jitter = 0.8,
	DensityScale = 180,
	-- Density noise above this keeps a tree; lower = denser forest.
	Threshold = 0.38,
	-- Keep trees this far from roads, pads, buildings and the lake shore.
	RoadClearance = 10,
	PadClearance = 8,
	PineChance = 0.6,
	RockChance = 0.05,
	BushChance = 0.12,
	LogChance = 0.03,
}

return WorldLayout
