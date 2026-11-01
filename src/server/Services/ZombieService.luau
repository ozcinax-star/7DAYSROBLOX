--!strict
-- ZombieService: Humanoid-free zombie simulation. Zombies are plain data on the server (position,
-- state, target, health); clients build, animate and interpolate the models themselves.
--
-- Movement: shared flow fields (one toward all players, one per recent sound point), plus a small
-- per-zombie spread offset and separation so the horde does not walk in single file.
-- LOD: zombies near a player tick at NearHz, the rest at FarHz. Snapshots carry only zombies that
-- changed since the previous snapshot, with a periodic full snapshot.
--
-- Non-horde zombies are slow walkers. Wanderers near a building sometimes walk in through a door
-- (a small precomputed flow field per building), linger inside and walk out again. A few zombies
-- spawn inside buildings as sleepers that stand still until they see, hear or bump into a player.
--
-- Upper floors are a second navigation layer (templates have at most two floors). Each flight of
-- stairs links the ground cell at its foot to the upper cell at its top; a zombie whose goal is on
-- the other level walks to the nearest end, then follows the flight with its height on the steps.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Melee = require(Shared.Melee)
local NavGrid = require(Shared.NavGrid)
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local ZombieKinds = require(Shared.ZombieKinds)
local ZombieProtocol = require(Shared.ZombieProtocol)
local HeightField = require(Shared.World.HeightField)
local WorldLayout = require(Shared.World.WorldLayout)

local DayNightService = require(script.Parent.DayNightService)
local MapService = require(script.Parent.MapService)
local BuildingKit = require(script.Parent.Parent.World.BuildingKit)

local ZC = Config.Zombie
local FC = Config.FlowField
local NC = Config.Network

local GROUND = 1
local UPPER = 2
local FLOOR_HEIGHT = BuildingKit.FloorHeight
local SIGHT_COS = math.cos(math.rad(ZC.SightConeDegrees / 2))
local SPAWN_VIEW_COS = math.cos(math.rad(ZC.SpawnViewDegrees / 2))
-- Distance from the foot or top cell centre at which a zombie steps onto the flight (studs).
local STAIR_SNAP = 1
-- Closest a zombie's path offset may come to the edge of the waypoint's cell (studs).
local SPREAD_EDGE = 0.25

type WanderMode = "Free" | "Enter" | "Linger" | "Exit"

-- One flight of stairs between the ground level and the upper level of a building.
type StairLink = {
	building: number,
	footCell: number,
	topCell: number,
	footX: number,
	footZ: number,
	topX: number,
	topZ: number,
	-- Unit direction from foot to top.
	dirX: number,
	dirZ: number,
	-- Walking surfaces at the foot and at the top.
	lowY: number,
	highY: number,
	-- Distance from the foot centre to the first step, length of the flight, and the lift of the
	-- walking line above the straight line between the floors (half a riser, onto the treads).
	rampStart: number,
	rampLength: number,
	riser: number,
	-- Next time a zombie may step onto the flight (StairSpacing).
	nextStart: number,
}

