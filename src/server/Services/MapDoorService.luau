--!strict
-- Working doors in the map's buildings. BuildingKit builds every doorway's leaf closed and without
-- collision, tagged Config.MapDoors.Tag; here each one leaves the map folder (so the zombie navigation
-- grid never sees it as a wall), gets an open/close prompt and collides only while closed. A closed
-- ground-floor door is a structure for zombies: they cannot open it (7DTD) and break through it instead.
-- Open and broken doors are saved with the world.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildGrid = require(Shared.BuildGrid)
local Config = require(Shared.Config)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local MapService = require(script.Parent.MapService)
local PersistenceService = require(script.Parent.PersistenceService)
local ZombieService = require(script.Parent.ZombieService)

local DC = Config.MapDoors

type Door = {
	id: string,
	model: Model,
	leaf: BasePart,
	closed: CFrame,
	open: CFrame,
	isOpen: boolean,
	broken: boolean,
	health: number,
	-- Points along the closed leaf marked as structure for zombies (empty for upper-floor doors).
	points: { Vector3 },
	prompt: ProximityPrompt,
	swingStarted: number,
	swingFrom: CFrame,
	swingTo: CFrame,
}

local MapDoorService = {}

local doors: { [string]: Door } = {}
-- Navigation cell index -> the closed door standing in it.
local doorAtCell: { [number]: Door } = {}
local swinging: { [Door]: boolean } = {}
local limiter: RateLimiter.RateLimiter
local worldSound: UnreliableRemoteEvent
local folder: Folder
local ready = false
local characterOverlap = OverlapParams.new()
characterOverlap.FilterType = Enum.RaycastFilterType.Include

local function cellOf(point: Vector3): number?
	return ZombieService.getNavGrid():cellAt(point.X, point.Z)
end

local function markStructure(door: Door, closed: boolean)
	local cost = if closed then BuildGrid.pathCost(door.health) else nil
	for _, point in door.points do
		ZombieService.setStructure(point.X, point.Z, cost)
		local cell = cellOf(point)
		if cell then
			doorAtCell[cell] = if closed then door else nil
		end
	end
end

local function setOpen(door: Door, open: boolean, animate: boolean)
	door.isOpen = open
	door.leaf.CanCollide = not open
	door.prompt.ActionText = Localization.get(if open then "DoorClose" else "DoorOpen")
	markStructure(door, not open)
	if animate then
		door.swingFrom = door.model:GetPivot()
		door.swingTo = if open then door.open else door.closed
		door.swingStarted = os.clock()
		swinging[door] = true
	else
		door.model:PivotTo(if open then door.open else door.closed)
	end
end

local function breakDoor(door: Door)
	if door.broken then
		return
	end
	door.broken = true
	markStructure(door, false)
	swinging[door] = nil
	worldSound:FireAllClients("BlockBreak", door.leaf.Position)
	door.model:Destroy()
end

-- Whether a player or a zombie stands in the doorway, so closing would trap them in the leaf.
local function doorwayOccupied(door: Door): boolean
	local list: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	characterOverlap.FilterDescendantsInstances = list
	local size = door.leaf.Size + Vector3.new(0, 0, 1.5)
	if #Workspace:GetPartBoundsInBox(door.closed, size, characterOverlap) > 0 then
		return true
	end
	return ZombieService.nearest(door.closed.Position, math.max(size.X, 2)) ~= nil
end

local function onTriggered(player: Player, door: Door)
	if door.broken or not limiter:allow(player) then
		return
	end
	local character = player.Character
	local root = character and character.PrimaryPart
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	if (root.Position - door.closed.Position).Magnitude > DC.Reach + 2 then
		return
	end
	if door.isOpen and doorwayOccupied(door) then
		return
	end
	setOpen(door, not door.isOpen, true)
	worldSound:FireAllClients(if door.isOpen then "DoorOpen" else "DoorClose", door.leaf.Position)
end

