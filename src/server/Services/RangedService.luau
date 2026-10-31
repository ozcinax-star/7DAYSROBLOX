--!strict
-- RangedService: bows and guns (7DTD Catapult and Ranged actions). "Use" with one in the hand shoots
-- one arrow from inventory or a round from that gun's magazine. The server checks the shot interval,
-- equip and reload deadlines, weapon durability and ammunition, consumes a round,
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
local Firearm = require(Shared.Firearm)
local Inventory = require(Shared.Inventory)
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

type Reload = { stack: Inventory.Stack, started: number, ends: number }
local reloads: { [Player]: Reload } = {}
local equipped: { [Player]: Inventory.Stack } = {}
local equipReady: { [Player]: number } = {}
local stateRemote: RemoteEvent
local reloadLimiter: RateLimiter.RateLimiter
local publishState: (Player, boolean?) -> ()
local updateWeapons: () -> ()

local aiming: { [Player]: boolean } = {}
local aimLimiter: RateLimiter.RateLimiter
local firedRemote: UnreliableRemoteEvent
local stoppedRemote: UnreliableRemoteEvent
local arrows: { [number]: Arrow } = {}
local inFlight: { [Player]: number } = {}
local nextShotAt: { [Player]: number } = {}

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
			local _, maximum = ZombieService.getHealth(hit.id)
			ZombieService.damage(hit.id, damage, arrow.owner)
			ToolService.reportHit(arrow.owner, (ZombieService.getHealth(hit.id)), maximum)
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
	updateWeapons()
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
	firedRemote:FireAllClients(id, origin, velocity, gravity, Workspace:GetServerTimeNow(), ammoId, itemId, player)
end

-- Reliable owner state; cartridges live on the individual inventory stack, not in a client counter.
local revision: { [Player]: number } = {}
publishState = function(player: Player, shot: boolean?)
	if player.Parent ~= Players then return end
	local held, slot = InventoryService.getHeld(player)
	local weapon = held and RC.Weapons[held.id]
	local reload = reloads[player]
	revision[player] = (revision[player] or 0) + 1
	local ammoId = if held and held.loadedAmmo then held.loadedAmmo elseif weapon then weapon.Ammo[1] else nil
	stateRemote:FireClient(player, {
		id = if weapon and held then held.id else false,
		slot = slot,
		loaded = if held then held.loadedRounds or 0 else 0,
		capacity = if weapon then weapon.Magazine or 0 else 0,
		reserve = if ammoId then InventoryService.count(player, ammoId) else 0,
		ammo = ammoId,
		reloadStarted = if reload then reload.started else 0,
		reloadEnds = if reload then reload.ends else 0,
		readyAt = Workspace:GetServerTimeNow() + math.max(0, (equipReady[player] or 0) - os.clock()),
		revision = revision[player],
		shot = shot == true,
	})
end

local function alive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function beginReload(player: Player)
	local held = InventoryService.getHeld(player)
	local weapon = held and RC.Weapons[held.id]
	if held == nil or weapon == nil or weapon.Magazine == nil or held.durability == 0
		or not alive(player) or reloads[player] or os.clock() < (equipReady[player] or 0) then
		return
	end
	local ammoId = if (held.loadedRounds or 0) > 0 then held.loadedAmmo else ammoFor(player, weapon)
	if ammoId == nil or not table.find(weapon.Ammo, ammoId) then publishState(player); return end
	local count = Firearm.reloadCount(weapon.Magazine, held.loadedRounds or 0, InventoryService.count(player, ammoId))
	if count == 0 then publishState(player); return end
	held.loadedAmmo = ammoId
	local now = Workspace:GetServerTimeNow()
	reloads[player] = { stack = held, started = now, ends = now + (weapon.ReloadSeconds or weapon.ShotSeconds) }
	aiming[player] = nil
	player:SetAttribute("WeaponAiming", false)
	player:SetAttribute("WeaponReloadEnds", reloads[player].ends)
	publishState(player)
end

updateWeapons = function()
	for _, player in Players:GetPlayers() do
		local held = InventoryService.getHeld(player)
		if equipped[player] ~= held then
			equipped[player] = held
			equipReady[player] = os.clock() + RC.EquipSeconds
			reloads[player], aiming[player] = nil, nil
			player:SetAttribute("WeaponAiming", false)
			player:SetAttribute("WeaponReloadEnds", 0)
			publishState(player)
		end
		local reload = reloads[player]
		if reload then
			if not alive(player) or held ~= reload.stack then
				reloads[player] = nil
				player:SetAttribute("WeaponReloadEnds", 0)
				publishState(player)
			elseif Workspace:GetServerTimeNow() >= reload.ends then
				local weapon = RC.Weapons[reload.stack.id]
				local ammoId = reload.stack.loadedAmmo
				local count = if ammoId then Firearm.reloadCount(weapon.Magazine or 0,
					reload.stack.loadedRounds or 0, InventoryService.count(player, ammoId)) else 0
				if ammoId and count > 0 and InventoryService.take(player, { [ammoId] = count }) then
					reload.stack.loadedRounds = (reload.stack.loadedRounds or 0) + count
					InventoryService.changed(player)
				end
				reloads[player] = nil
				player:SetAttribute("WeaponReloadEnds", 0)
				publishState(player)
			end
		end
	end
