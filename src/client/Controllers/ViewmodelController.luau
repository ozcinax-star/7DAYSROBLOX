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
local HeldItems = require(Shared.HeldItems)
local Melee = require(Shared.Melee)

local InventoryController = require(script.Parent.InventoryController)

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
local ARM_WIDTH = 0.42
local SLEEVE_WIDTH = 0.5
-- Share of the arm, from the shoulder end, that the sleeve covers.
local SLEEVE_SHARE = 0.55
local HAND_SIZE = 0.42
local FIST_SIZE = 0.5
-- Shoulders sit below the bottom screen edge (camera space) so only the forearms show.
local RIGHT_SHOULDER = Vector3.new(1.35, -2.1, -0.1)
local LEFT_SHOULDER = Vector3.new(-1.35, -2.1, -0.1)
-- Walking bob: phase speed per stud walked, and sideways / vertical size at walking speed.
local BOB_RATE = 0.55
local BOB_SIDE = 0.035
local BOB_DROP = 0.045
local BOB_SPEED = 16
-- Turning lag: how far the arms trail a camera turn (studs per radian) and how fast they catch up.
local SWAY = 0.5
local SWAY_LIMIT = 0.12
local SWAY_RETURN = 12
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
			else rest * CFrame.new(0, 0.08, 0.3) * CFrame.Angles(math.rad(14), 0, 0)
		keys = { { at = 0.3, pose = peak } }
	end
	local from, fromAt = rest, 0
	for _, key in keys :: { Key } do
		if progress < key.at then
			return from:Lerp(key.pose, ease((progress - fromAt) / (key.at - fromAt)))
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
local function placeArm(arm: Part, sleeve: Part, shoulder: Vector3, hand: Vector3)
	local length = math.max(0.1, (hand - shoulder).Magnitude)
	local along = CFrame.lookAt(shoulder, hand)
	arm.Size = Vector3.new(ARM_WIDTH, ARM_WIDTH, length)
	arm.CFrame = along * CFrame.new(0, 0, -length / 2)
	local sleeveLength = length * SLEEVE_SHARE
	sleeve.Size = Vector3.new(SLEEVE_WIDTH, SLEEVE_WIDTH, sleeveLength)
	sleeve.CFrame = along * CFrame.new(0, 0, -sleeveLength / 2)
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
	local offset = CFrame.new(
		math.sin(bobPhase) * BOB_SIDE * strength + sway.X,
		-math.abs(math.cos(bobPhase)) * BOB_DROP * strength + sway.Y,
		0
	)
	local view = camera.CFrame * offset

	local rest = REST[kind]
	local right = if current and not current.left then posed(rest, current, now) else rest
	local gripWorld = view * right
	local fists = kind == "Fist"
	rightHand.Size = Vector3.one * (if fists then FIST_SIZE else HAND_SIZE)
	rightHand.CFrame = gripWorld
	placeArm(rightArm, rightSleeve, (view * CFrame.new(RIGHT_SHOULDER)).Position, gripWorld.Position)
	for index, part in itemParts do
		part.CFrame = gripWorld * itemOffsets[index]
	end

	if fists ~= leftShown then
		leftShown = fists
		local parent = if fists then folder else nil
		leftArm.Parent = parent
		leftSleeve.Parent = parent
		leftHand.Parent = parent
	end
	if fists then
		local left = if current and current.left then mirrored(posed(REST.Fist, current, now)) else LEFT_REST
		local leftWorld = view * left
		leftHand.Size = Vector3.one * FIST_SIZE
		leftHand.CFrame = leftWorld
		placeArm(leftArm, leftSleeve, (view * CFrame.new(LEFT_SHOULDER)).Position, leftWorld.Position)
	end
end

local function skinColor(): Color3
	local character = player.Character
	local colors = character and character:FindFirstChildOfClass("BodyColors")
	return if colors then colors.RightArmColor3 else SKIN_COLOR
end

local function paint()
	local color = skinColor()
	rightArm.Color = color
	rightHand.Color = color
	leftArm.Color = color
	leftHand.Color = color
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
end

function ViewmodelController.start()
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Body Colors", 5)
		paint()
	end)
	paint()
	RunService.PreRender:Connect(onRender)
end

return ViewmodelController