type Zombie = {
	id: number,
	x: number,
	y: number,
	z: number,
	health: number,
	-- Config.Zombie.Kinds entry, from the id (ZombieKinds).
	kind: Config.ZombieKind,
	-- The health it spawned with (the hit bar's maximum).
	maxHealth: number,
	state: Types.ZombieState,
	-- Random per-zombie speed scale (SpeedJitter).
	speedFactor: number,
	-- Sleepers stand still until they notice a player.
	dormant: boolean,
	-- Horde-night zombies always know where the nearest player is and run (7DTD blood moon).
	horde: boolean,
	wanderMode: WanderMode,
	-- Index into buildingNavs while entering, lingering in or leaving a building; on the upper level
	-- always the building the zombie is in.
	building: number,
	-- While entering: once inside, the zombie stops walking at this deadline.
	insideUntil: number,
	stunUntil: number,
	-- Until slowUntil the zombie walks at slowFactor of its speed (spike traps).
	slowUntil: number,
	slowFactor: number,
	-- Navigation level (GROUND or UPPER) and, while on the stairs, the flight and its direction.
	level: number,
	stair: StairLink?,
	stairUp: boolean,
	-- Level and building of the goal point (heard sound, house visit).
	goalLevel: number,
	goalBuilding: number,
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
	-- Ground cell of the player structure this zombie walked into this step, and whether it is
	-- breaking one (sent to clients as AttackStructure).
	pushing: number?,
	-- Seconds wedged with no wall to push and no free axis, and the side it slides out to (1 / -1).
	stuckFor: number,
	slideSide: number,
	-- Unit direction of the last step taken: where the zombie looks (sight cone).
	faceX: number,
	faceZ: number,
	breaking: boolean,
	dirty: boolean,
	-- Last state put in a snapshot, and how many more snapshots repeat it: snapshots are unreliable and
	-- a standing zombie is never dirty again, so a lost attack state would otherwise wait for a full one.
	sentState: string,
	stateResends: number,
}

-- (x and z of the ground cell's centre, damage) for a zombie hitting a player structure.
export type StructureHitCallback = (x: number, z: number, damage: number) -> ()

type PlayerInfo = {
	player: Player,
	x: number,
	y: number,
	z: number,
	humanoid: Humanoid,
	root: BasePart,
	level: number,
	building: number,
}

-- Ground field toward the player, or toward the stairs of the building whose upper floor they are on.
type PlayerField = {
	field: NavGrid.Field?,
	rebuildAt: number,
	level: number,
	building: number,
}

type SoundField = {
	field: NavGrid.Field,
	lastUsed: number,
}

-- Door navigation of one building: following `enter` leads to any walkable ground-floor cell
-- inside, following `exit` leads to the cell in front of a doorway.
type BuildingNav = {
	minX: number,
	minZ: number,
	maxX: number,
	maxZ: number,
	centerX: number,
	centerZ: number,
	interior: { number },
	enter: NavGrid.Field?,
	exit: NavGrid.Field?,
	-- Upper floor: walking height, flights, open cells (empty in one-storey buildings), ground cells
	-- at the foot of the stairs, and fields toward the feet (ground) and the tops (upper level).
	upperY: number,
	links: { StairLink },
	upperCells: { number },
	footCells: { number },
	footField: NavGrid.Field?,
	topField: NavGrid.Field?,
	-- Cell window of the footprint, for upper-level fields.
	wx0: number,
	wz0: number,
	wx1: number,
	wz1: number,
}

export type DiedCallback = (x: number, y: number, z: number, killer: Player?) -> ()

export type Stats = {
	alive: number,
	queued: number,
	tickMs: number,
	tickMaxMs: number,
	stepsPerSecond: number,
}

local ZombieService = {}

local grid: NavGrid.NavGrid
-- Ground cell costs from the terrain alone (water, bounds, slopes), before map parts block cells; nil
-- until the navigation is marked. Reopening cells starts from here.
local terrainCost: buffer? = nil
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include
overlapParams.RespectCanCollide = true
-- Upper floors of every building in one layer (footprints never overlap); levels[GROUND] is `grid`.
local upperGrid: NavGrid.NavGrid
local levels: { NavGrid.NavGrid } = {}
local playerFields: { [Player]: PlayerField } = {}
local soundFields: { [number]: SoundField } = {}
local soundFieldCount = 0

local zombies: { [number]: Zombie } = {}
local buildingNavs: { BuildingNav } = {}
-- Buildings with stairs, and the flight starting at a ground cell / arriving at an upper cell.
local multiStorey: { number } = {}
local footLinks: { [number]: StairLink } = {}
local topLinks: { [number]: StairLink } = {}
-- Upper-level fields toward one goal cell, built on first use (upper floors are small).
local upperFields: { [number]: NavGrid.Field } = {}
local diedCallbacks: { DiedCallback } = {}
-- Ground cells holding a player structure that blocks zombies (BuildService), with their path cost.
local structureCosts: { [number]: number } = {}
local hasStructures = false
local structureHit: StructureHitCallback? = nil
local aliveCount = 0
local nextId = 1
local spawnQueue = 0
local hordeQueue = 0
local nextWaveTime = 0

local removedIds: { number } = {}
local killedIds: { number } = {}
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

local function isInside(nav: BuildingNav, x: number, z: number): boolean
	return x >= nav.minX and x <= nav.maxX and z >= nav.minZ and z <= nav.maxZ
end

-- Level and building of a root-height point (feet + RootHeight): UPPER with the building index when
-- it is on (or above) the upper floor of a building with stairs, else GROUND and 0.
local function locate(x: number, y: number, z: number): (number, number)
	for _, index in multiStorey do
		local nav = buildingNavs[index]
		if isInside(nav, x, z) and y - ZC.RootHeight >= nav.upperY - ZC.LevelSlack then
			local cell = upperGrid:cellAt(x, z)
			if cell and upperGrid:nearestWalkable(cell, 2) then
				return UPPER, index
			end
		end
	end
	return GROUND, 0
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
				local level, building = locate(p.X, p.Y, p.Z)
				table.insert(list, {
					player = player,
					x = p.X,
					y = p.Y,
					z = p.Z,
					humanoid = humanoid,
					root = root,
					level = level,
					building = building,
				})
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

-- The building containing (x, z), else the one whose centre is closest within `radius`.
local function nearbyBuilding(x: number, z: number, radius: number): number?
	local best: number? = nil
	local bestDistSq = radius * radius
	for index, nav in buildingNavs do
		if isInside(nav, x, z) then
			return index
		end
		local dx, dz = nav.centerX - x, nav.centerZ - z
		local d = dx * dx + dz * dz
		if d < bestDistSq then
			bestDistSq = d
			best = index
		end
	end
	return best
end

local function enterSearch(zombie: Zombie, now: number, x: number, z: number)
	setState(zombie, "Search")
	zombie.soundId = nil
	zombie.targetPlayer = nil
	zombie.goalX = x
	zombie.goalZ = z
	zombie.stateUntil = now + ZC.SearchDuration
end

local function enterLinger(zombie: Zombie, now: number)
	setState(zombie, "Idle")
	zombie.wanderMode = "Linger"
	zombie.stateUntil = now + randomRange(ZC.LingerMin, ZC.LingerMax)
end

local function enterWander(zombie: Zombie, now: number)
	setState(zombie, "Wander")
	zombie.soundId = nil
	zombie.soundStrength = 0
	zombie.targetPlayer = nil
	zombie.wanderMode = "Free"
	zombie.goalLevel = zombie.level
	zombie.goalX = zombie.x + randomRange(-ZC.WanderRadius, ZC.WanderRadius)
	zombie.goalZ = zombie.z + randomRange(-ZC.WanderRadius, ZC.WanderRadius)
	zombie.stateUntil = now + randomRange(ZC.WanderRetargetMin, ZC.WanderRetargetMax)

	-- Inside a building: linger or head for a door. Near one: sometimes walk in.
	local index = nearbyBuilding(zombie.x, zombie.z, ZC.HouseVisitRadius)
	if index == nil then
		return
	end
	local nav = buildingNavs[index]
	zombie.building = index
	if isInside(nav, zombie.x, zombie.z) then
		if nav.exit and math.random() < ZC.HouseExitChance then
			setState(zombie, "Wander")
			zombie.wanderMode = "Exit"
			zombie.stateUntil = now + ZC.LingerMax * 2
		else
			enterLinger(zombie, now)
		end
	else
		-- A visit picks any floor cell, upstairs included.
		local groundCount = if nav.enter then #nav.interior else 0
		local upperCount = #nav.upperCells
		if groundCount + upperCount > 0 and math.random() < ZC.HouseVisitChance then
			local pick = math.random(1, groundCount + upperCount)
			if pick <= groundCount then
				zombie.goalX, zombie.goalZ = grid:cellCenter(nav.interior[pick])
				zombie.goalLevel = GROUND
			else
				zombie.goalX, zombie.goalZ = upperGrid:cellCenter(nav.upperCells[pick - groundCount])
				zombie.goalLevel = UPPER
			end
			zombie.goalBuilding = index
			zombie.wanderMode = "Enter"
			zombie.insideUntil = math.huge
			zombie.stateUntil = now + ZC.LingerMax * 2
		end
	end
end

-- Wakes a sleeper or wanderer and sends it after `player`.
local function startChase(zombie: Zombie, player: Player)
	zombie.dormant = false
	zombie.targetPlayer = player
	zombie.soundId = nil
	setState(zombie, "Chase")
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
	local field = grid:buildField({ cell }, grid:windowAround(x, z, FC.FieldRadius))
	soundFields[soundId] = { field = field, lastUsed = now }
	soundFieldCount += 1
	return field
end

-- Moves the zombie toward (tx, tz) at `speed`, sliding along blocked cells.
-- The structure cell at (x, z) when it is not `here` (the cell the zombie stands in), else nil.
local function structureCell(here: number?, x: number, z: number): number?
	if here == nil then
		return nil
	end
	local cell = grid:cellAt(x, z)
	return if cell and cell ~= here and structureCosts[cell] then cell else nil
end

local function isFree(g: NavGrid.NavGrid, here: number?, x: number, z: number): boolean
	return g:isWalkable(x, z) and structureCell(here, x, z) == nil
end

-- Steps toward (tx, tz), sliding along walls. Player structures stop the step: a zombie aimed into
-- one, or stuck against it, is marked as pushing it (stepZombie decides whether it breaks it).
local function moveToward(zombie: Zombie, tx: number, tz: number, speed: number, dt: number)
	if zombie.slowUntil > os.clock() then
		speed *= zombie.slowFactor
	end
	local dx = tx - zombie.x
	local dz = tz - zombie.z
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist < 1e-3 then
		return
	end
	zombie.faceX, zombie.faceZ = dx / dist, dz / dist
	local step = math.min(dist, speed * dt)
	local nx = zombie.x + dx / dist * step
	local nz = zombie.z + dz / dist * step
	local g = levels[zombie.level]
	local here = if hasStructures and zombie.level == GROUND then grid:cellAt(zombie.x, zombie.z) else nil
	if isFree(g, here, nx, nz) then
		zombie.x = nx
		zombie.z = nz
	else
		local wall = structureCell(here, nx, nz)
		if wall and structureCell(here, tx, tz) == wall then
			zombie.pushing = wall
			return
		end
		if isFree(g, here, nx, zombie.z) then
			zombie.x = nx
		elseif isFree(g, here, zombie.x, nz) then
			zombie.z = nz
		else
			zombie.pushing = wall
			if wall ~= nil then
				return
			end
			-- Wedged on a corner the flow field cannot see (furniture, a prop edge): after a moment,
			-- slide sideways; if that side is shut too, try the other one next step.
			zombie.stuckFor += dt
			if zombie.stuckFor < ZC.StuckSeconds then
				return
			end
			local sx = -dz / dist * zombie.slideSide * step
			local sz = dx / dist * zombie.slideSide * step
			if not isFree(g, here, zombie.x + sx, zombie.z + sz) then
				zombie.slideSide = -zombie.slideSide
				return
			end
			zombie.x += sx
			zombie.z += sz
		end
	end
	if zombie.stuckFor > 0 and isFree(g, here, nx, nz) then
		zombie.stuckFor = 0
	end
	local floor = if zombie.level == GROUND
		then MapService.groundAt(zombie.x, zombie.z)
		else buildingNavs[zombie.building].upperY
	zombie.y = floor + ZC.RootHeight
	zombie.dirty = true
end

-- Follows `field` toward a goal; steers straight only in the goal cell or when the field has no path
-- (outside its window), so a wall between zombie and target is always walked around.
local function followField(
	zombie: Zombie,
	field: NavGrid.Field?,
	goalX: number,
	goalZ: number,
	speed: number,
	dt: number
)
	if field then
		local g = levels[zombie.level]
		local wx, wz = g:nextWaypoint(field, zombie.x, zombie.z)
		if wx and wz then
			-- The offset point stays inside the waypoint's cell: past its edge it can lie in the cell the
			-- zombie stands in, which reaches it and then stands there for good.
			local limit = g.cellSize / 2 - SPREAD_EDGE
			local sx = wx + math.clamp(zombie.spreadX, -limit, limit)
			local sz = wz + math.clamp(zombie.spreadZ, -limit, limit)
			-- The spread offset must not lead into a structure the path itself does not cross.
			local spreadCell = if hasStructures then g:cellAt(sx, sz) else nil
			local intoWall = spreadCell ~= nil and structureCosts[spreadCell] ~= nil and spreadCell ~= g:cellAt(wx, wz)
			if g:isWalkable(sx, sz) and not intoWall then
				moveToward(zombie, sx, sz, speed, dt)
			else
				moveToward(zombie, wx, wz, speed, dt)
			end
			return
		end
	end
	moveToward(zombie, goalX, goalZ, speed, dt)
end

-- Upper-level field toward the cell at (x, z) of building `index`.
local function upperField(index: number, x: number, z: number): NavGrid.Field?
	local cell = upperGrid:cellAt(x, z)
	local nav = buildingNavs[index]
	if cell == nil or nav == nil then
		return nil
	end
	local field = upperFields[cell]
	if field == nil then
		field = upperGrid:buildField({ cell }, nav.wx0, nav.wz0, nav.wx1, nav.wz1)
		upperFields[cell] = field
	end
	return field
end

-- Walks a zombie along its flight with the height on the steps; at the end it changes level.
local function stepStair(zombie: Zombie, speed: number, dt: number)
	local link = zombie.stair :: StairLink
	local up = zombie.stairUp
	local tx = if up then link.topX else link.footX
	local tz = if up then link.topZ else link.footZ
	local dx, dz = tx - zombie.x, tz - zombie.z
	local dist = math.sqrt(dx * dx + dz * dz)
	local step = speed * ZC.StairSpeedMultiplier * dt
	if dist <= step then
		zombie.x, zombie.z = tx, tz
		zombie.stair = nil
		zombie.level = if up then UPPER else GROUND
		zombie.building = link.building
		zombie.y = (if up then link.highY else link.lowY) + ZC.RootHeight
	else
		zombie.x += dx / dist * step
		zombie.z += dz / dist * step
		local height = link.highY - link.lowY
		local along = (zombie.x - link.footX) * link.dirX + (zombie.z - link.footZ) * link.dirZ
		local rise = (along - link.rampStart) / link.rampLength * height + link.riser
		zombie.y = link.lowY + math.clamp(rise, 0, height) + ZC.RootHeight
	end
	zombie.dirty = true
end

-- The flight of `nav` whose foot (up) or top (down) is closest to (x, z).
local function nearestStair(nav: BuildingNav, up: boolean, x: number, z: number): StairLink
	local best = nav.links[1]
	local bestSq = math.huge
	for _, link in nav.links do
		local dx = (if up then link.footX else link.topX) - x
		local dz = (if up then link.footZ else link.topZ) - z
		local d = dx * dx + dz * dz
		if d < bestSq then
			bestSq = d
			best = link
		end
	end
	return best
end

-- Walks toward a goal on either level. On the goal's level (upstairs: in the goal's building) the
-- zombie follows `groundField` or an upper-level field; otherwise it takes the stairs first, up those
-- of the goal building or down those of the building it is in. `groundField` leads to the goal on the
-- ground, or to the goal building's stair feet when the goal is upstairs (nil: the building's own).
local function travel(
	zombie: Zombie,
	goalX: number,
	goalZ: number,
	goalLevel: number,
	goalBuilding: number,
	groundField: NavGrid.Field?,
	speed: number,
	dt: number,
	now: number
)
	if zombie.stair then
		stepStair(zombie, speed, dt)
		return
	end
	local level = zombie.level
	if level == goalLevel and (level == GROUND or zombie.building == goalBuilding) then
		local field = if level == GROUND then groundField else upperField(goalBuilding, goalX, goalZ)
		followField(zombie, field, goalX, goalZ, speed, dt)
		return
	end
	local up = level == GROUND
	local index = if up then goalBuilding else zombie.building
	local nav = buildingNavs[index]
	if nav == nil or #nav.links == 0 then
		followField(zombie, if up then groundField else nil, goalX, goalZ, speed, dt)
		return
	end
	local g = levels[level]
	local cell = g:cellAt(zombie.x, zombie.z)
	local link = if cell == nil then nil elseif up then footLinks[cell] else topLinks[cell]
	if link and link.building == index then
		local px = if up then link.footX else link.topX
		local pz = if up then link.footZ else link.topZ
		local dx, dz = px - zombie.x, pz - zombie.z
		if dx * dx + dz * dz > STAIR_SNAP * STAIR_SNAP then
			moveToward(zombie, px, pz, speed, dt)
		elseif now >= link.nextStart then
			link.nextStart = now + ZC.StairSpacing
			zombie.stair = link
			zombie.stairUp = up
		end
		return
	end
	-- Next to the end cell, walk straight onto it: the spread offset could otherwise keep the zombie
	-- circling the single cell it must reach.
	local field = if up then groundField or nav.footField else nav.topField
	local target = nearestStair(nav, up, zombie.x, zombie.z)
	local px = if up then target.footX else target.topX
	local pz = if up then target.footZ else target.topZ
	if cell and field and g:distanceAt(field, cell) <= 1 then
		moveToward(zombie, px, pz, speed, dt)
	else
		followField(zombie, field, px, pz, speed, dt)
	end
