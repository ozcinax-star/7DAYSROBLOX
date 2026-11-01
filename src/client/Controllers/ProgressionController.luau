--!strict
-- Level and experience on the HUD, and the perk panel (K, or the Perks button on touch). The server owns
-- the numbers (ProgressionService); a "+" only asks it to spend a point.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

local SoundController = require(script.Parent.SoundController)

local PC = Config.Progression
local player = Players.LocalPlayer
local BACK = Color3.fromRGB(20, 24, 23)
local FILL = Color3.fromRGB(209, 177, 105)
local MUTED = Color3.fromRGB(150, 150, 140)

local ProgressionController = {}

type Row = { tier: TextLabel, need: TextLabel, button: TextButton }

local levelLabel: TextLabel
local xpFill: Frame
local panel: Frame
local pointsLabel: TextLabel
local rows: { [string]: Row } = {}
local upgradeRemote: RemoteEvent
local saved: any = nil

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2, textSize: number): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size, t.Position = size, pos
	t.Font, t.TextSize, t.TextColor3 = Enum.Font.GothamBold, textSize, Color3.new(1, 1, 1)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextWrapped = true
	t.Text = text
	t.Parent = parent
	return t
end

local function refresh(xpToNext: number?)
	if saved == nil then
		return
	end
	levelLabel.Text = Localization.get("HudLevel", { level = saved.Level })
	local need = xpToNext or 1
	xpFill.Size = UDim2.fromScale(math.clamp(saved.Xp / math.max(1, need), 0, 1), 1)
	pointsLabel.Text = Localization.get("PerksPoints", { points = saved.Points })
	for id, row in rows do
		local def = PC.Perks[id]
		local tier = saved.Perks[id] or 0
		local max = #def.TierLevels
		row.tier.Text = Localization.get("PerkTier", { tier = tier, max = max })
		local nextLevel = def.TierLevels[tier + 1]
		if tier >= max then
			row.need.Text = Localization.get("PerkMaxed")
		elseif nextLevel and saved.Level < nextLevel then
			row.need.Text = Localization.get("PerkNeedsLevel", { level = nextLevel })
		else
			row.need.Text = ""
		end
		local can = tier < max and saved.Points > 0 and nextLevel ~= nil and saved.Level >= nextLevel
		row.button.Visible = can
	end
end

local function toggle()
	if UserInputService:GetFocusedTextBox() then
		return
	end
	panel.Visible = not panel.Visible
	SoundController.play("UIClick")
end

local function buildGui()
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset = "Progression", false, true
	gui.DisplayOrder = 4

	-- Level and experience: a slim bar above the toolbelt.
	local bar = Instance.new("Frame")
	bar.Name = "Experience"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position, bar.Size = UDim2.new(0.5, 0, 1, -82), UDim2.fromOffset(360, 6)
	bar.BackgroundColor3, bar.BackgroundTransparency, bar.BorderSizePixel = BACK, 0.25, 0
	bar.Parent = gui
	xpFill = Instance.new("Frame")
	xpFill.BackgroundColor3, xpFill.BorderSizePixel = FILL, 0
	xpFill.Size = UDim2.fromScale(0, 1)
	xpFill.Parent = bar
	levelLabel = label(bar, "", UDim2.fromOffset(200, 16), UDim2.fromOffset(0, -18), 13)
	local hint = label(bar, Localization.get("PerksOpenHint"), UDim2.fromOffset(150, 16), UDim2.new(1, -150, 0, -18), 12)
	hint.TextXAlignment = Enum.TextXAlignment.Right
	hint.TextColor3 = MUTED

	panel = Instance.new("Frame")
	panel.Name = "Perks"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position, panel.Size = UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(420, 92 + 70 * #PC.PerkOrder)
	panel.BackgroundColor3, panel.BackgroundTransparency = BACK, 0.08
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel
	label(panel, Localization.get("PerksTitle"), UDim2.new(1, -24, 0, 26), UDim2.fromOffset(14, 10), 20)
	pointsLabel = label(panel, "", UDim2.new(1, -24, 0, 20), UDim2.fromOffset(14, 40), 14)
	pointsLabel.TextColor3 = FILL
	for index, id in PC.PerkOrder do
		local top = 70 + (index - 1) * 70
		label(panel, Localization.get(`Perk{id}`), UDim2.fromOffset(200, 22), UDim2.fromOffset(14, top), 17)
		local desc = label(panel, Localization.get(`Perk{id}Desc`), UDim2.fromOffset(300, 34), UDim2.fromOffset(14, top + 22), 12)
		desc.TextColor3 = MUTED
		local tier = label(panel, "", UDim2.fromOffset(60, 22), UDim2.new(1, -120, 0, top), 15)
		local need = label(panel, "", UDim2.fromOffset(110, 30), UDim2.new(1, -120, 0, top + 22), 11)
		need.TextColor3 = MUTED
		local button = Instance.new("TextButton")
		button.Name = id
		button.Size, button.Position = UDim2.fromOffset(40, 40), UDim2.new(1, -54, 0, top + 4)
		button.BackgroundColor3, button.TextColor3 = FILL, BACK
		button.Font, button.TextSize, button.Text = Enum.Font.GothamBold, 24, Localization.get("PerkUpgrade")
		button.Visible = false
		button.Parent = panel
		button.Activated:Connect(function()
			upgradeRemote:FireServer(id)
			SoundController.play("UIClick")
		end)
		rows[id] = { tier = tier, need = need, button = button }
	end

	-- K opens and closes the panel; a button does it on touch screens.
	local context = Instance.new("InputContext")
	context.Name = "ProgressionInput"
	local action = Instance.new("InputAction")
	action.Name = "TogglePerks"
	action.Parent = context
	local binding = Instance.new("InputBinding")
	binding.KeyCode = Enum.KeyCode.K
	binding.Parent = action
	action.Pressed:Connect(toggle)
	context.Parent = gui
	if UserInputService.TouchEnabled then
		local open = Instance.new("TextButton")
		open.Name = "PerksButton"
		open.AnchorPoint = Vector2.new(1, 1)
		open.Size, open.Position = UDim2.fromOffset(72, 36), UDim2.new(1, -24, 1, -440)
		open.BackgroundColor3, open.TextColor3 = BACK, Color3.new(1, 1, 1)
		open.Font, open.TextSize, open.Text = Enum.Font.GothamBold, 14, Localization.get("PerksTitle")
		open.Parent = gui
		open.Activated:Connect(toggle)
	end
	gui.Parent = player:WaitForChild("PlayerGui")
end

function ProgressionController.init()
	upgradeRemote = Net.event("PerkUpgrade")
end

function ProgressionController.start()
	buildGui()
	Net.event("ProgressionUpdate").OnClientEvent:Connect(function(data: unknown, xpToNext: unknown)
		if typeof(data) ~= "table" then
			return
		end
		saved = data
		refresh(if typeof(xpToNext) == "number" then xpToNext else nil)
	end)
end

return ProgressionController
