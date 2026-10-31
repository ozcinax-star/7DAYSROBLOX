--!strict
-- TurretController: draws turret shots from the server's TurretFired broadcast: a short bright
-- tracer from the muzzle to the hit and a muzzle flash. Purely visual; the server owns the shots.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local TRACER_SECONDS = 0.06
local TRACER_WIDTH = 0.06
local TRACER_COLOR = Color3.fromRGB(255, 214, 120)
local FLASH_SECONDS = 0.05
-- Shots further than this from the camera are not drawn (studs).
local DRAW_DISTANCE = 220

local TurretController = {}

local folder: Folder

local function onFired(from: unknown, to: unknown)
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera and (camera.CFrame.Position - from).Magnitude > DRAW_DISTANCE then
		return
	end
	local length = (to - from).Magnitude
	if length < 0.1 or length ~= length then
		return
	end
	local tracer = Instance.new("Part")
	tracer.Name = "TurretTracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.CanTouch = false
	tracer.CastShadow = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = TRACER_COLOR
	tracer.Size = Vector3.new(TRACER_WIDTH, TRACER_WIDTH, length)
	tracer.CFrame = CFrame.lookAt((from + to) / 2, to)
	tracer.Parent = folder
	Debris:AddItem(tracer, TRACER_SECONDS)
	local flash = Instance.new("Attachment")
	flash.WorldPosition = from
	local light = Instance.new("PointLight")
	light.Color = TRACER_COLOR
	light.Range = 8
	light.Brightness = 3
	light.Parent = flash
	flash.Parent = Workspace.Terrain
	Debris:AddItem(flash, FLASH_SECONDS)
end

function TurretController.init()
	folder = Instance.new("Folder")
	folder.Name = "TurretShots"
	folder.Parent = Workspace
end

function TurretController.start()
	Net.unreliable("TurretFired").OnClientEvent:Connect(onFired)
end

return TurretController
