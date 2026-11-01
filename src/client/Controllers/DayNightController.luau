--!strict
-- DayNightController: runs the world clock locally from the server's start time (Shared/DayClock)
-- and sets the lighting every frame: the sun follows the clock, nights are dark, and a horde night
-- tints the world red (7DTD's blood moon). A small label in the top-right corner shows the day and
-- the hour; on a horde day the day shows in red, like 7DTD's day counter.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local DayClock = require(Shared.DayClock)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)
local SoundController = require(script.Parent.SoundController)

-- Lighting at full day and deep night; between them it follows the sun's height.
local DAY_BRIGHTNESS = 2
local NIGHT_BRIGHTNESS = 0.3
local DAY_AMBIENT = Color3.fromRGB(110, 110, 115)
local NIGHT_AMBIENT = Color3.fromRGB(28, 32, 46)
local DAY_OUTDOOR = Color3.fromRGB(128, 128, 132)
local NIGHT_OUTDOOR = Color3.fromRGB(34, 38, 58)
-- Sun height (unit direction Y) where dusk starts and where full night is reached.
local DUSK_SUN_Y = 0.15
local NIGHT_SUN_Y = -0.1
local HORDE_TINT = Color3.fromRGB(255, 170, 160)
local HORDE_SATURATION = -0.15
-- Base grade for a worn, post-collapse look: drained colour, a little contrast, a dusty warm tint.
local BASE_TINT = Color3.fromRGB(255, 246, 232)
local BASE_SATURATION = -0.22
local BASE_CONTRAST = 0.08
-- Atmosphere by day and by night (dusty haze by day, a cold thick dark at night). The same for every
-- graphics preset, so no preset sees further than another.
local DAY_DENSITY = 0.32
local NIGHT_DENSITY = 0.42
local DAY_HAZE = 1.7
local NIGHT_HAZE = 0.4
local DAY_AIR = Color3.fromRGB(199, 189, 168)
local NIGHT_AIR = Color3.fromRGB(52, 60, 78)
local DAY_DECAY = Color3.fromRGB(112, 108, 100)
local NIGHT_DECAY = Color3.fromRGB(22, 25, 34)
local ATMOSPHERE_OFFSET = 0.25
local DAY_GLARE = 0.15
-- Clock label.
local LABEL_WIDTH = 200
local LABEL_HEIGHT = 24
local LABEL_MARGIN = 12
local TEXT_COLOR = Color3.new(1, 1, 1)
local HORDE_COLOR = Color3.fromRGB(235, 70, 60)

local DayNightController = {}

local tint: ColorCorrectionEffect
local atmosphere: Atmosphere
local clockLabel: TextLabel
local hordeLabel: TextLabel
-- Whether the last frame was a horde night, so its start is announced once.
local wasHordeNight = false

local function attribute(name: string, default: number): number
	local value = ReplicatedStorage:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

local function formatTime(clockTime: number): string
	local minutes = math.floor(clockTime * 60) % (24 * 60)
	return string.format("%02d:%02d", minutes // 60, minutes % 60)
end

local function buildGui(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Clock"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	clockLabel = Instance.new("TextLabel")
	clockLabel.Name = "Clock"
	clockLabel.AnchorPoint = Vector2.new(1, 0)
	clockLabel.Position = UDim2.new(1, -LABEL_MARGIN, 0, LABEL_MARGIN)
	clockLabel.Size = UDim2.fromOffset(LABEL_WIDTH, LABEL_HEIGHT)
	clockLabel.BackgroundTransparency = 1
	clockLabel.Font = Enum.Font.GothamBold
	clockLabel.TextSize = 18
	clockLabel.TextColor3 = TEXT_COLOR
	clockLabel.TextStrokeTransparency = 0.5
	clockLabel.TextXAlignment = Enum.TextXAlignment.Right
	clockLabel.Parent = gui
	hordeLabel = clockLabel:Clone()
	hordeLabel.Name = "Horde"
	hordeLabel.Position = UDim2.new(1, -LABEL_MARGIN, 0, LABEL_MARGIN + LABEL_HEIGHT)
	hordeLabel.TextSize = 15
	hordeLabel.TextColor3 = HORDE_COLOR
	hordeLabel.Text = Localization.get("HordeNight")
	hordeLabel.Visible = false
	hordeLabel.Parent = gui
	gui.Parent = playerGui
end

local function update()
	local epoch = attribute(Net.Attributes.ClockEpoch, Workspace:GetServerTimeNow())
	local every = attribute(Net.Attributes.HordeEvery, Config.DayNight.HordeNightDefault)
	local state = DayClock.at(Workspace:GetServerTimeNow() - epoch)
	Lighting.ClockTime = state.clockTime

	local sunY = Lighting:GetSunDirection().Y
	local light = math.clamp((sunY - NIGHT_SUN_Y) / (DUSK_SUN_Y - NIGHT_SUN_Y), 0, 1)
	Lighting.Brightness = NIGHT_BRIGHTNESS + (DAY_BRIGHTNESS - NIGHT_BRIGHTNESS) * light
	Lighting.Ambient = NIGHT_AMBIENT:Lerp(DAY_AMBIENT, light)
	Lighting.OutdoorAmbient = NIGHT_OUTDOOR:Lerp(DAY_OUTDOOR, light)

	local hordeDay = DayClock.isHordeDay(state.day, every)
	local hordeNight = hordeDay and state.phase == "Night"
	local redness = if hordeNight then 1 - light else 0
	tint.TintColor = BASE_TINT:Lerp(HORDE_TINT, redness)
	tint.Saturation = BASE_SATURATION + HORDE_SATURATION * redness
	tint.Contrast = BASE_CONTRAST

	atmosphere.Density = NIGHT_DENSITY + (DAY_DENSITY - NIGHT_DENSITY) * light
	atmosphere.Haze = NIGHT_HAZE + (DAY_HAZE - NIGHT_HAZE) * light
	atmosphere.Color = NIGHT_AIR:Lerp(DAY_AIR, light)
	atmosphere.Decay = NIGHT_DECAY:Lerp(DAY_DECAY, light)
	atmosphere.Glare = DAY_GLARE * light

	clockLabel.Text = Localization.get("HudClock", { day = state.day, time = formatTime(state.clockTime) })
	clockLabel.TextColor3 = if hordeDay then HORDE_COLOR else TEXT_COLOR
	hordeLabel.Visible = hordeNight
	if hordeNight and not wasHordeNight then
		SoundController.play("HordeRoar")
	end
	wasHordeNight = hordeNight
end

function DayNightController.init() end

function DayNightController.start()
	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "DayNightTint"
	tint.Parent = Lighting
	local existing = Lighting:FindFirstChildOfClass("Atmosphere")
	atmosphere = existing or Instance.new("Atmosphere")
	atmosphere.Offset = ATMOSPHERE_OFFSET
	atmosphere.Parent = Lighting
	buildGui(Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui)
	RunService.PreRender:Connect(update)
end

return DayNightController
