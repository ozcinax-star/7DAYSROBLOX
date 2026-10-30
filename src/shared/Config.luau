--!strict
-- Single source of truth for every balance number. Gameplay code must not contain magic numbers;
-- add a field here instead. Values are starting estimates from docs/PLAN.md and get tuned by playtests.

local Config = {}

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
	MaxHealth = 100,
	-- Speed while chasing a sound or a player (studs/s).
	RunSpeed = 12,
	WanderSpeed = 3,
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
	AttackRange = 4,
	AttackDamage = 10,
	AttackCooldown = 1.2,
	-- Individual offset from the shared path so the horde does not walk in a single file.
	SpreadRadius = 2.5,
	-- Zombies closer than this push each other apart.
	SeparationRadius = 2.5,
	-- Fraction of the overlap resolved per server step (0-1).
	SeparationStrength = 0.4,
	-- Height of the zombie root above the ground (grey-box map is flat).
	GroundY = 3,
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
	-- Cell size of the shared navigation grid (studs). Matches the build grid.
	CellSize = 4,
	-- Half-extent of the navigable area around the origin (studs).
	HalfExtent = 256,
	-- How often the player-chase field is rebuilt (seconds).
	RebuildInterval = 1,
	-- Path cost of entering a cell that holds a player structure (zombies prefer going around,
	-- but will break through when the detour is long).
	StructureCellCost = 8,
	-- Max cached flow fields toward sound points (least recently used is evicted).
	MaxSoundFields = 4,
	-- Within this distance the zombie steers straight at its target instead of following the field.
	DirectSteerDistance = 6,
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
	-- Grey-box body part sizes (studs).
	TorsoSize = { 2, 2, 1 },
	HeadSize = { 1.2, 1.2, 1.2 },
	LimbSize = { 0.9, 2, 0.9 },
	Color = { 0.36, 0.48, 0.32 },
	-- Client LOD distances (studs).
	RenderDistance = 260,
	AnimateDistance = 70,
	-- Zombies this close always update even if they are off screen (peripheral vision, camera turns).
	AlwaysUpdateDistance = 15,
	-- Off-screen zombies are re-posed (without animation) once every N frames.
	OffscreenUpdateEveryFrames = 6,
	-- Interpolation duration bounds between two server samples (seconds).
	MinInterpolation = 0.08,
	MaxInterpolation = 0.6,
	-- Procedural walk cycle.
	StrideFrequency = 1.6,
	ArmSwingRadians = 0.35,
	LegSwingRadians = 0.6,
	ArmRaiseRadians = 1.4,
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

Config.Remotes = {
	-- Per-player rate limits (requests per second) for client -> server remotes.
	BuildRequestsPerSecond = 6,
	DebugRequestsPerSecond = 2,
}

Config.Debug = {
	-- Debug commands are allowed in Studio, or for these UserIds in live servers.
	AllowedUserIds = {} :: { number },
	StressCounts = { 80, 120 },
	-- Interval of the FPS / server tick overlay refresh (seconds).
	StatsInterval = 0.5,
	-- Strength and radius of the debug "make noise" command.
	NoiseStrength = 50,
	NoiseRadius = 200,
}

return Config
