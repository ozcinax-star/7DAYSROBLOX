--!strict
-- SurvivalController: the survival HUD and the sprint input. Four bars (health, stamina, food, water)
-- sit at the bottom left beside the toolbelt, above it when the screen is too narrow, and at the top
-- centre on touch screens (the thumbstick owns the bottom left). The stamina bar shows the share that
-- hunger and thirst block; food and water labels turn orange and red with their stage. Values come
-- from the Player attributes SurvivalService sets; health from the Humanoid.
--
-- Sprint: hold Left Shift, or toggle with gamepad L3 or the Run button on touch. The server decides
-- whether the character actually sprints. A bare hand aimed at water shows the drink hint.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

local InventoryController = require(script.Parent.InventoryController)
local ToolController = require(script.Parent.ToolController)

local SC = Config.Survival
local A = Net.Attributes

local BAR_WIDTH = 220
local BAR_HEIGHT = 18
local BAR_GAP = 4
local MARGIN = 16
local BOTTOM_OFFSET = 10
local TOP_OFFSET = 8
local TEXT_SIZE = 13
local HINT_OFFSET = 150
local RUN_BUTTON_SIZE = 64
-- Left of the Hit button (ToolController: 84 wide, 24 from the right edge, 190 from the bottom).
local RUN_BUTTON_POSITION = UDim2.new(1, -24 - 84 - 14, 1, -190)

local BACK_COLOR = Color3.fromRGB(28, 28, 30)
local BLOCKED_COLOR = Color3.fromRGB(70, 44, 44)
local TEXT_COLOR = Color3.new(1, 1, 1)
local STAGE_COLORS = {
	[0] = TEXT_COLOR,
	[1] = Color3.fromRGB(255, 170, 70),
	[2] = Color3.fromRGB(255, 130, 50),
	[3] = Color3.fromRGB(255, 80, 70),
}
local RUN_OFF_COLOR = Color3.fromRGB(28, 28, 30)
local RUN_ON_COLOR = Color3.fromRGB(150, 120, 40)

type Bar = { fill: Frame, blocked: Frame?, name: TextLabel, value: TextLabel }

local SurvivalController = {}

local player = Players.LocalPlayer
local sprintRemote: RemoteEvent
local panel: Frame
local hint: TextLabel
local runButton: TextButton
local bars: { [string]: Bar } = {}
local healthConnection: RBXScriptConnection? = nil
-- Sprint wanted from the held key and from the toggles, and what the server was last told.
local sprintHeld = false
local sprintToggled = false
local sentSprint = false

local function makeBar(order: number, key: string, color: Color3, withBlocked: boolean): Bar
	local back = Instance.new("Frame")
	back.Name = key
	back.LayoutOrder = order
	back.Size = UDim2.new(1, 0, 0, BAR_HEIGHT)
	back.BackgroundColor3 = BACK_COLOR
	back.BackgroundTransparency = 0.25
	back.BorderSizePixel = 0
	back.ClipsDescendants = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = back

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back

	local blocked: Frame? = nil
	if withBlocked then
		local frame = Instance.new("Frame")
		frame.Name = "Blocked"
		frame.AnchorPoint = Vector2.new(1, 0)
		frame.Position = UDim2.fromScale(1, 0)
		frame.Size = UDim2.fromScale(0, 1)
		frame.BackgroundColor3 = BLOCKED_COLOR
		frame.BorderSizePixel = 0
		frame.Parent = back
		blocked = frame
	end

	local function label(name: string, alignment: Enum.TextXAlignment): TextLabel
		local text = Instance.new("TextLabel")
		text.Name = name
		text.Position = UDim2.fromOffset(6, 0)
		text.Size = UDim2.new(1, -12, 1, 0)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBold
		text.TextSize = TEXT_SIZE
		text.TextColor3 = TEXT_COLOR
		text.TextStrokeTransparency = 0.6
		text.TextXAlignment = alignment
		text.ZIndex = 2
		text.Parent = back
		return text
	end
	local name = label("Name", Enum.TextXAlignment.Left)
	name.Text = Localization.get(`Vital{key}`)
	local value = label("Value", Enum.TextXAlignment.Right)
	back.Parent = panel
	return { fill = fill, blocked = blocked, name = name, value = value }
end

local function setBar(bar: Bar, current: number, max: number)
	bar.fill.Size = UDim2.fromScale(math.clamp(current / max, 0, 1), 1)
	bar.value.Text = tostring(math.floor(current + 0.5))
end

local function number(name: string, default: number): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

local function refreshStats()
	local stamina = bars.Stamina
	setBar(stamina, number(A.Stamina, SC.MaxStamina), SC.MaxStamina)
	if stamina.blocked then
		local cap = number(A.StaminaCap, SC.MaxStamina)
		stamina.blocked.Size = UDim2.fromScale(math.clamp(1 - cap / SC.MaxStamina, 0, 1), 1)
	end
	setBar(bars.Food, number(A.Food, SC.MaxFood), SC.MaxFood)
	setBar(bars.Water, number(A.Water, SC.MaxWater), SC.MaxWater)
	bars.Food.name.TextColor3 = STAGE_COLORS[number(A.Hunger, 0)] or TEXT_COLOR
	bars.Water.name.TextColor3 = STAGE_COLORS[number(A.Thirst, 0)] or TEXT_COLOR
end

local function watchHealth(character: Model)
	if healthConnection then
		healthConnection:Disconnect()
		healthConnection = nil
	end
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local function update()
		setBar(bars.Health, humanoid.Health, humanoid.MaxHealth)
	end
	healthConnection = humanoid.HealthChanged:Connect(update)
	update()
