--!strict
-- Reliable firearm state, reload input/HUD, sight transition and damped cosmetic recoil.
-- Loaded ammunition is never predicted: only the server changes the displayed magazine.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Firearm = require(Shared.Firearm)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)
local InventoryController = require(script.Parent.InventoryController)

type State = { id: string | boolean, slot: number, loaded: number, capacity: number, reserve: number, ammo: string?,
	reloadStarted: number, reloadEnds: number, readyAt: number, revision: number, shot: boolean }
local WeaponController = {}
local player = Players.LocalPlayer
local HC = Config.WeaponHandling
local state: State? = nil
local aimWanted, aimBlend = false, 0
local recoilPitch, recoilYaw, recoilBack = 0, 0, 0
local lastPrediction = -math.huge
local lastHeld: string? = nil
local lastSlot = 0
local equippedAt = 0
local baseFov: number? = nil
local lastWritten: CFrame? = nil
local lastRotation = CFrame.identity
local hitUntil = 0
local ownProjectiles: { [number]: number } = {}
local reloadRemote: RemoteEvent
local panel: Frame
local title: TextLabel
local counter: TextLabel
local status: TextLabel
local ammoName: TextLabel
local progress: Frame
local reloadButton: TextButton
local reticle: Frame
local bars: { Frame } = {}
local hitBars: { Frame } = {}

function WeaponController.getState(): State?
	local held = InventoryController.getHeld()
	return if held and state and state.id == held.id and state.slot == InventoryController.getSelectedSlot() then state else nil
end

function WeaponController.setAiming(on: boolean) aimWanted = on end
function WeaponController.aimAlpha(): number return aimBlend end
function WeaponController.isAiming(): boolean return aimWanted end
function WeaponController.kick(): (number, number, number) return recoilPitch, recoilYaw, recoilBack end
function WeaponController.equipAlpha(): number
	return math.clamp((os.clock() - equippedAt) / Config.Ranged.EquipSeconds, 0, 1)
end
function WeaponController.reloadProgress(): (boolean, number)
	local s = WeaponController.getState()
	if s and s.reloadEnds > workspace:GetServerTimeNow() then
		return true, Firearm.progress(s.reloadStarted, s.reloadEnds, workspace:GetServerTimeNow())
	end
	return false, 0
end
function WeaponController.hitConfirmed() hitUntil = os.clock() + 0.18 end

function WeaponController.predictShot()
	local held = InventoryController.getHeld()
	local h = held and HC.Items[held.id]
	if h == nil then return end
	lastPrediction = os.clock()
	recoilPitch = math.min(8, recoilPitch + h.Recoil[1])
	recoilYaw += (math.random() * 2 - 1) * h.Recoil[2]
	recoilBack = math.min(0.35, recoilBack + h.Recoil[3])
end

function WeaponController.reload()
	local held = InventoryController.getHeld()
	local weapon = held and Config.Ranged.Weapons[held.id]
	if weapon == nil or weapon.Magazine == nil or InventoryController.isBackpackOpen()
		or UserInputService:GetFocusedTextBox() then return end
	local s = WeaponController.getState()
	if s and s.reloadEnds <= workspace:GetServerTimeNow() and s.loaded < s.capacity and s.reserve > 0 then
		reloadRemote:FireServer(true)
	end
end

local function label(parent: Instance, name: string, pos: UDim2, size: UDim2, textSize: number): TextLabel
	local t = Instance.new("TextLabel")
	t.Name, t.Position, t.Size = name, pos, size
	t.BackgroundTransparency = 1
	t.TextColor3, t.TextSize, t.Font = Color3.new(1, 1, 1), textSize, Enum.Font.GothamBold
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = ""
	t.Parent = parent
	return t
end

