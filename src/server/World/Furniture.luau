--!strict
-- Furniture for the building floor plans. Each piece is built in its cell's frame: origin on the floor
-- at the cell centre, local +Z toward the wall behind it, front toward -Z. Bodies collide (they are
-- obstacles for players and the zombie nav grid, and stay inside their own cell); small dressing is
-- decor and never collides. Every piece becomes its own Model so later systems (loot, searching) can
-- address it by its "Furniture" attribute.

local Palette = require(script.Parent.Palette)
local PartFactory = require(script.Parent.PartFactory)

local Furniture = {}

local S = Palette.Styles
local DECOR = PartFactory.DECOR
local BALL_DECOR: PartFactory.Options = { shape = Enum.PartType.Ball, decor = true }
local V = Vector3.new

-- Free-standing pieces near a wall without a back (lamps, plants) keep this gap to it.
local CORNER_GAP = 1.0

export type Placement = {
	model: Model,
	base: CFrame,
	-- Distance from the cell centre to the wall face behind; nil when the piece stands free.
	back: number?,
	-- The wall behind is solid (no window), so wall cabinets, mirrors and pegboards fit.
	solidBack: boolean,
	-- Building key (consistent picks within a building) and cell key (variation per piece).
	key: string,
	cell: string,
}

type Builder = (p: Placement) -> ()

-- Box with its bottom at height y and its centre at (x, z) in the cell frame.
local function box(
	p: Placement,
	name: string,
	size: Vector3,
	x: number,
	y: number,
	z: number,
	style: Palette.Style,
	decor: boolean?
): BasePart
	return PartFactory.make(
		p.model,
		name,
		size,
		p.base * CFrame.new(x, y + size.Y / 2, z),
		style,
		if decor then DECOR else nil
	)
end

-- Centre z of a piece `depth` deep: its back on the wall, or centred when it stands free.
local function backZ(p: Placement, depth: number): number
	return if p.back then p.back - depth / 2 else 0
end

local function pick(list: { Palette.Style }, p: Placement, salt: string): Palette.Style
	return PartFactory.pick(list, p.key .. salt)
end

local function pickPerPiece(list: { Palette.Style }, p: Placement, salt: string): Palette.Style
	return PartFactory.pick(list, p.key .. p.cell .. salt)
end

-- Chair at (x, z) with its back toward local +Z rotated by yaw (decor: never blocks a path).
local function chair(p: Placement, x: number, z: number, yaw: number, style: Palette.Style)
	local frame = p.base * CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	PartFactory.make(p.model, "ChairSeat", V(1.3, 1.6, 1.3), frame * CFrame.new(0, 0.8, 0), style, DECOR)
	PartFactory.make(p.model, "ChairBack", V(1.3, 1.9, 0.25), frame * CFrame.new(0, 2.55, 0.55), style, DECOR)
end

local function seat(p: Placement, name: string, width: number)
	local depth = 2.6
	local z = backZ(p, depth)
	local fabric = pick(Palette.Fabrics, p, "upholstery")
	box(p, name, V(width, 1.5, depth), 0, 0, z, fabric)
	box(p, name .. "Back", V(width, 2.1, 0.8), 0, 1.5, z + depth / 2 - 0.4, fabric)
	box(p, "Arm", V(0.6, 0.9, depth), -width / 2 + 0.3, 1.5, z, fabric, true)
	box(p, "Arm", V(0.6, 0.9, depth), width / 2 - 0.3, 1.5, z, fabric, true)
end

local function wallCabinet(p: Placement)
	if p.back and p.solidBack then
		box(p, "WallCabinet", V(4, 2.6, 1.2), 0, 6, p.back - 0.6, S.Cabinet, true)
	end
end

