--!strict
-- DebugOverlayController: FPS, server tick time and zombie counts, plus stress-test buttons for
-- players the server marked as DebugAllowed. The server validates every command again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

local ZombieRenderController = require(script.Parent.ZombieRenderController)

-- Overlay layout (pixels). Buttons are sized for touch.
local PANEL_WIDTH = 220
local LINE_HEIGHT = 20
local BUTTON_HEIGHT = 40
local PADDING = 6
local TEXT_SIZE = 16
local PANEL_TRANSPARENCY = 0.4

local DebugOverlayController = {}

local labels: { [string]: TextLabel } = {}

local function makeLabel(parent: Instance, order: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, LINE_HEIGHT)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = TEXT_SIZE
	label.Font = Enum.Font.GothamMedium
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.LayoutOrder = order
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, order: number, text: string, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
	button.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = TEXT_SIZE
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.LayoutOrder = order
	button.Parent = parent
	button.Activated:Connect(onClick)
	return button
end

local function buildGui(): (Frame, Frame)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "DebugOverlay"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Position = UDim2.fromOffset(PADDING, PADDING)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = Color3.new(0, 0, 0)
	panel.BackgroundTransparency = PANEL_TRANSPARENCY
	panel.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, PADDING)
	padding.PaddingRight = UDim.new(0, PADDING)
	padding.PaddingTop = UDim.new(0, PADDING)
	padding.PaddingBottom = UDim.new(0, PADDING)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, PADDING / 2)
	layout.Parent = panel

	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.BackgroundTransparency = 1
	buttons.Size = UDim2.new(1, 0, 0, 0)
	buttons.AutomaticSize = Enum.AutomaticSize.Y
	buttons.LayoutOrder = 100
	buttons.Visible = false
	buttons.Parent = panel
	local buttonLayout = layout:Clone()
	buttonLayout.Parent = buttons

	return panel, buttons
end

function DebugOverlayController.init() end

function DebugOverlayController.start()
	local panel, buttons = buildGui()
	labels.Fps = makeLabel(panel, 1)
	labels.Tick = makeLabel(panel, 2)
	labels.Zombies = makeLabel(panel, 3)
	labels.Rendered = makeLabel(panel, 4)

	local debugRemote = Net.event("DebugCommand")
	local order = 0
	for _, count in Config.Debug.StressCounts do
		order += 1
		makeButton(buttons, order, Localization.get("DebugSpawn", { value = count }), function()
			debugRemote:FireServer("Spawn", count)
		end)
	end
	makeButton(buttons, order + 1, Localization.get("DebugNoise"), function()
		debugRemote:FireServer("Noise")
	end)
	makeButton(buttons, order + 2, Localization.get("DebugGodMode"), function()
		debugRemote:FireServer("GodMode")
	end)
	makeButton(buttons, order + 3, Localization.get("DebugClear"), function()
		debugRemote:FireServer("Clear")
	end)

	local player = Players.LocalPlayer
	local function refreshAllowed()
		buttons.Visible = player:GetAttribute(Net.Attributes.DebugAllowed) == true
	end
	player:GetAttributeChangedSignal(Net.Attributes.DebugAllowed):Connect(refreshAllowed)
	refreshAllowed()

	local frames = 0
	RunService.PreRender:Connect(function()
		frames += 1
	end)

	local attributes = Net.Attributes
	while true do
		local started = os.clock()
		task.wait(Config.Debug.StatsInterval)
		local fps = frames / (os.clock() - started)
		frames = 0

		local tickMs = ReplicatedStorage:GetAttribute(attributes.TickMs) or 0
		local tickMaxMs = ReplicatedStorage:GetAttribute(attributes.TickMaxMs) or 0
		local alive = ReplicatedStorage:GetAttribute(attributes.ZombieCount) or 0
		local queued = ReplicatedStorage:GetAttribute(attributes.ZombieQueued) or 0

		labels.Fps.Text = Localization.get("DebugFps", { value = math.round(fps) })
		labels.Tick.Text = Localization.get("DebugServerTick", {
			value = string.format("%.2f / %.2f", tickMs, tickMaxMs),
		})
		labels.Zombies.Text = Localization.get("DebugZombieCount", { value = `{alive} (+{queued})` })
		labels.Rendered.Text = Localization.get("DebugRendered", {
			value = `{ZombieRenderController.getRenderedCount()} / {ZombieRenderController.getViewCount()}`,
		})
	end
end

return DebugOverlayController
