--!strict
-- HarvestService: gathering (7DTD). A swing that hits a tree, bush, grass, boulder, loose rock, piece
-- of town furniture or window pane deals the tool's block damage for that material. Harvest drops pay
-- out while the object is hit and Destroy drops when it breaks (Shared/Harvest). Everyone hitting the
-- same object shares its damage, like a 7DTD block. Loose rocks can also be picked up with the
-- interact key. What has no room in the inventory drops in a loot bag at the player's feet (7DTD drops
-- it on the ground).
--
-- A felled tree stops colliding at once, frees the zombie navigation cells under it, and falls away
-- from the player who felled it (clients animate the fall), then is removed. Nothing grows back:
-- 7DTD's natural trees and rocks do not respawn. Broken furniture frees its cells too, and a container
-- spills what it holds into a loot bag.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Harvest = require(Shared.Harvest)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local ChallengeService = require(script.Parent.ChallengeService)
local LootService = require(script.Parent.LootService)
local MapService = require(script.Parent.MapService)
local ThreatService = require(script.Parent.ThreatService)
local ToolService = require(script.Parent.ToolService)
local ZombieService = require(script.Parent.ZombieService)
local PersistenceService = require(script.Parent.PersistenceService)

local HC = Config.Harvest
-- Gathered items count as found in the world.
local SOURCE: Types.ItemSource = "Loot"
local TREES = { TreeSmall = true, TreeMedium = true, TreeLarge = true, TreeFull = true }
-- A pickup may come from slightly further than the prompt's range (the character moves on the server).
local PICKUP_TOLERANCE = 2

type Entry = {
	-- Stable id from the map generator (MapService.Harvestable), for a later world save.
	id: string,
	node: Config.HarvestNode,
	tree: boolean,
	furniture: boolean,
	model: Model,
	-- Cumulative damage, at most node.Health.
	damage: number,
}

local HarvestService = {}

local entries: { [Model]: Entry } = {}
local random = Random.new()
local pickupLimiter: RateLimiter.RateLimiter
local fellRemote: RemoteEvent

local function roll(drop: Config.Drop): number
	return random:NextInteger(drop.Min, drop.Max)
end

-- Ids of objects broken or felled in this world (saved).
local gone: { [string]: boolean } = {}

local function give(player: Player, id: string, count: number)
	LootService.giveOrDrop(player, id, count, SOURCE)
end

