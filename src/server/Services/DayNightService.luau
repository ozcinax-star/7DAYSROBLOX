--!strict
-- DayNightService: the world clock (Shared/DayClock). The server keeps the clock's start time in a
-- ReplicatedStorage attribute and clients compute the same clock from it every frame, so nothing is
-- sent per second. Other services read the current phase and listen for phase changes (zombie
-- population, horde night). The horde night interval is fixed when the world is created (PLAN).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local DayClock = require(Shared.DayClock)
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local DC = Config.DayNight
-- A skip lands this far past the phase boundary so rounding cannot leave it in the old phase.
local SKIP_MARGIN = 0.05

export type PhaseCallback = (phase: Types.DayPhase, day: number, horde: boolean) -> ()

local DayNightService = {}

-- Server time of the dawn of day 1.
local epoch = 0
local hordeEvery = DC.HordeNightDefault
local current: DayClock.State
local callbacks: { PhaseCallback } = {}
local sinceCheck = 0

local function publish()
	ReplicatedStorage:SetAttribute(Net.Attributes.ClockEpoch, epoch)
	ReplicatedStorage:SetAttribute(Net.Attributes.HordeEvery, hordeEvery)
end

function DayNightService.getState(): DayClock.State
	return DayClock.at(Workspace:GetServerTimeNow() - epoch)
end

function DayNightService.isNight(): boolean
	return DayNightService.getState().phase == "Night"
end

-- True during the night of a horde day.
function DayNightService.isHordeNight(): boolean
	local state = DayNightService.getState()
	return state.phase == "Night" and DayClock.isHordeDay(state.day, hordeEvery)
end

local function check()
	local state = DayNightService.getState()
	if state.phase == current.phase and state.day == current.day then
		return
	end
	current = state
	local horde = state.phase == "Night" and DayClock.isHordeDay(state.day, hordeEvery)
	for _, callback in callbacks do
		task.spawn(callback, state.phase, state.day, horde)
	end
end

-- Calls `callback` when day turns to night or night to day.
function DayNightService.onPhaseChanged(callback: PhaseCallback)
	table.insert(callbacks, callback)
end

-- Debug: jumps to the start of the next phase.
function DayNightService.skipPhase()
	epoch -= DayNightService.getState().phaseLeft + SKIP_MARGIN
	publish()
	check()
end

function DayNightService.init()
	epoch = Workspace:GetServerTimeNow() - DayClock.secondsAt(DC.StartClockTime)
	current = DayNightService.getState()
	publish()
end

function DayNightService.start()
	RunService.Heartbeat:Connect(function(dt)
		sinceCheck += dt
		if sinceCheck >= DC.BroadcastInterval then
			sinceCheck = 0
			check()
		end
	end)
end

return DayNightService
