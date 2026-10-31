--!strict
-- RangedService: bows and guns (7DTD Catapult and Ranged actions). "Use" with one in the hand shoots
-- one arrow or round from the inventory. The server checks the shot interval (and, for guns, the
-- magazine: after its last round the reload must pass), the weapon's durability, takes the ammo,
-- wears the weapon by one and flies the shot itself from the head of the character it simulates,
-- turned inside the gun's spread cone: one Heartbeat loop moves every shot along its arc and tests
-- each step against zombies (the melee hit volumes, head shots double) and the world (walls, blocks,
-- terrain, water). A gunshot is a Gunshot noise (ThreatService). A shotgun shell flies several pellets,
-- each turned on its own. Aiming (AimIntent) tightens a gun's spread to its AimSpread share. Clients
-- only draw the arc they are told about (ArrowController).
--
-- An arrow hits the first zombie or surface on its path. It damages zombies only: blocks and world
-- objects stop it (7DTD stone arrows do 1 block damage; ignored). A hit zombie chases the shooter,
-- like a melee hit. Arrows are not recovered.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ballistics = require(Shared.Ballistics)
local Config = require(Shared.Config)
local Melee = require(Shared.Melee)
local Net = require(Shared.Net)

local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local InventoryService = require(script.Parent.InventoryService)
local ThreatService = require(script.Parent.ThreatService)
local ToolService = require(script.Parent.ToolService)
local ZombieService = require(script.Parent.ZombieService)

local MC = Config.Melee
local RC = Config.Ranged
local SHAPE: Melee.Shape = {
	bottom = MC.HitBottom,
	top = MC.HitTop,
	radius = MC.HitRadius,
	headHeight = MC.HeadHeight,
	headRadius = MC.HeadRadius,
	headLean = MC.HeadLean,
}
-- Arrows that fall below this height are dropped (under the deepest terrain).
local LOWEST_Y = -100
-- How far around a flight step zombies are looked up, beyond half the step (studs).
local BODY_REACH = MC.HitRadius + math.max(MC.HitTop, -MC.HitBottom)

type Arrow = {
	id: number,
	owner: Player,
	position: Vector3,
	velocity: Vector3,
	gravity: number,
	damage: number,
	travelled: number,
	range: number,
}

local RangedService = {}

local aiming: { [Player]: boolean } = {}
local aimLimiter: RateLimiter.RateLimiter
local firedRemote: UnreliableRemoteEvent
local stoppedRemote: UnreliableRemoteEvent
local arrows: { [number]: Arrow } = {}
local inFlight: { [Player]: number } = {}
local nextShotAt: { [Player]: number } = {}
-- Rounds fired from the current magazine, per player and gun.
local fired: { [Player]: { [string]: number } } = {}
local nextArrowId = 1

-- Walls, blocks and terrain stop arrows; characters (no friendly fire, no PvP) and bars do not.
local function worldParams(): RaycastParams
	local ignored: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignored, other.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignored
	params.RespectCanCollide = true
	params.CollisionGroup = Config.Build.ShotsGroup
	return params
end

local function stop(arrow: Arrow, where: Vector3, zombieId: number)
	arrows[arrow.id] = nil
	local count = (inFlight[arrow.owner] or 1) - 1
	inFlight[arrow.owner] = if count > 0 then count else nil
	stoppedRemote:FireAllClients(arrow.id, where, zombieId)
end

-- Moves an arrow over `dt` seconds; stops it on the first zombie or surface it reaches.
local function fly(arrow: Arrow, dt: number, params: RaycastParams)
	local p, v = arrow.position, arrow.velocity
	local x, y, z = Ballistics.position(p.X, p.Y, p.Z, v.X, v.Y, v.Z, arrow.gravity, dt)
	local nextPosition = Vector3.new(x, y, z)
	local step = nextPosition - p
	local length = step.Magnitude
	if length < 1e-6 then
		return
	end
	local direction = step / length
	local wall = Workspace:Raycast(p, step, params)
	local wallDistance = if wall then wall.Distance else math.huge
	local ray: Melee.Ray = {
		ox = p.X,
		oy = p.Y,
		oz = p.Z,
		dx = direction.X,
		dy = direction.Y,
		dz = direction.Z,
		range = length,
	}
	local bodies = ZombieService.bodiesNear(p + step / 2, length / 2 + BODY_REACH)
	local hit = Melee.pick(ray, bodies, SHAPE, function(candidate)
		return candidate.distance - MC.BodyRadius > wallDistance
	end)
	if hit then
		local damage = arrow.damage * (if hit.head then MC.HeadshotMultiplier else 1)
		if arrow.owner.Parent then
			ZombieService.damage(hit.id, damage, arrow.owner)
		end
		stop(arrow, p + direction * math.min(hit.distance, length), hit.id)
		return
	end
	if wall then
		stop(arrow, wall.Position, 0)
		return
	end
	arrow.travelled += length
	arrow.position = nextPosition
	arrow.velocity = Vector3.new(v.X, v.Y - arrow.gravity * dt, v.Z)
	if arrow.travelled >= arrow.range or y < LOWEST_Y then
		stop(arrow, nextPosition, 0)
	end
