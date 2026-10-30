--!strict
-- Visual styles (colour + material) for map parts. Stylized, low-poly look (PLAN: art style).

export type Style = {
	color: Color3,
	material: Enum.Material,
	transparency: number?,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function style(color: Color3, material: Enum.Material, transparency: number?): Style
	return { color = color, material = material, transparency = transparency }
end

local M = Enum.Material

local Palette = {}

Palette.Styles = {
	-- Exterior walls
	Brick = style(rgb(150, 82, 64), M.Brick),
	Concrete = style(rgb(178, 176, 168), M.Concrete),
	ClinicWhite = style(rgb(232, 232, 226), M.Plaster),
	Metal = style(rgb(122, 132, 140), M.DiamondPlate),
	Planks = style(rgb(140, 104, 70), M.WoodPlanks),
	Logs = style(rgb(120, 82, 50), M.Wood),
	BarnRed = style(rgb(150, 44, 36), M.WoodPlanks),
	Trim = style(rgb(238, 234, 224), M.SmoothPlastic),
	Glass = style(rgb(160, 205, 225), M.Glass, 0.55),
	-- Interior surfaces
	Plaster = style(rgb(232, 226, 212), M.Plaster),
	Ceiling = style(rgb(242, 240, 234), M.Plaster),
	KitchenPaint = style(rgb(238, 232, 214), M.Plaster),
	OfficePaint = style(rgb(214, 218, 210), M.Plaster),
	ShopPaint = style(rgb(236, 236, 230), M.Plaster),
	BathTile = style(rgb(214, 228, 232), M.CeramicTiles),
	-- Floors
	WoodFloor = style(rgb(150, 110, 72), M.WoodPlanks),
	Tile = style(rgb(208, 206, 196), M.Marble),
	KitchenTile = style(rgb(222, 214, 196), M.CeramicTiles),
	BathFloor = style(rgb(186, 196, 200), M.CeramicTiles),
	Dirt = style(rgb(110, 86, 60), M.Ground),
	Foundation = style(rgb(120, 118, 112), M.Concrete),
	-- Roofs
	Shingles = style(rgb(92, 52, 44), M.RoofShingles),
	MetalRoof = style(rgb(110, 116, 122), M.CorrodedMetal),
	FlatRoof = style(rgb(80, 80, 82), M.Concrete),
	-- Furniture and fittings
	Wood = style(rgb(126, 88, 56), M.Wood),
	DarkWood = style(rgb(84, 58, 40), M.Wood),
	Fabric = style(rgb(70, 90, 130), M.Fabric),
	Sheet = style(rgb(225, 225, 220), M.Fabric),
	Appliance = style(rgb(220, 222, 218), M.SmoothPlastic),
	Porcelain = style(rgb(240, 240, 236), M.SmoothPlastic),
	Steel = style(rgb(150, 152, 156), M.Metal),
	Counter = style(rgb(70, 72, 76), M.Granite),
	Cabinet = style(rgb(196, 184, 160), M.WoodPlanks),
	Screen = style(rgb(22, 24, 28), M.SmoothPlastic),
	Soot = style(rgb(30, 28, 26), M.SmoothPlastic),
	Brass = style(rgb(190, 160, 90), M.Metal),
	Mirror = style(rgb(200, 215, 225), M.Glass, 0.15),
	Cardboard = style(rgb(170, 130, 90), M.Cardboard),
	Terracotta = style(rgb(170, 90, 60), M.Brick),
	Leaves = style(rgb(70, 120, 60), M.Grass),
	Red = style(rgb(180, 40, 36), M.SmoothPlastic),
	Hay = style(rgb(214, 182, 92), M.Grass),
	Goods = style(rgb(200, 150, 60), M.SmoothPlastic),
	GoodsAlt = style(rgb(80, 140, 90), M.SmoothPlastic),
	SignBoard = style(rgb(38, 42, 48), M.SmoothPlastic),
	-- Nature
	Bark = style(rgb(96, 66, 44), M.Wood),
	PineLeaves = style(rgb(46, 92, 58), M.Grass),
	OakLeaves = style(rgb(84, 128, 56), M.Grass),
	Bush = style(rgb(70, 112, 52), M.Grass),
	Rock = style(rgb(118, 116, 112), M.Rock),
	Water = style(rgb(60, 110, 140), M.Glass, 0.3),
	-- Vehicles and props
	Rust = style(rgb(130, 70, 40), M.CorrodedMetal),
	CarPaint = style(rgb(70, 90, 110), M.Metal),
	Tire = style(rgb(30, 30, 30), M.Rubber),
	Asphalt = style(rgb(60, 60, 62), M.Asphalt),
	Canvas = style(rgb(90, 120, 80), M.Fabric),
	Signal = style(rgb(200, 40, 40), M.Neon),
	Lamp = style(rgb(255, 236, 190), M.SmoothPlastic),
	Crop = style(rgb(150, 160, 60), M.Grass),
	Stone = style(rgb(150, 146, 138), M.Slate),
	Hazard = style(rgb(220, 160, 30), M.SmoothPlastic),
} :: { [string]: Style }

-- House siding colours; each house picks one from its name.
Palette.Siding = {
	style(rgb(196, 176, 140), M.WoodPlanks),
	style(rgb(150, 170, 180), M.WoodPlanks),
	style(rgb(180, 140, 120), M.WoodPlanks),
	style(rgb(200, 196, 170), M.WoodPlanks),
	style(rgb(140, 160, 128), M.WoodPlanks),
} :: { Style }

-- House roof colours ("Shingles" roofs pick one per building).
Palette.Shingles = {
	style(rgb(92, 52, 44), M.RoofShingles),
	style(rgb(64, 66, 72), M.RoofShingles),
	style(rgb(74, 58, 46), M.RoofShingles),
	style(rgb(56, 74, 66), M.RoofShingles),
} :: { Style }

-- Room wall paints for houses; each room picks one.
Palette.Paints = {
	style(rgb(236, 228, 208), M.Plaster),
	style(rgb(200, 212, 190), M.Plaster),
	style(rgb(192, 208, 222), M.Plaster),
	style(rgb(228, 204, 196), M.Plaster),
	style(rgb(234, 222, 182), M.Plaster),
	style(rgb(208, 200, 222), M.Plaster),
} :: { Style }

Palette.Carpets = {
	style(rgb(124, 100, 84), M.Carpet),
	style(rgb(98, 112, 132), M.Carpet),
	style(rgb(146, 126, 104), M.Carpet),
	style(rgb(112, 122, 98), M.Carpet),
} :: { Style }

Palette.Rugs = {
	style(rgb(150, 62, 52), M.Fabric),
	style(rgb(62, 82, 122), M.Fabric),
	style(rgb(172, 142, 92), M.Fabric),
	style(rgb(92, 112, 82), M.Fabric),
} :: { Style }

-- Upholstery for sofas, armchairs and blankets.
Palette.Fabrics = {
	style(rgb(70, 90, 130), M.Fabric),
	style(rgb(122, 62, 52), M.Fabric),
	style(rgb(92, 112, 82), M.Fabric),
	style(rgb(142, 122, 100), M.Fabric),
	style(rgb(80, 80, 86), M.Fabric),
} :: { Style }

Palette.DoorPaints = {
	style(rgb(140, 42, 36), M.Wood),
	style(rgb(44, 72, 62), M.Wood),
	style(rgb(52, 70, 100), M.Wood),
	style(rgb(96, 66, 44), M.Wood),
	style(rgb(226, 222, 208), M.Wood),
} :: { Style }

Palette.ShutterPaints = {
	style(rgb(42, 62, 52), M.WoodPlanks),
	style(rgb(52, 62, 84), M.WoodPlanks),
	style(rgb(92, 42, 38), M.WoodPlanks),
	style(rgb(62, 62, 66), M.WoodPlanks),
} :: { Style }

Palette.Awnings = {
	style(rgb(176, 44, 40), M.Fabric),
	style(rgb(42, 96, 64), M.Fabric),
	style(rgb(44, 64, 116), M.Fabric),
	style(rgb(196, 150, 50), M.Fabric),
} :: { Style }

-- Product colours on store shelves and book spines.
Palette.Goods = {
	style(rgb(200, 150, 60), M.SmoothPlastic),
	style(rgb(80, 140, 90), M.SmoothPlastic),
	style(rgb(180, 60, 50), M.SmoothPlastic),
	style(rgb(60, 100, 160), M.SmoothPlastic),
	style(rgb(230, 210, 120), M.SmoothPlastic),
	style(rgb(150, 90, 150), M.SmoothPlastic),
} :: { Style }

Palette.CarPaints = {
	style(rgb(120, 40, 36), M.Metal),
	style(rgb(52, 70, 100), M.Metal),
	style(rgb(180, 170, 150), M.Metal),
	style(rgb(60, 90, 60), M.Metal),
} :: { Style }

return Palette
