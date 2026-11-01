--!strict
-- ToolController: swings the held tool, or the fist; with a block in the hand the same input places
-- it (BuildService), with food, a drink or medicine it uses it, and a bare hand aimed at water drinks
-- (SurvivalService). Left mouse, gamepad R2, or the Hit button on touch; holding keeps swinging at
-- the tool's rate. A swing needs the tool's stamina. The server decides what is hit; this client
-- only sends its aim and animates. Its own swing plays at once, other players' swings, the zombie
-- stagger and the impact (ImpactController) come from the server's ToolSwing broadcast. A gun in
-- the hand is aimed with the right mouse button, gamepad L2 or the Aim toggle on touch: the camera
-- zooms in and the server tightens the spread (AimIntent).
--
-- The third-person swing is procedural: key poses of the R15 shoulder, elbow and waist joints,
-- layered on the walk animation by turning each joint's Transform after the Animator has written it
-- (PreSimulation). That works for Motor6D joints and for the AnimationConstraint joints of upgraded
-- avatars, whose C0 is read-only. Tools chop overhead, the spear thrusts and fists jab, the arms
-- taking turns; R6 rigs do not swing. In first person the player sees ViewmodelController's arms
-- instead, told of each swing and use from here.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponController = require(script.Parent.WeaponController)
local EquipmentPoseController = require(script.Parent.EquipmentPoseController)
local CameraController = require(script.Parent.CameraController)
local BowState = require(script.Parent.Parent.Modules.BowState)
local Config = require(Shared.Config)
local Localization = require(Shared.Localization)
local Melee = require(Shared.Melee)
local Net = require(Shared.Net)

local ImpactController = require(script.Parent.ImpactController)
local InventoryController = require(script.Parent.InventoryController)
local ViewmodelController = require(script.Parent.ViewmodelController)
local ZombieRenderController = require(script.Parent.ZombieRenderController)

local MC = Config.Melee
local SC = Config.Survival
local FIST = "Fist"
-- The server's melee hit shape (ToolService), for the "too far" check.
local SHAPE: Melee.Shape = {
	bottom = MC.HitBottom,
	top = MC.HitTop,
	radius = MC.HitRadius,
	headHeight = MC.HeadHeight,
	headRadius = MC.HeadRadius,
	headLean = MC.HeadLean,
}
-- After an "out of stamina" refusal, the next try waits this long (stamina comes back meanwhile).
local OUT_OF_STAMINA_RETRY = 0.3

-- Third-person swing poses: joint angles in degrees reached at shares of the swing. Shoulder and
-- elbow turn about the joint's X axis (positive raises the arm forward or bends the forearm toward
-- its front), the waist about Y (positive turns the chest left). A swing starts at the walk pose,
-- eases out into the first key, speeds into the second (the strike) and settles back.
local SWING_POSES: { [SwingStyle]: { SwingKey } } = {
	-- Axe, pickaxe, shovel, club: the tool up behind the head, then down past the horizontal.
	Chop = {
		{ at = 0.4, shoulder = 160, elbow = 70, waist = -18 },
		{ at = 0.62, shoulder = 35, elbow = 5, waist = 14 },
	},
	-- Spear: drawn back, then thrust straight out.
	Stab = {
		{ at = 0.3, shoulder = 60, elbow = 95, waist = -12 },
		{ at = 0.5, shoulder = 88, elbow = 0, waist = 14 },
	},
	-- Fist: up to a guard, then a straight jab with the chest turned into it.
	Punch = {
		{ at = 0.2, shoulder = 70, elbow = 110, waist = 0 },
		{ at = 0.45, shoulder = 90, elbow = 0, waist = 18 },
	},
}
-- A swing lasts this share of the tool's interval, capped by Config.Melee.SwingMaxSeconds.
local SWING_SHARE = 0.9

local HIT_BUTTON_SIZE = 84
local HIT_BUTTON_OFFSET = Vector2.new(-24, -190)
local AIM_BUTTON_SIZE = 64
local AIM_BUTTON_GAP = 12
local BUTTON_COLOR = Color3.fromRGB(28, 28, 30)
local AIM_ON_COLOR = Color3.fromRGB(70, 110, 150)
local MESSAGE_OFFSET = 120

