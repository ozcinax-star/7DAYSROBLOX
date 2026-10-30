--!strict
-- ZombieService: Humanoid-free zombie simulation. Zombies are plain data on the server (position,
-- state, target, health); clients build, animate and interpolate the models themselves.
--
-- Movement: shared flow fields (one toward all players, one per recent sound point), plus a small
-- per-zombie spread offset and separation so the horde does not walk in single file.
-- LOD: zombies near a player tick at NearHz, the rest at FarHz. Snapshots carry only zombies that
-- changed since the previous snapshot, with a periodic full snapshot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local NavGrid = require(Shared.NavGrid)
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local ZombieProtocol = require(Shared.ZombieProtocol)

local MapService = require(script.Parent.MapService)

local ZC = Config.Zombie
local FC = Config.FlowField
local NC = Config.Network

type Zombie = {
	id: number,
	x: number,
	y: number,
	z: number,
	health: number,
	state: Types.ZombieState,
	-- Current goal point (sound, search or wander point).
	goalX: number,
	goalZ: number,
	soundId: number?,
	soundStrength: number,
	soundCreatedAt: number,
	targetPlayer: Player?,
	stateUntil: number,
	spreadX: number,
	spreadZ: number,
	lastUpdate: number,
	nextUpdate: number,
	nextAttack: number,
	nextSightCheck: number,
	dirty: boolean,
}

type PlayerInfo = {
	player: Player,
	x: number,
	y: number,
	z: number,
	humanoid: Humanoid,
	root: BasePart,
}

type SoundField = {
	field: NavGrid.Field,
	lastUsed: number,
}

export type Stats = {
	alive: number,
	queued: number,
	tickMs: number,
	tickMaxMs: number,
	stepsPerSecond: number,
}

local ZombieService = {}

local grid: NavGrid.NavGrid
local playerField: NavGrid.Field? = nil
local nextFieldRebuild = 0
local soundFields: { [number]: SoundField } = {}
local soundFieldCount = 0

local zombies: { [number]: Zombie } = {}
local aliveCount = 0
local nextId = 1
local spawnQueue = 0
local nextWaveTime = 0

local removedIds: { number } = {}
local nextSnapshot = 0
local nextFullSnapshot = 0
local snapshotEntries: { ZombieProtocol.Entry } = {}

local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Include

local snapshotRemote: UnreliableRemoteEvent
local removedRemote: RemoteEvent

-- Tick timing (exponential moving average + window max), read by DebugService.
local TICK_EMA_WEIGHT = 0.1
local tickMsAvg = 0
local tickMsMax = 0
local stepCount = 0
local stepWindowStart = os.clock()
local stepsPerSecond = 0

local function randomRange(min: number, max: number): number
	return min + math.random() * (max - min)
end

local function allocateId(): number?
	-- Ids are u16 on the wire and recycled; 0 is never used.
	for _ = 1, 65535 do
		local id = nextId
		nextId = if nextId >= 65535 then 1 else nextId + 1
		if zombies[id] == nil then
			return id
		end
	end
	return nil
end

local function collectPlayers(): { PlayerInfo }
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local root = character.PrimaryPart
			if humanoid and root and humanoid.Health > 0 then
				local p = root.Position
				table.insert(list, { player = player, x = p.X, y = p.Y, z = p.Z, humanoid = humanoid, root = root })
			end
		end
	end
	return list
end

local function nearestPlayer(players: { PlayerInfo }, x: number, z: number): (PlayerInfo?, number)
	local best: PlayerInfo? = nil
	local bestDistSq = math.huge
	for _, info in players do
		local dx = info.x - x
		local dz = info.z - z
		local d = dx * dx + dz * dz
		if d < bestDistSq then
			bestDistSq = d
			best = info
		end
	end
	return best, math.sqrt(bestDistSq)
end

local function findPlayerInfo(players: { PlayerInfo }, player: Player?): PlayerInfo?
	if player == nil then
		return nil
	end
	for _, info in players do
		if info.player == player then
			return info
		end
	end
	return nil
end

local function hasLineOfSight(zombie: Zombie, info: PlayerInfo): boolean
	local origin = Vector3.new(zombie.x, zombie.y, zombie.z)
	local result = Workspace:Raycast(origin, Vector3.new(info.x, info.y, info.z) - origin, sightParams)
	return result == nil
