--!strict
-- Level data for the prototype map: a small town (north-east), a forest edge (south-west) and a few
-- rocks. Positions are x/z on the ground (studs); MapService places everything on the detected ground
-- height. Only each object's main body blocks zombie navigation; roofs, doors and canopies are decor.

export type Kind = "House" | "Store" | "Clinic" | "Fence" | "Tree" | "Rock"

export type Placement = {
	kind: Kind,
	name: string,
	x: number,
	z: number,
	-- Width (x), height (y), depth (z) of the main body.
	size: { number },
}

export type Style = {
	color: { number },
	material: Enum.Material,
}

local GreyBoxLayout = {}

-- Used only when the place has no terrain under the origin.
GreyBoxLayout.Ground = {
	size = { 512, 2, 512 },
	color = { 0.4, 0.55, 0.3 },
	material = Enum.Material.Grass,
}

GreyBoxLayout.SpawnSize = { 6, 1, 6 }

GreyBoxLayout.Styles = {
	HouseWall = { color = { 0.78, 0.68, 0.55 }, material = Enum.Material.Brick },
	Roof = { color = { 0.45, 0.2, 0.15 }, material = Enum.Material.Slate },
	StoreWall = { color = { 0.6, 0.62, 0.66 }, material = Enum.Material.Concrete },
	StoreSign = { color = { 0.95, 0.75, 0.1 }, material = Enum.Material.SmoothPlastic },
	ClinicWall = { color = { 0.92, 0.92, 0.9 }, material = Enum.Material.Concrete },
	ClinicCross = { color = { 0.8, 0.1, 0.1 }, material = Enum.Material.SmoothPlastic },
	Door = { color = { 0.35, 0.22, 0.12 }, material = Enum.Material.Wood },
	Window = { color = { 0.55, 0.75, 0.9 }, material = Enum.Material.Glass },
	Fence = { color = { 0.5, 0.35, 0.2 }, material = Enum.Material.WoodPlanks },
	Trunk = { color = { 0.4, 0.27, 0.15 }, material = Enum.Material.Wood },
	Canopy = { color = { 0.2, 0.45, 0.2 }, material = Enum.Material.Grass },
	Rock = { color = { 0.5, 0.5, 0.52 }, material = Enum.Material.Rock },
} :: { [string]: Style }

-- Decor proportions relative to the building body.
GreyBoxLayout.Decor = {
	RoofHeightRatio = 0.5,
	RoofOverhang = 1,
	DoorSize = { 4, 7 },
	WindowSize = { 4, 3 },
	WindowHeight = 5,
	TrimDepth = 0.2,
	SignHeight = 3,
	CrossArm = { 8, 2 },
	CanopyScale = 3,
}

-- Buildings face south (-Z), toward the spawn.
GreyBoxLayout.Placements = {
	{ kind = "House", name = "House1", x = 60, z = 40, size = { 24, 12, 20 } },
	{ kind = "House", name = "House2", x = 100, z = 40, size = { 20, 12, 24 } },
	{ kind = "House", name = "House3", x = 60, z = 90, size = { 28, 12, 20 } },
	{ kind = "Store", name = "Store", x = 110, z = 95, size = { 32, 14, 28 } },
	{ kind = "Clinic", name = "Clinic", x = 160, z = 60, size = { 36, 18, 40 } },
	{ kind = "Fence", name = "Fence1", x = 40, z = 140, size = { 80, 5, 1 } },
	{ kind = "Tree", name = "Tree1", x = -60, z = -50, size = { 3, 14, 3 } },
	{ kind = "Tree", name = "Tree2", x = -80, z = -30, size = { 3, 16, 3 } },
	{ kind = "Tree", name = "Tree3", x = -100, z = -70, size = { 3, 14, 3 } },
	{ kind = "Tree", name = "Tree4", x = -70, z = -100, size = { 3, 18, 3 } },
	{ kind = "Tree", name = "Tree5", x = -120, z = -40, size = { 3, 15, 3 } },
	{ kind = "Tree", name = "Tree6", x = -130, z = -110, size = { 3, 16, 3 } },
	{ kind = "Tree", name = "Tree7", x = -40, z = -130, size = { 3, 14, 3 } },
	{ kind = "Rock", name = "Rock1", x = -20, z = 60, size = { 14, 7, 10 } },
	{ kind = "Rock", name = "Rock2", x = 30, z = -70, size = { 10, 6, 16 } },
} :: { Placement }

return GreyBoxLayout
