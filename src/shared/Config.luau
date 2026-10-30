--!strict
-- Single source of truth for every balance number. Gameplay code must not contain magic numbers;
-- add a field here instead. Values are starting estimates from docs/PLAN.md and get tuned by playtests.

local Config = {}

-- An item. Stack: most per slot. Color: placeholder icon colour (0-1 RGB) until icons exist.
-- Durability: tools only, uses when new; tools never stack.
export type ItemDef = {
	Stack: number,
	Color: { number },
	Durability: number?,
}

export type ItemCount = { Id: string, Count: number }

-- A melee tool, or the bare fist. Numbers follow 7DTD's item stats (quality 1, no perks).
-- Range is in metres like 7DTD's MaxRange; Config.Melee.StudsPerMeter converts it.
export type ToolDef = {
	EntityDamage: number,
	BlockDamage: number,
	AttacksPerMinute: number,
	Range: number,
	-- Not used until stamina exists.
	StaminaLoss: number,
}

Config.DayNight = {
	-- One full day + night cycle, in real seconds (PLAN: 10-12 min).
	CycleSeconds = 11 * 60,
	-- Fraction of the cycle that is daytime; the rest is night.
	DayFraction = 0.6,
	-- Lighting.ClockTime at the start of the day phase and at the start of the night phase.
	DayStartClockTime = 6,
	NightStartClockTime = 18.5,
	-- Horde night is chosen once when the lobby is created and never changes afterwards.
	HordeNightDefault = 7,
	HordeNightMin = 5,
	HordeNightMax = 10,
	-- How often the server broadcasts the clock to clients (seconds).
	BroadcastInterval = 1,
}

Config.Threat = {
	Noise = {
		Max = 100,
		-- Fraction of the current value lost per second (PLAN: ~5%/s).
		DecayPerSecond = 0.05,
	},
	Trace = {
		Max = 100,
		-- Points lost per in-game day (PLAN: only a few points per day).
		DecayPerDay = 3,
		-- Contribution per source; summed and clamped to Max.
		PerBuildPart = 0.04,
		PerLight = 1.5,
		PerFire = 3,
	},
	-- Threat = Trace + Noise * NoiseWeight.
	NoiseWeight = 0.35,
	-- Lower bound of each tier (index = tier). Tier names come from Localization.
	TierThresholds = { 0, 20, 40, 60, 80 },
	-- Tier cap for the first N in-game days (PLAN: never reaches "Besieged" in the first 3 days).
	EarlyGameDays = 3,
	EarlyGameMaxTier = 3,
	-- Noise event strengths (added to the Noise meter) and hearing radii of the sound point they create (studs).
	Events = {
		Gunshot = { Noise = 25, Radius = 180 },
		Sprint = { Noise = 2, Radius = 30 },
		DoorBreak = { Noise = 15, Radius = 120 },
		Generator = { Noise = 4, Radius = 90 },
	},
	-- Sound points expire after this many seconds.
	SoundPointLifetime = 20,
	-- Server recalculation rate of the threat level (seconds).
	UpdateInterval = 0.5,
}

