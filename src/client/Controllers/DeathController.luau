--!strict
-- DeathController: what a player sees when they die (7DTD's death screen, without its respawn choice:
-- PLAN respawns on the bedroll or at the spawn). "You died" with a respawn countdown until the new
-- character arrives, a line on the death bag (SurvivalService, PlayerDied), and a marker on the bag
-- until the player reaches it or it is gone (7DTD marks the dropped backpack on the compass). The
-- marker is drawn on the screen over the bag, through walls, with its distance; while the bag is off
-- screen it waits at the screen edge on the bag's side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

local OVERLAY_COLOR = Color3.fromRGB(60, 0, 0)
local OVERLAY_TRANSPARENCY = 0.55
local TITLE_COLOR = Color3.fromRGB(235, 70, 60)
local TEXT_COLOR = Color3.fromRGB(235, 235, 235)
local MARKER_COLOR = Color3.fromRGB(235, 220, 160)
local MARKER_SIZE = Vector2.new(140, 40)
-- The marker sits this high over the bag (studs) and keeps this far from the screen edge (pixels).
local MARKER_HEIGHT = 2
local MARKER_MARGIN = 16
-- The marker goes once the player is this close to the bag (studs).
local MARKER_REACHED = 6

local DeathController = {}

local player = Players.LocalPlayer
local overlay: Frame
local detail: TextLabel
local countdown: TextLabel
local markerFrame: Frame
local markerDistance: TextLabel
-- Counts deaths, so an old countdown stops when the player dies again.
local deathToken = 0
-- Where the newest death bag lies and when it is gone (os.clock), or nil.
local bag: Vector3? = nil
local bagUntil = 0
-- The character that died: its body lies on the bag, so it never counts as reaching it.
local deadCharacter: Model? = nil

local function removeMarker()
	bag = nil
	markerFrame.Visible = false
end

-- Screen position of the marker for world point `point`: over it when it is on screen, otherwise
-- at the edge on its side.
local function screenPoint(camera: Camera, point: Vector3): Vector2
	local size = camera.ViewportSize
	local projected, onScreen = camera:WorldToViewportPoint(point)
	local x, y = projected.X, projected.Y
	if projected.Z < 0 then
		-- Behind the camera the projection is mirrored; it waits at the bottom edge on its side.
		x, y = size.X - x, size.Y
	elseif onScreen then
		return Vector2.new(x, y)
	end
	local halfX, halfY = MARKER_SIZE.X / 2 + MARKER_MARGIN, MARKER_SIZE.Y + MARKER_MARGIN
	return Vector2.new(math.clamp(x, halfX, size.X - halfX), math.clamp(y, halfY, size.Y - MARKER_MARGIN))
end

local function updateMarker()
	local position = bag
	if position == nil then
		return
	end
	if os.clock() >= bagUntil then
		removeMarker()
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	if character == deadCharacter or root == nil or not root:IsA("BasePart") or camera == nil then
		markerFrame.Visible = false
		return
	end
	local studs = (root.Position - position).Magnitude
	if studs <= MARKER_REACHED then
		removeMarker()
		return
	end
	local point = screenPoint(camera, position + Vector3.yAxis * MARKER_HEIGHT)
	markerFrame.Position = UDim2.fromOffset(point.X, point.Y)
	markerDistance.Text = Localization.get(
		"DeathMarkerDistance",
		{ distance = math.floor(studs / Config.Melee.StudsPerMeter + 0.5) }
	)
	markerFrame.Visible = true
end

local function onDied(dropped: unknown, seconds: unknown)
	local lasts = if typeof(seconds) == "number" then seconds else 0
	deathToken += 1
	local token = deathToken
	deadCharacter = player.Character
	if typeof(dropped) == "Vector3" then
		detail.Text = Localization.get("DeathBag", { minutes = math.floor(lasts / 60 + 0.5) })
		bag = dropped
		bagUntil = os.clock() + lasts
	else
		detail.Text = Localization.get("DeathKept")
	end
	overlay.Visible = true
	local respawnAt = os.clock() + Players.RespawnTime
	task.spawn(function()
		while token == deathToken and overlay.Visible do
			local left = math.max(0, math.ceil(respawnAt - os.clock()))
			countdown.Text = Localization.get("DeathRespawn", { seconds = left })
			task.wait(0.2)
		end
	end)
end

local function text(parent: Instance, name: string, size: number, color: Color3): TextLabel
	local item = Instance.new("TextLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.Font = Enum.Font.GothamBold
	item.TextSize = size
	item.TextColor3 = color
	item.TextStrokeTransparency = 0.5
	item.TextWrapped = true
	item.Parent = parent
	return item
end

local function build(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Death"
	gui.ResetOnSpawn = false
	-- Viewport coordinates, so the marker lands on the bag.
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10

	overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = OVERLAY_COLOR
	overlay.BackgroundTransparency = OVERLAY_TRANSPARENCY
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.Parent = gui
	local function line(name: string, y: number, height: number, size: number, color: Color3): TextLabel
		local item = text(overlay, name, size, color)
		item.AnchorPoint = Vector2.new(0.5, 0.5)
		item.Position = UDim2.new(0.5, 0, 0.4, y)
		item.Size = UDim2.new(0.8, 0, 0, height)
		return item
	end
	line("Title", 0, 60, 48, TITLE_COLOR).Text = Localization.get("DeathTitle")
	detail = line("Detail", 56, 48, 18, TEXT_COLOR)
	countdown = line("Countdown", 104, 24, 16, TEXT_COLOR)

	markerFrame = Instance.new("Frame")
	markerFrame.Name = "BagMarker"
	markerFrame.AnchorPoint = Vector2.new(0.5, 1)
	markerFrame.Size = UDim2.fromOffset(MARKER_SIZE.X, MARKER_SIZE.Y)
	markerFrame.BackgroundTransparency = 1
	markerFrame.Visible = false
	markerFrame.Parent = gui
	local title = text(markerFrame, "Title", 16, MARKER_COLOR)
	title.Size = UDim2.new(1, 0, 0.5, 0)
	title.Text = Localization.get("DeathMarker")
	markerDistance = text(markerFrame, "Distance", 14, MARKER_COLOR)
	markerDistance.Position = UDim2.fromScale(0, 0.5)
	markerDistance.Size = UDim2.new(1, 0, 0.5, 0)

	gui.Parent = playerGui
end

function DeathController.init() end

function DeathController.start()
	build(player:WaitForChild("PlayerGui") :: PlayerGui)
	Net.event("PlayerDied").OnClientEvent:Connect(onDied)
	player.CharacterAdded:Connect(function()
		overlay.Visible = false
	end)
	RunService.PreRender:Connect(updateMarker)
end

return DeathController
