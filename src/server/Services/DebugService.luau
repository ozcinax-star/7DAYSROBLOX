--!strict
-- DebugService: stress-test commands and server performance stats for the debug overlay.
-- Commands are only accepted in Studio or from Config.Debug.AllowedUserIds, and are validated and
-- rate limited like every other remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local InventoryService = require(script.Parent.InventoryService)
local ZombieService = require(script.Parent.ZombieService)

local DebugService = {}

local GOD_MODE_NAME = "DebugGodMode"

local limiter: RateLimiter.RateLimiter
-- Debug sound ids are negative so they never collide with ThreatService ids.
local nextDebugSoundId = -1

local function isAllowed(player: Player): boolean
	return RunService:IsStudio() or table.find(Config.Debug.AllowedUserIds, player.UserId) ~= nil
end

local function onCommand(player: Player, command: unknown, value: unknown)
	if not isAllowed(player) or not limiter:allow(player) then
		return
	end
	if typeof(command) ~= "string" then
		return
	end
	if command == "Spawn" then
		if typeof(value) ~= "number" or table.find(Config.Debug.StressCounts, value) == nil then
			return
		end
		ZombieService.clear()
		ZombieService.spawn(value)
	elseif command == "Clear" then
		ZombieService.clear()
	elseif command == "GodMode" then
		-- Invisible ForceField: Humanoid:TakeDamage ignores characters that have one.
		local character = player.Character
		if character == nil then
			return
		end
		local existing = character:FindFirstChild(GOD_MODE_NAME)
		if existing then
			existing:Destroy()
		else
			local field = Instance.new("ForceField")
			field.Name = GOD_MODE_NAME
			field.Visible = false
			field.Parent = character
		end
	elseif command == "Kill" then
		-- Target picked by the server around the character, like a melee hit will be.
		local character = player.Character
		local root = character and character.PrimaryPart
		if root == nil then
			return
		end
		local id = ZombieService.nearest(root.Position, Config.Debug.KillRadius)
		if id then
			ZombieService.damage(id, Config.Zombie.MaxHealth, player)
		end
	elseif command == "GiveKit" then
		for _, entry in Config.Debug.TestKit do
			InventoryService.give(player, entry.Id, entry.Count, "Loot")
		end
	elseif command == "Noise" then
		-- Position comes from the server's view of the character, never from the client.
		local character = player.Character
		local root = character and character.PrimaryPart
		if root == nil then
			return
		end
		local p = root.Position
		ZombieService.hearSound({
			id = nextDebugSoundId,
			x = p.X,
			y = p.Y,
			z = p.Z,
			radius = Config.Debug.NoiseRadius,
			strength = Config.Debug.NoiseStrength,
			createdAt = os.clock(),
		})
		nextDebugSoundId -= 1
	end
end

function DebugService.init()
	limiter = RateLimiter.new(Config.Remotes.DebugRequestsPerSecond)
end

function DebugService.start()
	Net.event("DebugCommand").OnServerEvent:Connect(onCommand)

	local function markPlayer(player: Player)
		player:SetAttribute(Net.Attributes.DebugAllowed, isAllowed(player))
	end
	Players.PlayerAdded:Connect(markPlayer)
	for _, player in Players:GetPlayers() do
		markPlayer(player)
	end

	local heartbeats = 0
	RunService.Heartbeat:Connect(function()
		heartbeats += 1
	end)

	local attributes = Net.Attributes
	while true do
		local started = os.clock()
		task.wait(Config.Debug.StatsInterval)
		local elapsed = os.clock() - started
		local stats = ZombieService.getStats()
		ReplicatedStorage:SetAttribute(attributes.TickMs, stats.tickMs)
		ReplicatedStorage:SetAttribute(attributes.TickMaxMs, stats.tickMaxMs)
		ReplicatedStorage:SetAttribute(attributes.ServerFps, heartbeats / elapsed)
		ReplicatedStorage:SetAttribute(attributes.ZombieCount, stats.alive)
		ReplicatedStorage:SetAttribute(attributes.ZombieQueued, stats.queued)
		ReplicatedStorage:SetAttribute(attributes.ZombieStepsPerSecond, stats.stepsPerSecond)
		heartbeats = 0
	end
end

return DebugService
