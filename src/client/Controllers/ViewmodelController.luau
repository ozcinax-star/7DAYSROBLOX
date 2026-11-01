--!strict
-- ViewmodelController: the first-person view of the player's own arms and held item (7DTD is played
-- in first person with the arms and the tool in view). Roblox hides the whole character in first
-- person, held item included, so this controller draws its own copy in front of the camera: the item
-- model from Shared/HeldItems, a hand around its grip and a sleeved arm reaching up from below the
-- screen edge. Empty hands show both fists.
--
-- Everything is procedural and local: each held kind has a rest pose (camera space) and every action
-- a few key poses blended with easing: a chop (axes, pickaxe, shovel, club), a spear thrust, a jab
-- that alternates fists, a gun's kick, a bow's release, raising food or a drink to the mouth and a
-- push for placing. Walking bobs the view and turning the camera lets the arms lag a little.
-- ToolController calls `swing` and `act` when the player swings or uses; the server still decides
-- what is hit. Parts are anchored, take no rays and cast no shadows; they are only shown while the
-- camera is at the head.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local HC = Config.WeaponHandling
local HeldItems = require(Shared.HeldItems)
local Melee = require(Shared.Melee)

local InventoryController = require(script.Parent.InventoryController)
local WeaponController = require(script.Parent.WeaponController)

export type Action = "Shoot" | "Use" | "Place"
type Kind = "Fist" | "Tool" | "Spear" | "Gun" | "Bow" | "Block"
type Style = "Chop" | "Stab" | "Punch" | Action
-- One key of an action: the share of its duration where the pose is reached and the pose.
type Key = { at: number, pose: CFrame }
type Motion = { style: Style, startedAt: number, duration: number, left: boolean }

local MC = Config.Melee
-- The camera counts as first person while it is this close to the head (studs).
local FIRST_PERSON_DISTANCE = 1.5
local SKIN_COLOR = Color3.fromRGB(204, 160, 128)
local SLEEVE_COLOR = Color3.fromRGB(62, 70, 58)
local ARM_WIDTH = 0.32
local SLEEVE_WIDTH = 0.38
-- Share of the arm, from the shoulder end, that the sleeve covers.
local SLEEVE_SHARE = 0.55
local HAND_SIZE = 0.42
local FIST_SIZE = 0.5
-- Shoulders sit below the bottom screen edge (camera space) so only the forearms show.
local RIGHT_SHOULDER = Vector3.new(1.35, -2.1, -0.1)
local LEFT_SHOULDER = Vector3.new(-1.35, -2.1, -0.1)
-- Walking bob: phase speed per stud walked, and sideways / vertical size at walking speed.
local BOB_RATE = HC.BobRate
local BOB_SIDE = HC.BobAmount
local BOB_DROP = HC.BobAmount * 1.3
local BOB_SPEED = 16
-- Turning lag: how far the arms trail a camera turn (studs per radian) and how fast they catch up.
local SWAY = HC.SwayAmount
local SWAY_LIMIT = HC.SwayLimit
local SWAY_RETURN = HC.SwayReturn
local SHOOT_SECONDS = 0.25
local BOW_SECONDS = 0.35
local PLACE_SECONDS = 0.3

-- A camera-space pose: position, then pitch / yaw / roll in degrees (roll first, then pitch, yaw).
local function pose(x: number, y: number, z: number, pitch: number, yaw: number, roll: number): CFrame
	return CFrame.new(x, y, z) * CFrame.fromOrientation(math.rad(pitch), math.rad(yaw), math.rad(roll))
end

local UNTILT = CFrame.Angles(HeldItems.HoldTilt, 0, 0):Inverse()
local V = Vector3.new

