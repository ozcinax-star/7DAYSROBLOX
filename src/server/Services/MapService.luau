--!strict
-- MapService: builds the prototype map from GreyBoxLayout on top of the detected ground.
-- If the place has terrain under the origin, its surface is the ground; otherwise a ground part is
-- created. Workspace.Map.Obstacles holds the parts that block zombie navigation; Workspace.Map.Decor
-- holds visual-only parts (roofs, doors, windows, canopies).

local Workspace = game:GetService("Workspace")

local GreyBoxLayout = require(script.Parent.Parent.Modules.GreyBoxLayout)

local MapService = {}

-- Height from which the ground probe ray starts, and its length (studs).
local GROUND_PROBE_HEIGHT = 1000
local GROUND_PROBE_LENGTH = 2000

local Styles = GreyBoxLayout.Styles
local Decor = GreyBoxLayout.Decor

local mapFolder: Folder? = nil
local obstaclesFolder: Folder? = nil
local groundY = 0

local function makePart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	style: GreyBoxLayout.Style,
	parent: Instance,
	className: string?
): BasePart
	local part = Instance.new(className or "Part") :: BasePart
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = Color3.new(style.color[1], style.color[2], style.color[3])
	part.Material = style.material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Returns the terrain surface height under the origin, or nil if there is no terrain there.
local function probeTerrain(): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	params.IgnoreWater = false
	local result = Workspace:Raycast(
		Vector3.new(0, GROUND_PROBE_HEIGHT, 0),
		Vector3.new(0, -GROUND_PROBE_LENGTH, 0),
		params
	)
	return if result then result.Position.Y else nil
end

local function frontZ(p: GreyBoxLayout.Placement): number
	return p.z - p.size[3] / 2
end

local function addDoorAndWindows(p: GreyBoxLayout.Placement, decor: Instance)
	local w = p.size[1]
	local zf = frontZ(p) - Decor.TrimDepth / 2
	local doorW, doorH = Decor.DoorSize[1], Decor.DoorSize[2]
	makePart(
		`{p.name}Door`,
		Vector3.new(doorW, doorH, Decor.TrimDepth),
		CFrame.new(p.x, groundY + doorH / 2, zf),
		Styles.Door,
		decor
	)
	local winW, winH = Decor.WindowSize[1], Decor.WindowSize[2]
	for _, side in { -1, 1 } do
		makePart(
			`{p.name}Window`,
			Vector3.new(winW, winH, Decor.TrimDepth),
			CFrame.new(p.x + side * w / 4, groundY + Decor.WindowHeight, zf),
			Styles.Window,
			decor
		)
	end
end

local function addGableRoof(p: GreyBoxLayout.Placement, decor: Instance)
	local w, h, d = p.size[1], p.size[2], p.size[3]
	local overhang = Decor.RoofOverhang
	local roofH = h * Decor.RoofHeightRatio
	local halfDepth = d / 2 + overhang
	local size = Vector3.new(w + overhang * 2, roofH, halfDepth)
	local y = groundY + h + roofH / 2
	-- A WedgePart slopes down toward its -Z side; the back half is the same wedge turned around.
	makePart(`{p.name}RoofFront`, size, CFrame.new(p.x, y, p.z - halfDepth / 2), Styles.Roof, decor, "WedgePart")
	makePart(
		`{p.name}RoofBack`,
		size,
		CFrame.new(p.x, y, p.z + halfDepth / 2) * CFrame.Angles(0, math.pi, 0),
		Styles.Roof,
		decor,
		"WedgePart"
	)
end

local function body(p: GreyBoxLayout.Placement, style: GreyBoxLayout.Style, obstacles: Instance): BasePart
	local size = Vector3.new(p.size[1], p.size[2], p.size[3])
	return makePart(p.name, size, CFrame.new(p.x, groundY + p.size[2] / 2, p.z), style, obstacles)
end

