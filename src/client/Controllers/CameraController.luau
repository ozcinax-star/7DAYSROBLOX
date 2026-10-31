--!strict
-- CameraController: the PLAN camera, switched in game with V.
-- - Shoulder (default): Roblox's own shift lock kept on. The mouse is locked to the screen centre,
--   where a crosshair shows what a swing or shot aims at; the character faces where the camera
--   looks; the camera sits over the right shoulder.
-- - First person: Roblox's LockFirstPerson.
-- - Free mouse: Roblox's default camera with a free cursor (aims at the cursor), the fallback.
-- The cursor is freed while the backpack (or a crate) or the graphics panel is open, or while Left
-- Alt is held, so the UI can be clicked. Zoom stays within Config.Camera's limits (PLAN: a short
-- zoom-out keeps walls hiding what is behind them). Touch keeps Roblox's touch camera and aims from
-- the screen centre, so it gets the shoulder offset and the crosshair.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Localization = require(Shared.Localization)

local GraphicsController = require(script.Parent.GraphicsController)
local InventoryController = require(script.Parent.InventoryController)

type Mode = "Shoulder" | "FirstPerson" | "Free"

local CC = Config.Camera
local MODES: { Mode } = { "Shoulder", "FirstPerson", "Free" }
local MODE_KEYS: { [Mode]: string } = {
	Shoulder = "CameraShoulder",
	FirstPerson = "CameraFirstPerson",
	Free = "CameraFree",
}
local CROSSHAIR_SIZE = 6
local FIRST_PERSON_ZOOM = 0.5
local CROSSHAIR_COLOR = Color3.new(1, 1, 1)
local NOTICE_SECONDS = 1.6
local NOTICE_TOP = 120
-- Runs right after Roblox's camera, which sets the mouse behaviour and rotation type every frame.
local RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 1

local CameraController = {}

local player = Players.LocalPlayer
local gameSettings = UserSettings():GetService("UserGameSettings")
local mode: Mode = if table.find(MODES, CC.DefaultMode :: Mode) then CC.DefaultMode :: Mode else "Shoulder"
local altHeld = false
-- Whether this controller locked the mouse last frame (so it only unlocks what it locked).
local locked = false
local crosshair: Frame
local notice: TextLabel
local noticeToken = 0

local function touchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- True while the player needs the cursor for the UI.
local function cursorWanted(): boolean
	return altHeld or InventoryController.isBackpackOpen() or GraphicsController.isOpen()
end

local function showNotice()
	noticeToken += 1
	local token = noticeToken
	notice.Text = Localization.get("CameraMode", { mode = Localization.get(MODE_KEYS[mode]) })
	notice.Visible = true
	task.delay(NOTICE_SECONDS, function()
		if token == noticeToken then
			notice.Visible = false
		end
	end)
end

-- Applies the zoom limits and camera mode of `mode` (once per change).
local function applyMode()
	if mode == "FirstPerson" then
		player.CameraMinZoomDistance = FIRST_PERSON_ZOOM
		player.CameraMaxZoomDistance = FIRST_PERSON_ZOOM
	else
		-- The maximum first: Roblox clamps a new minimum to the current maximum (measured).
		player.CameraMaxZoomDistance = CC.MaxZoom
		player.CameraMinZoomDistance = CC.MinZoom
	end
	player.CameraMode = if mode == "FirstPerson" then Enum.CameraMode.LockFirstPerson else Enum.CameraMode.Classic
	-- Every mode starts from Roblox's default; onRender locks again where the mode wants it (first
	-- person locks itself).
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	gameSettings.RotationType = Enum.RotationType.MovementRelative
	locked = false
end

local function onRender()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local free = cursorWanted()
	if humanoid then
		humanoid.CameraOffset = if mode == "Shoulder"
			then Vector3.new(CC.ShoulderOffsetX, CC.ShoulderOffsetY, 0)
			else Vector3.zero
	end
	local lock = mode == "Shoulder" and not free and UserInputService.MouseEnabled
	if lock then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		gameSettings.RotationType = Enum.RotationType.CameraRelative
	elseif locked or (free and mode == "FirstPerson") then
		-- Unlock what this controller locked, and free the first-person cursor for the UI.
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		gameSettings.RotationType = Enum.RotationType.MovementRelative
	end
	locked = lock
	-- The crosshair shows wherever swings aim at the screen centre.
	local centred = touchOnly()
		or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		or UserInputService:GetLastInputType() == Enum.UserInputType.Gamepad1
	crosshair.Visible = centred and not free
end

local function buildGui(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Camera"
	gui.ResetOnSpawn = false
	-- The crosshair must sit on the viewport centre, where ToolController aims.
	gui.IgnoreGuiInset = true

	crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Size = UDim2.fromOffset(CROSSHAIR_SIZE, CROSSHAIR_SIZE)
	crosshair.BackgroundColor3 = CROSSHAIR_COLOR
	crosshair.BorderSizePixel = 0
	crosshair.Visible = false
	crosshair.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = crosshair
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.4
	stroke.Parent = crosshair

	notice = Instance.new("TextLabel")
	notice.Name = "Notice"
	notice.AnchorPoint = Vector2.new(0.5, 0)
	notice.Position = UDim2.new(0.5, 0, 0, NOTICE_TOP)
	notice.Size = UDim2.fromOffset(300, 24)
	notice.BackgroundTransparency = 1
	notice.Font = Enum.Font.GothamBold
	notice.TextSize = 18
	notice.TextColor3 = Color3.new(1, 1, 1)
	notice.TextStrokeTransparency = 0.5
	notice.Visible = false
	notice.Parent = gui

	local context = Instance.new("InputContext")
	context.Name = "CameraInput"
	local cycle = Instance.new("InputAction")
	cycle.Name = "CameraMode"
	cycle.Parent = context
	local cycleKey = Instance.new("InputBinding")
	cycleKey.KeyCode = Enum.KeyCode.V
	cycleKey.Parent = cycle
	cycle.Pressed:Connect(function()
		mode = MODES[(table.find(MODES, mode) :: number) % #MODES + 1]
		applyMode()
		showNotice()
	end)
	local cursor = Instance.new("InputAction")
	cursor.Name = "FreeCursor"
	cursor.Parent = context
	local altKey = Instance.new("InputBinding")
	altKey.KeyCode = Enum.KeyCode.LeftAlt
	altKey.Parent = cursor
	cursor.Pressed:Connect(function()
		altHeld = true
	end)
	cursor.Released:Connect(function()
		altHeld = false
	end)
	context.Parent = gui

	gui.Parent = playerGui
end

-- The active camera mode ("Shoulder", "FirstPerson" or "Free").
function CameraController.getMode(): string
	return mode
end

function CameraController.init() end

function CameraController.start()
	buildGui(player:WaitForChild("PlayerGui") :: PlayerGui)
	if touchOnly() and mode == "FirstPerson" then
		mode = "Shoulder"
	end
	applyMode()
	RunService:BindToRenderStep("GameCamera", RENDER_PRIORITY, onRender)
end

return CameraController
