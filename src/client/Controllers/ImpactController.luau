--!strict
-- ImpactController: what a landed hit throws off, so a swing or shot that connects is seen (7DTD
-- impact particles). A tool striking the world raises a puff of dust and a few chips in the struck
-- surface's colour; a hit on a zombie sprays blood. Purely local and short-lived, and nothing is drawn
-- farther than MAX_DISTANCE from the camera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Surface = require(Shared.Surface)

local ZombieRenderController = require(script.Parent.ZombieRenderController)

local MC = Config.Melee
local MAX_DISTANCE = 120
local CHIPS = 5
local CHIP_SIZE = 0.22
local CHIP_SPEED = 13
-- How far chips stray from the surface normal (0: straight out, 1: up to sideways).
local CHIP_SPREAD = 0.8
local CHIP_SECONDS = 0.45
local PUFF_PARTICLES = 5
local PUFF_POOL = 6
local PUFF_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local BLOOD_COLOR = Color3.fromRGB(105, 12, 10)
-- Height of a body hit above the zombie root (torso centre); a head hit uses Config.Melee.HeadHeight.
local BODY_HIT_HEIGHT = 0.3
-- A bullet's stop point is found again with a ray this long across it (studs).
local PROBE_LENGTH = 1

local ImpactController = {}

local folder: Folder
local puffs: { ParticleEmitter } = {}
local nextPuff = 1
local probeParams = RaycastParams.new()

local function visible(point: Vector3): boolean
	local camera = Workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - point).Magnitude <= MAX_DISTANCE
end

-- A random direction around `normal`, tilted by up to CHIP_SPREAD.
local function scatter(normal: Vector3): Vector3
	local random = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2
	local direction = normal + random * CHIP_SPREAD
	return if direction.Magnitude > 1e-3 then direction.Unit else normal
end

local function burst(point: Vector3, normal: Vector3, color: Color3, chips: number)
	if not visible(point) then
		return
	end
	local puff = puffs[nextPuff]
	nextPuff = nextPuff % #puffs + 1
	local attachment = puff.Parent :: Attachment
	attachment.WorldPosition = point + normal * 0.1
	puff.Color = ColorSequence.new(color)
	puff:Emit(PUFF_PARTICLES)
	for _ = 1, chips do
		local chip = Instance.new("Part")
		chip.Size = Vector3.one * CHIP_SIZE
		chip.Color = color
		chip.Material = Enum.Material.SmoothPlastic
		chip.CanCollide = false
		chip.CanQuery = false
		chip.CanTouch = false
		chip.CastShadow = false
		chip.CFrame = CFrame.new(point + normal * CHIP_SIZE)
			* CFrame.Angles(math.random() * math.pi, math.random() * math.pi, 0)
		chip.AssemblyLinearVelocity = scatter(normal) * CHIP_SPEED * (0.6 + math.random() * 0.4)
		chip.Parent = folder
		task.delay(CHIP_SECONDS, chip.Destroy, chip)
	end
end

-- Dust and chips where a tool struck the world.
function ImpactController.surface(point: Vector3, normal: Vector3, color: Color3)
	burst(point, if normal.Magnitude > 1e-3 then normal.Unit else Vector3.yAxis, color, CHIPS)
end

-- Dust and chips where a shot that flew along `direction` stopped against the world.
function ImpactController.shot(point: Vector3, direction: Vector3)
	if direction.Magnitude < 1e-3 or not visible(point) then
		return
	end
	local unit = direction.Unit
	local result = Workspace:Raycast(point - unit * (PROBE_LENGTH / 2), unit * PROBE_LENGTH, probeParams)
	if result then
		ImpactController.surface(result.Position, result.Normal, Surface.color(result))
	else
		ImpactController.surface(point, -unit, Surface.DEFAULT_COLOR)
	end
end

-- Blood at `point`, sprayed back toward `from` (where the hit came from).
function ImpactController.blood(point: Vector3, from: Vector3?)
	local back = if from then from - point else Vector3.yAxis
	local normal = Vector3.new(back.X, 0, back.Z)
	normal = (if normal.Magnitude > 1e-3 then normal.Unit else Vector3.zero) + Vector3.yAxis * 0.5
	burst(point, normal.Unit, BLOOD_COLOR, CHIPS - 1)
end

-- Blood on zombie `id` as currently drawn, at its head or body.
function ImpactController.zombie(id: number, head: boolean, from: Vector3?)
	local root = ZombieRenderController.getPosition(id)
	if root then
		ImpactController.blood(root + Vector3.yAxis * (if head then MC.HeadHeight else BODY_HIT_HEIGHT), from)
	end
end

function ImpactController.init()
	folder = Instance.new("Folder")
	folder.Name = "Impacts"
	for _ = 1, PUFF_POOL do
		local attachment = Instance.new("Attachment")
		local puff = Instance.new("ParticleEmitter")
		puff.Texture = PUFF_TEXTURE
		puff.Enabled = false
		puff.Lifetime = NumberRange.new(0.3, 0.55)
		puff.Speed = NumberRange.new(2, 5)
		puff.SpreadAngle = Vector2.new(60, 60)
		puff.Acceleration = Vector3.new(0, -4, 0)
		puff.Drag = 3
		puff.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 1.4),
		})
		puff.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		puff.EmissionDirection = Enum.NormalId.Top
		puff.Parent = attachment
		attachment.Parent = Workspace.Terrain
		table.insert(puffs, puff)
	end
	probeParams.FilterType = Enum.RaycastFilterType.Exclude
	probeParams.FilterDescendantsInstances = { folder }
	folder.Parent = Workspace
end

function ImpactController.start() end

return ImpactController
