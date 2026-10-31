--!strict
-- ChallengeService: the 7DTD challenge chain (Config.Challenges), the game's tutorial. Each player
-- tracks one challenge at a time and only it counts, like 7DTD's linked challenges. Other services
-- report what players do (`record`: crafts, placed and upgraded blocks, harvests with the held tool,
-- lake drinks); zombie kills come from ZombieService and Gather objectives read the inventory whenever
-- it changes. The client is sent the tracked challenge (ChallengeUpdate) and only displays it.
-- Progress lives for the session; saving comes with the persistence step.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Challenges = require(Shared.Challenges)
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local InventoryService = require(script.Parent.InventoryService)
local ZombieService = require(script.Parent.ZombieService)

type State = {
	-- Index into Config.Challenges of the tracked challenge (past the end: all done).
	index: number,
	-- Count per objective of the tracked challenge.
	progress: { number },
}

local ChallengeService = {}

local states: { [Player]: State } = {}
local updateRemote: RemoteEvent

local function send(player: Player, state: State, completed: string?)
	local def = Config.Challenges[state.index]
	if def == nil then
		updateRemote:FireClient(player, false, completed)
		return
	end
	local objectives: { Challenges.ObjectiveView } = {}
	for index, objective in def.Objectives do
		table.insert(objectives, {
			kind = objective.Kind,
			item = objective.Item,
			held = objective.Held,
			have = math.min(objective.Count, state.progress[index] or 0),
			need = objective.Count,
		})
	end
	local position, total = Challenges.position(state.index)
	local view: Challenges.View = {
		id = def.Id,
		group = def.Group,
		index = position,
		total = total,
		objectives = objectives,
		completed = completed,
	}
	updateRemote:FireClient(player, view)
end

-- Gather objectives of the tracked challenge count what the inventory holds now; true if any changed.
local function readInventory(player: Player, state: State): boolean
	local def = Config.Challenges[state.index]
	if def == nil then
		return false
	end
	local changed = false
	for index, objective in def.Objectives do
		local item = objective.Item
		if objective.Kind == "Gather" and item then
			local have = math.min(objective.Count, InventoryService.count(player, item))
			-- A gathered objective stays met when the items are used afterwards.
			if have > (state.progress[index] or 0) then
				state.progress[index] = have
				changed = true
			end
		end
	end
	return changed
end

-- Moves past every finished challenge, then tells the client.
local function advance(player: Player, state: State)
	local completed: string? = nil
	while true do
		local def = Config.Challenges[state.index]
		if def == nil or not Challenges.isComplete(def, state.progress) then
			break
		end
		completed = def.Id
		state.index += 1
		state.progress = {}
		readInventory(player, state)
	end
	send(player, state, completed)
end

-- Counts `count` of an event toward the tracked challenge of `player`.
function ChallengeService.record(
	player: Player,
	kind: Config.ChallengeKind,
	item: string?,
	count: number,
	held: string?
)
	local state = states[player]
	local def = state and Config.Challenges[state.index]
	if state == nil or def == nil or count <= 0 then
		return
	end
	local changed = false
	for index, objective in def.Objectives do
		if objective.Kind ~= "Gather" and Challenges.matches(objective, kind, item, held) then
			local now = math.min(objective.Count, (state.progress[index] or 0) + count)
			if now ~= state.progress[index] then
				state.progress[index] = now
				changed = true
			end
		end
	end
	if changed then
		advance(player, state)
	end
end

local function onPlayerAdded(player: Player)
	local state: State = { index = 1, progress = {} }
	states[player] = state
	task.defer(function()
		if states[player] == state then
			readInventory(player, state)
			advance(player, state)
		end
	end)
end

function ChallengeService.init()
	updateRemote = Net.event("ChallengeUpdate")
end

function ChallengeService.start()
	InventoryService.onChanged(function(player)
		local state = states[player]
		if state and readInventory(player, state) then
			advance(player, state)
		end
	end)
	ZombieService.onDied(function(_x, _y, _z, killer)
		if killer then
			ChallengeService.record(killer, "Kill", nil, 1)
		end
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		if states[player] == nil then
			onPlayerAdded(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return ChallengeService