end

local function onHeartbeat(dt: number)
	if next(arrows) == nil then
		return
	end
	local params = worldParams()
	for _, arrow in arrows do
		fly(arrow, dt, params)
	end
end

-- The first ammo the weapon takes that the player carries, or nil.
local function ammoFor(player: Player, weapon: Config.RangedDef): string?
	for _, id in weapon.Ammo do
		if InventoryService.count(player, id) > 0 then
			return id
		end
	end
	return nil
end

-- Flies one projectile of `ammoId` from `weapon` along the unit `direction` and tells every client.
local function launch(
	player: Player,
	origin: Vector3,
	direction: Vector3,
	weapon: Config.RangedDef,
	ammoId: string,
	itemId: string
)
	local ammo = RC.Ammo[ammoId]
	local velocity = direction * Ballistics.speed(weapon, ammo)
	local gravity = Ballistics.gravity(ammo)
	local id = nextArrowId
	nextArrowId = if id >= 65535 then 1 else id + 1
	arrows[id] = {
		id = id,
		owner = player,
		position = origin,
		velocity = velocity,
		gravity = gravity,
		damage = Ballistics.damage(weapon, ammo),
		travelled = 0,
		range = weapon.MaxRange * MC.StudsPerMeter,
	}
	inFlight[player] = (inFlight[player] or 0) + 1
	firedRemote:FireAllClients(id, origin, velocity, gravity, Workspace:GetServerTimeNow(), ammoId, itemId)
end

-- ToolService use handler: `origin` is the server's head position, `direction` a checked unit aim.
local function onShoot(player: Player, origin: Vector3, direction: Vector3, itemId: string)
	local weapon = RC.Weapons[itemId]
	local now = os.clock()
	if weapon == nil or now < (nextShotAt[player] or 0) or (inFlight[player] or 0) >= RC.MaxArrowsPerPlayer then
		return
	end
	local held = InventoryService.getHeld(player)
	if held == nil or held.id ~= itemId or held.durability == 0 then
		return
	end
	local ammoId = ammoFor(player, weapon)
	if ammoId == nil or not InventoryService.take(player, { [ammoId] = 1 }) then
		return
	end
	local rounds = fired[player] or {}
	fired[player] = rounds
	local wait, kept = Ballistics.afterShot(weapon, (rounds[itemId] or 0) + 1)
	rounds[itemId] = kept
	nextShotAt[player] = now + wait * (1 - MC.CooldownTolerance)
	InventoryService.wearHeld(player, 1)
	if weapon.Noise then
		ThreatService.emit(weapon.Noise, origin, player)
	end
	local degrees = Ballistics.spreadDegrees(weapon, aiming[player] == true)
	for _ = 1, RC.Ammo[ammoId].Pellets or 1 do
		local shot = direction
		if degrees > 0 then
			local x, y, z =
				Ballistics.spread(direction.X, direction.Y, direction.Z, degrees, math.random(), math.random())
			shot = Vector3.new(x, y, z).Unit
		end
		launch(player, origin, shot, weapon, ammoId, itemId)
	end
end

local function onAimIntent(player: Player, wants: unknown)
	if typeof(wants) ~= "boolean" or not aimLimiter:allow(player) then
		return
	end
	aiming[player] = if wants then true else nil
end

function RangedService.init()
	aimLimiter = RateLimiter.new(Config.Remotes.AimRequestsPerSecond)
	Net.event("AimIntent")
	firedRemote = Net.unreliable("ArrowFired")
	stoppedRemote = Net.unreliable("ArrowStopped")
end

function RangedService.start()
	for itemId in RC.Weapons do
		ToolService.onUse(itemId, onShoot)
	end
	Net.event("AimIntent").OnServerEvent:Connect(onAimIntent)
	RunService.Heartbeat:Connect(onHeartbeat)
	Players.PlayerRemoving:Connect(function(player)
		aiming[player] = nil
		nextShotAt[player] = nil
		fired[player] = nil
		for _, arrow in arrows do
			if arrow.owner == player then
				stop(arrow, arrow.position, 0)
			end
		end
		inFlight[player] = nil
	end)
end

return RangedService
