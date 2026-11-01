--!strict
-- ZombieRig: builds the client-side zombie body and poses it every frame. No Humanoid, no animation
-- assets: anchored parts are posed procedurally and moved in one Workspace:BulkMoveTo call by the
-- render controller.
--
-- The body is thin and decayed (PLAN: stylized, no realistic gore): narrow torso, bone-thin limbs
-- with two segments each, a gaunt head with dark eye sockets, pale eyes and a hanging jaw, and a
-- grey-green wound. The gait is a slow shamble: a dragging, stiff limp leg, a hunched and swaying
-- torso, a lolling head with short twitches, arms that hang and swing while wandering and reach
-- forward while chasing or grabbing.
--
-- Joint conventions: every part hangs from its joint along -Y. A positive X rotation swings a limb
-- forward (toward -Z, the facing direction); a negative X rotation leans the torso forward.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Noise = require(Shared.World.Noise)
local ZombieAssets = require(Shared.ZombieAssets)
local ZombieLook = require(Shared.ZombieLook)

local ZombieMeshes = require(script.Parent.ZombieMeshes)

local VC = Config.ZombieVisual
local ZC = Config.Zombie

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local HALF_PI = math.pi / 2

-- Body geometry at height scale 1 (studs). Joint heights are measured from the joint above.
local HIP_HEIGHT = 2.1
local THIGH = V(0.48, 1.05, 0.48)
local SHIN = V(0.42, 1.05, 0.42)
local HIP_X = 0.36
local PELVIS = V(1.4, 0.55, 0.7)
-- Under the textured shirt, which is narrower than the block torso.
local MESH_PELVIS = V(1.15, 0.55, 0.62)
local PELVIS_UP = 0.2
local WAIST_UP = 0.45
local TORSO = V(1.5, 1.5, 0.66)
local SHOULDER_UP = 1.32
local SHOULDER_X = 0.88
-- Every limb reaches this far past its joint into the part above, so bent elbows, knees, hips
-- and shoulders never show a gap (studs at scale 1).
local JOINT_OVERLAP = 0.2
local NECK_UP = 1.5
local HEAD = V(0.82, 1, 0.88)
local HEAD_UP = 0.55
-- A textured head sits lower, on the collar.
local MESH_HEAD_UP = 0.4
local UPPER_ARM = V(0.36, 1, 0.36)
local FOREARM = V(0.32, 1, 0.32)
-- Limbs are cylinders (axis along X), turned onto the hanging -Y axis when posed.
local LIMB_TURN = CFrame.Angles(0, 0, math.pi / 2)
-- Textured meshes are drawn slightly larger than their block so they meet the limbs: the head
-- reaches the neck, the shirt the shoulders and hips.
local HEAD_MESH_SCALE = V(1.12, 1.12, 1.12)
local TORSO_MESH_SCALE = V(1.22, 1.06, 1.4)
-- A cut-off sleeve turns at a shoulder this far (native mesh units) below the top of its cap.
local SLEEVE_PIVOT_INSET = 0.08
-- How much of the head texture's own colour survives the skin tint (1 = untinted).
local HEAD_TINT_KEEP = 0.2
-- Face and wound details, relative to the head / torso centre.
local JAW = V(0.6, 0.2, 0.6)
local JAW_HINGE = V(0, -0.45, 0.22)
local JAW_OPEN = -0.3
local JAW_OFFSET = V(0, -0.08, -0.32)
local SOCKET = V(0.22, 0.17, 0.08)
local SOCKET_OFFSET = V(0.19, 0.1, -0.42)
-- Small dull eyes sunk into the sockets (they barely stand out of the socket face).
local EYE = V(0.07, 0.07, 0.04)
local EYE_OFFSET = V(0.19, 0.08, -0.45)
-- A slanted gash rather than a square patch.
local WOUND = V(0.5, 0.16, 0.05)
local WOUND_OFFSET = V(0.3, 0.2, -0.33)
local WOUND_TILT = 0.45
-- Resting bends (radians).
local ELBOW_REST = 0.25
local KNEE_REST = 0.08
local ARM_SPREAD = 0.1
-- Lying corpses are lifted by about half a body thickness so they rest on the ground.
local CORPSE_LIFT = 0.35
-- Crawling (crippled) and prone bodies lie forward this far (radians) and slide back this far
-- (studs at scale 1) so the head stays over the server's head sphere (Config.Combat root drops).
local CRAWL_PITCH = 1.3
local PRONE_PITCH = 1.5
local CRAWL_BACK = 3.9
-- Kneeling drops the hips to thigh height.
local KNEEL_DROP = 0.95

