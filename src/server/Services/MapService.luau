--!strict
-- MapService: builds the grey-box map from GreyBoxLayout at startup. Workspace.Map.Obstacles is the
-- set of static parts that block zombie navigation.

local Workspace = game:GetService("Workspace")

local GreyBoxLayout = require(script.Parent.Parent.Modules.GreyBoxLayout)

local MapService = {}

local mapFolder: Folder? = nil
local obstaclesFolder: Folder? = nil

local function color(rgb: { number }): Color3
	return Color3.new(rgb[1], rgb[2], rgb[3])
end

local function vector(v: { number }): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

local function makePart(name: string, position: Vector3, size: Vector3, rgb: { number }, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color(rgb)
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function MapService.init()
	local existing = Workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "Map"

	local groundSize = vector(GreyBoxLayout.Ground.size)
	makePart("Ground", Vector3.new(0, -groundSize.Y / 2, 0), groundSize, GreyBoxLayout.Ground.color, folder)

	local obstacles = Instance.new("Folder")
	obstacles.Name = "Obstacles"
	obstacles.Parent = folder
	for _, block in GreyBoxLayout.Obstacles do
		makePart(block.name, vector(block.position), vector(block.size), block.color, obstacles)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = vector(GreyBoxLayout.SpawnSize)
	spawn.Position = vector(GreyBoxLayout.SpawnPosition)
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

return MapService