end

-- Origin and aim have already been checked by ToolService. No client can supply ammo or a deadline.
local function onShoot(player: Player, origin: Vector3, direction: Vector3, itemId: string)
	local weapon = RC.Weapons[itemId]
	local held = InventoryService.getHeld(player)
	local now = os.clock()
	if weapon == nil or held == nil or held.id ~= itemId or held.durability == 0 or not alive(player)
		or now < (nextShotAt[player] or 0) or now < (equipReady[player] or 0)
		or (inFlight[player] or 0) >= RC.MaxArrowsPerPlayer then return end
	local ammoId: string?
	if weapon.Magazine then
		if reloads[player] then return end
		if (held.loadedRounds or 0) <= 0 then beginReload(player); return end
		if not Firearm.canFire(held.loadedRounds or 0, 0, nextShotAt[player] or 0, now) then return end
		ammoId = held.loadedAmmo
		if ammoId == nil or not table.find(weapon.Ammo, ammoId) then return end
		held.loadedRounds = (held.loadedRounds or 0) - 1
		InventoryService.changed(player)
	else
		ammoId = ammoFor(player, weapon)
		if ammoId == nil or not InventoryService.take(player, { [ammoId] = 1 }) then return end
	end
	nextShotAt[player] = now + weapon.ShotSeconds * (1 - MC.CooldownTolerance)
	InventoryService.wearHeld(player, 1)
	if weapon.Noise then ThreatService.emit(weapon.Noise, origin, player) end
	local degrees = Ballistics.spreadDegrees(weapon, aiming[player] == true)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude > RC.MoveSpreadSpeed then
		degrees *= RC.MoveSpreadMultiplier
	end
	if humanoid and humanoid.FloorMaterial == Enum.Material.Air then degrees *= RC.AirSpreadMultiplier end
	for _ = 1, RC.Ammo[ammoId].Pellets or 1 do
		local shot = direction
		if degrees > 0 then
			local x, y, z = Ballistics.spread(direction.X, direction.Y, direction.Z, degrees, math.random(), math.random())
			shot = Vector3.new(x, y, z).Unit
		end
		launch(player, origin, shot, weapon, ammoId, itemId)
	end
	publishState(player, true)
	if weapon.Magazine and held.loadedRounds == 0 then beginReload(player) end
end

local function onAimIntent(player: Player, wants: unknown, pitch: unknown)
	if typeof(wants) ~= "boolean" then return end
	if pitch ~= nil and (typeof(pitch) ~= "number" or pitch ~= pitch or math.abs(pitch) > math.pi / 2) then return end
	-- Releasing aim must still work after a burst of rate-limited pitch updates.
	if not wants then
		if aiming[player] then
			aiming[player] = nil
			player:SetAttribute("WeaponAiming", false)
			player:SetAttribute("WeaponPitch", 0)
		end
		return
	end
	if not aimLimiter:allow(player) then return end
	local held = InventoryService.getHeld(player)
	local weapon = held and RC.Weapons[held.id]
	local on = wants and weapon ~= nil and weapon.AimSpread ~= nil and reloads[player] == nil and alive(player)
	aiming[player] = if on then true else nil
	player:SetAttribute("WeaponAiming", on)
	player:SetAttribute("WeaponPitch", if on and typeof(pitch) == "number" then pitch else 0)
end

function RangedService.init()
	aimLimiter = RateLimiter.new(Config.Remotes.AimRequestsPerSecond)
	reloadLimiter = RateLimiter.new(RC.ReloadRequestsPerSecond)
	stateRemote = Net.event("WeaponState")
	Net.event("ReloadWeapon")
	Net.event("AimIntent")
	firedRemote = Net.unreliable("ArrowFired")
	stoppedRemote = Net.unreliable("ArrowStopped")
end

function RangedService.start()
	for itemId in RC.Weapons do ToolService.onUse(itemId, onShoot) end
	Net.event("AimIntent").OnServerEvent:Connect(onAimIntent)
	Net.event("ReloadWeapon").OnServerEvent:Connect(function(player: Player, wants: unknown)
		if wants == true and reloadLimiter:allow(player) then beginReload(player) end
	end)
	InventoryService.onChanged(function(player: Player) publishState(player) end)
	RunService.Heartbeat:Connect(onHeartbeat)
	Players.PlayerRemoving:Connect(function(player)
		aiming[player], nextShotAt[player], reloads[player], equipped[player] = nil, nil, nil, nil
		equipReady[player], revision[player] = nil, nil
		for _, arrow in arrows do if arrow.owner == player then stop(arrow, arrow.position, 0) end end
		inFlight[player] = nil
	end)
end

return RangedService
