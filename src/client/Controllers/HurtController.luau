--!strict
-- Damage feedback for the local player: a red screen-edge flash and a camera punch on every hit, and a
-- pulsing edge with drained colour while health is low. The HUD hides Roblox's own health flash.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local SoundController = require(script.Parent.SoundController)
local WeaponController = require(script.Parent.WeaponController)

local HurtController = {}
local HC = Config.Hurt
local player = Players.LocalPlayer
local RED = Color3.fromRGB(150, 12, 10)

local edges: { Frame } = {}
local grade: ColorCorrectionEffect
local humanoid: Humanoid? = nil
local lastHealth = 0
local flashStarted = -math.huge
local flashPeak = 0
local healthConnection: RBXScriptConnection? = nil

-- One band per screen edge, fading toward the centre.
local function edge(parent: Instance, anchor: Vector2, size: UDim2, rotation: number)
	local frame = Instance.new("Frame")
	frame.AnchorPoint, frame.Position, frame.Size = anchor, UDim2.fromScale(anchor.X, anchor.Y), size
	frame.BackgroundColor3, frame.BorderSizePixel = RED, 0
	frame.BackgroundTransparency = 1
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.6, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = frame
	frame.Parent = parent
	table.insert(edges, frame)
end

local function buildGui()
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset = "Hurt", false, true
	-- Under the weapon HUD (5) and the death screen (10), over the world.
	gui.DisplayOrder = 1
	local share = HC.EdgeShare
	edge(gui, Vector2.new(0.5, 0), UDim2.fromScale(1, share), 90)
	edge(gui, Vector2.new(0.5, 1), UDim2.fromScale(1, share), -90)
	edge(gui, Vector2.new(0, 0.5), UDim2.fromScale(share * 0.6, 1), 0)
	edge(gui, Vector2.new(1, 0.5), UDim2.fromScale(share * 0.6, 1), 180)
	gui.Parent = player:WaitForChild("PlayerGui")
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "HurtGrade"
	grade.Parent = Lighting
end

local function watch(character: Model)
	if healthConnection then
		healthConnection:Disconnect()
		healthConnection = nil
	end
	humanoid = nil
	local found = character:WaitForChild("Humanoid", 10)
	if found == nil or not found:IsA("Humanoid") or character.Parent == nil then
		return
	end
	local h: Humanoid = found
	humanoid, lastHealth = h, h.Health
	healthConnection = h.HealthChanged:Connect(function(health: number)
		local lost = lastHealth - health
		lastHealth = health
		if lost < HC.MinDamage or health <= 0 then
			return
		end
		local now = os.clock()
		-- Every hit restarts the fade; bigger hits flash stronger, small ones still show.
		flashPeak = math.clamp(lost / HC.FlashFullDamage, HC.FlashMinStrength, 1)
		flashStarted = now
		WeaponController.punch(math.min(HC.PunchMax, lost * HC.PunchPerDamage))
		SoundController.play("PlayerHurt")
	end)
end

local function render()
	local h = humanoid
	local now = os.clock()
	local flash = math.max(0, 1 - (now - flashStarted) / HC.FlashSeconds) * flashPeak * HC.FlashAlpha
	local low = 0
	if h and h.Health > 0 and h.MaxHealth > 0 then
		local share = h.Health / h.MaxHealth
		if share < HC.LowHealthShare then
			-- Deeper and faster the closer to death.
			local depth = 1 - share / HC.LowHealthShare
			local pulse = 0.65 + 0.35 * math.sin(now * math.pi * 2 * HC.PulseHz * (1 + depth * 0.5))
			low = depth * pulse * HC.LowHealthAlpha + depth * 0.08
		end
		grade.Saturation = if share < HC.LowHealthShare then HC.LowHealthSaturation * (1 - share / HC.LowHealthShare) else 0
	else
		grade.Saturation = 0
	end
	local alpha = math.min(0.85, flash + low)
	for _, frame in edges do
		frame.BackgroundTransparency = 1 - alpha
	end
end

function HurtController.init() end

function HurtController.start()
	buildGui()
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end
	RunService.PreRender:Connect(render)
end

return HurtController