Config.Zombie = {
	-- 7DTD: a common ("slim") zombie has 125 health, randomised by +-15% per zombie.
	MaxHealth = 125,
	HealthSpread = 0.15,
	-- Non-horde zombies are slow walkers (The Walking Dead style): a player walking at 16 studs/s
	-- outpaces them; the danger is numbers and being cornered. Speeds in studs/s.
	ChaseSpeed = 5,
	-- Walking toward a heard sound.
	SeekSpeed = 4,
	WanderSpeed = 2,
	-- Each zombie's speeds are scaled by a random factor in [1 - SpeedJitter, 1 + SpeedJitter].
	SpeedJitter = 0.15,
	-- Max distance at which a zombie notices a player directly; line of sight is checked by raycast.
	SightRange = 60,
	-- Chase is dropped when the player gets farther than SightRange * LoseSightMultiplier.
	LoseSightMultiplier = 1.5,
	SightCheckInterval = 0.5,
	-- A zombie hears a sound point if distance <= sound radius * HearingMultiplier.
	HearingMultiplier = 1,
	-- Seconds spent searching around a reached sound point before dispersing.
	SearchDuration = 8,
	SearchRadius = 12,
	-- Seconds between picking a new random wander point.
	WanderRetargetMin = 4,
	WanderRetargetMax = 9,
	WanderRadius = 20,
	-- Distance at which a target point counts as reached.
	ArriveDistance = 3,
	AttackRange = 3.6,
	-- A target more than this far above or below the zombie (another floor, a roof) cannot be hit.
	AttackHeightTolerance = 3,
	-- 7DTD: a common zombie hits for 8 every 1.5 s by day (1.1 s at night, once day/night exists).
	AttackDamage = 8,
	-- Arms-out reach before the first grab lands; the client plays the lunge at the same moment.
	AttackWindup = 0.6,
	AttackCooldown = 1.5,
	-- A hit zombie staggers and stops moving for this long.
	HitStunSeconds = 0.35,
	-- Wandering zombies near a building sometimes walk in through a door, linger inside, and walk
	-- out again later. Chances are rolled each time a wanderer picks a new goal; with these values
	-- about 30% of the zombies in town are indoors at any time (measured in Play: 22-24 of 80).
	-- A visit picks any floor cell of the building, so two-storey buildings send some upstairs.
	HouseVisitChance = 0.1,
	HouseExitChance = 0.7,
	HouseVisitRadius = 48,
	LingerMin = 8,
	LingerMax = 25,
	-- Chance that a spawned zombie appears inside a building, standing still (a "sleeper") until it
	-- sees or hears a player or one comes within DormantWakeDistance.
	IndoorSpawnChance = 0.1,
	-- Indoor spawns keep this distance from every player and are never placed in a player's sight.
	IndoorSpawnMinDistance = 30,
	DormantSightRange = 18,
	DormantWakeDistance = 8,
	-- Margin around a building's footprint covered by its door flow fields (studs).
	BuildingFieldMargin = 40,
	-- Zombies climb and descend stairs at this fraction of their walking speed.
	StairSpeedMultiplier = 0.6,
	-- Seconds between two zombies stepping onto the same flight, so a crowd climbs in a file.
	StairSpacing = 0.7,
	-- Someone whose feet are within this many studs below an upper floor counts as being on it
	-- (half-way up the stairs, or a jump on the floor below does not).
	LevelSlack = 4,
	-- Individual offset from the shared path so the horde does not walk in a single file.
	SpreadRadius = 2.5,
	-- Zombies closer than this push each other apart.
	SeparationRadius = 2.5,
	-- Fraction of the overlap resolved per server step (0-1).
	SeparationStrength = 0.4,
	-- Height of the zombie root (torso centre) above the ground surface detected by MapService.
	RootHeight = 3,
	-- Server LOD: zombies within NearDistance of any player tick at NearHz, the rest at FarHz.
	NearDistance = 80,
	NearHz = 10,
	FarHz = 2,
	-- Spawn ring around the target players (studs).
	SpawnMinDistance = 60,
	SpawnMaxDistance = 120,
	SpawnAttempts = 12,
}

Config.Horde = {
	ZombiesPerPlayer = 20,
	-- Hard cap of zombies alive at once; the rest queue and arrive in waves.
	MaxConcurrent = 120,
	WaveIntervalSeconds = 15,
}

Config.FlowField = {
	-- Cell size of the shared navigation grid (studs). Matches the build grid and terrain voxels.
	CellSize = 4,
	-- Each flow field only covers a square of this half-size around its target (players, sounds),
	-- so rebuilds stay cheap on the 2048-stud map. Zombies outside it steer straight at the target.
	FieldRadius = 160,
	-- How often each player's chase field is rebuilt (seconds); rebuilds are spread over frames.
	RebuildInterval = 1,
	-- Path cost of entering a cell that holds a player structure (zombies prefer going around,
	-- but will break through when the detour is long).
	StructureCellCost = 8,
	-- Max cached flow fields toward sound points (least recently used is evicted).
	MaxSoundFields = 4,
	-- Max ground height difference between neighbouring cells that zombies can walk (studs).
	MaxStepHeight = 2.5,
	-- Parts crossing this height above the ground block navigation (walls, trunks, furniture).
	StepHeight = 2,
	-- Shrinks part footprints before rasterizing, so a wall touching a cell edge does not block it.
	RasterEpsilon = 0.05,
}