local builders: { [GreyBoxLayout.Kind]: (GreyBoxLayout.Placement, Instance, Instance) -> () } = {
	House = function(p, obstacles, decor)
		body(p, Styles.HouseWall, obstacles)
		addDoorAndWindows(p, decor)
		addGableRoof(p, decor)
	end,
	Store = function(p, obstacles, decor)
		body(p, Styles.StoreWall, obstacles)
		addDoorAndWindows(p, decor)
		local w, h = p.size[1], p.size[2]
		makePart(
			`{p.name}Sign`,
			Vector3.new(w / 2, Decor.SignHeight, Decor.TrimDepth),
			CFrame.new(p.x, groundY + h - Decor.SignHeight, frontZ(p) - Decor.TrimDepth / 2),
			Styles.StoreSign,
			decor
		)
	end,
	Clinic = function(p, obstacles, decor)
		body(p, Styles.ClinicWall, obstacles)
		addDoorAndWindows(p, decor)
		local h = p.size[2]
		local long, short = Decor.CrossArm[1], Decor.CrossArm[2]
		local cf = CFrame.new(p.x, groundY + h - long / 2 - short, frontZ(p) - Decor.TrimDepth / 2)
		makePart(`{p.name}CrossH`, Vector3.new(long, short, Decor.TrimDepth), cf, Styles.ClinicCross, decor)
		makePart(`{p.name}CrossV`, Vector3.new(short, long, Decor.TrimDepth), cf, Styles.ClinicCross, decor)
	end,
	Fence = function(p, obstacles, _decor)
		body(p, Styles.Fence, obstacles)
	end,
	Tree = function(p, obstacles, decor)
		local width, height = p.size[1], p.size[2]
		-- Cylinders extend along their X axis, so the trunk is rotated upright.
		local trunk = makePart(
			p.name,
			Vector3.new(height, width, width),
			CFrame.new(p.x, groundY + height / 2, p.z) * CFrame.Angles(0, 0, math.pi / 2),
			Styles.Trunk,
			obstacles
		)
		trunk.Shape = Enum.PartType.Cylinder
		local canopy = width * Decor.CanopyScale
		local ball = makePart(
			`{p.name}Canopy`,
			Vector3.new(canopy, canopy, canopy),
			CFrame.new(p.x, groundY + height, p.z),
			Styles.Canopy,
			decor
		)
		ball.Shape = Enum.PartType.Ball
	end,
	Rock = function(p, obstacles, _decor)
		body(p, Styles.Rock, obstacles)
	end,
}

function MapService.init()
	local existing = Workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "Map"

	local terrainY = probeTerrain()
	if terrainY then
		groundY = terrainY
	else
		local g = GreyBoxLayout.Ground
		local size = Vector3.new(g.size[1], g.size[2], g.size[3])
		makePart("Ground", size, CFrame.new(0, -size.Y / 2, 0), g :: any, folder)
		groundY = 0
	end

	local obstacles = Instance.new("Folder")
	obstacles.Name = "Obstacles"
	obstacles.Parent = folder
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = folder
	for _, placement in GreyBoxLayout.Placements do
		builders[placement.kind](placement, obstacles, decor)
	end

	local spawnSize = GreyBoxLayout.SpawnSize
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(spawnSize[1], spawnSize[2], spawnSize[3])
	spawn.Position = Vector3.new(0, groundY + spawnSize[2] / 2, 0)
	spawn.Neutral = true
	spawn.Parent = folder

	folder.Parent = Workspace
	mapFolder = folder
	obstaclesFolder = obstacles
end

function MapService.start() end

function MapService.getObstacles(): Folder
	return assert(obstaclesFolder, "MapService not initialized")
end

function MapService.getMap(): Folder
	return assert(mapFolder, "MapService not initialized")
end

-- World height of the walkable ground surface.
function MapService.getGroundY(): number
	return groundY
end

return MapService