export type Rig = {
	model: Model,
	-- Fixed order: pelvis, torso, head, left upper arm, left forearm, right upper arm, right forearm,
	-- left thigh, left shin, right thigh, right shin.
	core: { BasePart },
	-- Fixed order: jaw, left socket, right socket, left eye, right eye, wound.
	detail: { BasePart },
	detailVisible: boolean,
	look: ZombieLook.Look,
	scale: number,
	-- The head came off (decapitating kill): head and face stay hidden.
	headless: boolean,
	-- Textured head / torso: their own face and wounds replace the block details.
	meshHead: boolean,
	meshTorso: boolean,
	-- Textured shirt only: its centre relative to the block torso's centre, each shoulder (left,
	-- right) relative to that centre, and each sleeve's centre relative to its shoulder (studs).
	torsoOffset: Vector3,
	shoulders: { Vector3 }?,
	sleeveOffsets: { Vector3 }?,
}

-- Per-frame pose input. The render controller keeps one per zombie and updates it in place.
export type Pose = {
	x: number,
	-- Ground height under the zombie.
	ground: number,
	z: number,
	yaw: number,
	state: string,
	moving: boolean,
	-- Gait amplitude 0..1 (1 = full walk), blended by the controller so steps never pop.
	gait: number,
	-- Gait phase (radians), advanced by the controller from the walking speed.
	phase: number,
	-- Seconds since the state last changed (drives the attack cycle).
	stateTime: number,
	now: number,
	-- 1 right after a hit, falling to 0.
	flinch: number,
	-- nil while alive; 0..1 collapse progress after death.
	death: number?,
	-- 1 = falls forward, -1 = falls backward.
	deathDirection: number,
	-- Knockdown from the server (Combat.Pose: 0 none, 1 kneel, 2 prone) and its 0..1 blend.
	knock: number,
	knockBlend: number,
	-- The server's current knockdown (0 while getting back up), set by the render controller.
	knockTarget: number?,
	-- Crippled zombies crawl; crawlBlend eases into the crawl.
	crippled: boolean,
	crawlBlend: number,
}

local ZombieRig = {}

local function color(c: { number }): Color3
	return Color3.new(c[1], c[2], c[3])
end

-- Draws `part` with a textured mesh scaled onto the part's size.
local function dress(part: BasePart, asset: ZombieAssets.Mesh, fit: Vector3)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = asset.mesh
	mesh.TextureId = asset.texture
	mesh.Scale = part.Size / V(asset.size[1], asset.size[2], asset.size[3]) * fit
	mesh.Parent = part
	part.Color = Color3.new(1, 1, 1)
end

-- Whether detail `index` (jaw, sockets, eyes, wound) stays hidden: a lost or textured head has no
-- block face, a textured torso carries its own wounds.
local function detailHidden(rig: Rig, index: number): boolean
	if index <= 5 then
		return rig.headless or rig.meshHead
	end
	return rig.meshTorso
end

local function makeShape(model: Model, name: string, size: Vector3, tint: { number }, material: Enum.Material,
	shape: Enum.PartType): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color(tint)
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = model
	return part
end

local function makePart(model: Model, name: string, size: Vector3, tint: { number }, material: Enum.Material): Part
	return makeShape(model, name, size, tint, material, Enum.PartType.Block)
end

-- A copy of a cut shirt piece, drawn like the other body parts.
local function makePiece(model: Model, name: string, template: MeshPart, size: Vector3): MeshPart
	local part = template:Clone()
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = model
	return part
end

-- A rounded limb: a cylinder whose length (`size.Y`) runs along its X axis (see LIMB_TURN).
local function makeLimb(model: Model, name: string, size: Vector3, tint: { number }, material: Enum.Material,
	scale: number): Part
	return makeShape(model, name, V(size.Y + JOINT_OVERLAP * scale, size.X, size.Z), tint, material, Enum.PartType.Cylinder)
end

