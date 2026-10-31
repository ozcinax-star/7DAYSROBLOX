--!strict
-- ArrowController: draws the arrows and bullets RangedService flies. Each launch comes with its origin,
-- velocity, gravity, server time and ammo; the client runs the same arc (Shared/Ballistics) every
-- frame, pins an arrow where the server says it stopped and removes it a few seconds later. Bullets
-- are bright tracers with a muzzle flash and vanish where they stop. A zombie hit flinches.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ballistics = require(Shared.Ballistics)
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local ZombieRenderController = require(script.Parent.ZombieRenderController)

local RC = Config.Ranged
local SHAFT_COLOR = Color3.fromRGB(150, 110, 70)
local TRACER_COLOR = Color3.fromRGB(255, 220, 140)
local FLASH_COLOR = Color3.fromRGB(255, 190, 90)
local FLASH_RANGE = 12
local FLASH_BRIGHTNESS = 3
-- An arrow never heard to stop is removed after its longest possible flight plus this (seconds).
local LOST_SLACK = 1

type Flight = {
	part: BasePart,
	origin: Vector3,
	velocity: Vector3,
	gravity: number,
	launchedAt: number,
	-- Server time after which an arrow that has not stopped is removed.
	lostAt: number,
	stopped: boolean,
	tracer: boolean,
}

local ArrowController = {}

local folder: Folder
local flights: { [number]: Flight } = {}
-- Longest flight time of any bow and ammo pair (seconds).
local longestFlight = 0

local function remove(id: number)
	local flight = flights[id]
	if flight then
		flights[id] = nil
		flight.part:Destroy()
	end
end

local function pose(flight: Flight, t: number): CFrame
	local o, v, g = flight.origin, flight.velocity, flight.gravity
	local x, y, z = Ballistics.position(o.X, o.Y, o.Z, v.X, v.Y, v.Z, g, t)
	local position = Vector3.new(x, y, z)
	local heading = Vector3.new(v.X, v.Y - g * t, v.Z)
	if heading.Magnitude < 1e-3 then
		return CFrame.new(position)
	end
	return CFrame.lookAt(position, position + heading)
end

-- A short flash of light where a gun fired.
local function flash(origin: Vector3)
	local part = Instance.new("Part")
	part.Name = "MuzzleFlash"
	part.Size = Vector3.one * 0.2
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = CFrame.new(origin)
	local light = Instance.new("PointLight")
	light.Color = FLASH_COLOR
	light.Range = FLASH_RANGE
	light.Brightness = FLASH_BRIGHTNESS
	light.Parent = part
	part.Parent = folder
	task.delay(RC.FlashSeconds, function()
		part:Destroy()
	end)
end

local function onFired(
	id: unknown,
	origin: unknown,
	velocity: unknown,
	gravity: unknown,
	launchedAt: unknown,
	ammoId: unknown
)
	if
		typeof(id) ~= "number"
		or typeof(origin) ~= "Vector3"
		or typeof(velocity) ~= "Vector3"
		or typeof(gravity) ~= "number"
		or typeof(launchedAt) ~= "number"
	then
		return
	end
	remove(id)
	local ammo = if typeof(ammoId) == "string" then RC.Ammo[ammoId] else nil
	local tracer = ammo ~= nil and ammo.Tracer == true
	local part = Instance.new("Part")
	if tracer then
		part.Name = "Tracer"
		part.Size = Vector3.new(0.07, 0.07, RC.TracerLength)
		part.Color = TRACER_COLOR
		part.Material = Enum.Material.Neon
		flash(origin)
	else
		part.Name = "Arrow"
		part.Size = Vector3.new(0.12, 0.12, RC.ArrowLength)
		part.Color = SHAFT_COLOR
		part.Material = Enum.Material.Wood
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	local flight: Flight = {
		part = part,
		origin = origin,
		velocity = velocity,
		gravity = gravity,
		launchedAt = launchedAt,
		lostAt = launchedAt + longestFlight + LOST_SLACK,
		stopped = false,
		tracer = tracer,
	}
	part.CFrame = pose(flight, 0)
	part.Parent = folder
	flights[id] = flight
end

local function onStopped(id: unknown, where: unknown, zombieId: unknown)
	if typeof(id) ~= "number" or typeof(where) ~= "Vector3" or typeof(zombieId) ~= "number" then
		return
	end
	local flight = flights[id]
	if flight == nil then
		return
	end
	flight.stopped = true
	if flight.tracer then
		if zombieId ~= 0 then
			ZombieRenderController.flinch(zombieId)
		end
		remove(id)
		return
	end
	-- Pinned with its tip at the stop point, pointing the way it flew.
	local heading = pose(flight, math.max(0, Workspace:GetServerTimeNow() - flight.launchedAt)).LookVector
	flight.part.CFrame = CFrame.lookAt(where - heading * (RC.ArrowLength / 2), where + heading)
	if zombieId ~= 0 then
		ZombieRenderController.flinch(zombieId)
		-- Zombie bodies move on; an arrow left hanging in the air looks wrong.
		remove(id)
		return
	end
	task.delay(RC.StuckSeconds, function()
		if flights[id] == flight then
			remove(id)
		end
	end)
end

local function onRender()
	local now = Workspace:GetServerTimeNow()
	for id, flight in flights do
		if not flight.stopped then
			if now >= flight.lostAt then
				remove(id)
			else
				flight.part.CFrame = pose(flight, math.max(0, now - flight.launchedAt))
			end
		end
	end
end

function ArrowController.init()
	for _, weapon in RC.Weapons do
		for _, ammoId in weapon.Ammo do
			local ammo = RC.Ammo[ammoId]
			local seconds = weapon.MaxRange * Config.Melee.StudsPerMeter / Ballistics.speed(weapon, ammo)
			longestFlight = math.max(longestFlight, seconds)
		end
	end
end

function ArrowController.start()
	folder = Instance.new("Folder")
	folder.Name = "ClientArrows"
	folder.Parent = Workspace
	Net.unreliable("ArrowFired").OnClientEvent:Connect(onFired)
	Net.unreliable("ArrowStopped").OnClientEvent:Connect(onStopped)
	RunService.PreRender:Connect(onRender)
end

return ArrowController
