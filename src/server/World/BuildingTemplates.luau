--!strict
-- Building floor plans on the 4-stud grid. One string per row; row 1 is the front (door side), which
-- faces -Z before the placement rotation. Every row of a floor has the same length.
--
-- Legend
--   #  wall            W  window          G  shop-front glass     D  doorway (open)
--   P  post            .  floor           (space) no floor
--   ^ v < >  stairs rising toward -row / +row / -col / +col (lower floor only; the floor above gets a
--            hole automatically)
--   Furniture (one cell each): b bed, t table, s store shelf, k kitchen counter, f fridge, o sofa,
--   r bookshelf, x crate, h hospital bed, m medicine cabinet, C checkout counter, w workbench,
--   d desk, B diner booth, H hay bale

export type Template = {
	floors: { { string } },
	-- Wall style key in BuildingKit palettes; "Siding" picks a colour per building.
	wall: string,
	floor: string,
	roof: "Gable" | "Flat",
	roofStyle: string,
}

local HOUSE_TWO_STORY = {
	{
		"#W##D#W#",
		"#.oo...#",
		"#^.....W",
		"#^..t..#",
		"#^.###D#",
		"#..#k..#",
		"W..#kf.#",
		"##W###W#",
	},
	{
		"#W###W##",
		"#..D..b#",
		"#..#..b#",
		"#..#.r.W",
		"#..##D##",
		"#.....b#",
		"W.o...b#",
		"##W##W##",
	},
}

local BuildingTemplates: { [string]: Template } = {
	HouseSmall = {
		wall = "Siding",
		floor = "WoodFloor",
		roof = "Gable",
		roofStyle = "Shingles",
		floors = {
			{
				"#W#D#W#",
				"#o..#b#",
				"#t..D.#",
				"W...#.W",
				"#kkf#r#",
				"###W###",
			},
		},
	},
	HouseLarge = {
		wall = "Siding",
		floor = "WoodFloor",
		roof = "Gable",
		roofStyle = "Shingles",
		floors = {
			{
				"#W#D##W#",
				"#o.....#",
				"#o..t..W",
				"##D###D#",
				"#k.#b..#",
				"#kf#b.r#",
				"##W##W##",
			},
		},
	},
	HouseTwoStory = {
		wall = "Siding",
		floor = "WoodFloor",
		roof = "Gable",
		roofStyle = "Shingles",
		floors = HOUSE_TWO_STORY,
	},
	FarmHouse = {
		wall = "Planks",
		floor = "WoodFloor",
		roof = "Gable",
		roofStyle = "MetalRoof",
		floors = HOUSE_TWO_STORY,
	},
	Market = {
		wall = "Concrete",
		floor = "Tile",
		roof = "Flat",
		roofStyle = "FlatRoof",
		floors = {
			{
				"#GGG#DD#GGG#",
				"#..........#",
				"#.CC.......#",
				"#....s.s.s.#",
				"#....s.s.s.#",
				"#....s.s.s.#",
				"#..........#",
				"#ffff..xx..#",
				"#..........#",
				"####D#######",
			},
		},
	},
	Diner = {
		wall = "Brick",
		floor = "Tile",
		roof = "Flat",
		roofStyle = "FlatRoof",
		floors = {
			{
				"#GG#D#GG#",
				"#B.....B#",
				"#B..t..B#",
				"#.......#",
				"#CCCC.CC#",
				"#kk...kf#",
				"####D####",
			},
		},
	},
	Clinic = {
		wall = "ClinicWhite",
		floor = "Tile",
		roof = "Flat",
		roofStyle = "FlatRoof",
		floors = {
			{
				"#W#GGDDGG#W#",
				"#..........#",
				"#.CC.oo...^#",
				"#.........^#",
				"#.........^#",
				"##D###D##..#",
				"#h.#mm.#h..#",
				"#h.#...#h..#",
				"#..#..m#...#",
				"##W##W##W###",
			},
			{
				"#W##W##W##W#",
				"#h.#h.#h...#",
				"#..#..#....#",
				"##D##D##D..#",
				"#..........#",
				"#mm....xx..#",
				"#..........#",
				"#.d....d...#",
				"#..........#",
				"##W##W##W###",
			},
		},
	},
	Hardware = {
		wall = "Brick",
		floor = "Concrete",
		roof = "Flat",
		roofStyle = "FlatRoof",
		floors = {
			{
				"#GG#DD#GG#",
				"#........#",
				"#.s.s.s..#",
				"#.s.s.s.C#",
				"#.......C#",
				"#ww..xx..#",
				"#ww..xx..#",
				"####D#####",
			},
		},
	},
	GasShop = {
		wall = "Concrete",
		floor = "Tile",
		roof = "Flat",
		roofStyle = "FlatRoof",
		floors = {
			{
				"#GDGG#",
				"#....#",
				"#s.sC#",
				"#s..f#",
				"###W##",
			},
		},
	},
	TownHall = {
		wall = "Brick",
		floor = "WoodFloor",
		roof = "Flat",
		roofStyle = "FlatRoof",
		floors = {
			{
				"#W#W#DD#W#W#",
				"#..........#",
				"#.dd...dd..#",
				"#..........#",
				"####D####.v#",
				"#rr...#r..v#",
				"#.....#...v#",
				"#..t..#....#",
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
		floor = "Concrete",
		roof = "Flat",
		roofStyle = "MetalRoof",
		floors = {
			{
				"#W#DDD#W##W#",
				"#..........#",
				"#.xx.xx.xx.#",
				"#.xx.xx.xx.#",
				"#..........#",
				"#.ss.ss.ss.#",
				"#..........#",
				"#ww....kk..#",
				"#####D######",
			},
		},
	},
	Shack = {
		wall = "Planks",
		floor = "WoodFloor",
		roof = "Gable",
		roofStyle = "MetalRoof",
		floors = {
			{
				"#WD##",
				"#..x#",
				"#w..W",
				"#####",
			},
		},
	},
	Cabin = {
		wall = "Logs",
		floor = "WoodFloor",
		roof = "Gable",
		roofStyle = "Shingles",
		floors = {
			{
				"#WD#W#",
				"#o..b#",
				"W.t.b#",
				"#kf..W",
				"##W###",
			},
		},
	},
	Barn = {
		wall = "BarnRed",
		floor = "Dirt",
		roof = "Gable",
		roofStyle = "MetalRoof",
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
