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
	-- Walls
	Brick = style(rgb(150, 82, 64), M.Brick),
	Concrete = style(rgb(178, 176, 168), M.Concrete),
	ClinicWhite = style(rgb(232, 232, 226), M.SmoothPlastic),
	Metal = style(rgb(122, 132, 140), M.DiamondPlate),
	Planks = style(rgb(140, 104, 70), M.WoodPlanks),
	Logs = style(rgb(120, 82, 50), M.Wood),
	BarnRed = style(rgb(150, 44, 36), M.WoodPlanks),
	Trim = style(rgb(240, 236, 226), M.SmoothPlastic),
	Glass = style(rgb(150, 200, 225), M.Glass, 0.45),
	-- Floors
	WoodFloor = style(rgb(150, 110, 72), M.WoodPlanks),
	Tile = style(rgb(208, 206, 196), M.Marble),
	Dirt = style(rgb(110, 86, 60), M.Ground),
	Foundation = style(rgb(120, 118, 112), M.Concrete),
	-- Roofs
	Shingles = style(rgb(92, 52, 44), M.Slate),
	MetalRoof = style(rgb(110, 116, 122), M.CorrodedMetal),
	FlatRoof = style(rgb(80, 80, 82), M.Concrete),
	-- Furniture
	Wood = style(rgb(126, 88, 56), M.Wood),
	DarkWood = style(rgb(84, 58, 40), M.Wood),
	Fabric = style(rgb(70, 90, 130), M.Fabric),
	Sheet = style(rgb(225, 225, 220), M.Fabric),
	Appliance = style(rgb(220, 222, 218), M.SmoothPlastic),
	Steel = style(rgb(150, 152, 156), M.Metal),
	Red = style(rgb(180, 40, 36), M.SmoothPlastic),
	Hay = style(rgb(214, 182, 92), M.Grass),
	Goods = style(rgb(200, 150, 60), M.SmoothPlastic),
	GoodsAlt = style(rgb(80, 140, 90), M.SmoothPlastic),
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

Palette.CarPaints = {
	style(rgb(120, 40, 36), M.Metal),
	style(rgb(52, 70, 100), M.Metal),
	style(rgb(180, 170, 150), M.Metal),
	style(rgb(60, 90, 60), M.Metal),
} :: { Style }

return Palette
