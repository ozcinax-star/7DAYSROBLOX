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
	WalkSpeed = 7,
	-- Speed while chasing a sound or a player.
	RunSpeed = 12,
	WanderSpeed = 3,
	-- Max distance at which a zombie notices a player directly.
	SightRange = 60,
	-- A zombie hears a sound point if distance <= sound radius * HearingMultiplier.
	HearingMultiplier = 1,
	-- Seconds spent searching around a reached sound point before dispersing.
	SearchDuration = 8,
	SearchRadius = 12,
	-- Distance at which a target point counts as reached.
	ArriveDistance = 3,
	AttackRange = 4,
	AttackDamage = 10,
	AttackCooldown = 1.2,
	-- Individual offset from the shared path so the horde does not walk in a single file.
	SpreadRadius = 4,
	-- Ground height the zombies walk on (grey-box map is flat).
	GroundY = 3,
	-- Server LOD: zombies within NearDistance of any player tick at NearHz, the rest at FarHz.
	NearDistance = 80,
	NearHz = 10,
	FarHz = 2,
	-- How often the server sends a state snapshot to clients.
	ReplicationHz = 10,
	-- Spawn ring around the target players (studs).
	SpawnMinDistance = 60,
	SpawnMaxDistance = 120,
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
	HalfExtent = 512,
	-- How often the field is rebuilt toward the current player positions (seconds).
	RebuildInterval = 1,
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
	StatsInterval = 0.5,
}

return Config
