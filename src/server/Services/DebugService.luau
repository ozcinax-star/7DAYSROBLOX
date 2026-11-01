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
local DayNightService = require(script.Parent.DayNightService)
local FarmService = require(script.Parent.FarmService)
local PersistenceService = require(script.Parent.PersistenceService)
local InventoryService = require(script.Parent.InventoryService)
local SurvivalService = require(script.Parent.SurvivalService)
local ThreatService = require(script.Parent.ThreatService)
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
		-- A stress test wants exactly this many zombies: the ambient director stays off until toggled.
		ThreatService.setDirectorEnabled(false)
		ZombieService.clear()
		ZombieService.spawn(value)
	elseif command == "Clear" then
		ThreatService.setDirectorEnabled(false)
		ZombieService.clear()
	elseif command == "Director" then
		ThreatService.setDirectorEnabled(not ThreatService.isDirectorEnabled())
	elseif command == "SaveReport" then
		print("[Debug] " .. PersistenceService.debugReport())
	elseif command == "LoadPart" then
		if typeof(value) == "string" and #value <= 32 then
			print("[Debug] " .. PersistenceService.debugLoadPart(value))
		end
	elseif command == "ReloadCharacter" then
		print("[Debug] " .. PersistenceService.debugReloadCharacter(player))
	elseif command == "SkipPhase" then
		DayNightService.skipPhase()
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
			ZombieService.damage(id, math.huge, player)
		end
	elseif command == "SetFood" or command == "SetWater" then
		-- Survival tests: puts the stat at `value` (0 to its max) right away.
		local max = if command == "SetFood" then Config.Survival.MaxFood else Config.Survival.MaxWater
		if typeof(value) ~= "number" or value ~= value or value < 0 or value > max then
			return
		end
		if command == "SetFood" then
			SurvivalService.setStats(player, value, nil)
		else
			SurvivalService.setStats(player, nil, value)
		end
	elseif command == "GrowCrops" then
		FarmService.ripenAll()
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
		local threat = ThreatService.getStats()
		ReplicatedStorage:SetAttribute(attributes.ThreatTier, threat.tier)
		ReplicatedStorage:SetAttribute(attributes.ThreatLevel, threat.level)
		ReplicatedStorage:SetAttribute(attributes.ThreatNoise, threat.noise)
		ReplicatedStorage:SetAttribute(attributes.ThreatTrace, threat.trace)
		ReplicatedStorage:SetAttribute(attributes.AmbientCount, threat.ambient)
		ReplicatedStorage:SetAttribute(attributes.AmbientTarget, threat.target)
		ReplicatedStorage:SetAttribute(attributes.HordeLeft, threat.hordeLeft)
		ReplicatedStorage:SetAttribute(attributes.DirectorEnabled, threat.directorEnabled)
		heartbeats = 0
	end
end

return DebugService
