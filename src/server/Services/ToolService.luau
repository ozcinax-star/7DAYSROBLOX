--!strict
-- ToolService: melee swings with the item in the active toolbelt slot (or the fist). The client
-- sends only its aim direction; the server checks the swing rate, picks the target from the head of
-- the character it simulates, applies the tool's damage and wear, and tells every client about the
-- swing so they can animate it and stagger the zombie.
--
-- A swing hits the nearest zombie in reach that no wall hides, otherwise the first world surface in
-- reach; world hits go to `onWorldHit` listeners (gathering). Tools wear by one per hit, never on a
-- miss (7DTD). A tool at 0 durability cannot swing until it is repaired.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Melee = require(Shared.Melee)
local Net = require(Shared.Net)

local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local InventoryService = require(script.Parent.InventoryService)
local ZombieService = require(script.Parent.ZombieService)

local MC = Config.Melee
local FIST = "Fist"
local SHAPE: Melee.Shape = {
	bottom = MC.HitBottom,
	top = MC.HitTop,
	radius = MC.HitRadius,
	headHeight = MC.HeadHeight,
	headRadius = MC.HeadRadius,
	headLean = MC.HeadLean,
}

-- (player, raycast result, tool id or "Fist", tool stats)
export type WorldHitCallback =
	(player: Player, result: RaycastResult, toolId: string, tool: Config.ToolDef) -> ()

local ToolService = {}

local limiter: RateLimiter.RateLimiter
local swingRemote: UnreliableRemoteEvent
-- Earliest os.clock() of each player's next swing, set by the tool that swung last.
local nextSwingAt: { [Player]: number } = {}
local worldHitCallbacks: { WorldHitCallback } = {}

-- Ray params that ignore every character (no friendly blocking, no PvP) and decor.
local function rayParams(): RaycastParams
	local ignored: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignored, other.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignored
	params.IgnoreWater = true
	params.RespectCanCollide = true
	return params
end

-- The tool id used for a swing: the held tool, or the fist for an empty hand and non-tools.
local function toolFor(player: Player): (string?, Config.ToolDef?)
	local stack = InventoryService.getHeld(player)
	if stack and Config.Tools[stack.id] then
		if stack.durability == 0 then
			return nil, nil
		end
		return stack.id, Config.Tools[stack.id]
	end
	return FIST, Config.Tools[FIST]
end

local function onUseTool(player: Player, aim: unknown)
	if not limiter:allow(player) then
		return
	end
	if typeof(aim) ~= "Vector3" or not Melee.isUnit(aim.X, aim.Y, aim.Z, MC.AimTolerance) then
		return
	end
	local direction = aim.Unit
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	if humanoid == nil or humanoid.Health <= 0 or head == nil or not head:IsA("BasePart") then
		return
	end
	local now = os.clock()
	if now < (nextSwingAt[player] or 0) then
		return
	end
	local toolId, tool = toolFor(player)
	if toolId == nil or tool == nil then
		return
	end
	local interval = Melee.interval(tool.AttacksPerMinute, MC.SwingDelay)
	nextSwingAt[player] = now + interval * (1 - MC.CooldownTolerance)

	local origin = head.Position
	local range = tool.Range * MC.StudsPerMeter
	local params = rayParams()
	local ray: Melee.Ray = {
		ox = origin.X,
		oy = origin.Y,
		oz = origin.Z,
		dx = direction.X,
		dy = direction.Y,
		dz = direction.Z,
		range = range,
	}
	local reach = range + MC.HitRadius + math.max(MC.HitTop, -MC.HitBottom)
	local hit = Melee.pick(ray, ZombieService.bodiesNear(origin, reach), SHAPE, function(candidate)
		-- Blocked when a wall stands between the head and the zombie's axis.
		local toAxis = Vector3.new(candidate.px, candidate.py, candidate.pz) - origin
		local wall = workspace:Raycast(origin, toAxis, params)
		return wall ~= nil and wall.Distance < toAxis.Magnitude - MC.BodyRadius
	end)

	local zombieId = 0
	local headHit = false
	if hit then
		local damage = tool.EntityDamage * (if hit.head then MC.HeadshotMultiplier else 1)
		ZombieService.damage(hit.id, damage, player)
		zombieId = hit.id
		headHit = hit.head
	else
		local result = workspace:Raycast(origin, direction * range, params)
		if result == nil then
			swingRemote:FireAllClients(player, toolId, 0, false)
			return
		end
		for _, callback in worldHitCallbacks do
			task.spawn(callback, player, result, toolId, tool)
		end
	end
	if toolId ~= FIST then
		InventoryService.wearHeld(player, 1)
	end
	swingRemote:FireAllClients(player, toolId, zombieId, headHit)
end

function ToolService.init()
	limiter = RateLimiter.new(Config.Remotes.UseToolRequestsPerSecond)
	swingRemote = Net.unreliable("ToolSwing")
	Net.event("UseTool")
end

function ToolService.start()
	Net.event("UseTool").OnServerEvent:Connect(onUseTool)
	Players.PlayerRemoving:Connect(function(player)
		nextSwingAt[player] = nil
	end)
end

-- Registers a listener for swings that hit the world (terrain or a part) instead of a zombie.
function ToolService.onWorldHit(callback: WorldHitCallback)
	table.insert(worldHitCallbacks, callback)
end

return ToolService
