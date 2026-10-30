--!strict
-- HarvestService: gathering (7DTD). A swing that hits a tree, bush, grass, boulder or loose rock deals
-- the tool's block damage for that material. Harvest drops pay out while the object is hit and
-- Destroy drops when it breaks (Shared/Harvest). Everyone hitting the same object shares its damage,
-- like a 7DTD block. Loose rocks can also be picked up with the interact key. What has no room in the
-- inventory drops in a loot bag at the player's feet (7DTD drops it on the ground).
--
-- A felled tree stops colliding at once, frees the zombie navigation cells under it, and falls away
-- from the player who felled it (clients animate the fall), then is removed. Nothing grows back:
-- 7DTD's natural trees and rocks do not respawn.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Harvest = require(Shared.Harvest)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local InventoryService = require(script.Parent.InventoryService)
local LootService = require(script.Parent.LootService)
local MapService = require(script.Parent.MapService)
local ToolService = require(script.Parent.ToolService)
local ZombieService = require(script.Parent.ZombieService)

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

local function give(player: Player, id: string, count: number)
	if count <= 0 then
		return
	end
	local left = InventoryService.give(player, id, count, SOURCE)
	local character = player.Character
	local root = character and character.PrimaryPart
	if left > 0 and root then
		LootService.drop(root.Position, { { id = id, count = left, source = SOURCE } }, true)
	end
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
	end
	release(model)
	task.delay(HC.FallSeconds + HC.FadeSeconds, model.Destroy, model)
end

-- Damages an object for one hit by `player` and pays what that hit earned; breaks it at full damage.
local function hit(entry: Entry, player: Player, damage: number)
	local node = entry.node
	local before = entry.damage
	local after = math.min(node.Health, before + damage)
	entry.damage = after
	for _, drop in node.Harvest do
		give(player, drop.Id, Harvest.payout(roll(drop), node.Health, before, after))
	end
	if after < node.Health then
		return
	end
	entries[entry.model] = nil
	for _, drop in node.Destroy do
		give(player, drop.Id, roll(drop))
	end
	if entry.tree then
		fell(entry.model, player)
	else
		release(entry.model)
		entry.model:Destroy()
	end
end

local function onWorldHit(player: Player, result: RaycastResult, _toolId: string, tool: Config.ToolDef)
	local model = result.Instance.Parent
	local entry = if model and model:IsA("Model") then entries[model] else nil
	if entry == nil then
		return
	end
	hit(entry, player, Harvest.blockDamage(tool.BlockDamage, tool.Materials[entry.node.Material]))
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
	-- Picking up takes the whole object, as if one hit broke it.
	hit(entry, player, entry.node.Health)
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

function HarvestService.init()
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
			model = harvestable.model,
			damage = 0,
		}
		entries[harvestable.model] = entry
		if harvestable.node == "LooseRock" then
			addPickupPrompt(entry)
		end
	end
	ToolService.onWorldHit(onWorldHit)
end

return HarvestService