end

-- Walking speed of the zombie's current behaviour.
local function stateSpeed(zombie: Zombie): number
	local state = zombie.state
	local base = if state == "Chase" or state == "AttackPlayer"
		then (if zombie.horde then ZC.HordeChaseSpeed else ZC.ChaseSpeed)
		elseif state == "SeekSound" then ZC.SeekSpeed
		else ZC.WanderSpeed
	return base * zombie.speedFactor
end

-- Wander behaviour: free roaming, or walking into, lingering in and leaving a building.
local function stepWander(zombie: Zombie, now: number, dt: number)
	local speed = ZC.WanderSpeed * zombie.speedFactor
	local mode = zombie.wanderMode
	local nav = buildingNavs[zombie.building]
	if mode == "Linger" then
		if now >= zombie.stateUntil then
			enterWander(zombie, now)
		end
		return
	elseif mode == "Enter" and nav then
		if now >= zombie.stateUntil then
			enterWander(zombie, now)
			return
		end
		local upstairs = zombie.goalLevel == UPPER
		local arrived
		if upstairs then
			arrived = zombie.level == UPPER and zombie.stair == nil
		else
			local cell = grid:cellAt(zombie.x, zombie.z)
			arrived = cell ~= nil and nav.enter ~= nil and grid:distanceAt(nav.enter, cell) == 0
		end
		if arrived then
			-- Inside (on the chosen floor): walk a little further in, then stand.
			if zombie.insideUntil == math.huge then
				zombie.insideUntil = now + ZC.WanderRetargetMax
			end
			local dx, dz = zombie.goalX - zombie.x, zombie.goalZ - zombie.z
			if now >= zombie.insideUntil or dx * dx + dz * dz <= ZC.ArriveDistance * ZC.ArriveDistance then
				enterLinger(zombie, now)
				return
			end
		end
		if upstairs then
			travel(zombie, zombie.goalX, zombie.goalZ, UPPER, zombie.building, nil, speed, dt, now)
		elseif arrived then
			moveToward(zombie, zombie.goalX, zombie.goalZ, speed, dt)
		else
			followField(zombie, nav.enter, nav.centerX, nav.centerZ, speed, dt)
		end
		return
	elseif mode == "Exit" and nav then
		if zombie.level == UPPER then
			-- Down the stairs first.
			travel(zombie, nav.centerX, nav.centerZ, GROUND, 0, nav.exit, speed, dt, now)
			return
		end
		local field = nav.exit :: NavGrid.Field
		local cell = grid:cellAt(zombie.x, zombie.z)
		if now >= zombie.stateUntil or cell == nil or grid:distanceAt(field, cell) == 0 then
			-- Out of the door: walk away from the building.
			zombie.wanderMode = "Free"
			local dx, dz = zombie.x - nav.centerX, zombie.z - nav.centerZ
			local length = math.max(1e-3, math.sqrt(dx * dx + dz * dz))
			zombie.goalX = zombie.x + dx / length * ZC.WanderRadius
			zombie.goalZ = zombie.z + dz / length * ZC.WanderRadius
			zombie.stateUntil = now + randomRange(ZC.WanderRetargetMin, ZC.WanderRetargetMax)
			return
		end
		followField(zombie, field, nav.centerX, nav.centerZ, speed, dt)
		return
	end
	if now >= zombie.stateUntil or zombie.state == "Idle" then
		enterWander(zombie, now)
		if zombie.wanderMode ~= "Free" then
			return
		end
	end
	moveToward(zombie, zombie.goalX, zombie.goalZ, speed, dt)
