--!strict
-- ThreatService: the threat system (PLAN, Tehdit sistemi; math in Shared/Threat) and the zombie
-- population it drives.
-- - Noise: events (harvest hits, a falling tree; later gunshots, doors, generators) fill a fast-fading
--   meter and leave a sound point that zombies in range walk to.
-- - Trace: follows what the players have built (sources set by other services), fades a few points a day.
-- - Ambient population (7DTD biome spawning): a number of zombies is kept around the living players,
--   more at night and at higher tiers. Idle ones far from every player are removed.
-- - Horde night (7DTD blood moon): ZombiesPerPlayer per player in waves over the night. They always
--   know where the nearest player is and run. Ambient spawning pauses; at dawn the survivors become
--   ordinary zombies.
-- The threat level is never shown to players (PLAN design rule 1); only the debug overlay reads it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Threat = require(Shared.Threat)
local Types = require(Shared.Types)

local DayNightService = require(script.Parent.DayNightService)
local ZombieService = require(script.Parent.ZombieService)

local TC = Config.Threat
local PC = Config.Population

export type Stats = {
	noise: number,
	trace: number,
	level: number,
	tier: number,
	-- Ambient (non-horde) zombies alive, and the count the director aims for.
	ambient: number,
	target: number,
	hordeLeft: number,
	directorEnabled: boolean,
}

local ThreatService = {}

local noise = 0
local trace = 0
local level = 0
local tier = 1
local traceSources: { [string]: number } = {}
local nextSoundId = 1
-- The last sound point each player (or named source, like a generator) made, refreshed while their
-- next events stay close.
local lastSounds: { [Player | string]: Types.SoundPoint } = {}

local directorEnabled = true
local ambientCount = 0
local ambientTarget = 0

local hordeActive = false
local hordeWaves: { Threat.Wave } = {}
local hordeNext = 1
local hordeStart = 0

local function livingRoots(): { Vector3 }
	local roots = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character.PrimaryPart
		if humanoid and humanoid.Health > 0 and root then
			table.insert(roots, root.Position)
		end
	end
	return roots
end

local function farFromAll(position: Vector3, roots: { Vector3 }, distanceSq: number): boolean
	for _, root in roots do
		local dx = root.X - position.X
		local dz = root.Z - position.Z
		if dx * dx + dz * dz <= distanceSq then
			return false
		end
	end
	return true
end

local function updateThreat(dt: number)
	noise = Threat.decayNoise(noise, dt)
	local target = 0
	for _, points in traceSources do
		target += points
	end
	trace = Threat.stepTrace(trace, target, dt / Config.DayNight.CycleSeconds)
	level = Threat.level(trace, noise)
	tier = Threat.tier(level, DayNightService.getState().day)
end

local function releaseWaves()
	if not hordeActive then
		return
	end
	local elapsed = os.clock() - hordeStart
	while hordeNext <= #hordeWaves and elapsed >= hordeWaves[hordeNext].at do
		ZombieService.spawn(hordeWaves[hordeNext].count, true)
		hordeNext += 1
	end
end

