--!strict
-- CraftingService: 7DTD backpack crafting. Every player has a queue of up to four jobs; only the first
-- one works, on the server clock, and keeps going while the backpack is closed. Ingredients leave the
-- inventory when a job is queued and stay in the job's pool with their sources; each finished craft
-- uses its share and a cancel gives the rest back. A finished item that does not fit waits in the
-- queue until there is room, so nothing is lost. Repairs use the same queue: the tool and its repair
-- items go into the job and the tool comes back repaired, into its old slot when that is still free.
-- What a cancel cannot give back drops in a loot bag at the player's feet; with no character to drop
-- it at, a cancel that does not all fit is refused, so nothing is lost.
--
-- Station recipes (cooking) are queued only next to a placed station of their kind, lit when it is a
-- fire station (a campfire, StationService), and, when they name a tool (cooking pot, grill), only
-- while the player carries it; the job then runs in the player's queue like any other.
--
-- Queues live only as long as the player is in the server (no saving yet).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Crafting = require(Shared.Crafting)
local Inventory = require(Shared.Inventory)
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local BuildService = require(script.Parent.BuildService)
local ChallengeService = require(script.Parent.ChallengeService)
local InventoryService = require(script.Parent.InventoryService)
local LootService = require(script.Parent.LootService)
local StationService = require(script.Parent.StationService)
local PersistenceService = require(script.Parent.PersistenceService)

local CC = Config.Crafting
local SOURCE: Types.ItemSource = "Craft"

type Job = {
	kind: "Craft" | "Repair",
	-- Recipe id for crafts, the tool's item id for repairs.
	id: string,
	-- Crafts still to make (a repair is one).
	left: number,
	unitSeconds: number,
	-- Seconds worked on the current craft.
	progress: number,
	-- Ingredients still held for the unfinished crafts.
	pool: { Inventory.Stack },
	unitCosts: { [string]: number },
	-- True while a finished item waits for room.
	waiting: boolean,
	-- Repairs: the tool, the slot it came from, and the durability it gets back.
	tool: Inventory.Stack?,
	slot: number,
	restore: number,
}

-- What the client sees of a job (Net: CraftUpdate).
export type JobView = {
	kind: string,
	id: string,
	left: number,
	unitSeconds: number,
	progress: number,
	waiting: boolean,
}

local CraftingService = {}

local queues: { [Player]: { Job } } = {}
local limiter: RateLimiter.RateLimiter
local updateRemote: RemoteEvent

local function isCount(value: unknown, max: number): boolean
	return typeof(value) == "number" and value == value and value % 1 == 0 and value >= 1 and value <= max
end

-- The player's queue, or nil once they have left (a late request must not recreate it).
local function queueOf(player: Player): { Job }?
	if InventoryService.get(player) == nil then
		return nil
	end
	local queue = queues[player]
	if queue == nil then
		queue = {}
		queues[player] = queue
	end
	return queue
end

-- Sends the player their queue; the client counts the first job down from `progress` at `sentAt`.
local function send(player: Player)
	local views: { JobView } = {}
	for _, job in queues[player] or {} do
		table.insert(views, {
			kind = job.kind,
			id = job.id,
			left = job.left,
			unitSeconds = job.unitSeconds,
			progress = job.progress,
			waiting = job.waiting,
		})
	end
	updateRemote:FireClient(player, views, Workspace:GetServerTimeNow())
end

-- Gives back everything a job still holds (the tool into its old slot when that is free); what does
-- not fit drops in a bag at the player's feet. Without a character it is all or nothing, and false
-- means nothing changed.
local function refund(player: Player, job: Job): boolean
	local returns: { Inventory.Return } = {}
	local tool = job.tool
	if tool then
		table.insert(returns, { stack = tool, slot = job.slot })
	end
	for _, stack in job.pool do
		table.insert(returns, { stack = stack, slot = nil })
	end
	local character = player.Character
	local root = character and character.PrimaryPart
	if root == nil then
		return InventoryService.giveBack(player, returns)
	end
	local dropped: { Inventory.Stack } = {}
	for _, entry in returns do
		local stack = entry.stack
		local slot = entry.slot
		local left = 0
		if slot == nil or not InventoryService.putSlot(player, slot, table.clone(stack)) then
			left = InventoryService.give(player, stack.id, stack.count, stack.source, stack.durability, stack)
		end
		if left > 0 then
			local remainder = table.clone(stack)
			remainder.count = left
			table.insert(dropped, remainder)
		end
	end
	if #dropped > 0 then
		LootService.drop(root.Position, dropped, true)
	end
	return true
end

-- Hands over one finished craft or the repaired tool; false when it does not fit yet.
local function deliver(player: Player, job: Job): boolean
	local tool = job.tool
	if tool then
		local repaired = table.clone(tool)
		repaired.durability = math.min(Config.Items[tool.id].Durability or 0, (tool.durability or 0) + job.restore)
		if InventoryService.putSlot(player, job.slot, repaired) then
			return true
		end
		if InventoryService.room(player, tool.id, tool.source) < 1 then
			return false
		end
		InventoryService.give(player, tool.id, 1, tool.source, repaired.durability, repaired)
		return true
	end
	local recipe = Config.Recipes[job.id]
	if InventoryService.room(player, recipe.Output, SOURCE) < recipe.Count then
		return false
	end
	InventoryService.give(player, recipe.Output, recipe.Count, SOURCE)
	ChallengeService.record(player, "Craft", recipe.Output, recipe.Count)
	return true
end