end

local stepMovement: (zombie: Zombie, players: { PlayerInfo }, now: number, dt: number) -> ()

-- True when `target` is inside the zombie's field of view, or close enough to be sensed anyway.
local function inSightCone(zombie: Zombie, target: PlayerInfo, dist: number): boolean
	if dist <= ZC.SenseRange or dist < 1e-3 then
		return true
	end
	local dot = ((target.x - zombie.x) * zombie.faceX + (target.z - zombie.z) * zombie.faceZ) / dist
	return dot >= SIGHT_COS
end

local function stepZombie(zombie: Zombie, players: { PlayerInfo }, now: number, dt: number)
	local nearest, nearestDist = nearestPlayer(players, zombie.x, zombie.z)

	-- Direct sight overrides sounds. Sleepers see less, but wake when a player bumps into them.
	local state = zombie.state
	if zombie.horde and nearest and (zombie.targetPlayer == nil or (state ~= "Chase" and state ~= "AttackPlayer")) then
		startChase(zombie, nearest.player)
		state = zombie.state
	end
	if state ~= "Chase" and state ~= "AttackPlayer" and nearest and now >= zombie.nextSightCheck then
		zombie.nextSightCheck = now + ZC.SightCheckInterval
		local sight = if zombie.dormant then ZC.DormantSightRange else ZC.SightRange
		-- Only a player on the same floor bumps into a sleeper, not one walking on the floor above.
		local bumped = zombie.dormant
			and nearestDist <= ZC.DormantWakeDistance
			and math.abs(nearest.y - zombie.y) < FLOOR_HEIGHT / 2
		if bumped or (nearestDist <= sight and inSightCone(zombie, nearest, nearestDist) and hasLineOfSight(zombie, nearest)) then
			startChase(zombie, nearest.player)
		end
	end

	if now < zombie.stunUntil then
		return
	end

	zombie.pushing = nil
	stepMovement(zombie, players, now, dt)
	-- A chasing or seeking zombie that walked into a player structure breaks it (7DTD: zombies dig
	-- through blocks on their path); wanderers only stop.
	local moved = zombie.state
	local breaking = zombie.pushing ~= nil and (moved == "Chase" or moved == "SeekSound")
	if breaking ~= zombie.breaking then
		zombie.breaking = breaking
		zombie.dirty = true
		if breaking then
			zombie.nextAttack = math.max(zombie.nextAttack, now + ZC.AttackWindup)
		end
	end
	local cell = zombie.pushing
	if breaking and cell and structureHit and now >= zombie.nextAttack then
		zombie.nextAttack = now + (if DayNightService.isNight() then ZC.AttackCooldownNight else ZC.AttackCooldown)
		local x, z = grid:cellCenter(cell)
		task.spawn(structureHit, x, z, ZC.AttackBlockDamage)
	end
end

-- Moves a zombie one step for its state: chase, attack, seek, search or wander.
function stepMovement(zombie: Zombie, players: { PlayerInfo }, now: number, dt: number)
	local state = zombie.state
	-- A zombie on the stairs finishes the flight before anything but a chase moves it.
	if zombie.stair and state ~= "Chase" and state ~= "AttackPlayer" then
		stepStair(zombie, stateSpeed(zombie), dt)
		return
	end
	if state == "Chase" or state == "AttackPlayer" then
		local target = findPlayerInfo(players, zombie.targetPlayer)
		if target == nil then
			-- A horde zombie whose target left or died goes for the next player.
			zombie.targetPlayer = nil
			if not zombie.horde then
				enterSearch(zombie, now, zombie.x, zombie.z)
			end
			return
		end
		local dx = target.x - zombie.x
		local dz = target.z - zombie.z
		local dist = math.sqrt(dx * dx + dz * dz)
		if not zombie.horde and dist > ZC.SightRange * ZC.LoseSightMultiplier then
			enterSearch(zombie, now, target.x, target.z)
			return
		end
		-- The height check keeps a zombie from hitting a player on the floor above or on a roof.
		if dist <= ZC.AttackRange and math.abs(target.y - zombie.y) <= ZC.AttackHeightTolerance then
			if state ~= "AttackPlayer" then
				-- Arms go out first; the client plays the grab at the same moment.
				zombie.nextAttack = math.max(zombie.nextAttack, now + ZC.AttackWindup)
				setState(zombie, "AttackPlayer")
			end
			if now >= zombie.nextAttack then
				zombie.nextAttack = now
					+ (if DayNightService.isNight() then ZC.AttackCooldownNight else ZC.AttackCooldown)
				target.humanoid:TakeDamage(ZC.AttackDamage * zombie.kind.DamageShare)
			end
			return
		end
		setState(zombie, "Chase")
		local entry = playerFields[target.player]
		local speed = stateSpeed(zombie)
		travel(zombie, target.x, target.z, target.level, target.building, entry and entry.field, speed, dt, now)
	elseif state == "SeekSound" then
		local dx = zombie.goalX - zombie.x
		local dz = zombie.goalZ - zombie.z
		local sameLevel = zombie.level == zombie.goalLevel
			and zombie.stair == nil
			and (zombie.level == GROUND or zombie.building == zombie.goalBuilding)
		if sameLevel and dx * dx + dz * dz <= ZC.ArriveDistance * ZC.ArriveDistance then
			enterSearch(zombie, now, zombie.goalX, zombie.goalZ)
			return
		end
		-- The sound's ground field is useless for a sound upstairs; travel uses the stair field then.
		local field = if zombie.goalLevel == GROUND
			then getSoundField(zombie.soundId :: number, zombie.goalX, zombie.goalZ, now)
			else nil
		local speed = ZC.SeekSpeed * zombie.speedFactor
		travel(zombie, zombie.goalX, zombie.goalZ, zombie.goalLevel, zombie.goalBuilding, field, speed, dt, now)
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
		moveToward(zombie, zombie.goalX, zombie.goalZ, ZC.WanderSpeed * zombie.speedFactor, dt)
	elseif not zombie.dormant then
		stepWander(zombie, now, dt)
	end