local MOUSE_INPUTS = {
	[Enum.UserInputType.MouseMovement] = true,
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.MouseButton2] = true,
	[Enum.UserInputType.MouseButton3] = true,
	[Enum.UserInputType.MouseWheel] = true,
	[Enum.UserInputType.Keyboard] = true,
}

type Source = "Pointer" | "Touch"
type SwingStyle = "Chop" | "Stab" | "Punch"
type SwingKey = { at: number, shoulder: number, elbow: number, waist: number }
-- Motor6D or AnimationConstraint: both carry the Transform the Animator writes.
type Joints = { shoulder: Instance, elbow: Instance?, waist: Instance? }
type Swing = { startedAt: number, duration: number, style: SwingStyle, left: boolean, joints: Joints }

local ToolController = {}

local player = Players.LocalPlayer
local useRemote: RemoteEvent
local aimRemote: RemoteEvent
local aimButton: TextButton
local aiming = false
local swings: { [Model]: Swing } = {}
-- What a swing last wrote into each joint's Transform and the animation pose it turned, so a frame
-- the Animator skips (a joint no track moves) is not turned twice; and which arm a character's next
-- punch uses (weak: characters come and go).
local layered: { [Instance]: { base: CFrame, written: CFrame } } = setmetatable({}, { __mode = "k" }) :: any
local punchLeft: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local holding: Source? = nil
local nextSwingAt = 0
-- Throttles the replicated aim pitch for other players' equipment poses.
local nextPoseAt = 0
local messageLabel: TextLabel
local messageToken = 0

local function joint(parent: Instance?, name: string): Instance?
	local found = parent and parent:FindFirstChild(name)
	return if found and (found:IsA("Motor6D") or found:IsA("AnimationConstraint")) then found else nil
end

local function getTransform(target: Instance): CFrame
	if target:IsA("Motor6D") then
		return target.Transform
	elseif target:IsA("AnimationConstraint") then
		return target.Transform
	end
	return CFrame.identity
end

local function setTransform(target: Instance, value: CFrame)
	if target:IsA("Motor6D") then
		target.Transform = value
	elseif target:IsA("AnimationConstraint") then
		target.Transform = value
	end
end

-- The R15 joints a swing turns: the shoulder and elbow of the swinging arm, and the waist.
local function jointsOf(character: Model, left: boolean): Joints?
	local side = if left then "Left" else "Right"
	local shoulder = joint(character:FindFirstChild(`{side}UpperArm`), `{side}Shoulder`)
	if shoulder == nil then
		return nil
	end
	return {
		shoulder = shoulder,
		elbow = joint(character:FindFirstChild(`{side}LowerArm`), `{side}Elbow`),
		waist = joint(character:FindFirstChild("UpperTorso"), "Waist"),
	}
end

local function eachJoint(joints: Joints, callback: (target: Instance) -> ())
	callback(joints.shoulder)
	if joints.elbow then
		callback(joints.elbow)
	end
	if joints.waist then
		callback(joints.waist)
	end
end

-- Turns `target` by `rotation` on top of this frame's animation pose.
local function layer(target: Instance, rotation: CFrame)
	local current = getTransform(target)
	local last = layered[target]
	local base = if last and current == last.written then last.base else current
	local written = base * rotation
	setTransform(target, written)
	layered[target] = { base = base, written = written }
end

-- Puts back the animation pose under what a swing wrote.
local function restore(joints: Joints)
	eachJoint(joints, function(target)
		local last = layered[target]
		if last and getTransform(target) == last.written then
			setTransform(target, last.base)
		end
		layered[target] = nil
	end)
end

local function playSwing(character: Model?, toolId: string, power: boolean?)
	if character == nil then
		return
	end
	EquipmentPoseController.release(character)
	local style: SwingStyle = if toolId == FIST then "Punch" elseif toolId == "StoneSpear" then "Stab" else "Chop"
	local left = false
	if style == "Punch" then
		left = punchLeft[character] == true
		punchLeft[character] = not left
	end
	local joints = jointsOf(character, left)
	if joints == nil then
		return
	end
	character:SetAttribute("MeleePoseUntil", workspace:GetServerTimeNow() + MC.SwingMaxSeconds)
	local playing = swings[character]
	if playing then
		restore(playing.joints)
	end
	local tool = Config.Tools[toolId] or Config.Tools[FIST]
	local interval = Melee.interval(tool.AttacksPerMinute, MC.SwingDelay)
	local duration = math.min(MC.SwingMaxSeconds, interval * SWING_SHARE)
		* (if power then Config.Combat.PowerIntervalScale else 1)
	swings[character] = { startedAt = os.clock(), duration = duration, style = style, left = left, joints = joints }
