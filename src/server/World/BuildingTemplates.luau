--!strict
-- Building floor plans on the 4-stud grid. One string per row; row 1 is the front (door side), which
-- faces -Z before the placement rotation. Every row of every floor has the same length. Pure data:
-- the Lune tests check that every room is reachable and every floor cell can be walked to.
--
-- Legend
--   #  wall            W  window          G  shop-front glass     D  doorway (open, door leaf swung back)
--   P  post            .  floor           (space) no floor
--   ^ v < >  stairs rising toward -row / +row / -col / +col (the floor above gets a hole and a railing)
--   Furniture (one cell each, backs against the best wall automatically):
--     bedroom   b bed, y wardrobe, c dresser
--     bathroom  T toilet + basin, U bathtub, n basin
--     kitchen   k counter, g stove, i sink, f fridge
--     living    o sofa, a armchair, e TV stand, F fireplace, t dining table + chairs, r bookshelf,
--               l floor lamp, p plant
--     clinic    h hospital bed, m medicine cabinet
--     office    d desk + chair, A filing cabinets, q waiting seats
--     shop      s store shelf, C checkout counter, B diner booth, L lockers
--     storage   x crates, R storage rack, w workbench, H hay bales

export type Template = {
	floors: { { string } },
	-- Exterior wall style key; "Siding" picks a colour per building.
	wall: string,
	-- Paint of every room (shops, sheds). nil = house: each room gets its own paint and floor.
	interior: string?,
	floor: string,
	roof: "Gable" | "Flat",
	-- Roof style key; "Shingles" picks a colour per building.
	roofStyle: string,
	-- Style of casings, corner boards and fascia (default "Trim").
	trim: string?,
	-- Localization key of the street sign above the front.
	sign: string?,
	-- Open shed or barn: no ceiling or ceiling lights; the roof trusses show.
	open: boolean?,
	-- Fluorescent ceiling panels (shops, offices) instead of one round fitting per room.
	panels: boolean?,
	chimney: boolean?,
	shutters: boolean?,
	-- Fabric awnings over shop-front glass.
	awnings: boolean?,
	-- Small canopy over exterior doors.
	porch: boolean?,
	-- Terrain surface under the footprint (default "Ground"); never grass, which grows through floors.
	apron: string?,
}

local HOUSE_TWO_STORY = {
	{
		"#W##D#W#",
		"#.o..al#",
		"W......W",
		"#^e...p#",
		"#^##D###",
		"#^....fW",
		"#..t...W",
		"W...kgi#",
		"##WDW###",
	},
	{
		"#W##WW##",
		"#..D..c#",
		"#..#..b#",
		"#..#y..W",
		"#..#####",
		"#..D..bW",
		"##D#c..#",
		"WT.#..y#",
		"##W##W##",
	},
}

