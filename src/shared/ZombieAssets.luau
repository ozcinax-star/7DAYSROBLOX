--!strict
-- Original zombie head and torso meshes generated with Roblox Studio Mesh Generation, 2026-11-01
-- (stylized: green-black infection, no red blood; PLAN art style). Size is the mesh's native size,
-- so ZombieRig can scale it onto its own part sizes. Faces look toward -Z, the rig's facing.
-- A shirt with sleeves names where they are cut off (native units): faces outside |x| = sleeveX
-- and below y = sleeveTop are the sleeves, which the client hangs on the arms (ZombieMeshes).

export type Mesh = { mesh: string, texture: string, size: { number }, sleeveX: number?, sleeveTop: number? }

local ZombieAssets = {}

ZombieAssets.Heads = {
	-- Bald, sunken eyes, torn cheek and slack jaw.
	{ mesh = "rbxassetid://99816754834736", texture = "rbxassetid://111689637237175", size = { 0.79218, 1, 0.869114 } },
	-- Matted hair over one side, one clouded eye.
	{ mesh = "rbxassetid://99347807610297", texture = "rbxassetid://71135632210667", size = { 0.813054, 1, 0.830087 } },
} :: { Mesh }

ZombieAssets.Torsos = {
	-- Torn plaid flannel over grey ribs.
	{ mesh = "rbxassetid://90318890472095", texture = "rbxassetid://100241041114414", size = { 1.448985, 1.443157, 0.66 },
		sleeveX = 0.44, sleeveTop = 0.4 },
} :: { Mesh }

return ZombieAssets