end

-- The joint angles (degrees) of `style` at `progress` (0-1).
local function swingPose(style: SwingStyle, progress: number): (number, number, number)
	local keys = SWING_POSES[style]
	local fromAt, shoulder, elbow, waist = 0, 0, 0, 0
	for index, key in keys do
		if progress < key.at then
			local a = (progress - fromAt) / (key.at - fromAt)
			-- Ease out of the rest pose, speed into the strike.
			a = if index == 1 then 1 - (1 - a) * (1 - a) else a * a
			return shoulder + (key.shoulder - shoulder) * a,
				elbow + (key.elbow - elbow) * a,
				waist + (key.waist - waist) * a
		end
		fromAt, shoulder, elbow, waist = key.at, key.shoulder, key.elbow, key.waist
	end
	local a = (progress - fromAt) / (1 - fromAt)
	local back = 1 - a * a * (3 - 2 * a)
	return shoulder * back, elbow * back, waist * back
end

-- Runs after the Animator wrote this frame's pose (PreSimulation).
local function stepSwings()
	local now = os.clock()
	for character, swing in swings do
		local progress = (now - swing.startedAt) / swing.duration
		local joints = swing.joints
		if progress >= 1 or joints.shoulder.Parent == nil then
			restore(joints)
			swings[character] = nil
			continue
		end
		local shoulder, elbow, waist = swingPose(swing.style, progress)
		layer(joints.shoulder, CFrame.Angles(math.rad(shoulder), 0, 0))
		if joints.elbow then
			layer(joints.elbow, CFrame.Angles(math.rad(elbow), 0, 0))
		end
		if joints.waist then
			layer(joints.waist, CFrame.Angles(0, math.rad(if swing.left then -waist else waist), 0))
		end
	end
end

local function showMessage(text: string)
	messageToken += 1
	local token = messageToken
	messageLabel.Text = text
	messageLabel.Visible = true
	task.delay(MC.MessageSeconds, function()
		if token == messageToken then
			messageLabel.Visible = false
		end
	end)
end

local function usingMouse(): boolean
	return MOUSE_INPUTS[UserInputService:GetLastInputType()] == true
end

-- True when the mouse is over a button or another active GUI element (a toolbelt click).
local function pointerOverGui(): boolean
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return false
	end
	local location = UserInputService:GetMouseLocation()
	local inset = GuiService:GetGuiInset()
	for _, object in playerGui:GetGuiObjectsAtPosition(location.X - inset.X, location.Y - inset.Y) do
		if object.Visible and (object:IsA("GuiButton") or object.Active) then
			return true
		end
	end
	return false
end

local function canSwing(source: Source): boolean
	if InventoryController.isBackpackOpen() or UserInputService:GetFocusedTextBox() then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	if source == "Pointer" then
		local last = UserInputService:GetLastInputType()
		if last == Enum.UserInputType.Touch then
			-- Screen taps do not swing; the Hit button does.
			return false
		end
		if usingMouse() and pointerOverGui() then
			return false
		end
	end
	return true
end

