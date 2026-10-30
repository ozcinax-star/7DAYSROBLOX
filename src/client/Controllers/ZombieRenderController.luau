--!strict
-- ZombieRenderController: builds client-side zombie bodies (ZombieRig) from server snapshots,
-- interpolates between samples and drives the shamble. LOD:
--   * beyond RenderDistance: model is unparented (sound keeps playing)
--   * on screen (or very close) within DetailDistance: full body with face and wound details
--   * on screen within AnimateDistance: body animated every frame, details hidden
--   * on screen beyond AnimateDistance: animated every FarAnimateEveryFrames frames
--   * off screen: re-posed every OffscreenUpdateEveryFrames frames
-- Killed zombies collapse and lie still for a while before they are removed; every zombie keeps its
-- positional sound updated, so attacks from behind are still heard.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local ZombieProtocol = require(Shared.ZombieProtocol)

local ZombieRig = require(script.Parent.Parent.Modules.ZombieRig)

local VC = Config.ZombieVisual
local ZC = Config.Zombie
local NC = Config.Network

local TWO_PI = math.pi * 2
-- Movement below this many studs between samples counts as standing still.
local MOVE_EPSILON = 0.05
-- Corpses fade out over their last second.
local CORPSE_FADE = 1

type View = {
	id: number,
	rig: ZombieRig.Rig,
	pose: ZombieRig.Pose,
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
	targetYaw: number,
	speed: number,
	stateSince: number,
	flinchAt: number,
	shown: boolean,
	attachment: Attachment?,
	sound: Sound?,
	nextGroan: number,
	-- Set when the zombie was killed: time of death.
	diedAt: number?,
}

local ZombieRenderController = {}

local views: { [number]: View } = {}
-- Killed zombies keep animating here until removed; their ids may be reused by the server meanwhile.
local corpses: { View } = {}
local container: Folder
local renderedCount = 0
local frame = 0

local function createView(id: number, x: number, y: number, z: number, state: string, now: number): View
	local rig = ZombieRig.build(id)
	local pose = ZombieRig.newPose(id)
	pose.state = state

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
		rig = rig,
		pose = pose,
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
		targetYaw = pose.yaw,
		speed = 0,
		stateSince = now,
		flinchAt = -math.huge,
		shown = false,
		attachment = attachment,
		sound = sound,
		nextGroan = now + VC.GroanIntervalMin + math.random() * (VC.GroanIntervalMax - VC.GroanIntervalMin),
		diedAt = nil,
	}
end

local function destroyView(view: View)
	view.rig.model:Destroy()
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
	local moved = math.sqrt(dx * dx + dz * dz)
	local duration = math.clamp(now - view.lastSample, VC.MinInterpolation, VC.MaxInterpolation)
	view.pose.moving = moved > MOVE_EPSILON
	if view.pose.moving then
		view.targetYaw = math.atan2(-dx, -dz)
		view.speed = moved / duration
	else
		view.speed = 0
	end
	view.fromX, view.fromY, view.fromZ = view.x, view.y, view.z
	view.toX, view.toY, view.toZ = x, y, z
	view.t0 = now
	view.duration = duration
	view.lastSample = now
	if view.pose.state ~= state then
		view.pose.state = state
		view.stateSince = now
	end
end

local function onKilled(id: number, now: number)
	local view = views[id]
	if view == nil then
		return
	end
	views[id] = nil
	view.diedAt = now
	view.pose.moving = false
	view.pose.state = "Idle"
	-- Corpses keep their face visible up close; the details follow the normal LOD afterwards.
	table.insert(corpses, view)
end

-- Shortest signed angle from a to b.
local function angleDelta(a: number, b: number): number
	return (b - a + math.pi) % TWO_PI - math.pi
end

local partBuffer: { BasePart } = {}
local cframeBuffer: { CFrame } = {}

-- Advances interpolation, gait phase and turning. Runs every frame for every zombie (cheap math).
local function advance(view: View, now: number, dt: number)
	local alpha = math.clamp((now - view.t0) / view.duration, 0, 1)
	view.x = view.fromX + (view.toX - view.fromX) * alpha
	view.y = view.fromY + (view.toY - view.fromY) * alpha
	view.z = view.fromZ + (view.toZ - view.fromZ) * alpha
	local pose = view.pose
	if pose.moving and now - view.lastSample > VC.MaxInterpolation then
		-- No sample for a while (far LOD or packet loss): stand until the server says otherwise.
		pose.moving = false
	end
	local attacking = pose.state == "AttackPlayer" or pose.state == "AttackStructure"
	local gaitTarget = if pose.moving then 1 elseif attacking then VC.AttackGait else 0
	local blend = math.min(1, dt * VC.GaitBlendRate)
	pose.gait += (gaitTarget - pose.gait) * blend
	local frequency
	if pose.moving then
		frequency = math.clamp(
			VC.StrideFrequency * view.speed / VC.ReferenceSpeed,
			VC.MinStrideFrequency,
			VC.MaxStrideFrequency
		)
	elseif attacking then
		frequency = VC.MinStrideFrequency
	else
		frequency = VC.MinStrideFrequency * 0.5
	end
	pose.phase = (pose.phase + dt * frequency * TWO_PI) % (TWO_PI * 2)
	local turn = angleDelta(pose.yaw, view.targetYaw)
	local maxTurn = VC.TurnRate * dt
	pose.yaw += math.clamp(turn, -maxTurn, maxTurn)
	pose.x = view.x
	pose.ground = view.y - ZC.RootHeight
	pose.z = view.z
	pose.now = now
	pose.stateTime = now - view.stateSince
	pose.flinch = math.max(0, 1 - (now - view.flinchAt) / VC.FlinchSeconds)
