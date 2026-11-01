--!strict
-- BowState: the draw of each player's bow, for the first-person and third-person poses. ToolController
-- starts a draw on the local player's click and releases it when it sends the shot; other players'
-- bows only show the release and the next arrow being nocked (from the server's ArrowFired).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

-- Seconds the string snaps forward after a release, and the gap before the next arrow sits on it.
local SNAP_SECONDS = 0.08
local RENOCK_SECONDS = 0.45

type State = { drawnAt: number?, releasedAt: number? }

local BowState = {}

local states: { [Player]: State } = {}
Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

local function stateOf(player: Player): State
	local state = states[player]
	if state == nil then
		state = {}
		states[player] = state
	end
	return state
end

function BowState.drawSeconds(): number
	return Config.Ranged.Weapons.PrimitiveBow.DrawSeconds or 0.35
end

function BowState.start(player: Player)
	local state = stateOf(player)
	state.drawnAt = os.clock()
	state.releasedAt = nil
end

function BowState.release(player: Player)
	local state = stateOf(player)
	state.drawnAt = nil
	state.releasedAt = os.clock()
end

function BowState.cancel(player: Player)
	states[player] = nil
end

-- How far the string is drawn (0 rest .. 1 full) and whether an arrow sits on it.
function BowState.sample(player: Player): (number, boolean)
	local state = states[player]
	if state == nil then
		return 0, true
	end
	local now = os.clock()
	if state.drawnAt then
		local t = math.clamp((now - state.drawnAt) / BowState.drawSeconds(), 0, 1)
		return 1 - (1 - t) * (1 - t), true
	end
	if state.releasedAt then
		local since = now - state.releasedAt
		if since >= RENOCK_SECONDS then
			states[player] = nil
			return 0, true
		end
		return math.max(0, 1 - since / SNAP_SECONDS), false
	end
	return 0, true
end

return BowState