end

-- Pushes zombies that share a cell apart. Cheap O(n) bucket pass, run on the zombies stepped this frame.
local function separate(stepped: { Zombie })
	-- Buckets are per level (zombies on the stairs follow their flight and are left out).
	local buckets: { [number]: { Zombie } } = {}
	for _, zombie in stepped do
		local cell = if zombie.stair then nil else levels[zombie.level]:cellAt(zombie.x, zombie.z)
		if cell then
			local key = cell + (zombie.level - 1) * grid.cellCount
			local bucket = buckets[key]
			if bucket == nil then
				buckets[key] = { zombie }
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
						-- Pushes never move a zombie into a wall or a player structure.
						local g = levels[a.level]
						local here = if hasStructures and a.level == GROUND then grid:cellAt(a.x, a.z) else nil
						if isFree(g, here, a.x - px, a.z - pz) then
							a.x -= px
							a.z -= pz
						end
						if isFree(g, here, b.x + px, b.z + pz) then
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

-- An interior floor cell (either floor) of a building near a random player, out of every player's
-- sight and at least IndoorSpawnMinDistance away from all of them, and not inside a player's block.
-- Returns x, z, level and building.
local function pickIndoorSpawnPoint(players: { PlayerInfo }): (number?, number?, number, number)
	if #players == 0 or #buildingNavs == 0 then
		return nil, nil, GROUND, 0
	end
	local anchor = players[math.random(1, #players)]
	local maxSq = ZC.SpawnMaxDistance * ZC.SpawnMaxDistance
	local minSq = ZC.IndoorSpawnMinDistance * ZC.IndoorSpawnMinDistance
	for _ = 1, ZC.SpawnAttempts do
		local index = math.random(1, #buildingNavs)
		local nav = buildingNavs[index]
		local groundCount, upperCount = #nav.interior, #nav.upperCells
		local dx, dz = nav.centerX - anchor.x, nav.centerZ - anchor.z
		if groundCount + upperCount > 0 and dx * dx + dz * dz <= maxSq then
			local pick = math.random(1, groundCount + upperCount)
			local level, x, z, floor
			local ok = true
			if pick <= groundCount then
				level = GROUND
				x, z = grid:cellCenter(nav.interior[pick])
				floor = MapService.groundAt(x, z)
				ok = structureCosts[nav.interior[pick]] == nil
			else
				level = UPPER
				x, z = upperGrid:cellCenter(nav.upperCells[pick - groundCount])
				floor = nav.upperY
			end
			local spot = Vector3.new(x, floor + ZC.RootHeight, z)
			for _, info in players do
				if not ok then
					break
				end
				local px, pz = x - info.x, z - info.z
				if px * px + pz * pz < minSq then
					ok = false
					break
				end
				local origin = Vector3.new(info.x, info.y, info.z)
				if Workspace:Raycast(origin, spot - origin, sightParams) == nil then
					ok = false
					break
				end
			end
			if ok then
				return x, z, level, index
			end
		end
	end
	return nil, nil, GROUND, 0
end

-- True when a player faces (x, z) within Config.Zombie.SpawnHiddenDistance and nothing blocks the view:
-- a zombie appearing there would pop in before their eyes.
local function seenFromPlayers(players: { PlayerInfo }, x: number, z: number): boolean
	local y = MapService.groundAt(x, z) + ZC.RootHeight
	for _, info in players do
		local dx, dz = x - info.x, z - info.z
		local dist = math.sqrt(dx * dx + dz * dz)
		if dist <= ZC.SpawnHiddenDistance and dist > 1e-3 then
			local look = info.root.CFrame.LookVector
			local flat = math.sqrt(look.X * look.X + look.Z * look.Z)
			local facing = flat < 1e-3 or (look.X * dx + look.Z * dz) / (flat * dist) >= SPAWN_VIEW_COS
			if facing then
				local origin = Vector3.new(info.x, info.y, info.z)
				if Workspace:Raycast(origin, Vector3.new(x, y, z) - origin, sightParams) == nil then
					return true
				end
			end
		end
	end
	return false
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
		-- Never inside a player structure (structure cells are walkable for path costs), never in view.
		if isFree(grid, -1, x, z) and not seenFromPlayers(players, x, z) then
			return x, z
		end
	end
	return nil, nil
end

local function spawnOne(players: { PlayerInfo }, now: number, horde: boolean): boolean
	local id = allocateId()
	if id == nil then
		return false
	end
	local dormant = false
	local x, z
	local level, building = GROUND, 0
	if not horde and math.random() < ZC.IndoorSpawnChance then
		x, z, level, building = pickIndoorSpawnPoint(players)
		dormant = x ~= nil
	end
	if x == nil or z == nil then
		x, z = pickSpawnPoint(players)
		level, building = GROUND, 0
	end
	if x == nil or z == nil then
		return false
	end
	local floor = if level == UPPER then buildingNavs[building].upperY else MapService.groundAt(x, z)
	local spread = ZC.SpreadRadius
	local kind = ZombieKinds.of(id)
	local faceAngle = math.random() * math.pi * 2
	local health = ZC.MaxHealth * kind.HealthShare * (1 + randomRange(-ZC.HealthSpread, ZC.HealthSpread))
	local zombie: Zombie = {
		id = id,
		kind = kind,
		x = x,
		y = floor + ZC.RootHeight,
		z = z,
		health = health,
		maxHealth = health,
		state = "Idle",
		speedFactor = kind.SpeedShare * (1 + randomRange(-ZC.SpeedJitter, ZC.SpeedJitter)),
		dormant = dormant,
		horde = horde,
		wanderMode = "Free",
		building = building,
		insideUntil = 0,
		stunUntil = 0,
		slowUntil = 0,
		slowFactor = 1,
		level = level,
		stair = nil,
		stairUp = false,
		goalLevel = level,
		goalBuilding = building,
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
		pushing = nil,
		stuckFor = 0,
		slideSide = if math.random() < 0.5 then 1 else -1,
		faceX = math.cos(faceAngle),
		faceZ = math.sin(faceAngle),
		breaking = false,
		dirty = true,
		sentState = "",
		stateResends = 0,
	}
	zombies[id] = zombie
	aliveCount += 1
	return true
end

local function processSpawnQueue(players: { PlayerInfo }, now: number)
	if (spawnQueue <= 0 and hordeQueue <= 0) or now < nextWaveTime then
		return
	end
	local capped = false
	while spawnQueue > 0 or hordeQueue > 0 do
		if aliveCount >= Config.Horde.MaxConcurrent then
			capped = true
			break
		end
		local horde = hordeQueue > 0
		if not spawnOne(players, now, horde) then
			break
		end
		if horde then
			hordeQueue -= 1
		else
			spawnQueue -= 1
		end
	end
	if capped then
		-- Remaining zombies arrive as the next wave once slots are free.
		nextWaveTime = now + Config.Horde.WaveIntervalSeconds
	end
end

-- Rebuilds at most one due player field per frame so rebuild cost is spread out.
local function updatePlayerFields(players: { PlayerInfo }, now: number)
	for _, info in players do
		local entry = playerFields[info.player]
		if entry == nil then
			entry = { field = nil, rebuildAt = 0, level = GROUND, building = 0 }
			playerFields[info.player] = entry
		end
		-- Going up or down the stairs changes the field's goal at once, not at the next rebuild.
		if entry.level ~= info.level or entry.building ~= info.building then
			entry.rebuildAt = 0
		end
		if now >= entry.rebuildAt then
			entry.rebuildAt = now + FC.RebuildInterval
			entry.level = info.level
			entry.building = info.building
			local sources: { number }? = nil
			if info.level == UPPER then
				sources = buildingNavs[info.building].footCells
			else
				local cell = grid:cellAt(info.x, info.z)
				sources = if cell then { cell } else nil
			end
			if sources then
				entry.field = grid:buildField(sources, grid:windowAround(info.x, info.z, FC.FieldRadius))
			end
			return
		end
	end
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
		local state = if zombie.breaking then "AttackStructure" else zombie.state
		if state ~= zombie.sentState then
			zombie.sentState = state
			zombie.stateResends = NC.StateResends
		end
		if full or zombie.dirty or zombie.stateResends > 0 then
			zombie.dirty = false
			zombie.stateResends = math.max(0, zombie.stateResends - 1)
			table.insert(snapshotEntries, {
				id = zombie.id,
				x = zombie.x,
				y = zombie.y,
				z = zombie.z,
				state = state,
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

	if #removedIds > 0 or #killedIds > 0 then
		removedRemote:FireAllClients(removedIds, killedIds)
		removedIds = {}
		killedIds = {}
	end
end

local stepped: { Zombie } = {}

local function onHeartbeat()
	local started = os.clock()
	local now = started
	local players = collectPlayers()

	updatePlayerFields(players, now)

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
	grid = NavGrid.new(FC.CellSize, WorldLayout.HalfSize, FC.StructureCellCost)
	upperGrid = NavGrid.new(FC.CellSize, WorldLayout.HalfSize, FC.StructureCellCost, NavGrid.BLOCKED)
	levels = { grid, upperGrid }
	snapshotRemote = Net.unreliable("ZombieSnapshot")
	removedRemote = Net.event("ZombieRemoved")
end

-- World-space centre and half extents of a part's bounding box.
local function partBounds(part: BasePart): (Vector3, number, number, number)
	local cf, size = part.CFrame, part.Size
	local right, up, look = cf.RightVector, cf.UpVector, cf.LookVector
	local halfX = (math.abs(right.X) * size.X + math.abs(up.X) * size.Y + math.abs(look.X) * size.Z) / 2
	local halfY = (math.abs(right.Y) * size.X + math.abs(up.Y) * size.Y + math.abs(look.Y) * size.Z) / 2
	local halfZ = (math.abs(right.Z) * size.X + math.abs(up.Z) * size.Y + math.abs(look.Z) * size.Z) / 2
	return cf.Position, halfX, halfY, halfZ
end

-- Blocks the cells of `g` under a part box that crosses `walkHeight`.
local function blockAtHeight(
	g: NavGrid.NavGrid,
	p: Vector3,
	halfX: number,
	halfY: number,
	halfZ: number,
	walkHeight: number
)
	if p.Y - halfY <= walkHeight and p.Y + halfY >= walkHeight then
		local e = FC.RasterEpsilon
		g:blockRect(p.X - halfX + e, p.Z - halfZ + e, p.X + halfX - e, p.Z + halfZ - e)
	end
end

-- Blocks water, out-of-bounds and steep cells, then every collidable map part that stands in the way
-- at walking height (walls, trunks, furniture). Roofs, upper floors and canopies do not block.
-- Upper floors get their own layer: their floor cells open, then whatever crosses their walking height.
local function markNavigation()
	local heightGrid = MapService.getHeightGrid()
	assert(heightGrid.columns == grid.width, "height grid and nav grid must share the 4-stud cells")
	local width = grid.width
	local heights = heightGrid.heights
	local function heightOf(cx: number, cz: number): number
		return buffer.readf32(heights, (cz * width + cx) * 4)
	end
	for cz = 0, width - 1 do
		for cx = 0, width - 1 do
			local index = cz * width + cx
			local x, z = grid:cellCenter(index)
			local h = heightOf(cx, cz)
			local steep = (cx + 1 < width and math.abs(heightOf(cx + 1, cz) - h) > FC.MaxStepHeight)
				or (cz + 1 < width and math.abs(heightOf(cx, cz + 1) - h) > FC.MaxStepHeight)
			if steep or not HeightField.isPlayable(x, z) or HeightField.isWater(x, z) then
				grid:setCost(index, NavGrid.BLOCKED)
				if steep and cx + 1 < width then
					grid:setCost(index + 1, NavGrid.BLOCKED)
				end
			end
		end
		if cz % 64 == 0 then
			task.wait()
		end
	end
	local terrainOnly = buffer.create(grid.cellCount)
	buffer.copy(terrainOnly, 0, grid.cost)
	terrainCost = terrainOnly

	local count = 0
	for _, part in MapService.getMap():GetDescendants() do
		if part:IsA("BasePart") and part.CanCollide then
			local p, halfX, halfY, halfZ = partBounds(part)
			blockAtHeight(grid, p, halfX, halfY, halfZ, MapService.heightAt(p.X, p.Z) + FC.StepHeight)
		end
		count += 1
		if count % 2000 == 0 then
			task.wait()
		end
	end

	-- Walls, furniture and the railings around stair holes cross the upper walking height; the stair
	-- ramps and guards below end under it.
	for _, info in MapService.getBuildings() do
		if #info.upperCells > 0 then
			for _, point in info.upperCells do
				local cell = upperGrid:cellAt(point.X, point.Z)
				if cell then
					upperGrid:setCost(cell, NavGrid.NORMAL)
				end
			end
			local walkHeight = info.upperCells[1].Y + FC.StepHeight
			for _, part in info.model:GetDescendants() do
				if part:IsA("BasePart") and part.CanCollide then
					local p, halfX, halfY, halfZ = partBounds(part)
					blockAtHeight(upperGrid, p, halfX, halfY, halfZ, walkHeight)
				end
				count += 1
				if count % 2000 == 0 then
					task.wait()
				end
			end
		end
	end
end

-- Door flow fields per building: walkable ground-floor cells inside the footprint are the "enter"
-- sources, the cells in front of exterior doorways the "exit" sources. Two-storey buildings also get
-- their flights (both ends must be open, else the flight is reported and left out) and stair fields.
local function buildBuildingNavs()
	local size = FC.CellSize
	for _, info in MapService.getBuildings() do
		assert(info.floors <= 2, `{info.name}: zombie navigation supports at most two floors`)
		local index = #buildingNavs + 1
		local centerX = (info.minX + info.maxX) / 2
		local centerZ = (info.minZ + info.maxZ) / 2
		local halfExtent = math.max(info.maxX - info.minX, info.maxZ - info.minZ) / 2
		local wx0, wz0, wx1, wz1 = upperGrid:windowAround(centerX, centerZ, halfExtent + size)
		local nav: BuildingNav = {
			minX = info.minX,
			minZ = info.minZ,
			maxX = info.maxX,
			maxZ = info.maxZ,
			centerX = centerX,
			centerZ = centerZ,
			interior = {},
			enter = nil,
			exit = nil,
			upperY = info.baseY + FLOOR_HEIGHT + BuildingKit.FloorTop,
			links = {},
			upperCells = {},
			footCells = {},
			footField = nil,
			topField = nil,
			wx0 = wx0,
			wz0 = wz0,
			wx1 = wx1,
			wz1 = wz1,
		}
		for z = info.minZ + size / 2, info.maxZ, size do
			for x = info.minX + size / 2, info.maxX, size do
				local cell = grid:cellAt(x, z)
				if cell and grid:getCost(cell) ~= NavGrid.BLOCKED then
					table.insert(nav.interior, cell)
				end
			end
		end
		local x0, z0, x1, z1 = grid:windowAround(centerX, centerZ, halfExtent + ZC.BuildingFieldMargin)
		if #nav.interior > 0 then
			nav.enter = grid:buildField(nav.interior, x0, z0, x1, z1)
		end
		local fronts = {}
		for _, front in info.doorFronts do
			local cell = grid:cellAt(front.X, front.Z)
			if cell then
				table.insert(fronts, cell)
			end
		end
		if #fronts > 0 then
			nav.exit = grid:buildField(fronts, x0, z0, x1, z1)
		end

		local cellSize = Config.Build.GridSize
		for _, stair in info.stairs do
			local footCell = grid:cellAt(stair.foot.X, stair.foot.Z)
			local topCell = upperGrid:cellAt(stair.top.X, stair.top.Z)
			if
				footCell
				and topCell
				and grid:getCost(footCell) ~= NavGrid.BLOCKED
				and upperGrid:getCost(topCell) ~= NavGrid.BLOCKED
			then
				local dx, dz = stair.top.X - stair.foot.X, stair.top.Z - stair.foot.Z
				local length = math.sqrt(dx * dx + dz * dz)
				local link: StairLink = {
					building = index,
					footCell = footCell,
					topCell = topCell,
					footX = stair.foot.X,
					footZ = stair.foot.Z,
					topX = stair.top.X,
					topZ = stair.top.Z,
					dirX = dx / length,
					dirZ = dz / length,
					lowY = stair.foot.Y,
					highY = stair.top.Y,
					rampStart = cellSize / 2,
					rampLength = stair.cells * cellSize,
					riser = (stair.top.Y - stair.foot.Y) / (2 * BuildingKit.StepCount),
					nextStart = 0,
				}
				table.insert(nav.links, link)
				table.insert(nav.footCells, footCell)
				footLinks[footCell] = link
				topLinks[topCell] = link
			else
				warn(`ZombieService: a stair of {info.name} has a blocked end; zombies will not use it`)
			end
		end
		if #nav.links > 0 then
			for _, point in info.upperCells do
				local cell = upperGrid:cellAt(point.X, point.Z)
				if cell and upperGrid:getCost(cell) ~= NavGrid.BLOCKED then
					table.insert(nav.upperCells, cell)
				end
			end
			local tops = {}
			for _, link in nav.links do
				table.insert(tops, link.topCell)
			end
			nav.footField = grid:buildField(nav.footCells, x0, z0, x1, z1)
			nav.topField = upperGrid:buildField(tops, wx0, wz0, wx1, wz1)
			table.insert(multiStorey, index)
		end
		table.insert(buildingNavs, nav)
	end
end

function ZombieService.start()
	markNavigation()
	buildBuildingNavs()
	-- Player structures hide players too (bars do not); BuildService creates their folder and the
	-- collision groups in init.
	sightParams.CollisionGroup = Config.Build.ShotsGroup
	sightParams.FilterDescendantsInstances = {
		MapService.getMap(),
		Workspace.Terrain,
		Workspace:WaitForChild(Config.Build.FolderName),
	}
	Players.PlayerRemoving:Connect(function(player)
		playerFields[player] = nil
	end)
	RunService.Heartbeat:Connect(onHeartbeat)
end

-- Queues `count` zombies (horde-night zombies with `horde`); up to Horde.MaxConcurrent are alive at
-- once, the rest arrive in waves.
function ZombieService.spawn(count: number, horde: boolean?)
	-- A queue that is already waiting for the cap keeps its wave timer.
	if spawnQueue <= 0 and hordeQueue <= 0 then
		nextWaveTime = 0
	end
	if horde then
		hordeQueue += math.max(0, math.floor(count))
	else
		spawnQueue += math.max(0, math.floor(count))
	end
end

-- Zombies queued and not yet spawned: ordinary ones, then horde ones.
function ZombieService.queued(): (number, number)
	return spawnQueue, hordeQueue
end

-- Horde night is over: the horde zombies left become ordinary zombies.
function ZombieService.endHorde()
	hordeQueue = 0
	for _, zombie in zombies do
		zombie.horde = false
	end
end

-- Calls `callback` for every living zombie: id, position, whether it is chasing or attacking a
-- player, and whether it belongs to the horde.
function ZombieService.forEach(callback: (id: number, position: Vector3, busy: boolean, horde: boolean) -> ())
	for id, zombie in zombies do
		local busy = zombie.state == "Chase" or zombie.state == "AttackPlayer"
		callback(id, Vector3.new(zombie.x, zombie.y, zombie.z), busy, zombie.horde)
	end
end

-- Despawns a zombie without a death (no corpse, no loot).
function ZombieService.remove(id: number)
	if zombies[id] then
		zombies[id] = nil
		aliveCount -= 1
		table.insert(removedIds, id)
	end
end

function ZombieService.clear()
	spawnQueue = 0
	hordeQueue = 0
	for id in zombies do
		ZombieService.remove(id)
	end
end

-- Server-side damage entry point (weapons call this after validating the hit). A hit staggers the
-- zombie and turns it on the attacker; a kill leaves a corpse on every client and notifies the
-- onDied listeners (loot). Returns true when the hit killed the zombie.
function ZombieService.damage(id: number, amount: number, attacker: Player?): boolean
	local zombie = zombies[id]
	if zombie == nil or amount <= 0 then
		return false
	end
	zombie.health -= amount
	if zombie.health <= 0 then
		zombies[id] = nil
		aliveCount -= 1
		table.insert(killedIds, id)
		for _, callback in diedCallbacks do
			task.spawn(callback, zombie.x, zombie.y, zombie.z, attacker)
		end
		return true
	end
	zombie.stunUntil = os.clock() + ZC.HitStunSeconds
	if attacker and zombie.state ~= "Chase" and zombie.state ~= "AttackPlayer" then
		startChase(zombie, attacker)
	end
	zombie.dormant = false
	return false
end

-- A zombie's health and the health it spawned with; 0, 0 when it is gone.
function ZombieService.getHealth(id: number): (number, number)
	local zombie = zombies[id]
	if zombie == nil then
		return 0, 0
	end
	return math.max(0, zombie.health), zombie.maxHealth
end

-- Slows a zombie to `factor` of its speed for `seconds` (spike traps; 7DTD movement_factor).
function ZombieService.slow(id: number, factor: number, seconds: number)
	local zombie = zombies[id]
	if zombie then
		zombie.slowFactor = factor
		zombie.slowUntil = os.clock() + seconds
	end
end

-- Registers a listener for zombie deaths (body position, killing player if any).
function ZombieService.onDied(callback: DiedCallback)
	table.insert(diedCallbacks, callback)
end

-- Id of the zombie closest to `position` (3D, root height) within `radius` studs, or nil.
function ZombieService.nearest(position: Vector3, radius: number): number?
	local best: number? = nil
	local bestSq = radius * radius
	for id, zombie in zombies do
		local dx, dy, dz = zombie.x - position.X, zombie.y - position.Y, zombie.z - position.Z
		local d = dx * dx + dy * dy + dz * dz
		if d <= bestSq then
			bestSq = d
			best = id
		end
	end
	return best
end

-- Direction a zombie faces, as its client draws it: toward the player it chases or attacks,
-- otherwise toward its goal point; 0, 0 while it stands still.
local function facing(zombie: Zombie): (number, number)
	local tx, tz = zombie.goalX, zombie.goalZ
	local target = zombie.targetPlayer
	if target and (zombie.state == "Chase" or zombie.state == "AttackPlayer") then
		local character = target.Character
		local root = character and character.PrimaryPart
		if root then
			tx, tz = root.Position.X, root.Position.Z
		end
	elseif zombie.state == "Idle" or zombie.dormant then
		return 0, 0
	end
	local dx, dz = tx - zombie.x, tz - zombie.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-3 then
		return 0, 0
	end
	return dx / length, dz / length
end

-- Every zombie whose root is within `radius` studs of `position`, as plain numbers for Shared/Melee.
function ZombieService.bodiesNear(position: Vector3, radius: number): { Melee.Body }
	local bodies: { Melee.Body } = {}
	local radiusSq = radius * radius
	for id, zombie in zombies do
		local dx, dy, dz = zombie.x - position.X, zombie.y - position.Y, zombie.z - position.Z
		if dx * dx + dy * dy + dz * dz <= radiusSq then
			local fx, fz = facing(zombie)
			table.insert(bodies, { id = id, x = zombie.x, y = zombie.y, z = zombie.z, fx = fx, fz = fz })
		end
	end
	return bodies
end

-- Current server position of a zombie (root height), or nil if it does not exist.
function ZombieService.getPosition(id: number): Vector3?
	local zombie = zombies[id]
	if zombie == nil then
		return nil
	end
	return Vector3.new(zombie.x, zombie.y, zombie.z)
end

-- Called by ThreatService for every noise event. Zombies in hearing range walk to the newest or
-- loudest sound and keep going until something newer or louder is heard (PLAN: sound tracking).
function ZombieService.hearSound(point: Types.SoundPoint)
	local range = point.radius * ZC.HearingMultiplier
	local goalLevel, goalBuilding = locate(point.x, point.y, point.z)
	for _, zombie in zombies do
		local state = zombie.state
		if state ~= "Chase" and state ~= "AttackPlayer" then
			local dx = point.x - zombie.x
			local dz = point.z - zombie.z
			local heard = range * zombie.kind.HearingShare
			if dx * dx + dz * dz <= heard * heard then
				local isNewer = point.createdAt > zombie.soundCreatedAt
				local isLouder = point.strength > zombie.soundStrength
				if zombie.soundId == nil or isNewer or isLouder then
					zombie.dormant = false
					zombie.soundId = point.id
					zombie.soundStrength = point.strength
					zombie.soundCreatedAt = point.createdAt
					zombie.goalX = point.x
					zombie.goalZ = point.z
					zombie.goalLevel = goalLevel
					zombie.goalBuilding = goalBuilding
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
		queued = spawnQueue + hordeQueue,
		tickMs = tickMsAvg,
		tickMaxMs = tickMsMax,
		stepsPerSecond = stepsPerSecond,
	}
	tickMsMax = 0
	return stats
end

-- Marks the ground cells under a world rectangle again after map parts there stopped colliding (a
-- felled tree, a broken boulder): each cell gets its terrain cost back, then every map part still
-- standing there blocks it as at start. Building door fields built at start keep their old view.
function ZombieService.reopenArea(minX: number, minZ: number, maxX: number, maxZ: number)
	local terrain = terrainCost
	if terrain == nil then
		return
	end
	local size, half = grid.cellSize, grid.halfExtent
	local x0 = math.max(0, math.floor((minX + half) / size))
	local z0 = math.max(0, math.floor((minZ + half) / size))
	local x1 = math.min(grid.width - 1, math.ceil((maxX + half) / size) - 1)
	local z1 = math.min(grid.width - 1, math.ceil((maxZ + half) / size) - 1)
	for cz = z0, z1 do
		for cx = x0, x1 do
			local index = cz * grid.width + cx
			grid:setCost(index, buffer.readu8(terrain, index))
		end
	end
	local center = Vector3.new((x0 + x1 + 1) * size / 2 - half, 0, (z0 + z1 + 1) * size / 2 - half)
	local extent = Vector3.new((x1 - x0 + 1) * size, WorldLayout.HalfSize * 2, (z1 - z0 + 1) * size)
	overlapParams.FilterDescendantsInstances = { MapService.getMap() }
	for _, part in Workspace:GetPartBoundsInBox(CFrame.new(center), extent, overlapParams) do
		local p, halfX, halfY, halfZ = partBounds(part)
		blockAtHeight(grid, p, halfX, halfY, halfZ, MapService.heightAt(p.X, p.Z) + FC.StepHeight)
	end
	-- Player structures in the area keep their path cost.
	for cz = z0, z1 do
		for cx = x0, x1 do
			local index = cz * grid.width + cx
			local cost = structureCosts[index]
			if cost and grid:getCost(index) ~= NavGrid.BLOCKED then
				grid:setCost(index, cost)
			end
		end
	end
end

-- Marks the ground cell at (x, z) as holding a player structure that zombies must break through, with
-- path cost `cost` (BuildGrid.pathCost); nil clears it.
function ZombieService.setStructure(x: number, z: number, cost: number?)
	local cell = grid:cellAt(x, z)
	if cell == nil then
		return
	end
	if cost then
		structureCosts[cell] = cost
		if grid:getCost(cell) ~= NavGrid.BLOCKED then
			grid:setCost(cell, cost)
		end
	elseif structureCosts[cell] then
		structureCosts[cell] = nil
		local cx, cz = grid:cellCenter(cell)
		local half = grid.cellSize / 2 - FC.RasterEpsilon
		ZombieService.reopenArea(cx - half, cz - half, cx + half, cz + half)
	end
	hasStructures = next(structureCosts) ~= nil
end

-- Sets the listener for zombies hitting a player structure (one listener: BuildService).
function ZombieService.onStructureHit(callback: StructureHitCallback)
	structureHit = callback
end

function ZombieService.getNavGrid(): NavGrid.NavGrid
	return grid
end

return ZombieService
