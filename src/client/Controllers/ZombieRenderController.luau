--!strict
-- ZombieRenderController: builds client-side zombie models from server snapshots and interpolates
-- between samples. LOD:
--   * beyond RenderDistance: model is unparented (sound keeps playing)
--   * on screen (or very close) and within AnimateDistance: full procedural walk cycle
--   * on screen beyond AnimateDistance: moved as a static pose
--   * off screen: parts are not moved at all
-- Every zombie keeps its positional sound updated, so attacks from behind are still heard.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local ZombieProtocol = require(Shared.ZombieProtocol)

local VC = Config.ZombieVisual
local NC = Config.Network

local TWO_PI = math.pi * 2
-- Movement below this many studs between samples counts as standing still.
local MOVE_EPSILON = 0.05

type View = {
	id: number,
	model: Model,
	parts: { BasePart },
	fromX: number,
	fromY: number,
	fromZ: number,
	toX: number,
	toY: number,
	toZ: number,
	t0: number,
	duration: number,
	lastSample: number,
	x: number,
	y: number,
	z: number,
	yaw: number,
	phase: number,
	moving: boolean,
	state: string,
	shown: boolean,
	attachment: Attachment?,
	sound: Sound?,
	nextGroan: number,
}

local ZombieRenderController = {}

local views: { [number]: View } = {}
local container: Folder
local renderedCount = 0
local frame = 0

local function vec(v: { number }): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

local TORSO = vec(VC.TorsoSize)
local HEAD = vec(VC.HeadSize)
local LIMB = vec(VC.LimbSize)
local COLOR = Color3.new(VC.Color[1], VC.Color[2], VC.Color[3])

-- Joint offsets relative to the torso centre.
local HEAD_OFFSET = CFrame.new(0, TORSO.Y / 2 + HEAD.Y / 2, 0)
local LEFT_SHOULDER = CFrame.new(-(TORSO.X + LIMB.X) / 2, TORSO.Y / 2, 0)
local RIGHT_SHOULDER = CFrame.new((TORSO.X + LIMB.X) / 2, TORSO.Y / 2, 0)
local LEFT_HIP = CFrame.new(-LIMB.X / 2, -TORSO.Y / 2, 0)
local RIGHT_HIP = CFrame.new(LIMB.X / 2, -TORSO.Y / 2, 0)
local LIMB_HANG = CFrame.new(0, -LIMB.Y / 2, 0)

