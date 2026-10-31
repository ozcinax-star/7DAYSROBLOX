--!strict
-- GraphicsController: the client graphics presets (PLAN: Low / Medium / High on top of Roblox's own
-- quality level; Auto picks one for the device). A "Graphics" button under the clock opens a small
-- panel, and a choice applies at once, to this client only: zombie draw, detail and animation
-- distances and corpse time (ZombieRenderController), sun shadows, bloom and sun rays, and how far
-- lamp light reaches. Fog, the atmosphere and the night tint stay as they are, so no preset sees
-- further at night. The choice lasts for the session (nothing is saved yet).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Graphics = require(Shared.Graphics)
local Localization = require(Shared.Localization)

local ZombieRenderController = require(script.Parent.ZombieRenderController)

local GC = Config.Graphics
local AUTO = "Auto"
-- Layout (pixels): right-aligned under the clock and horde labels (DayNightController).
local MARGIN = 12
local TOP = 64
local BUTTON_WIDTH = 170
local BUTTON_HEIGHT = 26
local PANEL_WIDTH = 260
local PADDING = 10
local TITLE_HEIGHT = 22
local OPTION_HEIGHT = 30
local OPTION_GAP = 4
local HINT_HEIGHT = 40

local PANEL_COLOR = Color3.fromRGB(18, 18, 20)
local BUTTON_COLOR = Color3.fromRGB(44, 44, 48)
local SELECTED_COLOR = Color3.fromRGB(64, 104, 64)
local TEXT_COLOR = Color3.new(1, 1, 1)
local MUTED_COLOR = Color3.fromRGB(170, 170, 176)

local GraphicsController = {}

-- AUTO or a preset name.
local choice = AUTO
local autoPreset = "Medium"
local lampScale = 1
local toggleButton: TextButton
local panel: Frame
local hint: TextLabel
local options: { [string]: TextButton } = {}

local function presetName(): string
	return if choice == AUTO then autoPreset else choice
end

local function scaleLight(instance: Instance)
	if instance:IsA("PointLight") then
		instance.Range = Config.Power.LightRange * lampScale
	end
end

local function setEffect(className: string, enabled: boolean)
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") and child.ClassName == className then
			child.Enabled = enabled
		end
	end
end

local function refresh()
	local name = presetName()
	toggleButton.Text = Localization.get("GraphicsButton", { preset = Localization.get(`Graphics{name}`) })
	options[AUTO].Text = Localization.get("GraphicsAuto", { preset = Localization.get(`Graphics{autoPreset}`) })
	for key, button in options do
		button.BackgroundColor3 = if key == choice then SELECTED_COLOR else BUTTON_COLOR
	end
	local text = Localization.get(`Graphics{name}Hint`)
	hint.Text = if choice == AUTO then `{Localization.get("GraphicsAutoHint")} {text}` else text
end

local function apply()
	local preset = GC.Presets[presetName()]
	ZombieRenderController.setQuality(
		preset.ZombieDistance,
		preset.DetailDistance,
		preset.AnimateDistance,
		preset.CorpseSeconds
	)
	Lighting.GlobalShadows = preset.Shadows
	setEffect("BloomEffect", preset.Bloom)
	setEffect("SunRaysEffect", preset.SunRays)
	lampScale = preset.LampLightScale
	local structures = Workspace:FindFirstChild(Config.Build.FolderName)
	if structures then
		for _, descendant in structures:GetDescendants() do
			scaleLight(descendant)
		end
	end
	refresh()
end

local function detectAuto()
	local saved = UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	local quality = if saved == 0 then nil else saved
	autoPreset = Graphics.autoPreset(UserInputService.TouchEnabled, UserInputService.KeyboardEnabled, quality)
end

local function button(name: string, parent: Instance): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = true
	b.BackgroundColor3 = BUTTON_COLOR
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 15
	b.TextColor3 = TEXT_COLOR
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = b
	b.Parent = parent
	return b
end

local function buildGui(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Graphics"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false

	toggleButton = button("Toggle", gui)
	toggleButton.AnchorPoint = Vector2.new(1, 0)
	toggleButton.Position = UDim2.new(1, -MARGIN, 0, TOP)
	toggleButton.Size = UDim2.fromOffset(BUTTON_WIDTH, BUTTON_HEIGHT)
	toggleButton.BackgroundTransparency = 0.35
	toggleButton.TextSize = 14

	local keys = { AUTO }
	for _, name in GC.Order do
		table.insert(keys, name)
	end
	local height = PADDING * 3 + TITLE_HEIGHT + #keys * (OPTION_HEIGHT + OPTION_GAP) + HINT_HEIGHT
	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -MARGIN, 0, TOP + BUTTON_HEIGHT + OPTION_GAP)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, height)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel
	panel.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromOffset(PADDING, PADDING)
	title.Size = UDim2.new(1, -PADDING * 2, 0, TITLE_HEIGHT)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 17
	title.TextColor3 = TEXT_COLOR
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = Localization.get("GraphicsTitle")
	title.Parent = panel

	for index, key in keys do
		local option = button(key, panel)
		local y = PADDING * 2 + TITLE_HEIGHT + (index - 1) * (OPTION_HEIGHT + OPTION_GAP)
		option.Position = UDim2.fromOffset(PADDING, y)
		option.Size = UDim2.new(1, -PADDING * 2, 0, OPTION_HEIGHT)
		option.Text = Localization.get(`Graphics{key}`)
		option.Activated:Connect(function()
			choice = key
			apply()
		end)
		options[key] = option
	end

	hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.new(0, PADDING, 1, -PADDING)
	hint.Size = UDim2.new(1, -PADDING * 2, 0, HINT_HEIGHT)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 14
	hint.TextColor3 = MUTED_COLOR
	hint.TextWrapped = true
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextYAlignment = Enum.TextYAlignment.Top
	hint.Parent = panel

	toggleButton.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	gui.Parent = playerGui
end

-- The preset in use ("Low", "Medium" or "High").
function GraphicsController.getPreset(): string
	return presetName()
end

function GraphicsController.init() end

function GraphicsController.start()
	local player = Players.LocalPlayer
	buildGui(player:WaitForChild("PlayerGui") :: PlayerGui)
	detectAuto()
	apply()
	UserSettings():GetService("UserGameSettings"):GetPropertyChangedSignal("SavedQualityLevel"):Connect(function()
		detectAuto()
		if choice == AUTO then
			apply()
		end
	end)
	-- Lamps placed or streamed in later get the preset's light reach too.
	local structures = Workspace:WaitForChild(Config.Build.FolderName)
	structures.DescendantAdded:Connect(scaleLight)
	for _, descendant in structures:GetDescendants() do
		scaleLight(descendant)
	end
end

return GraphicsController
