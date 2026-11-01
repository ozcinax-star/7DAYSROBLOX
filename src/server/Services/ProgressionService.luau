--!strict
-- Experience, levels and perks per player (Shared/Progression). Experience comes from the events
-- ChallengeService already hears (kills, harvests, crafts, placed and upgraded blocks); a level gives a
-- perk point, spent with the PerkUpgrade remote. The state lives in the player's profile, so it follows
-- them across worlds (PLAN: perks stay in the profile). Other services read the perk effects here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Progression = require(Shared.Progression)

local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local PersistenceService = require(script.Parent.PersistenceService)

local PC = Config.Progression

local ProgressionService = {}

local states: { [Player]: Progression.State } = {}
local updateRemote: RemoteEvent
local noticeRemote: RemoteEvent
local limiter: RateLimiter.RateLimiter

local function stateOf(player: Player): Progression.State
	local state = states[player]
	if state == nil then
		state = Progression.new()
		states[player] = state
	end
	return state
end

local function publish(player: Player)
	local state = states[player]
	if state and player.Parent == Players then
		updateRemote:FireClient(player, Progression.toSaved(state), Progression.xpToNext(state.level))
	end
end

-- Experience for an event ChallengeService recorded (kind: Config.ChallengeKind, count: items/units).
function ProgressionService.award(player: Player, kind: string, count: number)
	local per = PC.Xp[kind]
	if per == nil or count <= 0 then
		return
	end
	local state = stateOf(player)
	-- A craft or a kill is worth its rate once; harvests are paid per item.
	local amount = if kind == "Harvest" then per * count else per
	local gained = Progression.addXp(state, amount)
	if gained > 0 then
		noticeRemote:FireClient(player, "LevelUp", { level = state.level, points = state.points })
	end
	publish(player)
end

-- Multiplier on the entity damage the player deals (Combat).
function ProgressionService.damageShare(player: Player?): number
	local state = player and states[player]
	return if state then Progression.damageShare(state) else 1
end

-- Multiplier on the items a container rolls when this player fills it (Scavenger).
function ProgressionService.lootShare(player: Player): number
	local state = states[player]
	return if state then Progression.lootShare(state) else 1
end

-- `count` items of a block upgrade or repair after Builder's discount (never below 1).
function ProgressionService.buildCost(player: Player, count: number): number
	local state = states[player]
	local share = if state then Progression.costShare(state) else 1
	return math.max(1, math.ceil(count * share))
end

local function onUpgrade(player: Player, perkId: unknown)
	if not limiter:allow(player) or typeof(perkId) ~= "string" or PC.Perks[perkId] == nil then
		return
	end
	if Progression.upgrade(stateOf(player), perkId) then
		publish(player)
	end
end

function ProgressionService.init()
	limiter = RateLimiter.new(PC.PerkRequestsPerSecond)
	updateRemote = Net.event("ProgressionUpdate")
	noticeRemote = Net.event("Notice")
	Net.event("PerkUpgrade")
	-- Saved profile part "Progression": experience, level, points and perk tiers.
	PersistenceService.registerProfile("Progression", {
		save = function(player: Player)
			local state = states[player]
			return if state then Progression.toSaved(state) else nil
		end,
		load = function(player: Player, data: any)
			states[player] = Progression.fromSaved(data)
			publish(player)
		end,
	})
end

function ProgressionService.start()
	Net.event("PerkUpgrade").OnServerEvent:Connect(onUpgrade)
	Players.PlayerAdded:Connect(function(player)
		stateOf(player)
		task.defer(publish, player)
	end)
	for _, player in Players:GetPlayers() do
		stateOf(player)
		task.defer(publish, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return ProgressionService
