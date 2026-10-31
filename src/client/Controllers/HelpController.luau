--!strict
-- HelpController: a small controls panel in the bottom-right corner for players with a keyboard. H
-- hides and shows it; on a narrow screen it starts hidden so it does not cover the toolbelt. Letter
-- keys are named the way the player's keyboard layout prints them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared.Localization)

-- Layout (pixels).
local MARGIN = 12
local PADDING = 8
local TITLE_HEIGHT = 20
local ROW_HEIGHT = 18
local KEY_WIDTH = 64
local TEXT_WIDTH = 176
-- Screens narrower than this start with the panel hidden.
local MIN_WIDTH = 1180

local PANEL_COLOR = Color3.fromRGB(18, 18, 20)
local KEY_COLOR = Color3.fromRGB(235, 220, 160)
local TEXT_COLOR = Color3.fromRGB(220, 220, 225)

local HelpController = {}

local function keyName(code: Enum.KeyCode): string
	local text = UserInputService:GetStringForKeyCode(code)
	return if text ~= "" then text else code.Name
end

local function label(parent: Instance, text: string, x: number, y: number, width: number, color: Color3): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Position = UDim2.fromOffset(x, y)
	item.Size = UDim2.fromOffset(width, ROW_HEIGHT)
	item.Font = Enum.Font.GothamMedium
	item.TextSize = 14
	item.TextColor3 = color
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.Text = text
	item.Parent = parent
	return item
end

local function build(playerGui: PlayerGui): Frame
	local gui = Instance.new("ScreenGui")
	gui.Name = "Help"
	gui.ResetOnSpawn = false

	local rows = {
		{
			Localization.get("KeyEither", { first = Localization.get("KeyTab"), second = keyName(Enum.KeyCode.I) }),
			"HelpBackpack",
		},
		{ Localization.get("KeyLeftMouse"), "HelpHit" },
		{ Localization.get("KeyRightMouse"), "HelpAim" },
		{ keyName(Enum.KeyCode.R), "WeaponReload" },
		{ keyName(Enum.KeyCode.E), "HelpInteract" },
		{ keyName(Enum.KeyCode.G), "HelpDrop" },
		{ Localization.get("KeyShift"), "HelpRun" },
		{ Localization.get("KeyDigits"), "HelpToolbelt" },
		{ keyName(Enum.KeyCode.V), "HelpCamera" },
		{ Localization.get("KeyAlt"), "HelpCursor" },
		{ keyName(Enum.KeyCode.H), "HelpHide" },
	}

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -MARGIN, 1, -MARGIN)
	panel.Size = UDim2.fromOffset(PADDING * 2 + KEY_WIDTH + TEXT_WIDTH, PADDING * 2 + TITLE_HEIGHT + ROW_HEIGHT * #rows)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.35
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel

	local title = label(panel, Localization.get("HelpTitle"), PADDING, PADDING, KEY_WIDTH + TEXT_WIDTH, TEXT_COLOR)
	title.Font = Enum.Font.GothamBold
	for index, row in rows do
		local y = PADDING + TITLE_HEIGHT + ROW_HEIGHT * (index - 1)
		local key = label(panel, row[1], PADDING, y, KEY_WIDTH, KEY_COLOR)
		key.Font = Enum.Font.GothamBold
		label(panel, Localization.get(row[2]), PADDING + KEY_WIDTH, y, TEXT_WIDTH, TEXT_COLOR)
	end

	local context = Instance.new("InputContext")
	context.Name = "HelpInput"
	local toggle = Instance.new("InputAction")
	toggle.Name = "ToggleHelp"
	toggle.Parent = context
	local binding = Instance.new("InputBinding")
	binding.KeyCode = Enum.KeyCode.H
	binding.Parent = toggle
	toggle.Pressed:Connect(function()
		panel.Visible = not panel.Visible
	end)
	context.Parent = gui

	local camera = workspace.CurrentCamera
	panel.Visible = camera == nil or camera.ViewportSize.X >= MIN_WIDTH
	gui.Parent = playerGui
	return panel
end

function HelpController.init() end

function HelpController.start()
	if not UserInputService.KeyboardEnabled then
		return
	end
	build(Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui)
end

return HelpController