Config.Network = {
	-- Snapshot rate toward clients; each snapshot carries only zombies updated since the last one.
	SnapshotHz = 10,
	-- Every N seconds all zombies are sent, so late joiners and dropped packets recover.
	FullSnapshotInterval = 2,
	-- Positions are quantized to 1/PositionScale studs in int16 (range +-32767 / PositionScale).
	PositionScale = 8,
	-- UnreliableRemoteEvent payloads must stay under ~900 bytes.
	MaxEntriesPerPacket = 90,
}

Config.ZombieVisual = {
	-- Client LOD distances (studs). Within DetailDistance the face and wounds are shown; within
	-- AnimateDistance the body is animated every frame, beyond it every FarAnimateEveryFrames frames.
	RenderDistance = 260,
	DetailDistance = 45,
	AnimateDistance = 70,
	FarAnimateEveryFrames = 3,
	-- Zombies this close always update even if they are off screen (peripheral vision, camera turns).
	AlwaysUpdateDistance = 15,
	-- Off-screen zombies are re-posed once every N frames.
	OffscreenUpdateEveryFrames = 6,
	-- Interpolation duration bounds between two server samples (seconds).
	MinInterpolation = 0.08,
	MaxInterpolation = 0.6,
	-- Body turn rate toward the walking direction (radians/s).
	TurnRate = 3.5,
	-- An attacking zombie turns toward the nearest character within this distance (studs).
	AttackFaceDistance = 6,

	-- Shamble gait. Strides per second at ReferenceSpeed, scaled with the actual speed so the feet
	-- do not skate.
	StrideFrequency = 0.8,
	ReferenceSpeed = 3,
	MinStrideFrequency = 0.45,
	MaxStrideFrequency = 1.4,
	-- Gait amplitude while grabbing in place (0 = still, 1 = full walk) and how fast the gait blends
	-- between walking and standing (per second).
	AttackGait = 0.35,
	GaitBlendRate = 4,
	LegSwingRadians = 0.42,
	KneeBendRadians = 0.75,
	-- Lean of the whole body toward the limping leg, and the dip when weight lands on it.
	LimpLeanRadians = 0.12,
	LimpDip = 0.28,
	BodySwayRadians = 0.09,
	BobHeight = 0.1,
	-- Forward lurch of the upper body on every step (radians).
	LurchRadians = 0.07,
	HeadLollRadians = 0.18,
	-- Arms hang and swing loosely while idle or wandering; reach forward while chasing or attacking.
	ArmHangSwingRadians = 0.22,
	ArmReachRadians = 1.3,
	ArmReachBobRadians = 0.14,
	-- Extra torso pitch and arm lift at the moment a grab lands.
	AttackLungeRadians = 0.35,
	AttackArmLiftRadians = 0.35,
	-- Short head/torso jerks: average seconds between twitches and their strength.
	TwitchInterval = 3,
	TwitchRadians = 0.35,

	-- Per-zombie body shape ranges (picked from the zombie id, identical on every client).
	HeightScaleMin = 0.92,
	HeightScaleMax = 1.08,
	HunchMin = 0.18,
	HunchMax = 0.45,
	LimpMin = 0.15,
	LimpMax = 0.85,
	HeadTiltMax = 0.35,
	-- Chance of one arm hanging dead instead of reaching.
	DeadArmChance = 0.25,

	-- Skin tones (r, g, b in 0-1) and spawn weights. Default weights follow a small US town: mostly
	-- light skin, olive/tan and black/dark-brown skin in proportion to the population.
	SkinTones = {
		{ Color = { 0.93, 0.8, 0.69 }, Weight = 0.38 },
		{ Color = { 0.86, 0.69, 0.55 }, Weight = 0.32 },
		{ Color = { 0.72, 0.53, 0.38 }, Weight = 0.16 },
		{ Color = { 0.45, 0.31, 0.22 }, Weight = 0.08 },
		{ Color = { 0.3, 0.2, 0.14 }, Weight = 0.06 },
	},
	-- Decay pulls the skin toward RotColor by a per-zombie amount; hands, forearms and the face rot
	-- a little more (ExtremityRot). Stylized per PLAN: grey-green decay, no red gore.
	RotColor = { 0.5, 0.55, 0.45 },
	RotMin = 0.25,
	RotMax = 0.5,
	ExtremityRot = 0.15,
	-- Faces are gaunt: the head is darkened slightly and shrunk on X.
	FaceShade = 0.88,
	-- Dried, dark decay; milky, clouded eyes that do not glow.
	WoundColor = { 0.2, 0.17, 0.12 },
	EyeSocketColor = { 0.12, 0.1, 0.09 },
	EyeColor = { 0.52, 0.54, 0.46 },
	-- Dirty, faded clothing.
	ShirtColors = {
		{ 0.55, 0.52, 0.47 },
		{ 0.36, 0.42, 0.5 },
		{ 0.45, 0.25, 0.22 },
		{ 0.3, 0.36, 0.3 },
		{ 0.62, 0.58, 0.46 },
		{ 0.22, 0.22, 0.24 },
		{ 0.5, 0.42, 0.3 },
	},
	PantsColors = {
		{ 0.24, 0.29, 0.38 },
		{ 0.42, 0.37, 0.28 },
		{ 0.2, 0.2, 0.21 },
		{ 0.33, 0.31, 0.27 },
	},
	-- Chance that sleeves / trouser legs are torn away and rotten skin shows.
	BareArmChance = 0.45,
	BareShinChance = 0.25,
	-- Death: collapse time, then the body lies still before it is removed.
	DeathFallSeconds = 0.8,
	CorpseSeconds = 6,
	-- Hit flinch of a struck zombie (seconds).
	FlinchSeconds = 0.3,
	-- Groan audio; empty string disables sound until an asset is chosen.
	GroanSoundId = "",
	GroanIntervalMin = 4,
	GroanIntervalMax = 12,
	SoundRange = 120,
}