local BuildingTemplates: { [string]: Template } = {
	-- One bedroom: open living room with a kitchen corner, bedroom, bathroom.
	HouseSmall = {
		wall = "Siding",
		floor = "WoodFloor",
		roof = "Gable",
		roofStyle = "Shingles",
		shutters = true,
		porch = true,
		floors = {
			{
				"#W#D##W#",
				"#a...D.#",
				"#o..e#bW",
				"W....###",
				"#..t.D.#",
				"#kgf.#T#",
				"#W##W#W#",
			},
		},
	},
	-- Hallway down the middle: living room with a dining corner and kitchen on the left, two bedrooms
	-- and a bathroom on the right, back door through the kitchen.
	HouseLarge = {
		wall = "Siding",
		floor = "WoodFloor",
		roof = "Gable",
		roofStyle = "Shingles",
		shutters = true,
		porch = true,
		chimney = true,
		floors = {
			{
				"#W##D##W#",
				"#ao..D.b#",
				"W...t#.yW",
				"#.e..####",
				"####.D.TW",
				"W....####",
				"#fgi.D.b#",
				"###WD##W#",
			},
		},
	},
	-- Living room and kitchen downstairs; two bedrooms and a WC upstairs.
	HouseTwoStory = {
		wall = "Siding",
		floor = "WoodFloor",
		roof = "Gable",
		roofStyle = "Shingles",
		shutters = true,
		porch = true,
		chimney = true,
		floors = HOUSE_TWO_STORY,
	},
	FarmHouse = {
		wall = "Planks",
		floor = "WoodFloor",
		roof = "Gable",
		roofStyle = "MetalRoof",
		trim = "DarkWood",
		porch = true,
		chimney = true,
		floors = HOUSE_TWO_STORY,
	},
	-- Sales floor with shelf aisles and fridges; storeroom and office at the back.
	Market = {
		wall = "Concrete",
		interior = "ShopPaint",
		floor = "Tile",
		roof = "Flat",
		roofStyle = "FlatRoof",
		sign = "SignMarket",
		panels = true,
		awnings = true,
		apron = "Pavement",
		floors = {
			{
				"#GGG#DD#GGG#",
				"#..........#",
				"#.CC......f#",
				"#...s.s.s.f#",
				"#...s.s.s.f#",
				"#...s.s.s.f#",
				"#p........f#",
				"###D###D####",
				"#Rx.xR#..dA#",
				"#.....#....#",
				"###D########",
			},
		},
	},
	-- Booths along the windows, counter, kitchen behind it with a back door.
	Diner = {
		wall = "Brick",
		interior = "KitchenPaint",
		floor = "Tile",
		roof = "Flat",
		roofStyle = "FlatRoof",
		sign = "SignDiner",
		panels = true,
		awnings = true,
		apron = "Pavement",
		floors = {
			{
				"#GG#D#GG#",
				"#B.....B#",
				"#B.....B#",
				"#..t.t..#",
				"#CCC.CCC#",
				"#.......#",
				"#kgi.ffk#",
				"####D####",
			},
		},
	},
	-- Waiting room, exam room and pharmacy downstairs; patient rooms and staff area upstairs.
	Clinic = {
		wall = "ClinicWhite",
		interior = "ShopPaint",
		floor = "Tile",
		roof = "Flat",
		roofStyle = "FlatRoof",
		sign = "SignClinic",
		panels = true,
		apron = "Pavement",
		floors = {
			{
				"#W#GGDDGG#W#",
				"#p........p#",
				"#q..CC....^#",
				"#q........^#",
				"#q........^#",
				"##D###D##..#",
				"#h.#mm.#h..#",
				"#..#...#h..#",
				"#nm#.Am#p..#",
				"##W##W##W###",
			},
			{
				"##W###W##W##",
				"#h..#h..#..#",
				"Wh..#h..#..#",
				"#m..#m..#..#",
				"##D###D##..#",
				"#..........#",
				"#.dd..t...L#",
				"#.........L#",
				"#A.....kf..#",
				"##W##W##W###",
			},
		},
	},
	-- Shelf aisles and counter; workshop with a back door.
	Hardware = {
		wall = "Brick",
		interior = "ShopPaint",
		floor = "Concrete",
		roof = "Flat",
		roofStyle = "FlatRoof",
		sign = "SignHardware",
		panels = true,
		awnings = true,
		apron = "Pavement",
		floors = {
			{
				"#GG#DD#GG#",
				"#.......p#",
				"#.s.s.s.C#",
				"#.s.s.s.C#",
				"#.s.s.s..#",
				"###D######",
				"#w....xxR#",
				"#w.......#",
				"###D######",
			},
		},
	},
	GasShop = {
		wall = "Concrete",
		interior = "ShopPaint",
		floor = "Tile",
		roof = "Flat",
		roofStyle = "FlatRoof",
		sign = "SignGasStation",
		panels = true,
		apron = "Pavement",
		floors = {
			{
				"#GDGG#",
				"#C..p#",
				"#s..f#",
				"#s..f#",
				"###W##",
			},
		},
	},
	-- Lobby, records room and offices downstairs; council room upstairs.
	TownHall = {
		wall = "Brick",
		interior = "OfficePaint",
		floor = "WoodFloor",
		roof = "Flat",
		roofStyle = "FlatRoof",
		sign = "SignTownHall",
		panels = true,
		apron = "Pavement",
		floors = {
			{
				"#W#W#DD#W#W#",
				"#p........p#",
				"#qq..CC..dA#",
				"#..........#",
				"####D####.v#",
				"#rr..#..d.v#",
				"#....#....v#",
				"#A.t.#.....#",
				"##W###W##W##",
			},
			{
				"#W#W##W#W#W#",
				"#..........#",
				"#.tttttt...#",
				"#..........#",
				"####D####..#",
				"#rr..#.....#",
				"#....#.....#",
				"#.d..D.....#",
				"##W###W##W##",
			},
		},
	},
	Warehouse = {
		wall = "Metal",
		interior = "Metal",
		floor = "Concrete",
		roof = "Flat",
		roofStyle = "MetalRoof",
		sign = "SignWarehouse",
		panels = true,
		apron = "Pavement",
		floors = {
			{
				"#W#DDD#W##W#",
				"#x.........#",
				"#x.RR.RR.R.#",
				"#..........#",
				"#x.RR.RR.R.#",
				"#..........#",
				"#ww.....xx.#",
				"#..........#",
				"#####D######",
			},
		},
	},
	Shack = {
		wall = "Planks",
		interior = "Planks",
		floor = "WoodFloor",
		roof = "Gable",
		roofStyle = "MetalRoof",
		trim = "DarkWood",
		floors = {
			{
				"#WD##",
				"#..x#",
				"#w.bW",
				"#####",
			},
		},
	},
	Cabin = {
		wall = "Logs",
		interior = "Logs",
		floor = "WoodFloor",
		roof = "Gable",
		roofStyle = "Shingles",
		trim = "DarkWood",
		porch = true,
		chimney = true,
		floors = {
			{
				"#WD##W#",
				"#F...b#",
				"Wa.t..W",
				"#..kgi#",
				"###W###",
			},
		},
	},
	Barn = {
		wall = "BarnRed",
		interior = "Planks",
		floor = "Dirt",
		roof = "Gable",
		roofStyle = "MetalRoof",
		open = true,
		floors = {
			{
				"#W#DDDD#W#",
				"#H......H#",
				"#H......H#",
				"##.#..#.##",
				"#........#",
				"#x......x#",
				"##.#..#.##",
				"#H......w#",
				"#H......w#",
				"####DD####",
			},
		},
	},
	SawmillShed = {
		wall = "Planks",
		floor = "WoodFloor",
		roof = "Gable",
		roofStyle = "MetalRoof",
		trim = "DarkWood",
		open = true,
		floors = {
			{
				"P..P..P..P",
				"..........",
				"..www..xx.",
				"..........",
				"..www..xx.",
				"..........",
				"..........",
				"P..P..P..P",
			},
		},
	},
}

return BuildingTemplates