-- Stops every part of the model colliding and catching raycasts, then frees the navigation cells it
-- covered.
local function release(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
		end
	end
	local cframe, size = model:GetBoundingBox()
	local radius = math.max(size.X, size.Z) / 2
	local p = cframe.Position
	ZombieService.reopenArea(p.X - radius, p.Z - radius, p.X + radius, p.Z + radius)
end

local function fell(model: Model, player: Player)
	local trunk = model:FindFirstChild("Trunk")
	local character = player.Character
	local root = character and character.PrimaryPart
	if trunk and trunk:IsA("BasePart") and root then
		-- The trunk is an upright cylinder: its length is Size.X.
		local base = trunk.Position - Vector3.new(0, trunk.Size.X / 2, 0)
		local away = (base - root.Position) * Vector3.new(1, 0, 1)
		local direction = if away.Magnitude > 1e-3 then away.Unit else Vector3.new(1, 0, 0)
		fellRemote:FireAllClients(model, base, direction)
		ThreatService.emit("TreeFall", base)
	end
	release(model)
	task.delay(HC.FallSeconds + HC.FadeSeconds, model.Destroy, model)
end

-- Damages an object for one hit by `player` with `toolId` and pays what that hit earned; breaks it at
-- full damage.
local function hit(entry: Entry, player: Player, damage: number, toolId: string, tool: Config.ToolDef)
	local node = entry.node
	local before = entry.damage
	local after = math.min(node.Health, before + damage)
	entry.damage = after
	ToolService.reportHit(player, node.Health - after, node.Health)
	for _, drop in node.Harvest do
		local count = Harvest.toolCount(roll(drop), tool, drop.Id)
		local paid = Harvest.payout(count, node.Health, before, after)
		give(player, drop.Id, paid)
		if paid > 0 then
			ChallengeService.record(player, "Harvest", drop.Id, paid, toolId)
		end
	end
	if after < node.Health then
		return
	end
	entries[entry.model] = nil
	-- Nothing grows back (7DTD trees and boulders stay gone in a save); the world remembers it.
	gone[entry.id] = true
	for _, drop in node.Destroy do
		give(player, drop.Id, roll(drop))
	end
	if entry.tree then
		fell(entry.model, player)
	else
		release(entry.model)
		-- After release, so the bag lands on the floor instead of on the furniture.
		if entry.furniture then
			LootService.spillContainer(entry.model)
		end
		entry.model:Destroy()
	end
end

local function onWorldHit(player: Player, result: RaycastResult, toolId: string, tool: Config.ToolDef)
	local model = result.Instance.Parent
	local entry = if model and model:IsA("Model") then entries[model] else nil
	if entry == nil then
		return
	end
	-- Chopping and mining are heard (7DTD heat); cutting grass or a bush is not.
	if entry.node.Material ~= "Earth" then
		ThreatService.emit("Harvest", result.Position, player)
	end
	hit(entry, player, Harvest.blockDamage(tool.BlockDamage, tool.Materials[entry.node.Material]), toolId, tool)
end

local function onPickup(player: Player, entry: Entry, part: BasePart)
	if not pickupLimiter:allow(player) or entries[entry.model] ~= entry then
		return
	end
	local character = player.Character
	local root = character and character.PrimaryPart
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	if (root.Position - part.Position).Magnitude > HC.PickupDistance + PICKUP_TOLERANCE then
		return
	end
	-- Picking up takes the whole object, as if one bare-handed hit broke it.
	hit(entry, player, entry.node.Health, "Fist", Config.Tools.Fist)
end

-- Loose rocks get an interact prompt (7DTD: rocks can be picked up as small stones).
local function addPickupPrompt(entry: Entry)
	local part = entry.model:FindFirstChildWhichIsA("BasePart")
	local drop = entry.node.Destroy[1]
	if part == nil or drop == nil then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Localization.get("HarvestPickUp")
	prompt.ObjectText = Localization.get(`Item{drop.Id}`)
	prompt.MaxActivationDistance = HC.PickupDistance
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Triggered:Connect(function(player)
		onPickup(player, entry, part)
	end)
	prompt.Parent = part
end

-- Saved world part "Harvest": objects already broken, and the damage on ones partly worked.
local function saveHarvest(): any
	local goneOut = {}
	for id in gone do
		table.insert(goneOut, id)
	end
	local damaged = {}
	for _, entry in entries do
		if entry.damage > 0 then
			table.insert(damaged, { entry.id, entry.damage })
		end
	end
	return { Gone = goneOut, Damage = damaged }
end

local function loadHarvest(data: any)
	if type(data) ~= "table" then
		return
	end
	local byId: { [string]: Entry } = {}
	for _, entry in entries do
		byId[entry.id] = entry
	end
	if type(data.Gone) == "table" then
		for _, id in data.Gone do
			local entry = type(id) == "string" and byId[id]
			if entry then
				gone[id] = true
				entries[entry.model] = nil
				release(entry.model)
				entry.model:Destroy()
			end
		end
	end
	if type(data.Damage) == "table" then
		for _, row in data.Damage do
			local entry = type(row) == "table" and byId[row[1]]
			local damage = row[2]
			if entry and entries[entry.model] and type(damage) == "number" and damage == damage then
				entry.damage = math.clamp(damage, 0, entry.node.Health - 1)
			end
		end
	end
end

function HarvestService.init()
	PersistenceService.registerWorld("Harvest", { save = saveHarvest, load = loadHarvest })
	pickupLimiter = RateLimiter.new(HC.PickupsPerSecond)
	fellRemote = Net.event("TreeFelled")
end

function HarvestService.start()
	for _, harvestable in MapService.getHarvestables() do
		local node = HC.Nodes[harvestable.node]
		assert(node, `unknown harvest node {harvestable.node}`)
		local entry: Entry = {
			id = harvestable.id,
			node = node,
			tree = TREES[harvestable.node] == true,
			furniture = false,
			model = harvestable.model,
			damage = 0,
		}
		entries[harvestable.model] = entry
		if harvestable.node == "LooseRock" then
			addPickupPrompt(entry)
		end
	end
	-- Town furniture (by its "Furniture" attribute) and other map models that name their node (window
	-- panes, "HarvestNode").
	for _, model in MapService.getMap():GetDescendants() do
		if not model:IsA("Model") then
			continue
		end
		local furniture = model:GetAttribute("Furniture")
		local nodeName = if typeof(furniture) == "string"
			then HC.Furniture[furniture]
			else model:GetAttribute("HarvestNode")
		if typeof(nodeName) ~= "string" then
			continue
		end
		local node = HC.Nodes[nodeName]
		assert(node, `unknown harvest node {nodeName}`)
		local p = model:GetPivot().Position
		entries[model] = {
			id = if typeof(furniture) == "string"
				then `furniture:{model:GetAttribute("FurnitureCell")}`
				else `{nodeName}:{math.round(p.X * 10)},{math.round(p.Y * 10)},{math.round(p.Z * 10)}`,
			node = node,
			tree = false,
			furniture = typeof(furniture) == "string",
			model = model,
			damage = 0,
		}
	end
	ToolService.onWorldHit(onWorldHit)
end

return HarvestService