Config.Build = {
	GridSize = 4,
	WallHeight = 8,
	-- Part cap per world: also a performance limit and the natural ceiling of Trace.
	MaxPartsPerWorld = 2000,
	MaxPlaceDistance = 24,
	PlaceCooldown = 0.25,
	Pieces = {
		WoodWall = { MaxHealth = 250 },
	},
}

Config.Camera = {
	-- Shoulder camera (default) offset and zoom limits; zoom-out is deliberately short.
	-- Plain numbers, not Vector3: this module must stay loadable by Lune tests outside Roblox.
	ShoulderOffsetX = 2,
	ShoulderOffsetY = 1.5,
	MinZoom = 4,
	MaxZoom = 14,
	DefaultMode = "Shoulder",
}

-- Items. Stack sizes and durabilities follow 7 Days to Die 1.0+ (item id in each comment); Lumber and
-- the stone pickaxe are ours (PLAN, Kararlar).
Config.Items = {
	Wood = { Stack = 6000, Color = { 0.55, 0.38, 0.22 } }, -- resourceWood
	SmallStone = { Stack = 6000, Color = { 0.56, 0.56, 0.54 } }, -- resourceRockSmall
	PlantFiber = { Stack = 6000, Color = { 0.55, 0.63, 0.3 } }, -- resourceYuccaFibers
	Lumber = { Stack = 6000, Color = { 0.8, 0.62, 0.4 } },
	StoneAxe = { Stack = 1, Durability = 250, Color = { 0.45, 0.42, 0.38 } }, -- meleeToolRepairT0StoneAxe
	StoneShovel = { Stack = 1, Durability = 250, Color = { 0.5, 0.46, 0.4 } }, -- meleeToolShovelT0StoneShovel
	StonePickaxe = { Stack = 1, Durability = 250, Color = { 0.42, 0.42, 0.44 } },
} :: { [string]: ItemDef }

-- Melee stats by item id. "Fist" is the empty hand; any held item without an entry here (wood,
-- stone...) also hits like the fist. 7DTD item names in the comments; the stone pickaxe is ours
-- (7DTD has none): between the stone axe and the iron pickaxe (11.2 / 42 / 65 APM / 2.4 m).
Config.Tools = {
	-- meleeHandPlayer
	Fist = { EntityDamage = 5, BlockDamage = 2.2, AttacksPerMinute = 80, Range = 2.0, StaminaLoss = 10.5 },
	-- meleeToolRepairT0StoneAxe
	StoneAxe = { EntityDamage = 6, BlockDamage = 22, AttacksPerMinute = 105, Range = 2.4, StaminaLoss = 8 },
	-- meleeToolShovelT0StoneShovel
	StoneShovel = { EntityDamage = 9, BlockDamage = 38, AttacksPerMinute = 50, Range = 2.6, StaminaLoss = 16.2 },
	StonePickaxe = { EntityDamage = 7, BlockDamage = 26, AttacksPerMinute = 70, Range = 2.4, StaminaLoss = 14 },
} :: { [string]: ToolDef }