function ZombieRig.build(id: number): Rig
	local look = ZombieLook.fromId(id)
	local s = look.height
	local model = Instance.new("Model")
	model.Name = `Zombie{id}`
	local skin = Enum.Material.SmoothPlastic
	local cloth = Enum.Material.Fabric
	local armTint = if look.bareArms then look.skin else look.shirt
	local armMaterial = if look.bareArms then skin else cloth
	local shinTint = if look.bareShins then look.extremity else look.pants
	local shinMaterial = if look.bareShins then skin else cloth
	-- A textured shirt is drawn only once it has been cut into body and sleeves; until then (or
	-- without mesh API access) the zombie wears a block shirt.
	local shirt = ZombieAssets.Torsos[look.torsoMesh]
	local split = if shirt then ZombieMeshes.torso(look.torsoMesh) else nil
	local torsoOffset = Vector3.zero
	local shoulders: { Vector3 }? = nil
	local sleeveOffsets: { Vector3 }? = nil
	local torsoPart: BasePart, leftUpper: BasePart, rightUpper: BasePart
	if shirt and split then
		-- Native mesh units to studs, as the whole shirt was drawn on the block torso.
		local fit = TORSO * s / V(shirt.size[1], shirt.size[2], shirt.size[3]) * TORSO_MESH_SCALE
		local body = split.body
		torsoPart = makePiece(model, "Torso", body.part, body.size * fit)
		torsoOffset = body.center * fit
		local pieces: { BasePart } = {}
		local pivots: { Vector3 } = {}
		local offsets: { Vector3 } = {}
		for index, sleeve in split.sleeves do
			local name = if index == 1 then "LeftUpperArm" else "RightUpperArm"
			pieces[index] = makePiece(model, name, sleeve.part, sleeve.size * fit)
			local drop = sleeve.size.Y / 2 - SLEEVE_PIVOT_INSET
			pivots[index] = (sleeve.center + V(0, drop, 0)) * fit
			offsets[index] = V(0, -drop, 0) * fit
		end
		leftUpper, rightUpper = pieces[1], pieces[2]
		shoulders, sleeveOffsets = pivots, offsets
	else
		torsoPart = makePart(model, "Torso", TORSO * s, look.shirt, cloth)
		leftUpper = makeLimb(model, "LeftUpperArm", UPPER_ARM * s, armTint, armMaterial, s)
		rightUpper = makeLimb(model, "RightUpperArm", UPPER_ARM * s, armTint, armMaterial, s)
	end
	local core: { BasePart } = {
		makePart(model, "Pelvis", (if split then MESH_PELVIS else PELVIS) * s, look.pants, cloth),
		torsoPart,
		makePart(model, "Head", HEAD * s, look.face, skin),
		leftUpper,
		makeLimb(model, "LeftForearm", FOREARM * s, look.extremity, skin, s),
		rightUpper,
		makeLimb(model, "RightForearm", FOREARM * s, look.extremity, skin, s),
		makeLimb(model, "LeftThigh", THIGH * s, look.pants, cloth, s),
		makeLimb(model, "LeftShin", SHIN * s, shinTint, shinMaterial, s),
		makeLimb(model, "RightThigh", THIGH * s, look.pants, cloth, s),
		makeLimb(model, "RightShin", SHIN * s, shinTint, shinMaterial, s),
	}
	local detail = {
		makePart(model, "Jaw", JAW * s, look.extremity, skin),
		makePart(model, "LeftSocket", SOCKET * s, VC.EyeSocketColor, skin),
		makePart(model, "RightSocket", SOCKET * s, VC.EyeSocketColor, skin),
		makePart(model, "LeftEye", EYE * s, VC.EyeColor, skin),
		makePart(model, "RightEye", EYE * s, VC.EyeColor, skin),
		makePart(model, "Wound", WOUND * s, VC.WoundColor, Enum.Material.Slate),
	}
	model.PrimaryPart = core[2]
	local head = ZombieAssets.Heads[look.headMesh]
	if head then
		dress(core[3], head, HEAD_MESH_SCALE)
		-- Warm the textured face toward this zombie's skin so it matches its bare limbs.
		local face = look.face
		local k = 1 / math.max(face[1], face[2], face[3], 0.01)
		local mesh = core[3]:FindFirstChildOfClass("SpecialMesh") :: SpecialMesh
		mesh.VertexColor = V(face[1] * k, face[2] * k, face[3] * k):Lerp(Vector3.one, HEAD_TINT_KEEP)
	end
	local rig: Rig = {
		model = model,
		core = core,
		detail = detail,
		detailVisible = true,
		look = look,
		scale = s,
		headless = false,
		meshHead = head ~= nil,
		meshTorso = split ~= nil,
		torsoOffset = torsoOffset,
		shoulders = shoulders,
		sleeveOffsets = sleeveOffsets,
	}
	for index, part in detail do
		if detailHidden(rig, index) then
			part.Transparency = 1
		end
	end
	return rig
end

