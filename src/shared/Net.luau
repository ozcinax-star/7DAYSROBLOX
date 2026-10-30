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
	-- Client -> server: swing the held tool (aim direction: unit Vector3 from the head).
	UseTool = "RemoteEvent",
	-- Server -> client: a swing happened (player, tool id or "Fist", hit zombie id or 0, head hit).
	ToolSwing = "UnreliableRemoteEvent",
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
}

local Net = {}

-- Attribute names shared by server and client. Stats live on ReplicatedStorage, DebugAllowed on Player.
Net.Attributes = {
	TickMs = "ServerTickMs",
	TickMaxMs = "ServerTickMaxMs",
	ServerFps = "ServerFps",
	ZombieCount = "ZombieCount",
	ZombieQueued = "ZombieQueued",
	ZombieStepsPerSecond = "ZombieStepsPerSecond",
	DebugAllowed = "DebugAllowed",
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