Config.Melee = {
	-- Converts 7DTD metres to studs: a Roblox character (~5 studs) against a 1.8 m 7DTD player.
	StudsPerMeter = 2.8,
	-- 7DTD: player hits to the head deal double damage (HeadshotDamageModifier +100%).
	HeadshotMultiplier = 2,
	-- Zombie hit volume around its root (torso centre): an upright cylinder from the feet to the top
	-- of the hunched head. The radius is wider than the body because clients draw zombies slightly
	-- behind the server.
	HitBottom = -3,
	HitTop = 2.1,
	HitRadius = 1.3,
	-- Head sphere, measured on the client rig: the head centre sits 1.35 above the root and 0.4 ahead
	-- while walking, 1.0 above and 0.9 ahead in the attack lunge.
	HeadHeight = 1.15,
	HeadRadius = 0.55,
	HeadLean = 0.75,
	-- A zombie counts as blocked when a wall is closer than its axis minus this distance (about the
	-- torso's half depth, so a zombie pressed against the far side of a thin wall stays hidden).
	BodyRadius = 0.5,
	-- The aim direction must be a unit vector within this length tolerance.
	AimTolerance = 0.05,
	-- 7DTD: seconds between swings are 60 / AttacksPerMinute plus this delay.
	SwingDelay = 0.1,
	-- Swings may arrive this much earlier than the tool's interval (network jitter).
	CooldownTolerance = 0.12,
	-- Longest swing animation; faster tools swing in 90% of their interval.
	SwingMaxSeconds = 0.5,
	-- How far the client looks for what is under the crosshair or cursor (studs).
	AimDistance = 300,
	-- Seconds the "broken tool" message stays on screen.
	MessageSeconds = 1.6,
}

Config.Inventory = {
	-- 7DTD: a 10-slot toolbelt (keys 1-0) and a 5 x 9 backpack.
	ToolbeltSlots = 10,
	BackpackSlots = 45,
	-- New items fill the backpack before empty toolbelt slots, so the toolbelt keeps what the player
	-- put there.
	FillToolbeltFirst = false,
	-- PLAN: the player starts empty-handed (punches a tree, picks up stones).
	StartingItems = {} :: { ItemCount },
}

Config.Remotes = {
	-- Per-player rate limits (requests per second) for client -> server remotes.
	BuildRequestsPerSecond = 6,
	DebugRequestsPerSecond = 2,
	-- Moves while sorting the backpack and slot changes from number keys come in quick bursts.
	InventoryRequestsPerSecond = 20,
	-- The fastest tool swings under 2 times a second; the cooldown is checked separately.
	UseToolRequestsPerSecond = 4,
}

Config.Debug = {
	-- Debug commands are allowed in Studio, or for these UserIds in live servers.
	-- 11911303584: project owner (tester), needed to run the stress test on a phone.
	AllowedUserIds = { 11911303584 } :: { number },
	-- Spawn button counts: 1 for melee tests, 80 and 120 for stress tests.
	StressCounts = { 1, 80, 120 },
	-- Interval of the FPS / server tick overlay refresh (seconds).
	StatsInterval = 0.5,
	-- Strength and radius of the debug "make noise" command.
	NoiseStrength = 50,
	NoiseRadius = 200,
	-- The debug "kill" command kills the zombie nearest to the player within this distance (studs).
	KillRadius = 12,
	-- Items given by the debug "give kit" command.
	TestKit = {
		{ Id = "StoneAxe", Count = 1 },
		{ Id = "StoneShovel", Count = 1 },
		{ Id = "StonePickaxe", Count = 1 },
		{ Id = "Wood", Count = 50 },
		{ Id = "SmallStone", Count = 20 },
		{ Id = "PlantFiber", Count = 20 },
	} :: { ItemCount },
}

return Config
