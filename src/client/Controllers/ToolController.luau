--!strict
-- ToolController: swings the held tool, or the fist; with a block in the hand the same input places
-- it (BuildService), with food, a drink or medicine it uses it, and a bare hand aimed at water drinks
-- (SurvivalService). Left mouse, gamepad R2, or the Hit button on touch; holding keeps swinging at
-- the tool's rate. A swing needs the tool's stamina. The server decides what is hit; this client
-- only sends its aim and animates. Its own swing plays at once, other players' swings and the
-- zombie stagger come from the server's ToolSwing broadcast.
--
-- The swing is a procedural rotation of the right shoulder joint (R15 RightShoulder or R6
-- "Right Shoulder") layered on the walk animation through Motor6D.C0, restored when it ends.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Localization = require(Shared.Localization)
local Melee = require(Shared.Melee)
local Net = require(Shared.Net)

local InventoryController = require(script.Parent.InventoryController)
local ZombieRenderController = require(script.Parent.ZombieRenderController)

local MC = Config.Melee
local SC = Config.Survival
local FIST = "Fist"
-- After an "out of stamina" refusal, the next try waits this long (stamina comes back meanwhile).
local OUT_OF_STAMINA_RETRY = 0.3

-- Shoulder angles about the joint's X axis (positive raises the arm forward): wind up overhead,
-- chop down past the horizontal, then return. Shares are fractions of the swing duration.
local RAISE_ANGLE = math.rad(150)
local STRIKE_ANGLE = math.rad(35)
local WINDUP_SHARE = 0.4
local STRIKE_SHARE = 0.65
-- A swing lasts this share of the tool's interval, capped by Config.Melee.SwingMaxSeconds.
local SWING_SHARE = 0.9

local HIT_BUTTON_SIZE = 84
local HIT_BUTTON_OFFSET = Vector2.new(-24, -190)
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
type Swing = { startedAt: number, duration: number }

local ToolController = {}

local player = Players.LocalPlayer
local useRemote: RemoteEvent
local swings: { [Motor6D]: Swing } = {}
-- Each shoulder's C0 before any swing touched it (weak: characters come and go).
local baseC0: { [Motor6D]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local holding: Source? = nil
local nextSwingAt = 0
local messageLabel: TextLabel
local messageToken = 0

local function shoulderOf(character: Model): Motor6D?
	local upperArm = character:FindFirstChild("RightUpperArm")
	local motor = upperArm and upperArm:FindFirstChild("RightShoulder")
	if motor == nil then
		local torso = character:FindFirstChild("Torso")
		motor = torso and torso:FindFirstChild("Right Shoulder")
	end
	return if motor and motor:IsA("Motor6D") then motor else nil
end

local function playSwing(character: Model?, toolId: string)
	local motor = character and shoulderOf(character)
	if motor == nil then
		return
	end
	if baseC0[motor] == nil then
		baseC0[motor] = motor.C0
	end
	local tool = Config.Tools[toolId] or Config.Tools[FIST]
	local interval = Melee.interval(tool.AttacksPerMinute, MC.SwingDelay)
	local duration = math.min(MC.SwingMaxSeconds, interval * SWING_SHARE)
	swings[motor] = { startedAt = os.clock(), duration = duration }
end

local function swingAngle(progress: number): number
	if progress < WINDUP_SHARE then
		local a = progress / WINDUP_SHARE
		return RAISE_ANGLE * (1 - (1 - a) * (1 - a))
	elseif progress < STRIKE_SHARE then
		local a = (progress - WINDUP_SHARE) / (STRIKE_SHARE - WINDUP_SHARE)
		return RAISE_ANGLE + (STRIKE_ANGLE - RAISE_ANGLE) * a * a
	end
	local a = (progress - STRIKE_SHARE) / (1 - STRIKE_SHARE)
	return STRIKE_ANGLE * (1 - a)
end

local function onRender()
	local now = os.clock()
	for motor, swing in swings do
		local base = baseC0[motor]
		if base == nil or motor.Parent == nil then
			swings[motor] = nil
			continue
		end
		local progress = (now - swing.startedAt) / swing.duration
		if progress >= 1 then
			motor.C0 = base
			swings[motor] = nil
		else
			motor.C0 = base * CFrame.Angles(swingAngle(progress), 0, 0)
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

-- Sends a "use" that is not a swing (placing, eating, drinking), at most every `seconds`.
-- True when the inventory holds ammo the weapon takes.
local function hasAmmo(weapon: Config.RangedDef): boolean
	for _, slot in InventoryController.getSlots() do
		if slot and table.find(weapon.Ammo, slot.id) then
			return true
		end
	end
	return false
end

local function sendUse(now: number, seconds: number)
	local aim = ToolController.aimDirection()
	if aim then
		nextSwingAt = now + seconds
		useRemote:FireServer(aim)
	end
end

local function trySwing(source: Source)
	local now = os.clock()
	if now < nextSwingAt or not canSwing(source) then
		return
	end
	local held = InventoryController.getHeld()
	local item = held and Config.Items[held.id]
	if held and (Config.Build.Blocks[held.id] or (item and (item.Fill or item.Seed))) then
		-- A block, dirt or a seed in the hand is placed, not swung (BuildController shows where a block
		-- goes).
		sendUse(now, Config.Build.PlaceCooldown)
		return
	end
	if held and Config.Items[held.id] and Config.Items[held.id].Use then
		sendUse(now, SC.UseSeconds)
		return
	end
	local ranged = held and Config.Ranged.Weapons[held.id]
	if held and ranged then
		-- A bow shoots (RangedService flies the arrow; ArrowController draws it).
		if held.durability == 0 then
			showMessage(Localization.get("ToolBroken", { item = Localization.get(`Item{held.id}`) }))
			nextSwingAt = now + MC.MessageSeconds
		elseif not hasAmmo(ranged) then
			showMessage(Localization.get("NoAmmo"))
			nextSwingAt = now + MC.MessageSeconds
		else
			sendUse(now, ranged.ShotSeconds)
		end
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
		sendUse(now, SC.UseSeconds)
		return
	end
	local stamina = player:GetAttribute(Net.Attributes.Stamina)
	if typeof(stamina) == "number" and stamina < Config.Tools[toolId].StaminaLoss then
		showMessage(Localization.get("OutOfStamina"))
		nextSwingAt = now + OUT_OF_STAMINA_RETRY
		return
	end
	nextSwingAt = now + Melee.interval(Config.Tools[toolId].AttacksPerMinute, MC.SwingDelay)
	playSwing(player.Character, toolId)
	useRemote:FireServer(aim)
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

	gui.Parent = player:WaitForChild("PlayerGui")
	return hitButton
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
	context.Parent = parent
end

function ToolController.init()
	useRemote = Net.event("UseTool")
end

function ToolController.start()
	local hitButton = buildGui()
	bindInput(hitButton.Parent :: Instance, hitButton)
	RunService.PreRender:Connect(onRender)
	RunService.Heartbeat:Connect(function()
		if holding then
			trySwing(holding)
		end
	end)
	Net.unreliable("ToolSwing").OnClientEvent:Connect(
		function(attacker: Player?, toolId: string, zombieId: number, _head: boolean)
			if typeof(attacker) == "Instance" and attacker ~= player then
				playSwing(attacker.Character, toolId)
			end
			if zombieId ~= 0 then
				ZombieRenderController.flinch(zombieId)
			end
		end
	)
end

return ToolController