function ZombieRig.newPose(id: number): Pose
	local look = ZombieLook.fromId(id)
	return {
		x = 0,
		ground = 0,
		z = 0,
		yaw = look.yaw,
		state = "Idle",
		moving = false,
		gait = 0,
		phase = look.phase,
		stateTime = 0,
		now = 0,
		flinch = 0,
		death = nil,
		deathDirection = if Noise.hash(id, 17, 9173) < 0.7 then 1 else -1,
		knock = 0,
		knockBlend = 0,
		crippled = false,
		crawlBlend = 0,
	}
end

-- Hidden details stay where they were; they are not moved while hidden.
function ZombieRig.setDetailVisible(rig: Rig, visible: boolean)
	if rig.detailVisible == visible then
		return
	end
	rig.detailVisible = visible
	local transparency = if visible then 0 else 1
	for index, part in rig.detail do
		part.Transparency = if detailHidden(rig, index) then 1 else transparency
	end
end

-- A decapitating kill: hides the head and face for the rest of the corpse's life.
function ZombieRig.setHeadless(rig: Rig)
	rig.headless = true
	rig.core[3].Transparency = 1
	for index = 1, 5 do
		rig.detail[index].Transparency = 1
	end
end

function ZombieRig.setTransparency(rig: Rig, transparency: number)
	for index, part in rig.core do
		part.Transparency = if rig.headless and index == 3 then 1 else transparency
	end
	if rig.detailVisible then
		for index, part in rig.detail do
			part.Transparency = if detailHidden(rig, index) then 1 else transparency
		end
	end
end

-- Envelope of a grab: quick rise, slower release (u = seconds since the strike).
local function strikeEnvelope(u: number): number
	if u < 0 then
		return 0
	elseif u < 0.15 then
		return u / 0.15
	elseif u < 0.5 then
		return 1 - (u - 0.15) / 0.35
	end
	return 0
end

-- Short random head/torso jerks; deterministic per zombie so every client sees the same twitch.
local function twitch(now: number, seed: number): number
	local t = (now + seed) / VC.TwitchInterval
	local slot = math.floor(t)
	local frac = t - slot
	local window = 0.08
	if frac > window or Noise.hash(slot, seed, 4111) < 0.5 then
		return 0
	end
	local sign = if Noise.hash(slot, seed, 4112) < 0.5 then -1 else 1
	return sign * math.sin(frac / window * math.pi) * VC.TwitchRadians
end