end

local function setState(zombie: Zombie, state: Types.ZombieState)
	if zombie.state ~= state then
		zombie.state = state
		zombie.dirty = true
	end
end

local function enterSearch(zombie: Zombie, now: number, x: number, z: number)
	setState(zombie, "Search")
	zombie.soundId = nil
	zombie.targetPlayer = nil
	zombie.goalX = x
	zombie.goalZ = z
	zombie.stateUntil = now + ZC.SearchDuration
end

local function enterWander(zombie: Zombie, now: number)
	setState(zombie, "Wander")
	zombie.soundId = nil
	zombie.soundStrength = 0
	zombie.targetPlayer = nil
	zombie.goalX = zombie.x + randomRange(-ZC.WanderRadius, ZC.WanderRadius)
	zombie.goalZ = zombie.z + randomRange(-ZC.WanderRadius, ZC.WanderRadius)
	zombie.stateUntil = now + randomRange(ZC.WanderRetargetMin, ZC.WanderRetargetMax)
end

local function getSoundField(soundId: number, x: number, z: number, now: number): NavGrid.Field?
	local cached = soundFields[soundId]
	if cached then
		cached.lastUsed = now
		return cached.field
	end
	local cell = grid:cellAt(x, z)
	if cell == nil then
		return nil
	end
	if soundFieldCount >= FC.MaxSoundFields then
		local oldestId: number? = nil
		local oldestTime = math.huge
		for id, entry in soundFields do
			if entry.lastUsed < oldestTime then
				oldestTime = entry.lastUsed
				oldestId = id
			end
		end
		if oldestId then
			soundFields[oldestId] = nil
			soundFieldCount -= 1
		end
	end
	local field = grid:buildField({ cell })
	soundFields[soundId] = { field = field, lastUsed = now }
	soundFieldCount += 1
	return field
end

-- Moves the zombie toward (tx, tz) at `speed`, sliding along blocked cells.
local function moveToward(zombie: Zombie, tx: number, tz: number, speed: number, dt: number)
	local dx = tx - zombie.x
	local dz = tz - zombie.z
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist < 1e-3 then
		return
	end
	local step = math.min(dist, speed * dt)
	local nx = zombie.x + dx / dist * step
	local nz = zombie.z + dz / dist * step
	if grid:isWalkable(nx, nz) then
		zombie.x = nx
		zombie.z = nz
	elseif grid:isWalkable(nx, zombie.z) then
		zombie.x = nx
	elseif grid:isWalkable(zombie.x, nz) then
		zombie.z = nz
	else
		return
	end
	zombie.dirty = true
end

-- Follows `field` toward a goal; steers straight when close or when the field has no answer.
local function followField(
	zombie: Zombie,
	field: NavGrid.Field?,
	goalX: number,
	goalZ: number,
	speed: number,
	dt: number
)
	local dx = goalX - zombie.x
	local dz = goalZ - zombie.z
	local distSq = dx * dx + dz * dz
	if field and distSq > FC.DirectSteerDistance * FC.DirectSteerDistance then
		local wx, wz = grid:nextWaypoint(field, zombie.x, zombie.z)
		if wx and wz then
			local sx = wx + zombie.spreadX
			local sz = wz + zombie.spreadZ
			if grid:isWalkable(sx, sz) then
				moveToward(zombie, sx, sz, speed, dt)
			else
				moveToward(zombie, wx, wz, speed, dt)
			end
			return
		end
	end
	moveToward(zombie, goalX, goalZ, speed, dt)
end