local function counterBody(p: Placement): (number, number)
	local depth = 2.4
	local z = backZ(p, depth)
	box(p, "Cabinet", V(4, 3, depth), 0, 0, z, S.Cabinet)
	box(p, "Worktop", V(4, 0.25, depth + 0.15), 0, 3, z - 0.075, S.Counter, true)
	box(p, "DrawerLine", V(3.8, 0.06, 0.05), 0, 2.2, z - depth / 2 - 0.03, S.DarkWood, true)
	return z, depth
end

local function basin(p: Placement, x: number)
	local depth = 1.5
	local z = backZ(p, depth)
	box(p, "Vanity", V(1.9, 2.8, depth), x, 0, z, S.Cabinet)
	box(p, "Basin", V(1.7, 0.2, depth - 0.2), x, 2.8, z, S.Porcelain, true)
	box(p, "Tap", V(0.2, 0.6, 0.2), x, 3, z + depth / 2 - 0.25, S.Steel, true)
	if p.back and p.solidBack then
		box(p, "Mirror", V(1.6, 2.2, 0.08), x, 4.4, p.back - 0.04, S.Mirror, true)
	end
end

local Builders: { [string]: Builder } = {
	-- Bedroom
	b = function(p)
		local depth = if p.back then 5.3 else 3.9
		local z = backZ(p, depth)
		local head = z + depth / 2
		box(p, "BedFrame", V(3.6, 1, depth), 0, 0, z, S.Wood)
		box(p, "Mattress", V(3.4, 0.7, depth - 0.4), 0, 1, z - 0.1, S.Sheet)
		box(p, "Blanket", V(3.5, 0.2, depth * 0.62), 0, 1.6, z - depth * 0.19 - 0.1, pickPerPiece(Palette.Fabrics, p, "blanket"), true)
		box(p, "Pillow", V(2.4, 0.45, 0.9), 0, 1.7, head - 0.95, S.Sheet, true)
		box(p, "Headboard", V(3.8, 3.4, 0.3), 0, 0, head - 0.15, S.DarkWood)
	end,
	y = function(p)
		local depth = 2
		local z = backZ(p, depth)
		local front = z - depth / 2
		box(p, "Wardrobe", V(3.6, 7.6, depth), 0, 0, z, S.Wood)
		box(p, "DoorGap", V(0.08, 7, 0.06), 0, 0.3, front - 0.03, S.DarkWood, true)
		box(p, "Handle", V(0.15, 0.8, 0.15), -0.35, 3.6, front - 0.08, S.Brass, true)
		box(p, "Handle", V(0.15, 0.8, 0.15), 0.35, 3.6, front - 0.08, S.Brass, true)
	end,
	c = function(p)
		local depth = 1.7
		local z = backZ(p, depth)
		local front = z - depth / 2
		box(p, "Dresser", V(3.4, 3.2, depth), 0, 0, z, S.Wood)
		box(p, "DrawerLine", V(3.2, 0.06, 0.05), 0, 1.05, front - 0.03, S.DarkWood, true)
		box(p, "DrawerLine", V(3.2, 0.06, 0.05), 0, 2.1, front - 0.03, S.DarkWood, true)
		box(p, "TableLamp", V(0.7, 1.2, 0.7), 1.1, 3.2, z, S.Lamp, true)
		box(p, "PhotoFrame", V(0.9, 1.1, 0.15), -0.8, 3.2, z + 0.3, S.DarkWood, true)
	end,

	-- Bathroom
	T = function(p)
		local depth = 2.2
		local z = backZ(p, depth)
		box(p, "ToiletBowl", V(1.3, 1.5, 1.6), -1, 0, z - 0.3, S.Porcelain)
		box(p, "ToiletTank", V(1.6, 1.4, 0.6), -1, 1.4, z + depth / 2 - 0.3, S.Porcelain, true)
		box(p, "ToiletLid", V(1.4, 0.12, 1.5), -1, 1.5, z - 0.35, S.Porcelain, true)
		basin(p, 1.05)
	end,
	U = function(p)
		local depth = 2.6
		local z = backZ(p, depth)
		box(p, "Bathtub", V(3.9, 1.9, depth), 0, 0, z, S.Porcelain)
		box(p, "TubInside", V(3.4, 0.05, depth - 0.5), 0, 1.9, z, S.BathTile, true)
		box(p, "Tap", V(0.25, 0.25, 0.6), -1.5, 2.1, z + depth / 2 - 0.4, S.Steel, true)
	end,
	n = function(p)
		basin(p, 0)
	end,

	-- Kitchen
	k = function(p)
		counterBody(p)
		wallCabinet(p)
	end,
	g = function(p)
		local depth = 2.4
		local z = backZ(p, depth)
		box(p, "Stove", V(4, 3, depth), 0, 0, z, S.Appliance)
		box(p, "Cooktop", V(3.6, 0.1, depth - 0.2), 0, 3, z, S.Screen, true)
		box(p, "OvenDoor", V(2.8, 1.5, 0.06), 0, 0.6, z - depth / 2 - 0.03, S.Screen, true)
		if p.back and p.solidBack then
			box(p, "Hood", V(3, 1, 1.6), 0, 6.6, p.back - 0.8, S.Steel, true)
		end
	end,
	i = function(p)
		local z, depth = counterBody(p)
		box(p, "Sink", V(2, 0.08, 1.4), 0, 3.22, z, S.Steel, true)
		box(p, "Tap", V(0.2, 0.9, 0.2), 0, 3.25, z + depth / 2 - 0.3, S.Steel, true)
		wallCabinet(p)
	end,
	f = function(p)
		local depth = 2.6
		local z = backZ(p, depth)
		local front = z - depth / 2
		box(p, "Fridge", V(3.2, 6.8, depth), 0, 0, z, S.Appliance)
		box(p, "DoorGap", V(3.22, 0.08, 0.05), 0, 4.4, front - 0.03, S.Steel, true)
		box(p, "Handle", V(0.15, 1.4, 0.15), 1.3, 4.8, front - 0.1, S.Steel, true)
		box(p, "Handle", V(0.15, 1.8, 0.15), 1.3, 2, front - 0.1, S.Steel, true)
	end,

	-- Living
	o = function(p)
		seat(p, "Sofa", 3.9)
	end,
	a = function(p)
		seat(p, "Armchair", 2.9)
	end,
	e = function(p)
		local depth = 1.5
		local z = backZ(p, depth)
		box(p, "TVStand", V(3.6, 1.8, depth), 0, 0, z, S.DarkWood)
		box(p, "TVFoot", V(1, 0.1, 0.6), 0, 1.8, z + 0.2, S.Screen, true)
		box(p, "TV", V(3.2, 1.9, 0.2), 0, 1.9, z + 0.2, S.Screen, true)
	end,
	F = function(p)
		local depth = 1.8
		local z = backZ(p, depth)
		local front = z - depth / 2
		box(p, "Hearth", V(4, 0.3, depth + 1), 0, 0, z - 0.5, S.Stone, true)
		box(p, "Fireplace", V(3.8, 4.4, depth), 0, 0, z, S.Brick)
		box(p, "Firebox", V(2.2, 2, 0.1), 0, 0.3, front - 0.04, S.Soot, true)
		box(p, "Mantel", V(4.2, 0.3, depth + 0.3), 0, 4.4, z - 0.15, S.DarkWood, true)
		box(p, "ChimneyBreast", V(2.8, 6.4, 1.2), 0, 4.7, z + depth / 2 - 0.6, S.Brick, true)
	end,
	t = function(p)
		local z = backZ(p, 2.8)
		box(p, "TableTop", V(2.8, 0.25, 2.8), 0, 2.6, z, S.Wood)
		box(p, "TablePedestal", V(0.6, 2.6, 0.6), 0, 0, z, S.DarkWood)
		box(p, "TableFoot", V(1.6, 0.2, 1.6), 0, 0, z, S.DarkWood, true)
		if p.back then
			chair(p, 1.75, z, math.pi / 2, S.Wood)
			chair(p, -1.75, z, -math.pi / 2, S.Wood)
		else
			chair(p, 0, z + 1.75, 0, S.Wood)
			chair(p, 0, z - 1.75, math.pi, S.Wood)
		end
	end,
	r = function(p)
		local depth = 1.2
		local z = backZ(p, depth)
		box(p, "Bookshelf", V(3.6, 7, depth), 0, 0, z, S.DarkWood)
		for level = 1, 3 do
			box(p, "Books", V(3.2, 1.3, depth - 0.3), 0, 0.5 + (level - 1) * 2.2, z - 0.2, pickPerPiece(Palette.Goods, p, `books{level}`), true)
		end
	end,
	l = function(p)
		local z = if p.back then p.back - CORNER_GAP else 0
		box(p, "LampBase", V(1, 0.2, 1), 0, 0, z, S.DarkWood, true)
		box(p, "LampPole", V(0.2, 5, 0.2), 0, 0.2, z, S.Brass, true)
		box(p, "LampShade", V(1.5, 1.1, 1.5), 0, 5, z, S.Lamp, true)
	end,
	p = function(p)
		local foliage = 2.6
		-- The foliage is wider than the pot, so it sets the gap to the wall.
		local z = if p.back then p.back - foliage / 2 - 0.1 else 0
		box(p, "Pot", V(1.4, 1.4, 1.4), 0, 0, z, S.Terracotta, true)
		PartFactory.make(p.model, "Foliage", V(foliage, foliage, foliage), p.base * CFrame.new(0, foliage, z), S.Leaves, BALL_DECOR)
	end,

	-- Clinic and office
	h = function(p)
		local depth = if p.back then 5 else 4
		local z = backZ(p, depth)
		box(p, "HospitalBed", V(2.8, 2, depth), 0, 0, z, S.Steel)
		box(p, "Mattress", V(2.6, 0.4, depth - 0.2), 0, 2, z, S.Sheet, true)
		box(p, "Pillow", V(1.8, 0.35, 0.8), 0, 2.4, z + depth / 2 - 0.6, S.Sheet, true)
		box(p, "IVPole", V(0.15, 6, 0.15), 1.7, 0, z + depth / 2 - 0.5, S.Steel, true)
	end,
	m = function(p)
		local depth = 1.4
		local z = backZ(p, depth)
		local front = z - depth / 2
		box(p, "MedCabinet", V(3.6, 6.4, depth), 0, 0, z, S.Appliance)
		box(p, "CabinetGlass", V(3.2, 3, 0.05), 0, 3, front - 0.03, S.Glass, true)
		box(p, "Cross", V(1, 0.3, 0.06), 0, 1.6, front - 0.03, S.Red, true)
		box(p, "Cross", V(0.3, 1, 0.06), 0, 1.25, front - 0.03, S.Red, true)
	end,
	d = function(p)
		local depth = 2
		local z = backZ(p, depth)
		box(p, "DeskTop", V(3.6, 0.2, depth), 0, 2.8, z, S.Wood)
		box(p, "DeskSide", V(0.25, 2.8, depth - 0.1), -1.65, 0, z, S.DarkWood)
		box(p, "DeskSide", V(0.25, 2.8, depth - 0.1), 1.65, 0, z, S.DarkWood)
		box(p, "Monitor", V(1.6, 1.1, 0.15), 0, 3.1, z + 0.4, S.Screen, true)
		box(p, "Papers", V(0.9, 0.05, 1.1), -1, 3, z - 0.2, S.Sheet, true)
		chair(p, 0, z - depth / 2 - 0.5, math.pi, S.Screen)
	end,
	A = function(p)
		local depth = 2
		local z = backZ(p, depth)
		for _, x in { -0.95, 0.95 } do
			box(p, "FilingCabinet", V(1.8, 4.4, depth), x, 0, z, S.Steel)
			box(p, "DrawerLine", V(1.6, 0.06, 0.05), x, 1.5, z - depth / 2 - 0.03, S.Screen, true)
			box(p, "DrawerLine", V(1.6, 0.06, 0.05), x, 3, z - depth / 2 - 0.03, S.Screen, true)
		end
	end,
	q = function(p)
		local depth = 1.8
		local z = backZ(p, depth)
		local fabric = pick(Palette.Fabrics, p, "seats")
		box(p, "SeatFrame", V(3.8, 1.5, depth), 0, 0, z, S.Steel)
		box(p, "SeatCushion", V(3.7, 0.25, depth - 0.2), 0, 1.5, z - 0.1, fabric, true)
		box(p, "SeatBack", V(3.8, 1.9, 0.25), 0, 1.5, z + depth / 2 - 0.125, fabric)
	end,

	-- Shops
	s = function(p)
		local double = p.back == nil
		local depth = if double then 3.4 else 1.8
		local z = backZ(p, depth)
		box(p, "ShelfBase", V(3.9, 0.5, depth), 0, 0, z, S.Steel)
		box(p, "ShelfPanel", V(3.9, 6.6, 0.2), 0, 0.5, if double then z else z + depth / 2 - 0.1, S.Steel)
		box(p, "ShelfBoard", V(3.9, 0.12, depth), 0, 2.45, z, S.Steel, true)
		box(p, "ShelfBoard", V(3.9, 0.12, depth), 0, 4.55, z, S.Steel, true)
		local sides = if double then { -1, 1 } else { -1 }
		for _, side in sides do
			local goodsZ = if double then z + side * 0.85 else z - 0.15
			for level, y in { 0.5, 2.57, 4.67 } do
				box(p, "Goods", V(3.6, 1.5, 1.3), 0, y, goodsZ, pickPerPiece(Palette.Goods, p, `{side}{level}`), true)
			end
		end
	end,
	C = function(p)
		local depth = 2.2
		local z = backZ(p, depth)
		box(p, "Counter", V(3.9, 3.2, depth), 0, 0, z, S.DarkWood)
		box(p, "CounterTop", V(4, 0.2, depth + 0.2), 0, 3.2, z, S.Counter, true)
		if PartFactory.pick({ true, false }, p.key .. p.cell) then
			box(p, "Register", V(1.2, 0.9, 1), 0.9, 3.4, z + 0.2, S.Screen, true)
		end
	end,
	B = function(p)
		local depth = 3.4
		local z = backZ(p, depth)
		box(p, "BoothTable", V(1.8, 0.25, depth - 0.6), 0, 2.6, z + 0.3, S.Counter)
		box(p, "BoothPedestal", V(0.5, 2.6, 0.5), 0, 0, z, S.Steel)
		for _, side in { -1, 1 } do
			box(p, "BoothSeat", V(1.1, 1.6, depth), side * 1.35, 0, z, S.Red)
			box(p, "BoothBack", V(0.35, 2.6, depth), side * 1.83, 1.6, z, S.Red)
		end
	end,
	L = function(p)
		local depth = 1.8
		local z = backZ(p, depth)
		local front = z - depth / 2
		box(p, "Lockers", V(3.8, 7.2, depth), 0, 0, z, S.Steel)
		box(p, "LockerGap", V(0.08, 6.8, 0.05), -0.65, 0.2, front - 0.03, S.Screen, true)
		box(p, "LockerGap", V(0.08, 6.8, 0.05), 0.65, 0.2, front - 0.03, S.Screen, true)
		box(p, "LockerVents", V(3.4, 0.3, 0.05), 0, 6.2, front - 0.03, S.Screen, true)
	end,

	-- Storage
	x = function(p)
		local z = backZ(p, 3)
		box(p, "Crate", V(3, 3, 3), 0, 0, z, pickPerPiece({ S.Wood, S.Cardboard }, p, "crate"))
		PartFactory.make(
			p.model,
			"Crate",
			V(2, 2, 2),
			p.base * CFrame.new(0.2, 4, z) * CFrame.Angles(0, 0.35, 0),
			S.Cardboard,
			DECOR
		)
	end,
	R = function(p)
		local depth = if p.back then 1.8 else 3.2
		local z = backZ(p, depth)
		box(p, "RackPost", V(0.3, 8, depth), -1.8, 0, z, S.Hazard)
		box(p, "RackPost", V(0.3, 8, depth), 1.8, 0, z, S.Hazard)
		for level, y in { 0.4, 3.2, 6 } do
			box(p, "RackShelf", V(3.9, 0.15, depth), 0, y, z, S.Steel, true)
			box(p, "Boxes", V(2.4, 1.8, depth - 0.4), (level - 2) * 0.4, y + 0.15, z, pickPerPiece({ S.Cardboard, S.Wood }, p, `box{level}`), true)
		end
	end,
	w = function(p)
		local depth = 2.2
		local z = backZ(p, depth)
		box(p, "BenchTop", V(3.8, 0.3, depth), 0, 2.8, z, S.Wood)
		box(p, "BenchLeg", V(0.3, 2.8, depth - 0.2), -1.7, 0, z, S.DarkWood)
		box(p, "BenchLeg", V(0.3, 2.8, depth - 0.2), 1.7, 0, z, S.DarkWood)
		box(p, "BenchShelf", V(3.2, 0.15, depth - 0.3), 0, 0.6, z, S.Wood, true)
		box(p, "Vise", V(0.8, 0.7, 0.8), 1.3, 3.1, z - depth / 2 + 0.4, S.Steel, true)
		if p.back and p.solidBack then
			box(p, "Pegboard", V(3.6, 2.8, 0.1), 0, 3.6, p.back - 0.05, S.Cardboard, true)
			box(p, "Tool", V(0.3, 1.4, 0.12), -0.8, 4.4, p.back - 0.15, S.Red, true)
			box(p, "Tool", V(1.2, 0.3, 0.12), 0.6, 5, p.back - 0.15, S.Steel, true)
		end
	end,
	H = function(p)
		local z = backZ(p, 2.6)
		box(p, "HayBale", V(3.6, 2.4, 2.6), 0, 0, z, S.Hay)
		PartFactory.make(p.model, "HayBale", V(3.2, 2.2, 2.4), p.base * CFrame.new(0, 3.5, z) * CFrame.Angles(0, 0.25, 0), S.Hay, DECOR)
	end,
}