local function step(player: Player, queue: { Job }, dt: number)
	local job = queue[1]
	if job == nil then
		return
	end
	if not job.waiting then
		job.progress += dt
	end
	if job.progress < job.unitSeconds then
		return
	end
	if not deliver(player, job) then
		if not job.waiting then
			job.waiting = true
			send(player)
		end
		return
	end
	job.waiting = false
	Crafting.draw(job.pool, job.unitCosts)
	job.left -= 1
	job.progress -= job.unitSeconds
	if job.left <= 0 then
		table.remove(queue, 1)
		local nextJob = queue[1]
		if nextJob then
			nextJob.progress = job.progress
		end
	end
	send(player)
end

local function onQueue(player: Player, recipeId: unknown, count: unknown)
	if not limiter:allow(player) then
		return
	end
	if typeof(recipeId) ~= "string" or Config.Recipes[recipeId] == nil or not isCount(count, CC.MaxCount) then
		return
	end
	local queue = queueOf(player)
	if queue == nil or #queue >= CC.QueueSlots then
		return
	end
	local recipe = Config.Recipes[recipeId]
	local function countOf(id: string): number
		return InventoryService.count(player, id)
	end
	local function stationNear(kind: string): boolean
		local character = player.Character
		local root = character and character.PrimaryPart
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root == nil or humanoid == nil or humanoid.Health <= 0 then
			return false
		end
		if Config.Stations.Kinds[kind] then
			return StationService.litNear(kind, root.Position, CC.StationReach)
		end
		return BuildService.near(kind, root.Position, CC.StationReach)
	end
	if not Crafting.canUse(recipe, countOf, stationNear) then
		return
	end
	local crafts = count :: number
	local ok, taken = InventoryService.take(player, Crafting.costs(recipe, crafts))
	if not ok then
		return
	end
	table.insert(queue, {
		kind = "Craft",
		id = recipeId,
		left = crafts,
		unitSeconds = Crafting.unitSeconds(recipe),
		progress = 0,
		pool = taken,
		unitCosts = Crafting.costs(recipe, 1),
		waiting = false,
		tool = nil,
		slot = 0,
		restore = 0,
	})
	send(player)
end

local function onCancel(player: Player, index: unknown)
	if not limiter:allow(player) then
		return
	end
	local queue = queueOf(player)
	if queue == nil or not isCount(index, #queue) then
		return
	end
	if refund(player, queue[index :: number]) then
		table.remove(queue, index :: number)
		send(player)
	end
end

local function onRepair(player: Player, slot: unknown)
	if not limiter:allow(player) or typeof(slot) ~= "number" then
		return
	end
	local queue = queueOf(player)
	if queue == nil or #queue >= CC.QueueSlots then
		return
	end
	local stack = InventoryService.peekSlot(player, slot)
	local item = stack and Config.Items[stack.id]
	local repair = item and item.Repair
	if stack == nil or item == nil or repair == nil or item.Durability == nil or stack.durability == nil then
		return
	end
	local missing = item.Durability - stack.durability
	if missing <= 0 then
		return
	end
	local units = Crafting.repairUnits(missing, repair.Amount)
	local ok, taken = InventoryService.take(player, { [repair.Id] = units })
	if not ok then
		return
	end
	local tool = InventoryService.takeSlot(player, slot)
	if tool == nil then
		for _, stone in taken do
			InventoryService.give(player, stone.id, stone.count, stone.source)
		end
		return
	end
	table.insert(queue, {
		kind = "Repair",
		id = tool.id,
		left = 1,
		unitSeconds = units * repair.Seconds,
		progress = 0,
		pool = taken,
		unitCosts = { [repair.Id] = units },
		waiting = false,
		tool = tool,
		slot = slot,
		restore = units * repair.Amount,
	})
	send(player)
end

-- Saved character part "Crafting": the queue is not resumed, but what it holds (ingredients already
-- taken, a tool being repaired) comes back as items, so leaving mid-craft never loses them.
local function saveCrafting(player: Player): any
	local queue = queues[player]
	if queue == nil then
		return nil
	end
	local held = Inventory.new(0, 0)
	for _, job in queue do
		for _, stack in job.pool do
			table.insert(held.slots, stack)
		end
		if job.tool then
			table.insert(held.slots, job.tool)
		end
	end
	return Inventory.serialize(held)
end

local function loadCrafting(player: Player, data: any)
	if type(data) ~= "table" then
		return
	end
	local held = Inventory.new(0, #data)
	Inventory.deserialize(held, data)
	for _, stack in held.slots do
		if stack then
			local left = InventoryService.give(player, stack.id, stack.count, stack.source, stack.durability, stack)
			local character = player.Character
			local root = character and character.PrimaryPart
			if left > 0 and root then
				LootService.drop(root.Position, { { id = stack.id, count = left, source = stack.source, durability = stack.durability } }, true)
			end
		end
	end
end

function CraftingService.init()
	PersistenceService.registerCharacter("Crafting", { save = saveCrafting, load = loadCrafting })
	limiter = RateLimiter.new(Config.Remotes.CraftRequestsPerSecond)
	updateRemote = Net.event("CraftUpdate")
	Net.event("CraftQueue")
	Net.event("CraftCancel")
	Net.event("CraftRepair")
end

function CraftingService.start()
	Net.event("CraftQueue").OnServerEvent:Connect(onQueue)
	Net.event("CraftCancel").OnServerEvent:Connect(onCancel)
	Net.event("CraftRepair").OnServerEvent:Connect(onRepair)
	Players.PlayerRemoving:Connect(function(player)
		queues[player] = nil
	end)
	RunService.Heartbeat:Connect(function(dt)
		for player, queue in queues do
			step(player, queue, dt)
		end
	end)
end

return CraftingService