-- One director pass: counts the ambient zombies, removes idle ones far from every player and queues
-- new ones up to the target.
local function direct()
	local roots = livingRoots()
	local far: { number } = {}
	local despawnSq = PC.DespawnDistance * PC.DespawnDistance
	local count = 0
	ZombieService.forEach(function(id, position, busy, horde)
		if horde then
			return
		end
		count += 1
		if directorEnabled and not busy and #roots > 0 and #far < PC.MaxDespawnPerPass then
			if farFromAll(position, roots, despawnSq) then
				table.insert(far, id)
			end
		end
	end)
	for _, id in far do
		ZombieService.remove(id)
	end
	ambientCount = count - #far
	ambientTarget = if hordeActive then 0 else Threat.ambientTarget(#roots, DayNightService.getState().phase, tier)
	if not directorEnabled then
		return
	end
	local queued = ZombieService.queued()
	local need = ambientTarget - ambientCount - queued
	if need > 0 then
		ZombieService.spawn(math.min(need, PC.MaxSpawnPerPass))
	end
end

local function startHorde()
	-- Everyone in the world counts, dead or alive: a dead player respawns into the same night.
	hordeWaves = Threat.hordeWaves(#Players:GetPlayers(), DayNightService.getState().phaseLeft)
	hordeNext = 1
	hordeStart = os.clock()
	hordeActive = true
	releaseWaves()
end

local function endHorde()
	if not hordeActive then
		return
	end
	hordeActive = false
	hordeWaves = {}
	ZombieService.endHorde()
end

-- A noise event at `position`. Zombies in range walk to it; a source's events close in place and time
-- refresh its last sound point, so steady chopping (a player) or a running generator (its name) makes
-- one zombie path, not one per hit.
function ThreatService.emit(kind: Types.NoiseKind, position: Vector3, source: (Player | string)?)
	local event = TC.Events[kind]
	if event == nil then
		return
	end
	noise = Threat.addNoise(noise, event.Noise)
	local now = os.clock()
	local point = if source then lastSounds[source] else nil
	local merged = false
	if point and now - point.createdAt <= TC.SoundMergeSeconds then
		local dx = point.x - position.X
		local dz = point.z - position.Z
		merged = dx * dx + dz * dz <= TC.SoundMergeDistance * TC.SoundMergeDistance
	end
	if point and merged then
		point.createdAt = now
		point.strength = math.max(point.strength, event.Noise)
		point.radius = math.max(point.radius, event.Radius)
	else
		point = {
			id = nextSoundId,
			x = position.X,
			y = position.Y,
			z = position.Z,
			radius = event.Radius,
			strength = event.Noise,
			createdAt = now,
		}
		nextSoundId += 1
		if source then
			lastSounds[source] = point
		end
	end
	ZombieService.hearSound(point :: Types.SoundPoint)
end

-- Sets one Trace source to `points` (e.g. BuildService: placed parts * PerBuildPart). Trace follows the
-- sum of all sources at once when it rises and fades slowly when it falls.
function ThreatService.setTraceSource(name: string, points: number)
	traceSources[name] = if points > 0 then points else nil
end

-- Drops a named source's last sound point (a removed generator).
function ThreatService.forgetSource(source: string)
	lastSounds[source] = nil
end

function ThreatService.getTier(): number
	return tier
end

-- Debug: stops or resumes the ambient director (spawning and despawning). Horde nights still come.
function ThreatService.setDirectorEnabled(enabled: boolean)
	directorEnabled = enabled
end

function ThreatService.isDirectorEnabled(): boolean
	return directorEnabled
end

function ThreatService.getStats(): Stats
	local left = 0
	if hordeActive then
		for index = hordeNext, #hordeWaves do
			left += hordeWaves[index].count
		end
		local _, queued = ZombieService.queued()
		left += queued
	end
	return {
		noise = noise,
		trace = trace,
		level = level,
		tier = tier,
		ambient = ambientCount,
		target = ambientTarget,
		hordeLeft = left,
		directorEnabled = directorEnabled,
	}
end

function ThreatService.init() end

function ThreatService.start()
	Players.PlayerRemoving:Connect(function(player)
		lastSounds[player] = nil
	end)
	DayNightService.onPhaseChanged(function(phase, _day, horde)
		if phase == "Night" and horde then
			startHorde()
		else
			endHorde()
		end
	end)
	local sinceThreat = 0
	local sinceDirector = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceThreat += dt
		sinceDirector += dt
		if sinceThreat >= TC.UpdateInterval then
			updateThreat(sinceThreat)
			sinceThreat = 0
			releaseWaves()
		end
		if sinceDirector >= PC.Interval then
			sinceDirector = 0
			direct()
		end
	end)
end

return ThreatService
