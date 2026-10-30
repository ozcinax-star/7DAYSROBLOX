--!strict
-- Level data for the grey-box prototype map: a flat field with a small town block and a forest edge.
-- Positions/sizes are layout data (studs), not balance numbers. Obstacles also block zombie navigation.

export type Block = {
	name: string,
	position: { number },
	size: { number },
	color: { number },
}

local TOWN_COLOR = { 0.62, 0.62, 0.65 }
local TREE_COLOR = { 0.3, 0.42, 0.28 }

local GreyBoxLayout = {
	Ground = {
		size = { 512, 2, 512 },
		color = { 0.45, 0.47, 0.42 },
	},
	SpawnPosition = { 0, 0.5, 0 },
	SpawnSize = { 6, 1, 6 },
	Obstacles = {
		-- Small town (north-east)
		{ name = "House1", position = { 60, 8, 40 }, size = { 24, 16, 20 }, color = TOWN_COLOR },
		{ name = "House2", position = { 100, 8, 40 }, size = { 20, 16, 24 }, color = TOWN_COLOR },
		{ name = "House3", position = { 60, 8, 90 }, size = { 28, 16, 20 }, color = TOWN_COLOR },
		{ name = "Store", position = { 110, 10, 95 }, size = { 32, 20, 28 }, color = TOWN_COLOR },
		{ name = "Clinic", position = { 160, 12, 60 }, size = { 36, 24, 40 }, color = TOWN_COLOR },
		{ name = "Fence1", position = { 40, 3, 140 }, size = { 80, 6, 2 }, color = TOWN_COLOR },
		-- Forest edge (south-west)
		{ name = "Tree1", position = { -60, 10, -50 }, size = { 6, 20, 6 }, color = TREE_COLOR },
		{ name = "Tree2", position = { -80, 10, -30 }, size = { 6, 20, 6 }, color = TREE_COLOR },
		{ name = "Tree3", position = { -100, 10, -70 }, size = { 6, 20, 6 }, color = TREE_COLOR },
		{ name = "Tree4", position = { -70, 10, -100 }, size = { 6, 20, 6 }, color = TREE_COLOR },
		{ name = "Tree5", position = { -120, 10, -40 }, size = { 6, 20, 6 }, color = TREE_COLOR },
		{ name = "Tree6", position = { -130, 10, -110 }, size = { 6, 20, 6 }, color = TREE_COLOR },
		{ name = "Tree7", position = { -40, 10, -130 }, size = { 6, 20, 6 }, color = TREE_COLOR },
		{ name = "Rock1", position = { -20, 4, 60 }, size = { 14, 8, 10 }, color = TOWN_COLOR },
		{ name = "Rock2", position = { 30, 4, -70 }, size = { 10, 8, 16 }, color = TOWN_COLOR },
	} :: { Block },
}

return GreyBoxLayout