end

local function layout()
	if UserInputService.TouchEnabled then
		panel.AnchorPoint = Vector2.new(0.5, 0)
		panel.Position = UDim2.new(0.5, 0, 0, TOP_OFFSET)
		return
	end
	panel.AnchorPoint = Vector2.new(0, 1)
	local toolbelt = InventoryController.getToolbelt()
	local beside = toolbelt == nil or toolbelt.AbsolutePosition.X >= BAR_WIDTH + MARGIN * 2
	local bottom = if beside or toolbelt == nil
		then BOTTOM_OFFSET
		else BOTTOM_OFFSET + toolbelt.AbsoluteSize.Y + BAR_GAP * 2
	panel.Position = UDim2.new(0, MARGIN, 1, -bottom)
end

local function sendSprint(force: boolean?)
	local wants = sprintHeld or sprintToggled
	runButton.BackgroundColor3 = if wants then RUN_ON_COLOR else RUN_OFF_COLOR
	if force or wants ~= sentSprint then
		sentSprint = wants
		sprintRemote:FireServer(wants)
	end
end

local function buildGui(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "SurvivalHud"
	gui.ResetOnSpawn = false

	panel = Instance.new("Frame")
	panel.Name = "Vitals"
	panel.Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT * 4 + BAR_GAP * 3)
	panel.BackgroundTransparency = 1
	panel.Parent = gui
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, BAR_GAP)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel
	bars.Health = makeBar(1, "Health", Color3.fromRGB(180, 45, 45), false)
	bars.Stamina = makeBar(2, "Stamina", Color3.fromRGB(205, 175, 55), true)
	bars.Food = makeBar(3, "Food", Color3.fromRGB(190, 120, 55), false)
	bars.Water = makeBar(4, "Water", Color3.fromRGB(60, 130, 210), false)

	hint = Instance.new("TextLabel")
	hint.Name = "DrinkHint"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -HINT_OFFSET)
	hint.Size = UDim2.fromOffset(240, 24)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.GothamBold
	hint.TextSize = 16
	hint.TextColor3 = Color3.fromRGB(170, 210, 255)
	hint.TextStrokeTransparency = 0.5
	hint.Text = Localization.get("DrinkHint")
	hint.Visible = false
	hint.Parent = gui

	runButton = Instance.new("TextButton")
	runButton.Name = "Run"
	runButton.AnchorPoint = Vector2.new(1, 1)
	runButton.Position = RUN_BUTTON_POSITION
	runButton.Size = UDim2.fromOffset(RUN_BUTTON_SIZE, RUN_BUTTON_SIZE)
	runButton.BackgroundColor3 = RUN_OFF_COLOR
	runButton.BackgroundTransparency = 0.25
	runButton.Font = Enum.Font.GothamBold
	runButton.TextScaled = true
	runButton.TextColor3 = TEXT_COLOR
	runButton.Text = Localization.get("SprintButton")
	runButton.Visible = UserInputService.TouchEnabled
	runButton.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = runButton

	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

-- Input Action System: Left Shift is held, gamepad L3 and the touch button toggle.
local function bindInput(parent: Instance)
	local context = Instance.new("InputContext")
	context.Name = "SurvivalInput"

	local hold = Instance.new("InputAction")
	hold.Name = "Sprint"
	hold.Parent = context
	local shift = Instance.new("InputBinding")
	shift.KeyCode = Enum.KeyCode.LeftShift
	shift.Parent = hold
	hold.Pressed:Connect(function()
		sprintHeld = true
		sendSprint()
	end)
	hold.Released:Connect(function()
		sprintHeld = false
		sendSprint()
	end)

	local toggle = Instance.new("InputAction")
	toggle.Name = "SprintToggle"
	toggle.Parent = context
	local stick = Instance.new("InputBinding")
	stick.KeyCode = Enum.KeyCode.ButtonL3
	stick.Parent = toggle
	local button = Instance.new("InputBinding")
	button.UIButton = runButton
	button.Parent = toggle
	toggle.Pressed:Connect(function()
		sprintToggled = not sprintToggled
		sendSprint()
	end)
	context.Parent = parent
end

local function updateHint()
	local held = InventoryController.getHeld()
	local item = held and Config.Items[held.id]
	local bare = held == nil
		or not (
			Config.Tools[held.id]
			or Config.Ranged.Weapons[held.id]
			or Config.Build.Blocks[held.id]
			or (item and (item.Use or item.Fill))
		)
	local aim = if bare and not InventoryController.isBackpackOpen() then ToolController.aimDirection() else nil
	hint.Visible = aim ~= nil and ToolController.waterInReach(aim)
end

function SurvivalController.init()
	sprintRemote = Net.event("SprintIntent")
end

function SurvivalController.start()
	local gui = buildGui()
	bindInput(gui)
	for _, name in { A.Stamina, A.StaminaCap, A.Food, A.Water, A.Hunger, A.Thirst } do
		player:GetAttributeChangedSignal(name):Connect(refreshStats)
	end
	refreshStats()
	player.CharacterAdded:Connect(function(character)
		-- A new character walks: the toggle is dropped and the server hears the intent again.
		sprintToggled = false
		sendSprint(true)
		watchHealth(character)
	end)
	if player.Character then
		task.spawn(watchHealth, player.Character)
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
	task.defer(function()
		local toolbelt = InventoryController.getToolbelt()
		if toolbelt then
			toolbelt:GetPropertyChangedSignal("AbsolutePosition"):Connect(layout)
		end
		layout()
	end)
	layout()
	RunService.PreRender:Connect(updateHint)
end

return SurvivalController
