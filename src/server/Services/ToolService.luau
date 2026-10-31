--!strict
-- ToolService: melee swings with the item in the active toolbelt slot (or the fist). The client
-- sends only its aim direction; the server checks the swing rate, picks the target from the head of
-- the character it simulates, applies the tool's damage and wear, and tells every client about the
-- swing so they can animate it, stagger the zombie and draw the impact (where a world hit landed and
-- the struck surface's colour).
--
-- A swing hits the nearest zombie in reach that no wall hides, otherwise the first world surface in
-- reach, grass and bushes included; world hits go to `onWorldHit` listeners (gathering), which report
-- what is left of the thing they damaged to the swinging player (`reportHit`). Tools wear
-- by one per hit, never on a miss (7DTD). A tool at 0 durability cannot swing until it is repaired.
-- Every swing costs the tool's stamina and needs that much (the stamina gate, SurvivalService).
--
-- Items with a use handler (blocks: BuildService; food, drinks, medicine: SurvivalService) are used
-- instead of swung, and a fist "use" may be taken by the fist handler first (drinking from a lake).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Melee = require(Shared.Melee)
local Net = require(Shared.Net)
local Surface = require(Shared.Surface)

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
-- (player, head position, unit aim, id of the held item)
export type UseCallback = (player: Player, origin: Vector3, direction: Vector3, itemId: string) -> ()
-- (player, head position, unit aim) -> whether it used the action, so no punch follows.
export type FistCallback = (player: Player, origin: Vector3, direction: Vector3) -> boolean
-- (player, stamina cost) -> whether the swing may go ahead; takes the stamina when it does.
export type StaminaGate = (player: Player, cost: number) -> boolean

local ToolService = {}

local limiter: RateLimiter.RateLimiter
local swingRemote: UnreliableRemoteEvent
local hitRemote: UnreliableRemoteEvent
-- Earliest os.clock() of each player's next swing, set by the tool that swung last.
local nextSwingAt: { [Player]: number } = {}
local worldHitCallbacks: { WorldHitCallback } = {}
local useCallbacks: { [string]: UseCallback } = {}
local fistCallback: FistCallback? = nil
local staminaGate: StaminaGate? = nil

-- Ray params that ignore every character (no friendly blocking, no PvP) and decor. Walls only
-- (`solid`) hide zombies, and bars do not (a spear reaches through them); world hits also land on what
-- the player walks through, such as grass, and on bars.
local function rayParams(solid: boolean): RaycastParams
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
	params.RespectCanCollide = solid
	if solid then
		params.CollisionGroup = Config.Build.ShotsGroup
	end
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
	-- An item with a use handler is used instead of swung (the handler checks the rest).
	local held = InventoryService.getHeld(player)
	local use = held and useCallbacks[held.id]
	if held and use then
		use(player, head.Position, direction, held.id)
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
	if toolId == FIST and fistCallback and fistCallback(player, head.Position, direction) then
		return
	end
	if staminaGate and not staminaGate(player, tool.StaminaLoss) then
		return
	end
	local interval = Melee.interval(tool.AttacksPerMinute, MC.SwingDelay)
	nextSwingAt[player] = now + interval * (1 - MC.CooldownTolerance)

	local origin = head.Position
	local range = tool.Range * MC.StudsPerMeter
	local params = rayParams(true)
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
	local point: Vector3? = nil
	local normal: Vector3? = nil
	local color: Color3? = nil
	if hit then
		local damage = tool.EntityDamage * (if hit.head then MC.HeadshotMultiplier else 1)
		ZombieService.damage(hit.id, damage, player)
		zombieId = hit.id
		headHit = hit.head
	else
		local result = workspace:Raycast(origin, direction * range, rayParams(false))
		if result == nil then
			swingRemote:FireAllClients(player, toolId, 0, false)
			return
		end
		-- Read before the listeners run: a hit may remove what it struck.
		point, normal, color = result.Position, result.Normal, Surface.color(result)
		for _, callback in worldHitCallbacks do
			task.spawn(callback, player, result, toolId, tool)
		end
	end
	if toolId ~= FIST then
		InventoryService.wearHeld(player, 1)
	end
	swingRemote:FireAllClients(player, toolId, zombieId, headHit, point, normal, color)
end

function ToolService.init()
	limiter = RateLimiter.new(Config.Remotes.UseToolRequestsPerSecond)
	swingRemote = Net.unreliable("ToolSwing")
	hitRemote = Net.unreliable("HitInfo")
	Net.event("UseTool")
end

function ToolService.start()
	Net.event("UseTool").OnServerEvent:Connect(onUseTool)
	Players.PlayerRemoving:Connect(function(player)
		nextSwingAt[player] = nil
	end)
end

-- Sets the handler for "use" with item `itemId` in the hand (one per item).
function ToolService.onUse(itemId: string, callback: UseCallback)
	assert(useCallbacks[itemId] == nil, `use handler for {itemId} already set`)
	useCallbacks[itemId] = callback
end

-- Sets the handler that may take a fist "use" before it becomes a punch (one handler).
function ToolService.onFistUse(callback: FistCallback)
	fistCallback = callback
end

-- Sets the check every swing passes before it happens (one gate).
function ToolService.setStaminaGate(gate: StaminaGate)
	staminaGate = gate
end

-- Shows `player` the health left on what their swing just hit (a health bar under the crosshair).
function ToolService.reportHit(player: Player, remaining: number, maximum: number)
	if maximum > 0 then
		hitRemote:FireClient(player, math.max(0, remaining), maximum)
	end
end

-- Registers a listener for swings that hit the world (terrain or a part) instead of a zombie.
function ToolService.onWorldHit(callback: WorldHitCallback)
	table.insert(worldHitCallbacks, callback)
end

return ToolService