end

local function updateSound(view: View, now: number, distSq: number, soundSq: number)
	local attachment = view.attachment
	if attachment and distSq <= soundSq then
		attachment.WorldPosition = Vector3.new(view.x, view.y, view.z)
		local sound = view.sound
		if sound and now >= view.nextGroan then
			sound:Play()
			view.nextGroan = now + VC.GroanIntervalMin + math.random() * (VC.GroanIntervalMax - VC.GroanIntervalMin)
		end
	end
end

local function onRender(dt: number)
	local now = os.clock()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local camPos = camera.CFrame.Position
	local renderSq = VC.RenderDistance * VC.RenderDistance
	local detailSq = VC.DetailDistance * VC.DetailDistance
	local animateSq = VC.AnimateDistance * VC.AnimateDistance
	local alwaysSq = VC.AlwaysUpdateDistance * VC.AlwaysUpdateDistance
	local soundSq = VC.SoundRange * VC.SoundRange

	table.clear(partBuffer)
	table.clear(cframeBuffer)
	local rendered = 0
	frame += 1

	for _, view in views do
		advance(view, now, dt)

		local dx = view.x - camPos.X
		local dy = view.y - camPos.Y
		local dz = view.z - camPos.Z
		local distSq = dx * dx + dy * dy + dz * dz
		updateSound(view, now, distSq, soundSq)

		local model = view.rig.model
		if distSq > renderSq then
			if view.shown then
				model.Parent = nil
				view.shown = false
			end
		else
			local justShown = not view.shown
			if justShown then
				model.Parent = container
				view.shown = true
			end
			local visible = distSq <= alwaysSq
			if not visible then
				local _, onScreen = camera:WorldToViewportPoint(Vector3.new(view.x, view.y, view.z))
				visible = onScreen
			end
			local slot = frame + view.id
			if visible then
				rendered += 1
				ZombieRig.setDetailVisible(view.rig, distSq <= detailSq)
				if justShown or distSq <= animateSq or slot % VC.FarAnimateEveryFrames == 0 then
					ZombieRig.pose(view.rig, view.pose, partBuffer, cframeBuffer)
				end
			elseif justShown or slot % VC.OffscreenUpdateEveryFrames == 0 then
				ZombieRig.setDetailVisible(view.rig, false)
				ZombieRig.pose(view.rig, view.pose, partBuffer, cframeBuffer)
			end
		end
	end

	local lifetime = VC.DeathFallSeconds + VC.CorpseSeconds
	for index = #corpses, 1, -1 do
		local view = corpses[index]
		local age = now - (view.diedAt :: number)
		if age >= lifetime or not view.shown then
			destroyView(view)
			table.remove(corpses, index)
		else
			advance(view, now, 0)
			view.pose.death = math.min(1, age / VC.DeathFallSeconds)
			local fade = math.clamp((age - (lifetime - CORPSE_FADE)) / CORPSE_FADE, 0, 1)
			if fade > 0 then
				ZombieRig.setTransparency(view.rig, fade)
			end
			ZombieRig.pose(view.rig, view.pose, partBuffer, cframeBuffer)
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
	Net.event("ZombieRemoved").OnClientEvent:Connect(function(removed: unknown, killed: unknown)
		local now = os.clock()
		if typeof(killed) == "table" then
			for _, id in killed :: { any } do
				if typeof(id) == "number" then
					onKilled(id, now)
				end
			end
		end
		if typeof(removed) == "table" then
			for _, id in removed :: { any } do
				local view = views[id]
				if view then
					destroyView(view)
					views[id] = nil
				end
			end
		end
	end)
	RunService.PreRender:Connect(onRender)
end

-- Plays the hit flinch on a zombie (local feedback for the attacking player).
function ZombieRenderController.flinch(id: number)
	local view = views[id]
	if view then
		view.flinchAt = os.clock()
	end
end

-- Interpolated position of a zombie as currently drawn, or nil.
function ZombieRenderController.getPosition(id: number): Vector3?
	local view = views[id]
	if view == nil then
		return nil
	end
	return Vector3.new(view.x, view.y, view.z)
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