-- Appends the CFrames of the rig's parts (details only when shown) to parts/cframes.
function ZombieRig.pose(rig: Rig, p: Pose, parts: { BasePart }, cframes: { CFrame })
	local look = rig.look
	local s = rig.scale
	local state = p.state
	local phase = p.phase
	local sinP, cosP = math.sin(phase), math.cos(phase)
	local chasing = state == "Chase"
	local attacking = state == "AttackPlayer" or state == "AttackStructure"
	local seeking = state == "SeekSound"
	local gait = p.gait
	local limp = look.limp
	local bad = look.limpSide
	-- Phase of the limping leg: left leg swings with sin(phase), right leg with -sin(phase).
	local badCos = if bad < 0 then cosP else -cosP
	local badStance = math.max(0, -badCos)
	local dip = VC.LimpDip * limp * badStance * gait

	-- Attack cycle: first grab after the windup, then one per cooldown.
	local strike = 0
	if attacking then
		local sinceFirst = p.stateTime - ZC.AttackWindup
		local u = if sinceFirst < 0 then sinceFirst else sinceFirst % ZC.AttackCooldown
		strike = strikeEnvelope(u)
	end

	local hunch = look.hunch + (if chasing or attacking then 0.08 else 0)
	local torsoPitch = -(hunch + VC.LurchRadians * math.sin(2 * phase) * gait + VC.AttackLungeRadians * strike)
	torsoPitch += VC.TwitchRadians * 0.3 * p.flinch + twitch(p.now, look.twitchSeed) * 0.25
	local lean = VC.LimpLeanRadians * limp * bad * (0.4 + badStance) * gait
	local torsoRoll = VC.BodySwayRadians * sinP * gait + lean * 0.5
	local torsoTwist = 0.08 * sinP * gait

	local base = CF(p.x, p.ground, p.z) * ANG(0, p.yaw, 0)
	local death = p.death
	-- Lying forward: a crawl (crippled) or a prone knockdown, eased in; both slide the body back over
	-- the root. Kneeling drops the hips instead.
	local prone = if p.knock == 2 then p.knockBlend else 0
	local kneel = if p.knock == 1 then p.knockBlend else 0
	local lying = math.max(p.crawlBlend, prone)
	if death then
		local fall = 1 - (1 - death) * (1 - death)
		if lying > 0 then
			-- Already down: settle flat where it lies.
			base = base * CF(0, CORPSE_LIFT * fall, CRAWL_BACK * s * lying) * ANG(-(CRAWL_PITCH + (HALF_PI - CRAWL_PITCH) * fall) * lying, 0, 0)
		else
			base = base * CF(0, CORPSE_LIFT * fall, 0) * ANG(-HALF_PI * fall * p.deathDirection, 0, 0)
		end
		gait = 0
	elseif lying > 0 then
		local pitch = CRAWL_PITCH + (PRONE_PITCH - CRAWL_PITCH) * prone
		base = base * CF(0, CORPSE_LIFT * lying, CRAWL_BACK * s * lying) * ANG(-pitch * lying, 0, 0)
		-- Crawlers keep a slow arm-pull rhythm; a prone zombie lies still.
		gait *= p.crawlBlend * (1 - prone)
	end
	if kneel > 0 then
		base = base * CF(0, -KNEEL_DROP * s * kneel, 0)
		gait *= 1 - kneel
	end

	local bob = VC.BobHeight * math.cos(2 * phase) * gait
	local lurchForward = 0.4 * strike
	local pelvisPivot = base * CF(0, (HIP_HEIGHT + bob - dip) * s, -lurchForward * s) * ANG(0, -torsoTwist, -lean)
	local waist = pelvisPivot * CF(0, WAIST_UP * s, 0) * ANG(torsoPitch, torsoTwist * 2, torsoRoll)
	local neck = waist * CF(0, NECK_UP * s, 0)

	-- Head: compensates part of the hunch so it looks ahead, lolls to its tilted side and twitches.
	local headPitch = hunch * (if chasing or attacking then 0.85 else 0.35)
		- (if state == "Idle" then 0.25 else 0)
		+ twitch(p.now, look.twitchSeed + 31)
	local headRoll = look.headTilt + VC.HeadLollRadians * math.sin(phase * 0.5 + look.twitchSeed) * (0.4 + gait)
	local head = neck * ANG(headPitch, 0, headRoll) * CF(0, (if rig.meshHead then MESH_HEAD_UP else HEAD_UP) * s, 0)

	local core = rig.core
	local n = #parts
	parts[n + 1] = core[1]
	cframes[n + 1] = pelvisPivot * CF(0, PELVIS_UP * s, 0)
	local torsoCentre = waist * CF(0, TORSO.Y / 2 * s, 0)
	parts[n + 2] = core[2]
	cframes[n + 2] = torsoCentre * CF(rig.torsoOffset)
	parts[n + 3] = core[3]
	cframes[n + 3] = head
	n += 3

	-- Arms. World pitch is converted to torso space by adding the hunch back.
	local torsoLean = -torsoPitch
	for index, side in { -1, 1 } do
		local pitch, elbow, spread
		local dead = look.deadArm == side
		local legSwing = if side < 0 then -sinP else sinP
		if death then
			pitch, elbow, spread = 2.4, 0.4, 0.5
		elseif lying > 0.5 then
			-- Reaching ahead along the ground and pulling, one arm then the other.
			local pull = math.sin(phase + side * HALF_PI)
			pitch = torsoLean + 2.6 + 0.45 * pull * p.crawlBlend
			elbow = 0.35 - 0.3 * pull * p.crawlBlend
			spread = 0.25
		elseif dead then
			pitch = torsoLean + 0.05 + VC.ArmHangSwingRadians * 0.6 * legSwing * gait
			elbow, spread = 0.1, ARM_SPREAD
		elseif attacking then
			local claw = strike * (if index == 1 then 1 else 0.8)
			pitch = torsoLean + VC.ArmReachRadians + VC.AttackArmLiftRadians * claw
			elbow = 0.35 + 0.6 * claw
			spread = -0.15
		elseif chasing then
			pitch = torsoLean + VC.ArmReachRadians + VC.ArmReachBobRadians * math.sin(phase + side * HALF_PI)
			elbow = 0.3 + 0.12 * math.sin(phase * 2 + side)
			spread = -0.12
		elseif seeking then
			pitch = torsoLean + VC.ArmReachRadians * 0.55 + VC.ArmHangSwingRadians * 0.5 * legSwing * gait
			elbow, spread = 0.45, ARM_SPREAD * 0.5
		else
			pitch = torsoLean + 0.12 + VC.ArmHangSwingRadians * legSwing * gait
			elbow, spread = ELBOW_REST, ARM_SPREAD
		end
		-- A textured shirt's sleeve turns with the arm at the shoulder inside its cap.
		local shoulders, sleeveOffsets = rig.shoulders, rig.sleeveOffsets
		local shoulder = if shoulders
			then torsoCentre * CF(shoulders[index]) * ANG(pitch, 0, side * spread)
			else waist * CF(side * SHOULDER_X * s, SHOULDER_UP * s, 0) * ANG(pitch, 0, side * spread)
		local elbowJoint = shoulder * CF(0, -UPPER_ARM.Y * s, 0) * ANG(elbow, 0, 0)
		parts[n + 1] = core[2 + index * 2]
		cframes[n + 1] = if sleeveOffsets
			then shoulder * CF(sleeveOffsets[index])
			else shoulder * CF(0, (JOINT_OVERLAP - UPPER_ARM.Y) / 2 * s, 0) * LIMB_TURN
		parts[n + 2] = core[3 + index * 2]
		cframes[n + 2] = elbowJoint * CF(0, (JOINT_OVERLAP - FOREARM.Y) / 2 * s, 0) * LIMB_TURN
		n += 2
	end

	-- Legs. The limping leg swings less, stays stiff and turns out; the other bends its knee while
	-- swinging forward.
	for index, side in { -1, 1 } do
		local swing = if side < 0 then sinP else -sinP
		local forward = if side < 0 then cosP else -cosP
		local isBad = side == bad
		local amp = VC.LegSwingRadians * gait * (if isBad then 1 - 0.5 * limp else 1)
		local knee = KNEE_REST + VC.KneeBendRadians * math.max(0, forward) * gait * (if isBad then 1 - 0.8 * limp else 1)
		local thighPitch = swing * amp - (if isBad then 0.08 * limp * gait else 0)
		local turnOut = if isBad then side * 0.08 * limp else 0
		if death then
			thighPitch, knee = 0.15 * side, 0.5
		elseif lying > 0.5 then
			thighPitch, knee = -0.1 + 0.08 * side * math.sin(phase), 0.2
		elseif kneel > 0 then
			thighPitch = thighPitch * (1 - kneel) + 0.25 * kneel
			knee = knee * (1 - kneel) + 1.75 * kneel
		end
		local hip = pelvisPivot * CF(side * HIP_X * s, 0, 0) * ANG(thighPitch, 0, turnOut)
		local kneeJoint = hip * CF(0, -THIGH.Y * s, 0) * ANG(-knee, 0, 0)
		parts[n + 1] = core[6 + index * 2]
		cframes[n + 1] = hip * CF(0, (JOINT_OVERLAP - THIGH.Y) / 2 * s, 0) * LIMB_TURN
		parts[n + 2] = core[7 + index * 2]
		cframes[n + 2] = kneeJoint * CF(0, (JOINT_OVERLAP - SHIN.Y) / 2 * s, 0) * LIMB_TURN
		n += 2
	end

	if rig.detailVisible then
		local detail = rig.detail
		parts[n + 1] = detail[1]
		cframes[n + 1] = head * CF(JAW_HINGE * s) * ANG(JAW_OPEN - 0.25 * strike, 0, 0) * CF(JAW_OFFSET * s)
		parts[n + 2] = detail[2]
		cframes[n + 2] = head * CF(-SOCKET_OFFSET.X * s, SOCKET_OFFSET.Y * s, SOCKET_OFFSET.Z * s)
		parts[n + 3] = detail[3]
		cframes[n + 3] = head * CF(SOCKET_OFFSET.X * s, SOCKET_OFFSET.Y * s, SOCKET_OFFSET.Z * s)
		parts[n + 4] = detail[4]
		cframes[n + 4] = head * CF(-EYE_OFFSET.X * s, EYE_OFFSET.Y * s, EYE_OFFSET.Z * s)
		parts[n + 5] = detail[5]
		cframes[n + 5] = head * CF(EYE_OFFSET.X * s, EYE_OFFSET.Y * s, EYE_OFFSET.Z * s)
		parts[n + 6] = detail[6]
		cframes[n + 6] = waist
			* CF(WOUND_OFFSET.X * bad * s, (TORSO.Y / 2 + WOUND_OFFSET.Y) * s, WOUND_OFFSET.Z * s)
			* ANG(0, 0, WOUND_TILT * bad)
	end
end

return ZombieRig