-- A tool's grip pose from where the fist is, the way the handle points out of it and the side its
-- head faces (camera space; the head sits on the handle's -Y side, Shared/HeldItems).
local function hold(x: number, y: number, z: number, handle: Vector3, head: Vector3): CFrame
	local along = handle.Unit
	local up = -(head - head:Dot(along) * along).Unit
	return CFrame.fromMatrix(V(x, y, z), up:Cross(-along), up, -along) * UNTILT
end

-- Rest poses of the right hand's grip for each held kind. A tool rests low on the right with its
-- handle leaning forward and its head up to the right of the crosshair, blade to the left; a gun's
-- barrel points along -Z; a bow's limb stands along Y.
local REST: { [Kind]: CFrame } = {
	Fist = pose(0.8, -1.0, -1.7, 0, 0, 0),
	Tool = hold(1.25, -1.45, -2.25, V(-0.25, 0.75, -0.6), V(-0.7, 0, -0.7)),
	Spear = pose(0.9, -1.0, -1.2, -20, 8, 0),
	Gun = pose(0.75, -0.85, -1.6, 0, 4, 0),
	Bow = pose(0.6, -0.6, -2.1, 0, 0, -12),
	Block = pose(0.85, -0.8, -1.7, 15, 20, 0),
}
local LEFT_REST = pose(-0.8, -1.0, -1.7, 0, 0, 0)

-- Key poses of each action after the rest pose; every action ends back at rest. Melee keys are
-- shares of the swing; the strike lands where the server's hit would. A chop raises the tool upright
-- at the right edge with the blade forward, brings its head down just under the crosshair and
-- follows through low to the left.
local KEYS: { [Style]: { Key } } = {
	Chop = {
		{ at = 0.35, pose = hold(1.3, -0.9, -1.8, V(0.3, 0.95, 0.1), V(0, 0, -1)) },
		{ at = 0.55, pose = hold(0.6, -0.9, -1.6, V(-0.35, 0.32, -0.9), V(0, -1, 0)) },
		{ at = 0.7, pose = hold(0.35, -1.35, -1.7, V(-0.45, -0.05, -0.9), V(0, -1, 0.1)) },
	},
	Stab = {
		{ at = 0.3, pose = pose(1.0, -0.9, -0.7, -15, 10, 0) },
		{ at = 0.5, pose = pose(0.45, -0.75, -2.6, -25, 2, 0) },
	},
	Punch = {
		{ at = 0.25, pose = pose(0.95, -0.95, -1.3, 0, 0, 0) },
		{ at = 0.45, pose = pose(0.15, -0.5, -2.7, 0, -10, 0) },
	},
	Use = {
		{ at = 0.3, pose = pose(0.2, -0.35, -0.9, 20, 0, 0) },
		{ at = 0.7, pose = pose(0.2, -0.35, -0.9, 20, 0, 0) },
	},
}

local ViewmodelController = {}

local player = Players.LocalPlayer
local folder: Folder
local rightArm: Part
local rightSleeve: Part
local rightHand: Part
local leftArm: Part
local leftSleeve: Part
local leftHand: Part
local rightUpper: Part
local leftUpper: Part
local handDetails: { { part: Part, hand: Part, offset: CFrame } } = {}
local wallBlend = 0
local sprintBlend = 0
-- The held item's model and each part's offset from the grip, rebuilt when the held item changes.
local itemModel: Model? = nil
local itemParts: { BasePart } = {}
local itemOffsets: { CFrame } = {}
local heldId: string? = nil
local kind: Kind = "Fist"
local motion: Motion? = nil
local leftNext = false
local shown = false
local leftShown = true
local bobPhase = 0
local sway = Vector2.zero
local lastLook: Vector3? = nil

local function makePart(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = folder
	return part
end

local function fromPose(p: { number }): CFrame
	return pose(p[1], p[2], p[3], p[4], p[5], p[6])
end

local function makeFingers(hand: Part, side: number)
	local glove = Color3.fromRGB(56, 61, 50)
	hand.Material = Enum.Material.Fabric
	for i = 0, 3 do
		for segment = 1, 2 do
			local finger = makePart("GlovedFinger", V(0.075, 0.064, 0.095), glove)
			finger.Material = Enum.Material.Fabric
			table.insert(handDetails, { part = finger, hand = hand,
				offset = CFrame.new(side * (if segment == 1 then -0.12 else -0.065), 0.09 - i * 0.063,
					if segment == 1 then -0.07 else -0.135) * CFrame.Angles(0, math.rad(side * 35), 0) })
		end
	end
	local thumb = makePart("GlovedThumb", V(0.075, 0.14, 0.085), glove)
	table.insert(handDetails, { part = thumb, hand = hand,
		offset = CFrame.new(side * 0.12, 0.095, -0.02) * CFrame.Angles(0, 0, math.rad(side * -35)) })
end

local function kindOf(id: string?): Kind
	if id == nil then
		return "Fist"
	end
	local weapon = Config.Ranged.Weapons[id]
	if weapon then
		return if weapon.Magazine then "Gun" else "Bow"
	end
	if id == "StoneSpear" then
		return "Spear"
	end
	if Config.Tools[id] then
		return "Tool"
	end
	return "Block"
end

-- Builds the held item at a stand-in grip and keeps each part's offset from it, following the welds
-- (part1 = part0 * C0 * C1:Inverse()); the parts are then anchored and moved directly.
local function buildItem(id: string?)
	if itemModel then
		itemModel:Destroy()
		itemModel = nil
	end
	table.clear(itemParts)
	table.clear(itemOffsets)
	heldId = id
	kind = kindOf(id)
	if id == nil then
		return
	end
	local grip = makePart("Grip", Vector3.one * 0.1, SKIN_COLOR)
	local model = HeldItems.build(id, grip, CFrame.identity)
	local offsets: { [BasePart]: CFrame } = { [grip] = CFrame.identity }
	local welds: { Weld } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Weld") then
			table.insert(welds, descendant)
		end
	end
	local progress = true
	while progress do
		progress = false
		for _, weld in welds do
			local part0, part1 = weld.Part0, weld.Part1
			if part0 and part1 and offsets[part0] and offsets[part1] == nil then
				offsets[part1] = offsets[part0] * weld.C0 * weld.C1:Inverse()
				progress = true
			end
		end
	end
	for _, weld in welds do
		weld:Destroy()
	end
	for part, offset in offsets do
		if part ~= grip then
			part.Anchored = true
			part.CastShadow = false
			table.insert(itemParts, part)
			table.insert(itemOffsets, offset)
		end
	end
	grip:Destroy()
	model.Parent = folder
	itemModel = model
end

local function ease(alpha: number): number
	return alpha * alpha * (3 - 2 * alpha)
end

-- The grip pose `motion` is at, starting from and returning to `rest`.
local function posed(rest: CFrame, current: Motion, now: number): CFrame
	local progress = (now - current.startedAt) / current.duration
	local keys = KEYS[current.style]
	if keys == nil then
		-- Short actions without keys: a kick back for guns and bows, a push forward for placing.
		local peak = if current.style == "Place"
			then rest * CFrame.new(0, 0, -0.4)
			elseif kind == "Bow" then rest * CFrame.new(0, 0, 0.25)
			else rest * CFrame.new(0, 0.015, 0.025) * CFrame.Angles(math.rad(1), 0, 0)
		keys = { { at = 0.3, pose = peak } }
	end
	local from, fromAt = rest, 0
	for index, key in keys :: { Key } do
		if progress < key.at then
			local a = (progress - fromAt) / (key.at - fromAt)
			-- The wind-up eases in and out; later keys (the strike) accelerate into contact instead of
			-- slowing to a stop right where the hit lands.
			return from:Lerp(key.pose, if index == 1 then ease(a) else a * a)
		end
		from, fromAt = key.pose, key.at
	end
	return from:Lerp(rest, ease(math.min(1, (progress - fromAt) / (1 - fromAt))))
end

-- Mirrors a right-hand pose to the left side.
local function mirrored(cf: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

-- Places an arm from its shoulder to `hand` (world space) with its sleeve at the shoulder end.
local function placeArm(arm: Part, sleeve: Part, upper: Part, shoulder: Vector3, hand: Vector3, side: number)
	local elbow = (shoulder + hand) / 2 + Vector3.new(side * 0.22, -0.27, 0.12)
	local upperLength = math.max(0.1, (elbow - shoulder).Magnitude)
	upper.Size = Vector3.new(upperLength, SLEEVE_WIDTH, SLEEVE_WIDTH)
	upper.CFrame = CFrame.lookAt(shoulder, elbow) * CFrame.new(0, 0, -upperLength / 2) * CFrame.Angles(0, math.pi / 2, 0)
	local length = math.max(0.1, (hand - elbow).Magnitude)
	local along = CFrame.lookAt(elbow, hand)
	arm.Size = Vector3.new(length, ARM_WIDTH, ARM_WIDTH)
	arm.CFrame = along * CFrame.new(0, 0, -length / 2) * CFrame.Angles(0, math.pi / 2, 0)
	local sleeveLength = length * SLEEVE_SHARE
	sleeve.Size = Vector3.new(sleeveLength, SLEEVE_WIDTH, SLEEVE_WIDTH)
	sleeve.CFrame = along * CFrame.new(0, 0, -sleeveLength / 2) * CFrame.Angles(0, math.pi / 2, 0)
end

local function setShown(value: boolean)
	if value == shown then
		return
	end
	shown = value
	folder.Parent = if value then Workspace else nil
end

local function onRender(dt: number)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = Workspace.CurrentCamera
	if
		head == nil
		or not head:IsA("BasePart")
		or humanoid == nil
		or humanoid.Health <= 0
		or camera == nil
		or (camera.CFrame.Position - head.Position).Magnitude > FIRST_PERSON_DISTANCE
	then
		setShown(false)
		lastLook = nil
		return
	end
	setShown(true)
	local held = InventoryController.getHeld()
	local id = if held then held.id else nil
	if id ~= heldId then
		buildItem(id)
	end
	local now = os.clock()
	local current = motion
	if current and now - current.startedAt >= current.duration then
		motion = nil
		current = nil
	end

	-- Walking bob and turning lag, in camera space.
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local speed = if root and root:IsA("BasePart")
		then (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		else 0
	local walking = humanoid.FloorMaterial ~= Enum.Material.Air and speed > 0.5
	bobPhase += if walking then dt * speed * BOB_RATE else 0
	local strength = if walking then math.min(1.5, speed / BOB_SPEED) else 0
	local look = camera.CFrame.LookVector
	if lastLook then
		local turn = camera.CFrame:VectorToObjectSpace(lastLook)
		sway += Vector2.new(turn.X, turn.Y) * SWAY
	end
	lastLook = look
	sway -= sway * math.min(1, dt * SWAY_RETURN)
	sway = Vector2.new(math.clamp(sway.X, -SWAY_LIMIT, SWAY_LIMIT), math.clamp(sway.Y, -SWAY_LIMIT, SWAY_LIMIT))
	local swayShare = 1 - WeaponController.aimAlpha() * 0.95
	local offset = CFrame.new(
		math.sin(bobPhase) * BOB_SIDE * strength * (1 - WeaponController.aimAlpha() * (1 - HC.AimBobShare)) + sway.X * swayShare,
		-math.abs(math.cos(bobPhase)) * BOB_DROP * strength * (1 - WeaponController.aimAlpha() * (1 - HC.AimBobShare)) + sway.Y * swayShare,
		0
	)
	local view = camera.CFrame * offset

	local handling = heldId and Config.WeaponHandling.Items[heldId]
	local rest = REST[kind]
	if handling then rest = fromPose(handling.Hip):Lerp(fromPose(handling.Aim), WeaponController.aimAlpha()) end
	local reloading, reloadProgress = WeaponController.reloadProgress()
	if reloading and handling then
		local weight = math.sin(math.pi * reloadProgress) ^ 0.6
		rest *= CFrame.new(0.12 * weight, -0.14 * weight, 0.28 * weight)
			* CFrame.Angles(math.rad(-12 * weight), math.rad(-24 * weight), math.rad(-32 * weight))
	end
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character :: Model, folder }
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local wall = Workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * Config.WeaponHandling.WallReach, params)
	local blocked = if wall then 1 - wall.Distance / Config.WeaponHandling.WallReach else 0
	wallBlend += (blocked - wallBlend) * (1 - math.exp(-Config.WeaponHandling.WallResponse * dt))
	local sprint = if kind == "Gun" and speed > Config.WeaponHandling.SprintSpeed and not reloading then 1 else 0
	sprintBlend += (sprint - sprintBlend) * math.min(1, dt * 10)
	local equip = 1 - WeaponController.equipAlpha()
	local kickPitch, kickYaw, kickBack = WeaponController.kick()
	rest *= CFrame.new(0, -equip * Config.WeaponHandling.EquipDip - sprintBlend * 0.4 - wallBlend * 0.3, equip * 0.2 + kickBack)
		* CFrame.Angles(math.rad(kickPitch * 0.6 + sprintBlend * -22 + wallBlend * 32), math.rad(kickYaw), math.rad(-equip * 15))
	local right = if current and not current.left then posed(rest, current, now) else rest
	local gripWorld = view * right
	local fists = kind == "Fist"
	rightHand.Size = if fists then V(0.31, 0.32, 0.22) else V(0.28, 0.3, 0.16)
	rightHand.CFrame = gripWorld
	placeArm(rightArm, rightSleeve, rightUpper, (view * CFrame.new(RIGHT_SHOULDER)).Position, gripWorld.Position, 1)
	for index, part in itemParts do part.CFrame = gripWorld * itemOffsets[index] end
	local support = kind ~= "Block" and heldId ~= "WoodenClub"
	if support ~= leftShown then
		leftShown = support
		local parent = if support then folder else nil
		leftArm.Parent, leftSleeve.Parent, leftHand.Parent, leftUpper.Parent = parent, parent, parent, parent
	end
	if fists then
		local left = if current and current.left then mirrored(posed(REST.Fist, current, now)) else LEFT_REST
		local leftWorld = view * left
		leftHand.Size = V(0.31, 0.32, 0.22)
		leftHand.CFrame = leftWorld
		placeArm(leftArm, leftSleeve, leftUpper, (view * CFrame.new(LEFT_SHOULDER)).Position, leftWorld.Position, -1)
	elseif support then
		local itemRoot = itemModel and itemModel.PrimaryPart
		local attachment = itemRoot and itemRoot:FindFirstChild("SupportGrip")
		local at = if attachment and attachment:IsA("Attachment") then attachment.WorldPosition
			else (gripWorld * CFrame.new(-0.1, 0.25, -0.7)).Position
		if reloading and handling then
			local start = V(handling.Support[1], handling.Support[2], handling.Support[3])
			local goal = if handling.ReloadStyle == "Magazine" then V(-0.18, -0.72, -0.15)
				elseif handling.ReloadStyle == "Cylinder" then V(-0.35, 0.24, -0.45) else V(-0.12, 0.28, -0.65)
			local travel = math.sin(math.pi * reloadProgress) ^ 0.7
			at = (gripWorld * CFrame.new(start:Lerp(goal, travel))).Position
		end
		leftHand.Size = V(0.28, 0.3, 0.16)
		leftHand.CFrame = CFrame.new(at) * gripWorld.Rotation * CFrame.Angles(0, 0, math.rad(-70))
		placeArm(leftArm, leftSleeve, leftUpper, (view * CFrame.new(LEFT_SHOULDER)).Position, at, -1)
	end
	for _, detail in handDetails do
		detail.part.Parent = if detail.hand == leftHand and not support then nil else folder
		detail.part.CFrame = detail.hand.CFrame * detail.offset
	end
end

local function paint()
	local color = SKIN_COLOR
	rightArm.Color = color
	rightHand.Color = Color3.fromRGB(56, 61, 50)
	leftArm.Color = color
	leftHand.Color = Color3.fromRGB(56, 61, 50)
end

-- Plays the melee swing of `toolId` (the fist when it is not a tool) for the swing's duration.
function ViewmodelController.swing(toolId: string)
	local tool = Config.Tools[toolId] or Config.Tools.Fist
	local interval = Melee.interval(tool.AttacksPerMinute, MC.SwingDelay)
	local style: Style = if kind == "Fist" then "Punch" elseif kind == "Spear" then "Stab" else "Chop"
	local left = false
	if style == "Punch" then
		left = leftNext
		leftNext = not leftNext
	end
	motion = {
		style = style,
		startedAt = os.clock(),
		duration = math.min(MC.SwingMaxSeconds, interval * 0.9),
		left = left,
	}
end

-- Plays a use that is not a swing: a shot, eating or drinking, placing.
function ViewmodelController.act(action: Action)
	local duration = if action == "Use"
		then Config.Survival.UseSeconds
		elseif action == "Place" then PLACE_SECONDS
		elseif kind == "Bow" then BOW_SECONDS
		else SHOOT_SECONDS
	motion = { style = action, startedAt = os.clock(), duration = duration, left = false }
end

function ViewmodelController.init()
	folder = Instance.new("Folder")
	folder.Name = "Viewmodel"
	rightSleeve = makePart("RightSleeve", Vector3.one, SLEEVE_COLOR)
	rightArm = makePart("RightArm", Vector3.one, SKIN_COLOR)
	rightHand = makePart("RightHand", Vector3.one * HAND_SIZE, SKIN_COLOR)
	leftSleeve = makePart("LeftSleeve", Vector3.one, SLEEVE_COLOR)
	leftArm = makePart("LeftArm", Vector3.one, SKIN_COLOR)
	leftHand = makePart("LeftHand", Vector3.one * FIST_SIZE, SKIN_COLOR)
	rightUpper = makePart("RightUpperArm", Vector3.one, SLEEVE_COLOR)
	leftUpper = makePart("LeftUpperArm", Vector3.one, SLEEVE_COLOR)
	for _, limb in { rightArm, leftArm, rightSleeve, leftSleeve, rightUpper, leftUpper } do
		limb.Shape = Enum.PartType.Cylinder
		limb.Material = if limb == rightArm or limb == leftArm then Enum.Material.SmoothPlastic else Enum.Material.Fabric
	end
	makeFingers(rightHand, 1)
	makeFingers(leftHand, -1)
end

function ViewmodelController.start()
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Body Colors", 5)
		paint()
	end)
	paint()
	RunService:BindToRenderStep("EquipmentViewmodel", Enum.RenderPriority.Camera.Value + 3, onRender)
end

return ViewmodelController