-- A zombie hit the structure cell at (x, z): damage the closed door there, if any.
local function onStructureHit(x: number, z: number, damage: number)
	local cell = ZombieService.getNavGrid():cellAt(x, z)
	local door = cell and doorAtCell[cell]
	if door == nil or door.broken or door.isOpen then
		return
	end
	door.health -= damage
	door.leaf:SetAttribute("Health", math.max(0, door.health))
	if door.health <= 0 then
		breakDoor(door)
	end
end

local function addDoor(model: Model)
	local leaf = model.PrimaryPart
	local closed = model:GetAttribute("ClosedPivot")
	local open = model:GetAttribute("OpenPivot")
	if leaf == nil or typeof(closed) ~= "CFrame" or typeof(open) ~= "CFrame" then
		return
	end
	local p = closed.Position
	local id = `{math.floor(p.X * 2 + 0.5)},{math.floor(p.Y * 2 + 0.5)},{math.floor(p.Z * 2 + 0.5)}`
	if doors[id] then
		return
	end
	model.Parent = folder
	leaf.CanQuery = true
	-- Only a door on the ground floor stands in the ground navigation grid.
	local points: { Vector3 } = {}
	local bottom = p.Y - leaf.Size.Y / 2
	if bottom - MapService.groundAt(p.X, p.Z) < Config.Build.GridSize then
		local half = leaf.Size.X / 2
		local t = -half + 0.5
		while t <= half - 0.5 do
			table.insert(points, (closed * CFrame.new(t, 0, 0)).Position)
			t += 1
		end
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = Localization.get("ItemWoodDoor")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = DC.Reach
	prompt.RequiresLineOfSight = false
	prompt.Parent = leaf
	local door: Door = {
		id = id,
		model = model,
		leaf = leaf,
		closed = closed,
		open = open,
		isOpen = false,
		broken = false,
		health = DC.Health,
		points = points,
		prompt = prompt,
		swingStarted = 0,
		swingFrom = closed,
		swingTo = closed,
	}
	doors[id] = door
	leaf:SetAttribute("Health", door.health)
	leaf:SetAttribute("MaxHealth", DC.Health)
	prompt.Triggered:Connect(function(player)
		onTriggered(player, door)
	end)
	setOpen(door, false, false)
end

local function step()
	local now = os.clock()
	for door in swinging do
		local a = math.clamp((now - door.swingStarted) / DC.SwingSeconds, 0, 1)
		local eased = a * a * (3 - 2 * a)
		if door.model.Parent then
			door.model:PivotTo(door.swingFrom:Lerp(door.swingTo, eased))
		end
		if a >= 1 then
			swinging[door] = nil
		end
	end
end

-- Saved world part "MapDoors": ids of doors left open and of doors broken down.
local function save(): any
	local open, broken = {}, {}
	for id, door in doors do
		if door.broken then
			table.insert(broken, id)
		elseif door.isOpen then
			table.insert(open, id)
		end
	end
	return { Open = open, Broken = broken }
end

local function load(data: any)
	if type(data) ~= "table" then
		return
	end
	if type(data.Open) == "table" then
		for _, id in data.Open do
			local door = type(id) == "string" and doors[id]
			if door and not door.broken then
				setOpen(door, true, false)
			end
		end
	end
	if type(data.Broken) == "table" then
		for _, id in data.Broken do
			local door = type(id) == "string" and doors[id]
			if door then
				breakDoor(door)
			end
		end
	end
end

function MapDoorService.init()
	limiter = RateLimiter.new(DC.TogglesPerSecond)
	PersistenceService.registerWorld("MapDoors", { save = save, load = load })
	PersistenceService.registerReady(function()
		return ready
	end)
end

function MapDoorService.start()
	worldSound = Net.unreliable("WorldSound")
	folder = Instance.new("Folder")
	folder.Name = DC.FolderName
	folder.Parent = Workspace
	-- Doors mark the zombie grid, so they wait until ZombieService has marked it from the map.
	while not MapService.isReady() or not ZombieService.isNavReady() do
		task.wait(0.25)
	end
	for _, model in CollectionService:GetTagged(DC.Tag) do
		if model:IsA("Model") then
			addDoor(model)
		end
	end
	ZombieService.onStructureHit(onStructureHit)
	RunService.Heartbeat:Connect(step)
	ready = true
end

return MapDoorService