local NAMES: { [string]: string } = {
	b = "Bed",
	y = "Wardrobe",
	c = "Dresser",
	T = "Toilet",
	U = "Bathtub",
	n = "Basin",
	k = "KitchenCounter",
	g = "Stove",
	i = "KitchenSink",
	f = "Fridge",
	o = "Sofa",
	a = "Armchair",
	e = "TVStand",
	F = "Fireplace",
	t = "DiningTable",
	r = "Bookshelf",
	l = "FloorLamp",
	p = "Plant",
	h = "HospitalBed",
	m = "MedicineCabinet",
	d = "Desk",
	A = "FilingCabinets",
	q = "WaitingSeats",
	s = "StoreShelf",
	C = "Counter",
	B = "Booth",
	L = "Lockers",
	x = "Crates",
	R = "StorageRack",
	w = "Workbench",
	H = "HayBales",
}

function Furniture.has(symbol: string): boolean
	return Builders[symbol] ~= nil
end

-- Builds the piece for `symbol` as a Model under `parent`.
function Furniture.build(
	symbol: string,
	parent: Instance,
	base: CFrame,
	back: number?,
	solidBack: boolean,
	key: string,
	cell: string
): Model
	local builder = Builders[symbol]
	assert(builder, `unknown furniture {symbol}`)
	local model = Instance.new("Model")
	model.Name = NAMES[symbol]
	model:SetAttribute("Furniture", NAMES[symbol])
	builder({ model = model, base = base, back = back, solidBack = solidBack, key = key, cell = cell })
	model.Parent = parent
	return model
end

return Furniture