local function stepZombie(zombie: Zombie, players: { PlayerInfo }, now: number, dt: number)
	local nearest, nearestDist = nearestPlayer(players, zombie.x, zombie.z)

	-- Direct sight overrides sounds.
	local state = zombie.state
	if state ~= "Chase" and state ~= "AttackPlayer" and nearest and now >= zombie.nextSightCheck then
		zombie.nextSightCheck = now + ZC.SightCheckInterval
		if nearestDist <= ZC.SightRange and hasLineOfSight(zombie, nearest) then
			zombie.targetPlayer = nearest.player
			zombie.soundId = nil
			setState(zombie, "Chase")
		end
	end

	state = zombie.state
	if state == "Chase" or state == "AttackPlayer" then
		local target = findPlayerInfo(players, zombie.targetPlayer)
		if target == nil then
			enterSearch(zombie, now, zombie.x, zombie.z)
			return
		end
		local dx = target.x - zombie.x
		local dz = target.z - zombie.z
		local dist = math.sqrt(dx * dx + dz * dz)
		if dist > ZC.SightRange * ZC.LoseSightMultiplier then
			enterSearch(zombie, now, target.x, target.z)
			return
		end
		if dist <= ZC.AttackRange then
			setState(zombie, "AttackPlayer")
			if now >= zombie.nextAttack then
				zombie.nextAttack = now + ZC.AttackCooldown
				target.humanoid:TakeDamage(ZC.AttackDamage)
			end
			return
		end
		setState(zombie, "Chase")
		followField(zombie, playerField, target.x, target.z, ZC.RunSpeed, dt)
	elseif state == "SeekSound" then
		local dx = zombie.goalX - zombie.x
		local dz = zombie.goalZ - zombie.z
		if dx * dx + dz * dz <= ZC.ArriveDistance * ZC.ArriveDistance then
			enterSearch(zombie, now, zombie.goalX, zombie.goalZ)
			return
		end
		local field = getSoundField(zombie.soundId :: number, zombie.goalX, zombie.goalZ, now)
		followField(zombie, field, zombie.goalX, zombie.goalZ, ZC.RunSpeed, dt)
	elseif state == "Search" then
		if now >= zombie.stateUntil then
			enterWander(zombie, now)
			return
		end
		local dx = zombie.goalX - zombie.x
		local dz = zombie.goalZ - zombie.z
		if dx * dx + dz * dz <= ZC.ArriveDistance * ZC.ArriveDistance then
			-- Pick a new spot around the search centre (the original goal drifts, which is fine).
			zombie.goalX += randomRange(-ZC.SearchRadius, ZC.SearchRadius)
			zombie.goalZ += randomRange(-ZC.SearchRadius, ZC.SearchRadius)
		end
		moveToward(zombie, zombie.goalX, zombie.goalZ, ZC.WanderSpeed, dt)
	else
		if now >= zombie.stateUntil or state == "Idle" then
			enterWander(zombie, now)
		end
		moveToward(zombie, zombie.goalX, zombie.goalZ, ZC.WanderSpeed, dt)
	end
end

-- Pushes zombies that share a cell apart. Cheap O(n) bucket pass, run on the zombies stepped this frame.
local function separate(stepped: { Zombie })
	local buckets: { [number]: { Zombie } } = {}
	for _, zombie in stepped do
		local cell = grid:cellAt(zombie.x, zombie.z)
		if cell then
			local bucket = buckets[cell]
			if bucket == nil then
				buckets[cell] = { zombie }
			else
				table.insert(bucket, zombie)
			end
		end
	end
	local radius = ZC.SeparationRadius
	local radiusSq = radius * radius
	for _, bucket in buckets do
		local n = #bucket
		if n > 1 then
			for i = 1, n - 1 do
				local a = bucket[i]
				for j = i + 1, n do
					local b = bucket[j]
					local dx = b.x - a.x
					local dz = b.z - a.z
					local d2 = dx * dx + dz * dz
					if d2 < radiusSq then
						local d = math.sqrt(d2)
						if d < 1e-3 then
							dx, dz, d = 1, 0, 1
						end
						-- Each zombie moves half of the resolved overlap.
						local push = (radius - d) * 0.5 * ZC.SeparationStrength
						local px = dx / d * push
						local pz = dz / d * push
						if grid:isWalkable(a.x - px, a.z - pz) then
							a.x -= px
							a.z -= pz
						end
						if grid:isWalkable(b.x + px, b.z + pz) then
							b.x += px
							b.z += pz
						end
						a.dirty = true
						b.dirty = true
					end
				end
			end
		end
	end
end

