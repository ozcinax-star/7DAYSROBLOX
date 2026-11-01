--!strict
-- Save and load (PLAN: "Oyuncu profili + dünya kaydı"). Two ProfileStore stores, both session-locked so
-- no two servers own the same data:
--   * World (Config.Persistence.WorldStore): everything in one world, plus each player's character in
--     that world (inventory, stats, bed), like 7DTD keeps characters per save. Only private servers
--     (and Studio) have a world key; a public server is a temporary world (PLAN lobby decision).
--   * Profile (Config.Persistence.ProfileStore): what a player keeps across worlds (challenges now;
--     perks and cosmetics later).
-- Services own their own state: they register a save/load pair here and never touch the stores.
-- Saved data holds ids, numbers and strings only (ProfileStore cannot store Instances or Vector3).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Localization = require(Shared.Localization)
local ProfileStore = require(script.Parent.Parent.Vendor.ProfileStore) :: any
local MapService = require(script.Parent.MapService)

local PC = Config.Persistence

export type WorldPart = { save: () -> any, load: (data: any) -> () }
export type CharacterPart = { save: (player: Player) -> any, load: (player: Player, data: any) -> () }
export type ProfilePart = { save: (player: Player) -> any, load: (player: Player, data: any) -> () }

local PersistenceService = {}

-- Registered in service init(), so every part exists before any load.
local worldParts: { [string]: WorldPart } = {}
local worldOrder: { string } = {}
local characterParts: { [string]: CharacterPart } = {}
local profileParts: { [string]: ProfilePart } = {}
-- Checks that must pass before the world loads (a service whose start() sets up what a load needs).
local readyChecks: { () -> boolean } = {}

local worldStore: any = nil
local profileStore: any = nil
local world: any = nil -- the world Profile, nil in a temporary world
local profiles: { [Player]: any } = {}
-- Players whose character was restored (or found new): only they are written back, so a player who
-- left before the world finished loading never overwrites their saved character with an empty one.
local restored: { [Player]: boolean } = {}
local worldLoaded = false
local loadedSignal = Instance.new("BindableEvent")

local WORLD_TEMPLATE = { Version = PC.WorldVersion, Parts = {}, Characters = {} }
local PROFILE_TEMPLATE = { Version = PC.ProfileVersion, Parts = {} }

-- The key of this server's world, or nil when the world is temporary.
local function worldKey(): string?
	if game.PrivateServerId ~= "" then
		return `Private_{game.PrivateServerId}`
	end
	if RunService:IsStudio() then
		return PC.StudioWorldKey
	end
	return nil
end

local function store(name: string, template: any): any
	local live = ProfileStore.New(name, template)
	return if RunService:IsStudio() and not PC.StudioUsesLiveStore then live.Mock else live
end

-- Calls `fn(...)`; a failing part is reported and skipped so one bad part cannot block the rest.
local function guarded(label: string, fn: (...any) -> ...any, ...: any): (boolean, any)
	local ok, result = pcall(fn, ...)
	if not ok then
		warn(`[Persistence] {label} failed: {result}`)
	end
	return ok, result
end

local function snapshotCharacter(player: Player)
	if world == nil or not world:IsActive() or not restored[player] then
		return
	end
	local entry = {}
	for name, part in characterParts do
		local ok, value = guarded(`save character {name}`, part.save, player)
		if ok then
			entry[name] = value
		end
	end
	world.Data.Characters[tostring(player.UserId)] = entry
end

local function snapshotWorld()
	if world == nil or not world:IsActive() or not worldLoaded then
		return
	end
	for _, name in worldOrder do
		local ok, value = guarded(`save world {name}`, worldParts[name].save)
		if ok then
			world.Data.Parts[name] = value
		end
	end
	for _, player in Players:GetPlayers() do
		snapshotCharacter(player)
	end
end

local function restoreCharacter(player: Player)
	if restored[player] or player.Parent ~= Players then
		return
	end
	restored[player] = true
	local entry = if world then world.Data.Characters[tostring(player.UserId)] else nil
	if entry == nil then
		return
	end
	for name, part in characterParts do
		if entry[name] ~= nil then
			guarded(`load character {name}`, part.load, player, entry[name])
		end
	end
end

local function migrateWorld(data: any)
	-- Version 1 is the first schema; later versions add steps here and never rename keys without one.
	data.Version = PC.WorldVersion
end

local function loadWorld()
	local key = worldKey()
	if key == nil then
		worldLoaded = true
		return
	end
	world = worldStore:StartSessionAsync(key, {
		Cancel = function()
			return ProfileStore.IsClosing
		end,
	})
	if world == nil then
		-- Nothing is written without a session, so the save is safe; this world just will not keep.
		warn(`[Persistence] world {key} could not be loaded; playing a temporary world`)
		worldLoaded = true
		return
	end
	world:Reconcile()
	migrateWorld(world.Data)
	world.OnSave:Connect(snapshotWorld)
	world.OnSessionEnd:Connect(function()
		-- Another server took the world (or the server is closing): stop writing to it.
		world = nil
	end)
	for _, name in worldOrder do
		local data = world.Data.Parts[name]
		if data ~= nil then
			guarded(`load world {name}`, worldParts[name].load, data)
		end
	end
	worldLoaded = true
end