-- Unit direction from the head to what is under the cursor (free mouse) or the screen centre.
function ToolController.aimDirection(): Vector3?
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local camera = workspace.CurrentCamera
	if character == nil or head == nil or not head:IsA("BasePart") or camera == nil then
		return nil
	end
	local point = if usingMouse() and UserInputService.MouseBehavior == Enum.MouseBehavior.Default
		then UserInputService:GetMouseLocation()
		else camera.ViewportSize / 2
	local ray = camera:ViewportPointToRay(point.X, point.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	local result = workspace:Raycast(ray.Origin, ray.Direction * MC.AimDistance, params)
	local target = if result then result.Position else ray.Origin + ray.Direction * MC.AimDistance
	-- Zombie bodies take no rays, so the camera ray is also tested with the server's hit shape. A body
	-- under the cursor is aimed at through its axis: the camera sits off the shoulder, and aiming at
	-- whatever lies behind the zombie would pass beside it from the head. Bodies between the camera
	-- and the head (behind the player) do not count.
	local headAlong = (head.Position - ray.Origin):Dot(ray.Direction)
	local zombie = Melee.pick({
		ox = ray.Origin.X,
		oy = ray.Origin.Y,
		oz = ray.Origin.Z,
		dx = ray.Direction.X,
		dy = ray.Direction.Y,
		dz = ray.Direction.Z,
		range = (target - ray.Origin).Magnitude,
	}, ZombieRenderController.bodiesNear(head.Position, MC.AimDistance), SHAPE, function(hit)
		return hit.distance < headAlong
	end)
	if zombie then
		target = Vector3.new(zombie.px, zombie.py, zombie.pz)
	end
	local direction = target - head.Position
	if direction.Magnitude < 0.5 or direction.Unit:Dot(ray.Direction) < 0 then
		-- The cursor is on something between the camera and the head: swing where the camera looks.
		direction = ray.Direction
	end
	return direction.Unit
end

-- Whether a bare-hand "use" along `aim` reaches lake or river water (the server's drink check).
function ToolController.waterInReach(aim: Vector3): boolean
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if character == nil or head == nil or not head:IsA("BasePart") then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = false
	local result = workspace:Raycast(head.Position, aim * SC.DrinkReach, params)
	return result ~= nil and result.Instance == workspace.Terrain and result.Material == Enum.Material.Water
end

-- True when a melee swing along `aim` reaches nothing but the cursor is on something a little
-- further away (a tree clicked from too far with the free mouse). Zombie bodies take no rays, so
-- they are tested with the server's melee shape.
local function outOfReach(aim: Vector3, tool: Config.ToolDef): boolean
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if character == nil or head == nil or not head:IsA("BasePart") then
		return false
	end
	local origin = head.Position
	local reach = tool.Range * MC.StudsPerMeter
	local ray: Melee.Ray = {
		ox = origin.X,
		oy = origin.Y,
		oz = origin.Z,
		dx = aim.X,
		dy = aim.Y,
		dz = aim.Z,
		range = reach + MC.TooFarMargin,
	}
	local bodies = ZombieRenderController.bodiesNear(origin, ray.range + MC.HitRadius - MC.HitBottom)
	if Melee.pick(ray, bodies, SHAPE, function()
		return false
	end) then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	params.RespectCanCollide = false
	if workspace:Raycast(origin, aim * ray.range, params) then
		return false
	end
	return workspace:Raycast(origin, aim * MC.TooFarDistance, params) ~= nil
end

-- True when the inventory holds ammo the weapon takes.
local function hasAmmo(weapon: Config.RangedDef): boolean
	for _, slot in InventoryController.getSlots() do
		if slot and table.find(weapon.Ammo, slot.id) then
			return true
		end
	end
	return false
end

-- Sends a "use" that is not a swing (placing, eating, drinking, shooting), at most every `seconds`.
-- A free-mouse right click counts as a power attack when this short and still (seconds, pixels).
local POWER_CLICK_SECONDS = 0.25
local POWER_CLICK_PIXELS = 6

-- Ammo a turret takes: "use" with it in the hand loads the turret looked at (PowerService).
local TURRET_AMMO: { [string]: boolean } = {}
for _, turret in Config.Power.Turrets do
	TURRET_AMMO[turret.Ammo] = true
end

local function sendUse(now: number, seconds: number)
	local aim = ToolController.aimDirection()
	if aim then
		nextSwingAt = now + seconds
		useRemote:FireServer(aim)
	end
end

local function trySwing(source: Source, repeated: boolean?, power: boolean?)
	local now = os.clock()
	if now < nextSwingAt or not canSwing(source) then
		return
	end
	local held = InventoryController.getHeld()
	local item = held and Config.Items[held.id]
	if power and held and (Config.Ranged.Weapons[held.id] or not Config.Tools[held.id]) then
		-- Only melee tools (and the fist) have a power attack; RMB aims guns.
		return
	end
	if held and (Config.Build.Blocks[held.id] or (item and (item.Fill or item.Seed or item.Fuel or item.Wiring))
		or TURRET_AMMO[held.id]) then
		-- A block, dirt, a seed, gas, the wire tool or turret ammo in the hand is placed, poured, wired
		-- or loaded, not swung (BuildController shows where a block goes).
		ViewmodelController.act("Place")
		sendUse(now, Config.Build.PlaceCooldown)
		return
	end
	if held and Config.Items[held.id] and Config.Items[held.id].Use then
		ViewmodelController.act("Use")
		sendUse(now, SC.UseSeconds)
		return
	end
	local ranged = held and Config.Ranged.Weapons[held.id]
	if held and ranged then
		if repeated and ranged.Magazine and not ranged.Automatic then return end
		if held.durability == 0 then
			showMessage(Localization.get("ToolBroken", { item = Localization.get(`Item{held.id}`) }))
			nextSwingAt = now + MC.MessageSeconds
			return
		end
		if ranged.Magazine then
			local state = WeaponController.getState()
			if state == nil or state.reloadEnds > workspace:GetServerTimeNow() or state.readyAt > workspace:GetServerTimeNow() then return end
			if state.loaded <= 0 then
				if state.reserve > 0 then WeaponController.reload()
				else showMessage(Localization.get("NoBullets")); nextSwingAt = now + MC.MessageSeconds end
				return
			end
		elseif not hasAmmo(ranged) then
			showMessage(Localization.get("NoAmmo")); nextSwingAt = now + MC.MessageSeconds
			return
		end
		if ranged.DrawSeconds then
			-- A bow: draw first, loose the arrow when the draw ends (if the bow is still in hand).
			nextSwingAt = now + ranged.ShotSeconds
			BowState.start(player)
			local id = held.id
			task.delay(ranged.DrawSeconds, function()
				local still = InventoryController.getHeld()
				local aim = ToolController.aimDirection()
				if still == nil or still.id ~= id or aim == nil then
					BowState.cancel(player)
					return
				end
				BowState.release(player)
				WeaponController.predictShot()
				ViewmodelController.act("Shoot")
				useRemote:FireServer(aim)
			end)
			return
		end
		WeaponController.predictShot()
		ViewmodelController.act("Shoot")
		sendUse(now, ranged.ShotSeconds)
		return
	end
	local toolId = if held and Config.Tools[held.id] then held.id else FIST
	if held and toolId ~= FIST and held.durability == 0 then
		showMessage(Localization.get("ToolBroken", { item = Localization.get(`Item{held.id}`) }))
		nextSwingAt = now + MC.MessageSeconds
		return
	end
	local aim = ToolController.aimDirection()
	if aim == nil then
		return
	end
	if toolId == FIST and ToolController.waterInReach(aim) then
		ViewmodelController.act("Use")
		sendUse(now, SC.UseSeconds)
		return
	end
	if power and Config.Combat.PowerMultiplier[toolId] == nil then
		showMessage(Localization.get("ToolNoPowerAttack"))
		nextSwingAt = now + MC.MessageSeconds
		return
	end
	local scale = if power then Config.Combat.PowerStaminaScale else 1
	local stamina = player:GetAttribute(Net.Attributes.Stamina)
	if typeof(stamina) == "number" and stamina < Config.Tools[toolId].StaminaLoss * scale then
		showMessage(Localization.get("OutOfStamina"))
		nextSwingAt = now + OUT_OF_STAMINA_RETRY
		return
	end
	nextSwingAt = now + Melee.interval(Config.Tools[toolId].AttacksPerMinute, MC.SwingDelay)
		* (if power then Config.Combat.PowerIntervalScale else 1)
	playSwing(player.Character, toolId, power)
	ViewmodelController.swing(toolId, power)
	useRemote:FireServer(aim, power == true)
	if outOfReach(aim, Config.Tools[toolId]) then
		showMessage(Localization.get("ToolTooFar"))
	end
end

local function buildGui(): TextButton
	local gui = Instance.new("ScreenGui")
	gui.Name = "ToolHud"
	gui.ResetOnSpawn = false

	messageLabel = Instance.new("TextLabel")
	messageLabel.Name = "Message"
	messageLabel.AnchorPoint = Vector2.new(0.5, 1)
	messageLabel.Position = UDim2.new(0.5, 0, 1, -MESSAGE_OFFSET)
	messageLabel.Size = UDim2.fromOffset(360, 26)
	messageLabel.BackgroundTransparency = 1
	messageLabel.Font = Enum.Font.GothamBold
	messageLabel.TextSize = 18
	messageLabel.TextColor3 = Color3.fromRGB(255, 120, 100)
	messageLabel.TextStrokeTransparency = 0.5
	messageLabel.Visible = false
	messageLabel.Parent = gui

	local hitButton = Instance.new("TextButton")
	hitButton.Name = "Hit"
	hitButton.AnchorPoint = Vector2.new(1, 1)
	hitButton.Position = UDim2.new(1, HIT_BUTTON_OFFSET.X, 1, HIT_BUTTON_OFFSET.Y)
	hitButton.Size = UDim2.fromOffset(HIT_BUTTON_SIZE, HIT_BUTTON_SIZE)
	hitButton.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
	hitButton.BackgroundTransparency = 0.25
	hitButton.Font = Enum.Font.GothamBold
	hitButton.TextScaled = true
	hitButton.TextColor3 = Color3.new(1, 1, 1)
	hitButton.Text = Localization.get("ToolUse")
	hitButton.Visible = UserInputService.TouchEnabled
	hitButton.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = hitButton

	-- Touch: an Aim toggle above the Hit button while a gun is in the hand.
	aimButton = Instance.new("TextButton")
	aimButton.Name = "Aim"
	aimButton.AnchorPoint = Vector2.new(1, 1)
	aimButton.Position = UDim2.new(1, HIT_BUTTON_OFFSET.X, 1, HIT_BUTTON_OFFSET.Y - HIT_BUTTON_SIZE - AIM_BUTTON_GAP)
	aimButton.Size = UDim2.fromOffset(AIM_BUTTON_SIZE, AIM_BUTTON_SIZE)
	aimButton.BackgroundColor3 = BUTTON_COLOR
	aimButton.BackgroundTransparency = 0.25
	aimButton.Font = Enum.Font.GothamBold
	aimButton.TextScaled = true
	aimButton.TextColor3 = Color3.new(1, 1, 1)
	aimButton.Text = Localization.get("ToolAim")
	aimButton.Visible = false
	aimButton.Parent = gui
	local aimCorner = Instance.new("UICorner")
	aimCorner.CornerRadius = UDim.new(0.5, 0)
	aimCorner.Parent = aimButton

	gui.Parent = player:WaitForChild("PlayerGui")
	return hitButton
end

-- The gun in the hand when it can be aimed, else nil.
local function aimableHeld(): Config.RangedDef?
	local held = InventoryController.getHeld()
	local weapon = held and Config.Ranged.Weapons[held.id]
	return if weapon and weapon.AimSpread then weapon else nil
end

-- Starts or stops aiming: the server tightens the spread, the camera zooms in or back out.
local function setAiming(on: boolean)
	if on and (aimableHeld() == nil or InventoryController.isBackpackOpen() or WeaponController.reloadProgress()) then
		return
	end
	if on == aiming then
		return
	end
	aiming = on
	aimRemote:FireServer(on, if workspace.CurrentCamera then math.asin(workspace.CurrentCamera.CFrame.LookVector.Y) else 0)
	aimButton.BackgroundColor3 = if on then AIM_ON_COLOR else BUTTON_COLOR
	WeaponController.setAiming(on)
end

-- Input Action System: one action for mouse / gamepad, one for the touch button.
local function bindInput(parent: Instance, hitButton: TextButton)
	local context = Instance.new("InputContext")
	context.Name = "ToolInput"

	local function action(name: string, source: Source, configure: (InputBinding) -> ())
		local inputAction = Instance.new("InputAction")
		inputAction.Name = name
		inputAction.Parent = context
		local binding = Instance.new("InputBinding")
		configure(binding)
		binding.Parent = inputAction
		inputAction.Pressed:Connect(function()
			holding = source
			trySwing(source)
		end)
		inputAction.Released:Connect(function()
			if holding == source then
				holding = nil
			end
		end)
		return inputAction
	end

	local pointer = action("UseTool", "Pointer", function(binding)
		binding.KeyCode = Enum.KeyCode.MouseLeftButton
	end)
	local gamepad = Instance.new("InputBinding")
	gamepad.KeyCode = Enum.KeyCode.ButtonR2
	gamepad.Parent = pointer
	action("UseToolTouch", "Touch", function(binding)
		binding.UIButton = hitButton
	end)
	local aim = Instance.new("InputAction")
	aim.Name = "Aim"
	aim.Parent = context
	for _, key in { Enum.KeyCode.MouseRightButton, Enum.KeyCode.ButtonL2 } do
		local binding = Instance.new("InputBinding")
		binding.KeyCode = key
		binding.Parent = aim
	end
	-- Guns aim; melee tools and the fist swing a power attack (7DTD right mouse button). In the free
	-- mouse camera RMB also turns the view, so there only a short click without a drag swings.
	local pressedAt, pressedMouse = 0, Vector2.zero
	aim.Pressed:Connect(function()
		if aimableHeld() then
			setAiming(true)
		elseif CameraController.getMode() == "Free" then
			pressedAt, pressedMouse = os.clock(), UserInputService:GetMouseLocation()
		elseif not InventoryController.isBackpackOpen() then
			trySwing("Pointer", false, true)
		end
	end)
	aim.Released:Connect(function()
		setAiming(false)
		if pressedAt > 0 and CameraController.getMode() == "Free" and not aimableHeld() then
			local click = os.clock() - pressedAt <= POWER_CLICK_SECONDS
				and (UserInputService:GetMouseLocation() - pressedMouse).Magnitude <= POWER_CLICK_PIXELS
			if click and not InventoryController.isBackpackOpen() then
				trySwing("Pointer", false, true)
			end
		end
		pressedAt = 0
	end)
	aimButton.Activated:Connect(function()
		-- Touch: the same button aims a gun, or swings a power attack with a melee tool.
		if aimableHeld() then
			setAiming(not aiming)
		else
			trySwing("Touch", false, true)
		end
	end)
	context.Parent = parent
end

function ToolController.init()
	useRemote = Net.event("UseTool")
	aimRemote = Net.event("AimIntent")
end

function ToolController.start()
	local hitButton = buildGui()
	bindInput(hitButton.Parent :: Instance, hitButton)
	RunService.PreSimulation:Connect(stepSwings)
	RunService.Heartbeat:Connect(function()
		if holding then
			trySwing(holding, true)
		end
		-- Putting the gun away (or opening the backpack) ends aiming.
		local gun = aimableHeld()
		if aiming and (gun == nil or InventoryController.isBackpackOpen() or WeaponController.reloadProgress() or not WeaponController.isAiming()) then
			setAiming(false)
		end
		if aiming and os.clock() >= nextPoseAt and workspace.CurrentCamera then
			nextPoseAt = os.clock() + Config.WeaponHandling.PoseInterval
			aimRemote:FireServer(true, math.asin(workspace.CurrentCamera.CFrame.LookVector.Y))
		end
		local held = InventoryController.getHeld()
		-- An empty hand or a melee tool that has a power attack.
		local meleeId = if held == nil then "Fist" elseif Config.Tools[held.id] then held.id else nil
		local melee = gun == nil and meleeId ~= nil and Config.Combat.PowerMultiplier[meleeId] ~= nil
		aimButton.Visible = UserInputService.TouchEnabled and (gun ~= nil or melee)
		local label = Localization.get(if gun then "ToolAim" else "ToolPower")
		if aimButton.Text ~= label then
			aimButton.Text = label
		end
	end)
	player.CharacterAdded:Connect(function()
		setAiming(false)
	end)
	Net.unreliable("ToolSwing").OnClientEvent:Connect(
		function(
			attacker: Player?,
			toolId: string,
			zombieId: number,
			head: boolean,
			point: unknown,
			normal: unknown,
			color: unknown,
			power: unknown
		)
			local character = if typeof(attacker) == "Instance" then attacker.Character else nil
			if character and attacker ~= player then
				playSwing(character, toolId, power == true)
			end
			local from = if character then character:GetPivot().Position else nil
			if zombieId ~= 0 then
				if attacker == player then WeaponController.hitConfirmed() end
				ZombieRenderController.flinch(zombieId)
				ImpactController.zombie(zombieId, head == true, from)
			elseif typeof(point) == "Vector3" and typeof(normal) == "Vector3" and typeof(color) == "Color3" then
				ImpactController.surface(point, normal, color)
			end
		end
	)
end

return ToolController