local function pickSpawnPoint(players: { PlayerInfo }): (number?, number?)
	local cx, cz = 0, 0
	if #players > 0 then
		local info = players[math.random(1, #players)]
		cx, cz = info.x, info.z
	end
	for _ = 1, ZC.SpawnAttempts do
		local angle = math.random() * math.pi * 2
		local radius = randomRange(ZC.SpawnMinDistance, ZC.SpawnMaxDistance)
		local x = cx + math.cos(angle) * radius
		local z = cz + math.sin(angle) * radius
		if grid:isWalkable(x, z) then
			return x, z
		end
	end
	return nil, nil
end

local function spawnOne(players: { PlayerInfo }, now: number): boolean
	local id = allocateId()
	local x, z = pickSpawnPoint(players)
	if id == nil or x == nil or z == nil then
		return false
	end
	local spread = ZC.SpreadRadius
	local zombie: Zombie = {
		id = id,
		x = x,
		y = MapService.getGroundY() + ZC.RootHeight,
		z = z,
		health = ZC.MaxHealth,
		state = "Idle",
		goalX = x,
		goalZ = z,
		soundId = nil,
		soundStrength = 0,
		soundCreatedAt = 0,
		targetPlayer = nil,
		stateUntil = 0,
		spreadX = randomRange(-spread, spread),
		spreadZ = randomRange(-spread, spread),
		lastUpdate = now,
		-- Random phase so far zombies do not all tick on the same frame.
		nextUpdate = now + math.random() / ZC.FarHz,
		nextAttack = 0,
		nextSightCheck = now + math.random() * ZC.SightCheckInterval,
		dirty = true,
	}
	zombies[id] = zombie
	aliveCount += 1
	return true
end

local function processSpawnQueue(players: { PlayerInfo }, now: number)
	if spawnQueue <= 0 or now < nextWaveTime then
		return
	end
	local capped = false
	while spawnQueue > 0 do
		if aliveCount >= Config.Horde.MaxConcurrent then
			capped = true
			break
		end
		if not spawnOne(players, now) then
			break
		end
		spawnQueue -= 1
	end
	if capped then
		-- Remaining zombies arrive as the next wave once slots are free.
		nextWaveTime = now + Config.Horde.WaveIntervalSeconds
	end
end

local function rebuildPlayerField(players: { PlayerInfo })
	local sources = {}
	for _, info in players do
		local cell = grid:cellAt(info.x, info.z)
		if cell then
			table.insert(sources, cell)
		end
	end
	playerField = if #sources > 0 then grid:buildField(sources) else nil
end

local function sendSnapshots(now: number)
	if now < nextSnapshot then
		return
	end
	nextSnapshot = now + 1 / NC.SnapshotHz
	local full = now >= nextFullSnapshot
	if full then
		nextFullSnapshot = now + NC.FullSnapshotInterval
	end

	table.clear(snapshotEntries)
	for _, zombie in zombies do
		if full or zombie.dirty then
			zombie.dirty = false
			table.insert(snapshotEntries, {
				id = zombie.id,
				x = zombie.x,
				y = zombie.y,
				z = zombie.z,
				state = zombie.state,
			})
		end
	end

	local serverTime = Workspace:GetServerTimeNow()
	local count = #snapshotEntries
	local first = 1
	while first <= count do
		local last = math.min(count, first + NC.MaxEntriesPerPacket - 1)
		snapshotRemote:FireAllClients(
			ZombieProtocol.encode(serverTime, snapshotEntries, first, last, NC.PositionScale)
		)
		first = last + 1
	end

	if #removedIds > 0 then
		removedRemote:FireAllClients(removedIds)
		removedIds = {}
	end
end

local stepped: { Zombie } = {}

local function onHeartbeat()
	local started = os.clock()
	local now = started
	local players = collectPlayers()

	if now >= nextFieldRebuild then
		nextFieldRebuild = now + FC.RebuildInterval
		rebuildPlayerField(players)
	end

	processSpawnQueue(players, now)

	table.clear(stepped)
	local maxDt = 2 / ZC.FarHz
	for _, zombie in zombies do
		if now >= zombie.nextUpdate then
			local dt = math.min(now - zombie.lastUpdate, maxDt)
			zombie.lastUpdate = now
			stepZombie(zombie, players, now, dt)
			local _, dist = nearestPlayer(players, zombie.x, zombie.z)
			local hz = if dist <= ZC.NearDistance then ZC.NearHz else ZC.FarHz
			zombie.nextUpdate = now + 1 / hz
			table.insert(stepped, zombie)
		end
	end
	separate(stepped)
	stepCount += #stepped

	sendSnapshots(now)

	local elapsedMs = (os.clock() - started) * 1000
	tickMsAvg += (elapsedMs - tickMsAvg) * TICK_EMA_WEIGHT
	tickMsMax = math.max(tickMsMax, elapsedMs)
end

function ZombieService.init()
	grid = NavGrid.new(FC.CellSize, FC.HalfExtent, FC.StructureCellCost)
	snapshotRemote = Net.unreliable("ZombieSnapshot")
	removedRemote = Net.event("ZombieRemoved")
end

function ZombieService.start()
	local obstacles = MapService.getObstacles()
	for _, part in obstacles:GetDescendants() do
		if part:IsA("BasePart") then
			local cf, size = part.CFrame, part.Size
			-- Axis-aligned footprint of the (possibly rotated) part.
			local halfX = (math.abs(cf.RightVector.X) * size.X + math.abs(cf.UpVector.X) * size.Y + math.abs(
				cf.LookVector.X
			) * size.Z) / 2
			local halfZ = (math.abs(cf.RightVector.Z) * size.X + math.abs(cf.UpVector.Z) * size.Y + math.abs(
				cf.LookVector.Z
			) * size.Z) / 2
			local p = cf.Position
			grid:blockRect(p.X - halfX, p.Z - halfZ, p.X + halfX, p.Z + halfZ)
		end
	end
	sightParams.FilterDescendantsInstances = { obstacles }

	RunService.Heartbeat:Connect(onHeartbeat)
end

-- Queues `count` zombies; up to Horde.MaxConcurrent are alive at once, the rest arrive in waves.
function ZombieService.spawn(count: number)
	spawnQueue += math.max(0, math.floor(count))
	nextWaveTime = 0
end

function ZombieService.remove(id: number)
	if zombies[id] then
		zombies[id] = nil
		aliveCount -= 1
		table.insert(removedIds, id)
	end
end

function ZombieService.clear()
	spawnQueue = 0
	for id in zombies do
		ZombieService.remove(id)
	end
end

-- Server-side damage entry point (weapons call this after validating the hit).
function ZombieService.damage(id: number, amount: number)
	local zombie = zombies[id]
	if zombie == nil or amount <= 0 then
		return
	end
	zombie.health -= amount
	if zombie.health <= 0 then
		ZombieService.remove(id)
	end
end

-- Called by ThreatService for every noise event. Zombies in hearing range walk to the newest or
-- loudest sound and keep going until something newer or louder is heard (PLAN: sound tracking).
function ZombieService.hearSound(point: Types.SoundPoint)
	local range = point.radius * ZC.HearingMultiplier
	local rangeSq = range * range
	for _, zombie in zombies do
		local state = zombie.state
		if state ~= "Chase" and state ~= "AttackPlayer" then
			local dx = point.x - zombie.x
			local dz = point.z - zombie.z
			if dx * dx + dz * dz <= rangeSq then
				local isNewer = point.createdAt > zombie.soundCreatedAt
				local isLouder = point.strength > zombie.soundStrength
				if zombie.soundId == nil or isNewer or isLouder then
					zombie.soundId = point.id
					zombie.soundStrength = point.strength
					zombie.soundCreatedAt = point.createdAt
					zombie.goalX = point.x
					zombie.goalZ = point.z
					setState(zombie, "SeekSound")
				end
			end
		end
	end
end

function ZombieService.getStats(): Stats
	local now = os.clock()
	local window = now - stepWindowStart
	if window >= 1 then
		stepsPerSecond = stepCount / window
		stepCount = 0
		stepWindowStart = now
	end
	local stats = {
		alive = aliveCount,
		queued = spawnQueue,
		tickMs = tickMsAvg,
		tickMaxMs = tickMsMax,
		stepsPerSecond = stepsPerSecond,
	}
	tickMsMax = 0
	return stats
end

function ZombieService.getNavGrid(): NavGrid.NavGrid
	return grid
end

return ZombieService
