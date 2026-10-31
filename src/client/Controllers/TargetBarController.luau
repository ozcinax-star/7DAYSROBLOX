--!strict
-- TargetBarController: a small health bar under the screen centre for what the player's last swing or
-- shot hit (a tree, a rock, a block, the ground, a zombie), from the server's HitInfo. It hides again
-- after Config.Melee.HitInfoSeconds. It tells the player the hit landed and how much is left; 7DTD
-- shows a hit zombie's health the same way and block damage as cracks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

-- Layout (pixels): centred, just below the screen centre.
local BAR_WIDTH = 160
local BAR_HEIGHT = 8
local OFFSET_Y = 44
local TEXT_HEIGHT = 18
local BACK_COLOR = Color3.fromRGB(18, 18, 20)
local FILL_COLOR = Color3.fromRGB(225, 195, 110)
local TEXT_COLOR = Color3.new(1, 1, 1)

local TargetBarController = {}

local bar: Frame
local fill: Frame
local label: TextLabel
local token = 0

local function build(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "TargetBar"
	gui.ResetOnSpawn = false

	bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0.5, OFFSET_Y)
	bar.Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT)
	bar.BackgroundColor3 = BACK_COLOR
	bar.BackgroundTransparency = 0.3
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.Parent = gui

	fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = FILL_COLOR
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = bar

	label = Instance.new("TextLabel")
	label.Name = "Health"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 1, 2)
	label.Size = UDim2.new(1, 0, 0, TEXT_HEIGHT)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = TEXT_COLOR
	label.TextStrokeTransparency = 0.5
	label.Parent = bar

	gui.Parent = playerGui
end

local function show(remaining: number, maximum: number)
	token += 1
	local mine = token
	fill.Size = UDim2.fromScale(math.clamp(remaining / maximum, 0, 1), 1)
	label.Text = Localization.get("HitHealth", { remaining = math.ceil(remaining), maximum = math.ceil(maximum) })
	bar.Visible = true
	task.delay(Config.Melee.HitInfoSeconds, function()
		if mine == token then
			bar.Visible = false
		end
	end)
end

function TargetBarController.init() end

function TargetBarController.start()
	build(Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui)
	Net.unreliable("HitInfo").OnClientEvent:Connect(function(remaining: unknown, maximum: unknown)
		if typeof(remaining) == "number" and typeof(maximum) == "number" and maximum > 0 then
			show(remaining, maximum)
		end
	end)
end

return TargetBarController