local function onPlayerAdded(player: Player)
	-- The player's own profile (challenges...): kick on failure rather than play on defaults that would
	-- overwrite the real save.
	local profile = profileStore:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		if player.Parent == Players then
			player:Kick(Localization.get("SaveLoadFailed"))
		end
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	profiles[player] = profile
	profile.OnSave:Connect(function()
		if player.Parent == Players then
			for name, part in profileParts do
				local ok, value = guarded(`save profile {name}`, part.save, player)
				if ok then
					profile.Data.Parts[name] = value
				end
			end
		end
	end)
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick(Localization.get("SaveOpenElsewhere"))
		end
	end)
	for name, part in profileParts do
		local data = profile.Data.Parts[name]
		if data ~= nil then
			guarded(`load profile {name}`, part.load, player, data)
		end
	end
	if worldLoaded then
		restoreCharacter(player)
	end
end

local function onPlayerRemoving(player: Player)
	snapshotCharacter(player)
	restored[player] = nil
	local profile = profiles[player]
	if profile then
		for name, part in profileParts do
			local ok, value = guarded(`save profile {name}`, part.save, player)
			if ok then
				profile.Data.Parts[name] = value
			end
		end
		profile:EndSession()
		profiles[player] = nil
	end
end

-- Registration (call from a service's init()). World parts load in registration order: blocks before
-- the crates that sit in them.
function PersistenceService.registerWorld(name: string, part: WorldPart)
	assert(worldParts[name] == nil, `[Persistence] world part {name} registered twice`)
	worldParts[name] = part
	table.insert(worldOrder, name)
end

function PersistenceService.registerCharacter(name: string, part: CharacterPart)
	characterParts[name] = part
end

function PersistenceService.registerProfile(name: string, part: ProfilePart)
	profileParts[name] = part
end

-- The world waits to load until `check()` is true (call from init()).
function PersistenceService.registerReady(check: () -> boolean)
	table.insert(readyChecks, check)
end

-- True once the world is restored (or known to be temporary).
function PersistenceService.isWorldLoaded(): boolean
	return worldLoaded
end

-- Fires once the world is restored; services that act on joining players can wait for it.
PersistenceService.worldLoaded = loadedSignal.Event

-- True when this server keeps its world.
function PersistenceService.isPersistent(): boolean
	return world ~= nil
end

-- Writes everything now (debug and tests); ProfileStore otherwise saves every few minutes, when a
-- player leaves and when the server closes.
function PersistenceService.saveNow()
	snapshotWorld()
	if world then
		world:Save()
	end
end

-- Debug: saves now, reads the world back from the store and compares it with what was written; returns
-- a one-line report (part sizes, character count, whether the read-back matches).
function PersistenceService.debugReport(): string
	if world == nil then
		return "temporary world: nothing is saved"
	end
	PersistenceService.saveNow()
	local written = HttpService:JSONEncode(world.Data)
	local parts = {}
	for _, name in worldOrder do
		local value = world.Data.Parts[name]
		table.insert(parts, `{name}={if value ~= nil then #HttpService:JSONEncode(value) else 0}B`)
	end
	local readBack = worldStore:GetAsync(world.Key)
	local match = readBack ~= nil and HttpService:JSONEncode(readBack.Data) == written
	local characters = 0
	for _ in world.Data.Characters do
		characters += 1
	end
	return `world {world.Key}: {#written} B, {table.concat(parts, " ")}, characters={characters}, read-back match={match}`
end

-- Debug: snapshots the player's character, empties their inventory and restores it from the snapshot
-- (the inventory and vitals parts; crafting refunds are skipped, they would duplicate a live queue).
function PersistenceService.debugReloadCharacter(player: Player): string
	if not restored[player] then
		return "character not restored yet"
	end
	local entry = {}
	for _, name in { "Inventory", "Vitals" } do
		local part = characterParts[name]
		if part then
			entry[name] = part.save(player)
		end
	end
	local before = HttpService:JSONEncode(entry)
	for name, data in entry do
		characterParts[name].load(player, { Slots = {}, Selected = 1, Food = 0, Water = 0, Stamina = 0, Health = 1 })
		characterParts[name].load(player, data)
	end
	local after = {}
	for name in entry do
		after[name] = characterParts[name].save(player)
	end
	local same = HttpService:JSONEncode(after) == before
	return `character {player.UserId}: {#before} B, reload identical={same}`
end

-- Debug: loads the last saved copy of one world part into the running world (tests a load path without
-- restarting the server; parts skip what already exists, so only missing things come back).
function PersistenceService.debugLoadPart(name: string): string
	local part = worldParts[name]
	if world == nil or part == nil then
		return `no saved part {name}`
	end
	local data = world.Data.Parts[name]
	if data == nil then
		return `part {name} has not been saved yet`
	end
	local ok = guarded(`debug load {name}`, part.load, data)
	return `loaded {name}: {ok}`
end

function PersistenceService.init()
	worldStore = store(PC.WorldStore, WORLD_TEMPLATE)
	profileStore = store(PC.ProfileStore, PROFILE_TEMPLATE)
	-- Connected before any other service's start(), so a leaving player's state is saved before the
	-- services drop it.
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

local function everythingReady(): boolean
	if not MapService.isReady() then
		return false
	end
	for _, check in readyChecks do
		if not check() then
			return false
		end
	end
	return true
end

function PersistenceService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	-- The world loads into a finished map: blocks need the ground, dug columns need the terrain.
	while not everythingReady() do
		task.wait(0.25)
	end
	loadWorld()
	for _, player in Players:GetPlayers() do
		if profiles[player] then
			restoreCharacter(player)
		end
	end
	loadedSignal:Fire()
end

return PersistenceService
