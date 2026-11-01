--!strict
-- Every sound effect goes through here: a Config.Sounds event name picks a random take and pitch,
-- plays positionally at a point (or flat for the local player), and cleans itself up. Also runs the
-- day and night ambient beds and the crackle of lit fires near the camera.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local DayClock = require(Shared.DayClock)
local Net = require(Shared.Net)

local SoundController = {}
local SC = Config.Sounds
-- Sounds of one event still playing, so a burst cannot stack past MaxPerEvent.
local playing: { [string]: number } = {}
-- Positional one-shots hang off attachments on the terrain; flat ones sit in this folder.
local flatFolder: Folder
local ambientDay: Sound? = nil
local ambientNight: Sound? = nil
local nightBlend = 0
-- Lit fire part -> its looping crackle.
local fires: { [BasePart]: Sound } = {}
local nextFireCheck = 0

local function configure(sound: Sound, def: Config.SoundDef)
	sound.SoundId = def.Ids[math.random(1, #def.Ids)]
	sound.Volume = def.Volume
	local pitch = def.Pitch
	sound.PlaybackSpeed = if pitch then pitch[1] + math.random() * (pitch[2] - pitch[1]) else 1
	local region = def.Region
	if region then
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(region[1], region[2])
	end
	sound.Looped = def.Looped == true
	if def.Range then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = math.min(10, def.Range * 0.1)
		sound.RollOffMaxDistance = def.Range
	end
end

-- Plays `name` once. With `at`, it is heard from that point (only within the event's Range); without,
-- flat. Unknown names, full events and points out of earshot do nothing.
function SoundController.play(name: string, at: Vector3?)
	local def = SC.Events[name]
	if def == nil or (playing[name] or 0) >= SC.MaxPerEvent then
		return
	end
	local camera = Workspace.CurrentCamera
	if at and def.Range and camera and (camera.CFrame.Position - at).Magnitude > def.Range then
		return
	end
	local sound = Instance.new("Sound")
	configure(sound, def)
	sound.Looped = false
	local holder: Instance
	if at and def.Range then
		local point = Instance.new("Attachment")
		point.Name = name
		point.WorldPosition = at
		point.Parent = Workspace.Terrain
		sound.Parent = point
		holder = point
	else
		sound.Parent = flatFolder
		holder = sound
	end
	playing[name] = (playing[name] or 0) + 1
	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		playing[name] = math.max(0, (playing[name] or 1) - 1)
		holder:Destroy()
	end
	sound.Ended:Once(finish)
	-- Ended never fires for an asset that fails to load; the longest one-shot is under 6 s.
	local length = if def.Region then def.Region[2] - def.Region[1] else 6
	task.delay(length / sound.PlaybackSpeed + 1, finish)
	sound:Play()
end

local function loop(name: string, parent: Instance): Sound?
	local def = SC.Events[name]
	if def == nil then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	configure(sound, def)
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = parent
	sound:Play()
	return sound
end

local function updateAmbient(dt: number)
	local epoch = ReplicatedStorage:GetAttribute(Net.Attributes.ClockEpoch)
	if typeof(epoch) ~= "number" then
		return
	end
	local state = DayClock.at(Workspace:GetServerTimeNow() - epoch)
	local target = if state.phase == "Night" then 1 else 0
	nightBlend += math.clamp(target - nightBlend, -dt / SC.AmbientFadeSeconds, dt / SC.AmbientFadeSeconds)
	if ambientDay then
		ambientDay.Volume = SC.Events[SC.AmbientDay].Volume * (1 - nightBlend)
	end
	if ambientNight then
		ambientNight.Volume = SC.Events[SC.AmbientNight].Volume * nightBlend
	end
end

local function updateFires(now: number)
	if now < nextFireCheck then
		return
	end
	nextFireCheck = now + SC.FireCheckSeconds
	local camera = Workspace.CurrentCamera
	local structures = Workspace:FindFirstChild("Structures")
	if camera == nil or structures == nil then
		return
	end
	local eye = camera.CFrame.Position
	local seen: { [BasePart]: boolean } = {}
	for _, part in structures:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute(Net.Attributes.StationLit) == true
			and (part.Position - eye).Magnitude <= SC.FireHearRange then
			seen[part] = true
			if fires[part] == nil then
				local crackle = loop("FireCrackle", part)
				if crackle then
					crackle.Volume = SC.Events.FireCrackle.Volume
					fires[part] = crackle
				end
			end
		end
	end
	for part, crackle in fires do
		if not seen[part] or part.Parent == nil then
			crackle:Destroy()
			fires[part] = nil
		end
	end
end

function SoundController.init() end

function SoundController.start()
	flatFolder = Instance.new("Folder")
	flatFolder.Name = "FlatSounds"
	flatFolder.Parent = SoundService
	ambientDay = loop(SC.AmbientDay, flatFolder)
	ambientNight = loop(SC.AmbientNight, flatFolder)
	-- World events the server decides (doors, placed and broken blocks): name and point.
	Net.unreliable("WorldSound").OnClientEvent:Connect(function(name: unknown, at: unknown)
		if typeof(name) == "string" and typeof(at) == "Vector3" then
			SoundController.play(name, at)
		end
	end)
	RunService.PreRender:Connect(function(dt: number)
		updateAmbient(dt)
		updateFires(os.clock())
	end)
end

return SoundController
