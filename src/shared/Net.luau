--!strict
-- Remote definitions. The server creates them on startup; clients wait for them.
-- Every client -> server remote must be validated (type, range, rate) by its handler.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local Definitions: { [string]: "RemoteEvent" | "UnreliableRemoteEvent" } = {
	-- Server -> client: zombie position snapshots (buffer).
	ZombieSnapshot = "UnreliableRemoteEvent",
	-- Server -> client: ids of removed zombies ({ number }).
	ZombieRemoved = "RemoteEvent",
	-- Client -> server: debug command (string, number?). Studio / allowlist only.
	DebugCommand = "RemoteEvent",
	-- Server -> client: the player's own inventory ({ Inventory.Slot }) and active toolbelt slot (number).
	InventoryUpdate = "RemoteEvent",
	-- Client -> server: move items between own slots (from: number, to: number, count: number?).
	InventoryMove = "RemoteEvent",
	-- Client -> server: choose the active toolbelt slot (number).
	InventorySelect = "RemoteEvent",
	-- Client -> server: drop the whole stack in an own slot on the ground (slot: number).
	InventoryDrop = "RemoteEvent",
	-- Client -> server: the player starts or stops aiming a gun (boolean).
	AimIntent = "RemoteEvent",
	-- Client -> server: swing the held tool (aim direction: unit Vector3 from the head).
	UseTool = "RemoteEvent",
	-- Server -> client: a swing happened (player, tool id or "Fist", hit zombie id or 0, head hit).
	ToolSwing = "UnreliableRemoteEvent",
	-- Server -> client: what the player's last swing hit in the world has this much health left
	-- (remaining: number, maximum: number).
	HitInfo = "UnreliableRemoteEvent",
	-- Server -> client: items entered the player's inventory (item id, count added, count that did not fit).
	InventoryGain = "RemoteEvent",
	-- Server -> client: a tree was felled (tree model, trunk base Vector3, horizontal unit fall direction).
	TreeFelled = "RemoteEvent",
	-- Client -> server: queue crafts (recipe id: string, count: number).
	CraftQueue = "RemoteEvent",
	-- Client -> server: cancel a queued job (queue index: number).
	CraftCancel = "RemoteEvent",
	-- Client -> server: repair the tool in an inventory slot (slot index: number).
	CraftRepair = "RemoteEvent",
	-- Server -> client: the player's crafting queue ({ CraftingService.JobView }, server time: number).
	CraftUpdate = "RemoteEvent",
	-- Client -> server: sprint held or released (boolean).
	SprintIntent = "RemoteEvent",
	-- Server -> client: an arrow, bullet or pellet left a weapon (arrow id, origin Vector3, velocity
	-- Vector3, gravity, server launch time, ammo id, weapon item id).
	ArrowFired = "UnreliableRemoteEvent",
	-- Server -> client: an arrow stopped (arrow id, Vector3 where, id of the zombie it hit or 0).
	ArrowStopped = "UnreliableRemoteEvent",
	-- Client -> server: act on the open storage crate (action: "Take" crate slot | "Put" own slot,
	-- crate slot? | "TakeAll" | "Close").
	StorageAction = "RemoteEvent",
	-- Server -> client: the open crate's slots ({ Inventory.Slot }), or false when it closed.
	StorageUpdate = "RemoteEvent",
}

local Net = {}

-- Attribute names shared by server and client. Stats live on ReplicatedStorage; DebugAllowed and the
-- survival stats on Player.
Net.Attributes = {
	TickMs = "ServerTickMs",
	TickMaxMs = "ServerTickMaxMs",
	ServerFps = "ServerFps",
	ZombieCount = "ZombieCount",
	ZombieQueued = "ZombieQueued",
	ZombieStepsPerSecond = "ZombieStepsPerSecond",
	DebugAllowed = "DebugAllowed",
	-- World clock (DayNightService): server time of the dawn of day 1, and the horde night interval.
	ClockEpoch = "ClockEpoch",
	HordeEvery = "HordeEvery",
	-- Threat and population, for the debug overlay only (PLAN: no threat meter on screen).
	ThreatTier = "ThreatTier",
	ThreatLevel = "ThreatLevel",
	ThreatNoise = "ThreatNoise",
	ThreatTrace = "ThreatTrace",
	AmbientCount = "AmbientCount",
	AmbientTarget = "AmbientTarget",
	HordeLeft = "HordeLeft",
	DirectorEnabled = "DirectorEnabled",
	-- Survival stats of a player, on that Player (SurvivalService): current values, the stamina the
	-- bar can hold, and the hunger and thirst stages.
	Stamina = "Stamina",
	StaminaCap = "StaminaCap",
	Food = "Food",
	Water = "Water",
	Hunger = "Hunger",
	Thirst = "Thirst",
}

local function getFolder(): Folder
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if folder == nil then
			local created = Instance.new("Folder")
			created.Name = FOLDER_NAME
			created.Parent = ReplicatedStorage
			return created
		end
		return folder :: Folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local function get(name: string): Instance
	local className = Definitions[name]
	assert(className, `[Net] unknown remote: {name}`)
	local folder = getFolder()
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing
		end
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name)
end

function Net.event(name: string): RemoteEvent
	return get(name) :: RemoteEvent
end

function Net.unreliable(name: string): UnreliableRemoteEvent
	return get(name) :: UnreliableRemoteEvent
end

return Net