local function buildGui()
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset = "WeaponHud", false, true
	gui.DisplayOrder = 5
	panel = Instance.new("Frame")
	panel.Name, panel.AnchorPoint = "Ammo", Vector2.new(1, 1)
	panel.Position, panel.Size = UDim2.new(1, -24, 1, -340), UDim2.fromOffset(240, 115)
	panel.BackgroundColor3, panel.BackgroundTransparency = Color3.fromRGB(20, 24, 23), 0.16
	panel.Parent = gui
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = panel
	title = label(panel, "WeaponName", UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 20), 16)
	counter = label(panel, "Rounds", UDim2.fromOffset(12, 31), UDim2.new(1, -24, 0, 36), 32)
	ammoName = label(panel, "AmmoType", UDim2.fromOffset(12, 69), UDim2.new(1, -24, 0, 17), 12)
	status = label(panel, "Status", UDim2.fromOffset(12, 88), UDim2.new(1, -24, 0, 18), 12)
	progress = Instance.new("Frame")
	progress.Name, progress.Size, progress.Position = "ReloadProgress", UDim2.fromScale(0, 0), UDim2.new(0, 0, 1, -3)
	progress.BorderSizePixel, progress.BackgroundColor3 = 0, Color3.fromRGB(209, 177, 105)
	progress.Parent = panel
	reloadButton = Instance.new("TextButton")
	reloadButton.Name, reloadButton.Text = "Reload", Localization.get("WeaponReload")
	reloadButton.AnchorPoint = Vector2.new(1, 1)
	reloadButton.Position, reloadButton.Size = UDim2.new(1, -24, 1, -370), UDim2.fromOffset(72, 62)
	reloadButton.BackgroundColor3, reloadButton.TextColor3 = Color3.fromRGB(35, 40, 38), Color3.new(1, 1, 1)
	reloadButton.TextSize, reloadButton.Font = 16, Enum.Font.GothamBold
	reloadButton.Parent = gui
	reloadButton.Activated:Connect(WeaponController.reload)
	reticle = Instance.new("Frame")
	reticle.Name, reticle.Position, reticle.Size = "Reticle", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(0, 0)
	reticle.BackgroundTransparency = 1; reticle.Parent = gui
	for i = 1, 4 do
		local bar = Instance.new("Frame"); bar.BorderSizePixel = 0; bar.BackgroundColor3 = Color3.fromRGB(225, 225, 210)
		bar.AnchorPoint = Vector2.new(0.5, 0.5); bar.Parent = reticle; table.insert(bars, bar)
		local hit = bar:Clone(); hit.Size = UDim2.fromOffset(8, 2); hit.Rotation = if i % 2 == 0 then -45 else 45
		hit.Position = UDim2.fromOffset(if i <= 2 then -7 else 7, if i == 1 or i == 4 then -7 else 7)
		hit.Parent = reticle; table.insert(hitBars, hit)
	end
	local context = Instance.new("InputContext"); context.Name = "WeaponInput"; context.Parent = gui
	local action = Instance.new("InputAction"); action.Name = "Reload"; action.Parent = context
	for _, key in { Enum.KeyCode.R, Enum.KeyCode.ButtonB } do
		local binding = Instance.new("InputBinding"); binding.KeyCode = key; binding.Parent = action
	end
	action.Pressed:Connect(WeaponController.reload)
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function render(dt: number)
	for id, started in ownProjectiles do if os.clock() - started > 12 then ownProjectiles[id] = nil end end
	local held = InventoryController.getHeld()
	local id = if held then held.id else nil
	local slot = InventoryController.getSelectedSlot()
	if id ~= lastHeld or slot ~= lastSlot then
		lastHeld, lastSlot = id, slot; equippedAt = os.clock(); aimWanted = false; recoilPitch, recoilYaw, recoilBack = 0, 0, 0
	end
	local weapon = id and Config.Ranged.Weapons[id]
	local s = WeaponController.getState()
	local reloading = s ~= nil and s.reloadEnds > workspace:GetServerTimeNow()
	local ch = player.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	local active = weapon ~= nil and not InventoryController.isBackpackOpen() and hum ~= nil and hum.Health > 0
	if not active or reloading then aimWanted = false end
	local target = if aimWanted and active then 1 else 0
	aimBlend += (target - aimBlend) * (1 - math.exp(-HC.AimResponse * dt))
	local decay = math.exp(-HC.RecoilReturn * dt)
	recoilPitch, recoilYaw, recoilBack = recoilPitch * decay, recoilYaw * decay, recoilBack * decay
	local camera = workspace.CurrentCamera
	if camera then
		if baseFov == nil then baseFov = camera.FieldOfView end
		camera.FieldOfView = (baseFov :: number) + (Config.Ranged.AimFieldOfView - (baseFov :: number)) * aimBlend
		local base = if lastWritten and camera.CFrame == lastWritten then camera.CFrame * lastRotation:Inverse() else camera.CFrame
		lastRotation = CFrame.Angles(math.rad(recoilPitch), math.rad(recoilYaw), 0)
		camera.CFrame = base * lastRotation; lastWritten = camera.CFrame
	end
	panel.Visible = active
	reloadButton.Visible = active and weapon ~= nil and weapon.Magazine ~= nil and UserInputService.TouchEnabled
	if UserInputService.TouchEnabled and camera and camera.ViewportSize.X < 900 then
		panel.AnchorPoint = Vector2.new(0, 0); panel.Position = UDim2.new(0, 12, 0.5, 0); panel.Size = UDim2.fromOffset(195, 112)
	else
		local challengeGui = player.PlayerGui:FindFirstChild("Challenge")
		local challenge = challengeGui and challengeGui:FindFirstChild("Panel")
		local top = if challenge and challenge:IsA("Frame") and challenge.Visible
			then challenge.AbsolutePosition.Y + challenge.AbsoluteSize.Y + GuiService:GetGuiInset().Y + 12 else 145
		panel.AnchorPoint = Vector2.new(1, 0); panel.Position = UDim2.new(1, -24, 0, top)
		panel.Size = UDim2.fromOffset(240, 115)
	end
	if active and held and weapon then
		local loaded = if s then s.loaded else held.loadedRounds or 0
		local reserve = if s then s.reserve else 0
		title.Text = Localization.get(`Item{held.id}`)
		counter.Text = if weapon.Magazine then Localization.get("WeaponAmmo", { loaded = loaded, reserve = reserve }) else tostring(reserve)
		counter.TextColor3 = if weapon.Magazine and loaded == 0 then Color3.fromRGB(235, 145, 105) else Color3.new(1, 1, 1)
		local ammoLabel = Localization.get(`Item{if s and s.ammo then s.ammo else weapon.Ammo[1]}`)
		ammoName.Text = if weapon.Magazine then Localization.get("WeaponDetails", {
			ammo = ammoLabel, mode = Localization.get(if weapon.Automatic then "WeaponAuto" else "WeaponSingle"),
		}) else ammoLabel
		status.Text = if reloading and s then Localization.get("WeaponReloading", { seconds = string.format("%.1f", s.reloadEnds - workspace:GetServerTimeNow()) })
			elseif s and workspace:GetServerTimeNow() < s.readyAt then Localization.get("WeaponEquipping")
			elseif weapon.Magazine and loaded == 0 then Localization.get("WeaponEmpty")
			elseif weapon.Magazine then Localization.get("WeaponReloadHint") else ""
		progress.Size = UDim2.new(if reloading and s then Firearm.progress(s.reloadStarted, s.reloadEnds, workspace:GetServerTimeNow()) else 0, 0, 0, 3)
	end
	reticle.Visible = active and (UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		or UserInputService:GetLastInputType() == Enum.UserInputType.Gamepad1 or UserInputService.TouchEnabled)
	local gap = 5 + (1 - aimBlend) * 5 + recoilPitch * 3
	for i, bar in bars do
		bar.BackgroundTransparency = aimBlend * 0.85
		bar.Size = if i <= 2 then UDim2.fromOffset(7, 2) else UDim2.fromOffset(2, 7)
		bar.Position = UDim2.fromOffset(if i == 1 then -gap elseif i == 2 then gap else 0, if i == 3 then -gap elseif i == 4 then gap else 0)
	end
	for _, bar in hitBars do bar.Visible = os.clock() < hitUntil end
end

function WeaponController.init() reloadRemote = Net.event("ReloadWeapon") end
function WeaponController.start()
	buildGui()
	Net.event("WeaponState").OnClientEvent:Connect(function(nextState: State)
		if state and nextState.revision <= state.revision then return end
		state = nextState
		if nextState.shot and os.clock() - lastPrediction > 0.25 then WeaponController.predictShot() end
	end)
	Net.unreliable("ArrowFired").OnClientEvent:Connect(function(id, _, _, _, _, _, _, owner)
		if owner == player then ownProjectiles[id] = os.clock() end
	end)
	Net.unreliable("ArrowStopped").OnClientEvent:Connect(function(id, _, zombie)
		if ownProjectiles[id] then ownProjectiles[id] = nil; if zombie ~= 0 then WeaponController.hitConfirmed() end end
	end)
	RunService:BindToRenderStep("WeaponCamera", Enum.RenderPriority.Camera.Value + 2, render)
	player.CharacterAdded:Connect(function() aimWanted = false; state = nil; lastWritten = nil end)
end

return WeaponController