local function makePart(name: string, size: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = COLOR
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function createView(id: number, x: number, y: number, z: number, state: string, now: number): View
	local model = Instance.new("Model")
	model.Name = `Zombie{id}`
	local parts = {
		makePart("Torso", TORSO, model),
		makePart("Head", HEAD, model),
		makePart("LeftArm", LIMB, model),
		makePart("RightArm", LIMB, model),
		makePart("LeftLeg", LIMB, model),
		makePart("RightLeg", LIMB, model),
	}

	local attachment: Attachment? = nil
	local sound: Sound? = nil
	if VC.GroanSoundId ~= "" then
		local a = Instance.new("Attachment")
		a.Name = `ZombieSound{id}`
		a.WorldPosition = Vector3.new(x, y, z)
		local s = Instance.new("Sound")
		s.SoundId = VC.GroanSoundId
		s.RollOffMaxDistance = VC.SoundRange
		s.Parent = a
		a.Parent = Workspace.Terrain
		attachment = a
		sound = s
	end

	return {
		id = id,
		model = model,
		parts = parts,
		fromX = x,
		fromY = y,
		fromZ = z,
		toX = x,
		toY = y,
		toZ = z,
		t0 = now,
		duration = VC.MinInterpolation,
		lastSample = now,
		x = x,
		y = y,
		z = z,
		yaw = 0,
		phase = math.random() * TWO_PI,
		moving = false,
		state = state,
		shown = false,
		attachment = attachment,
		sound = sound,
		nextGroan = now + VC.GroanIntervalMin + math.random() * (VC.GroanIntervalMax - VC.GroanIntervalMin),
	}
end

local function destroyView(view: View)
	view.model:Destroy()
	if view.attachment then
		view.attachment:Destroy()
	end
end

local function onSample(id: number, x: number, y: number, z: number, state: string)
	local now = os.clock()
	local view = views[id]
	if view == nil then
		views[id] = createView(id, x, y, z, state, now)
		return
	end
	local dx = x - view.toX
	local dz = z - view.toZ
	view.moving = dx * dx + dz * dz > MOVE_EPSILON * MOVE_EPSILON
	if view.moving then
		view.yaw = math.atan2(-dx, -dz)
	end
	view.fromX, view.fromY, view.fromZ = view.x, view.y, view.z
	view.toX, view.toY, view.toZ = x, y, z
	view.t0 = now
	view.duration = math.clamp(now - view.lastSample, VC.MinInterpolation, VC.MaxInterpolation)
	view.lastSample = now
	view.state = state
end

local partBuffer: { BasePart } = {}
local cframeBuffer: { CFrame } = {}

local function poseInto(view: View, animate: boolean)
	local root = CFrame.new(view.x, view.y, view.z) * CFrame.Angles(0, view.yaw, 0)
	local swing = if animate and view.moving then math.sin(view.phase) else 0
	local armSwing = swing * VC.ArmSwingRadians
	local legSwing = swing * VC.LegSwingRadians
	if view.state == "AttackPlayer" or view.state == "AttackStructure" then
		armSwing = if animate then math.sin(view.phase * 2) * VC.ArmSwingRadians * 2 else 0
	end
	local parts = view.parts
	local n = #partBuffer
	partBuffer[n + 1] = parts[1]
	cframeBuffer[n + 1] = root
	partBuffer[n + 2] = parts[2]
	cframeBuffer[n + 2] = root * HEAD_OFFSET
	partBuffer[n + 3] = parts[3]
	cframeBuffer[n + 3] = root * LEFT_SHOULDER * CFrame.Angles(VC.ArmRaiseRadians + armSwing, 0, 0) * LIMB_HANG
	partBuffer[n + 4] = parts[4]
	cframeBuffer[n + 4] = root * RIGHT_SHOULDER * CFrame.Angles(VC.ArmRaiseRadians - armSwing, 0, 0) * LIMB_HANG
	partBuffer[n + 5] = parts[5]
	cframeBuffer[n + 5] = root * LEFT_HIP * CFrame.Angles(legSwing, 0, 0) * LIMB_HANG
	partBuffer[n + 6] = parts[6]
	cframeBuffer[n + 6] = root * RIGHT_HIP * CFrame.Angles(-legSwing, 0, 0) * LIMB_HANG
end

local function onRender(dt: number)
	local now = os.clock()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local camPos = camera.CFrame.Position
	local renderSq = VC.RenderDistance * VC.RenderDistance
	local animateSq = VC.AnimateDistance * VC.AnimateDistance
	local alwaysSq = VC.AlwaysUpdateDistance * VC.AlwaysUpdateDistance
	local soundSq = VC.SoundRange * VC.SoundRange

	table.clear(partBuffer)
	table.clear(cframeBuffer)
	local rendered = 0
	frame += 1

	for _, view in views do
		local alpha = math.clamp((now - view.t0) / view.duration, 0, 1)
		view.x = view.fromX + (view.toX - view.fromX) * alpha
		view.y = view.fromY + (view.toY - view.fromY) * alpha
		view.z = view.fromZ + (view.toZ - view.fromZ) * alpha
		if view.moving and alpha < 1 then
			view.phase = (view.phase + dt * VC.StrideFrequency * TWO_PI) % (TWO_PI * 2)
		end

		local dx = view.x - camPos.X
		local dy = view.y - camPos.Y
		local dz = view.z - camPos.Z
		local distSq = dx * dx + dy * dy + dz * dz

		local attachment = view.attachment
		if attachment and distSq <= soundSq then
			attachment.WorldPosition = Vector3.new(view.x, view.y, view.z)
			local sound = view.sound
			if sound and now >= view.nextGroan then
				sound:Play()
				view.nextGroan = now
					+ VC.GroanIntervalMin
					+ math.random() * (VC.GroanIntervalMax - VC.GroanIntervalMin)
			end
		end

		if distSq > renderSq then
			if view.shown then
				view.model.Parent = nil
				view.shown = false
			end
		else
			local justShown = not view.shown
			if justShown then
				view.model.Parent = container
				view.shown = true
			end
			local visible = distSq <= alwaysSq
			if not visible then
				local _, onScreen = camera:WorldToViewportPoint(Vector3.new(view.x, view.y, view.z))
				visible = onScreen
			end
			if visible then
				rendered += 1
				poseInto(view, distSq <= animateSq)
			elseif justShown or (frame + view.id) % VC.OffscreenUpdateEveryFrames == 0 then
				-- Off screen: static pose at a reduced rate so models never linger where they were.
				poseInto(view, false)
			end
		end
	end

	if #partBuffer > 0 then
		Workspace:BulkMoveTo(partBuffer, cframeBuffer, Enum.BulkMoveMode.FireCFrameChanged)
	end
	renderedCount = rendered
end

function ZombieRenderController.init()
	container = Instance.new("Folder")
	container.Name = "ClientZombies"
	container.Parent = Workspace
end

function ZombieRenderController.start()
	Net.unreliable("ZombieSnapshot").OnClientEvent:Connect(function(packet: unknown)
		if typeof(packet) ~= "buffer" then
			return
		end
		ZombieProtocol.decode(packet, NC.PositionScale, onSample)
	end)
	Net.event("ZombieRemoved").OnClientEvent:Connect(function(ids: unknown)
		if typeof(ids) ~= "table" then
			return
		end
		for _, id in ids :: { any } do
			local view = views[id]
			if view then
				destroyView(view)
				views[id] = nil
			end
		end
	end)
	RunService.PreRender:Connect(onRender)
end

function ZombieRenderController.getRenderedCount(): number
	return renderedCount
end

function ZombieRenderController.getViewCount(): number
	local count = 0
	for _ in views do
		count += 1
	end
	return count
end

return ZombieRenderController
