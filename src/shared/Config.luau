--!strict
-- Single source of truth for every balance number. Gameplay code must not contain magic numbers;
-- add a field here instead. Values are starting estimates from docs/PLAN.md and get tuned by playtests.

local Config = {}

-- How a tool is repaired: each unit of item Id restores Amount durability and takes Seconds in the
-- crafting queue (7DTD RepairTools / RepairAmount / RepairTime).
export type RepairDef = { Id: string, Amount: number, Seconds: number }

-- What using an item from the hand does (food, drink, medicine; 7DTD consumables): Food and Water
-- points, Heal health given over time at HealRate per second, Damage health taken at once.
export type UseDef = { Food: number?, Water: number?, Heal: number?, HealRate: number?, Damage: number? }

-- An item. Stack: most per slot. Color: placeholder icon colour (0-1 RGB) until icons exist.
-- Durability: tools only, uses when new; tools never stack. Repair: tools that can be repaired.
-- Raw: a raw resource (half of what is carried drops on death, PLAN). Use: a consumable.
export type ItemDef = {
	Stack: number,
	Color: { number },
	Durability: number?,
	Repair: RepairDef?,
	Raw: boolean?,
	Use: UseDef?,
}

-- A hunger or thirst stage: reached at or below Enter (share of the max), left above Leave, and
-- blocking Block of max stamina.
export type SurvivalStage = { Enter: number, Leave: number, Block: number }

export type ItemCount = { Id: string, Count: number }

-- A noise event: points added to the Noise meter and the hearing radius of its sound point (studs).
export type NoiseEvent = { Noise: number, Radius: number }

-- A building block tier (7DTD material). Health: full cube hit points. Placeable: placed from the item
-- of the same id. UpgradeTo / Upgrade: the next tier and what one upgrade costs. Repair: the item used
-- for repairs and how many of it repair the block from nothing to full. Climbable: a ladder (players
-- climb it; zombies walk through it). Material and Color are the look.
export type BlockDef = {
	Health: number,
	Placeable: boolean?,
	UpgradeTo: string?,
	Upgrade: ItemCount?,
	Repair: ItemCount,
	Climbable: boolean?,
	Material: string,
	Color: { number },
	Transparency: number?,
}

-- A crafting recipe: Count of item Output from the ingredients. Seconds per craft when given,
-- otherwise the ingredients' Config.Crafting.IngredientSeconds add up (7DTD).
export type Recipe = {
	Output: string,
	Count: number,
	Ingredients: { ItemCount },
	Seconds: number?,
}

-- What a world object is made of, for tool damage (7DTD damage categories: earth covers dirt, grass and
-- leaves; stone covers rock and boulders).
export type HarvestMaterial = "Wood" | "Earth" | "Stone"

-- A melee tool, or the bare fist. Numbers follow 7DTD's item stats (quality 1, no perks).
-- Range is in metres like 7DTD's MaxRange; Config.Melee.StudsPerMeter converts it.
-- Materials: block damage multiplier by material (7DTD DamageModifier per damage category).
export type ToolDef = {
	EntityDamage: number,
	BlockDamage: number,
	AttacksPerMinute: number,
	Range: number,
	-- Stamina one swing costs; a swing needs at least this much (7DTD).
	StaminaLoss: number,
	Materials: { [HarvestMaterial]: number },
}

-- Items a world object gives: Min-Max rolled again on every payout.
export type Drop = { Id: string, Min: number, Max: number }

-- One entry of a loot group: Weight against the group's other entries, Min-Max items when picked.
export type LootPick = { Id: string, Min: number, Max: number, Weight: number }

-- A searchable piece of furniture: Rolls picks, each of which comes up empty with EmptyChance; one more
-- roll in a building whose Loot attribute is Bonus.
export type ContainerDef = { Rolls: number, EmptyChance: number, Bonus: string?, Picks: { LootPick } }

-- A harvestable world object (7DTD block). Harvest drops pay two thirds while it is hit, in proportion
-- to damage, and one third on the killing hit; Destroy drops pay once when it breaks.
export type HarvestNode = {
	Material: HarvestMaterial,
	Health: number,
	Harvest: { Drop },
	Destroy: { Drop },
}

Config.DayNight = {
	-- One full day + night cycle, in real seconds (PLAN: 10-12 min).
	CycleSeconds = 11 * 60,
	-- Fraction of the cycle that is daytime; the rest is night.
	DayFraction = 0.6,
	-- Lighting.ClockTime at the start of the day phase and at the start of the night phase.
	DayStartClockTime = 6,
	NightStartClockTime = 18.5,
	-- A new world starts on day 1 at this hour.
	StartClockTime = 8,
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
	-- Harvest: a hit on a tree or a rock (7DTD: chopping and mining raise the heat map). TreeFall: the crash
	-- of a felled tree.
	Events = {
		Gunshot = { Noise = 25, Radius = 180 },
		Sprint = { Noise = 2, Radius = 30 },
		DoorBreak = { Noise = 15, Radius = 120 },
		Generator = { Noise = 4, Radius = 90 },
		Harvest = { Noise = 1.5, Radius = 35 },
		TreeFall = { Noise = 6, Radius = 70 },
	} :: { [string]: NoiseEvent },
	-- A player's events within this distance and time of their last sound point refresh that point
	-- instead of making a new one, so steady chopping costs one zombie path, not one per hit.
	SoundMergeDistance = 8,
	SoundMergeSeconds = 4,
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
	-- Horde-night zombies run. 7DTD's default blood moon speed is a sprint, 4.5x the day walk, which
	-- would outrun a walking player here; we use its "jog" setting, 2.2x (lerp(0.3, 1.35, 0.35) / 0.3).
	HordeChaseSpeed = 11,
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
	-- 7DTD: a common zombie hits for 8 every 1.5 s by day and every 1.1 s at night.
	AttackDamage = 8,
	-- 7DTD meleeHandZombieShort DamageBlock: damage to a player block per hit, at the same rate.
	AttackBlockDamage = 7,
	-- Arms-out reach before the first grab lands; the client plays the lunge at the same moment.
	AttackWindup = 0.6,
	AttackCooldown = 1.5,
	AttackCooldownNight = 1.1,
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
	-- PLAN: a horde night brings 20 zombies per player in all; the threat tier does not change it.
	ZombiesPerPlayer = 20,
	-- The horde comes in this many waves, spread over the first WaveSpreadFraction of the night, so the
	-- pressure lasts the whole night (7DTD keeps spawning until 04:00).
	WavesPerNight = 4,
	WaveSpreadFraction = 0.6,
	-- Hard cap of zombies alive at once; the rest queue and arrive in waves.
	MaxConcurrent = 120,
	-- Seconds before queued zombies try again once the cap was reached.
	WaveIntervalSeconds = 15,
}

-- Ambient zombie population (7DTD biome spawning): ThreatService keeps this many zombies around the
-- living players, more at night and at higher threat tiers (PLAN: each tier raises the spawn rate).
-- Horde nights pause it. Idle zombies farther than DespawnDistance from every player are removed and
-- new ones spawn near the players, so the population follows them.
Config.Population = {
	-- Seconds between director passes.
	Interval = 2,
	-- PLAN budget is 60-80 zombies per server: 10 per player at night fills 60 with six players.
	DayPerPlayer = 6,
	NightPerPlayer = 10,
	Max = 80,
	-- Multiplier on the per-player count for threat tiers 1-5.
	TierMultipliers = { 1, 1.15, 1.3, 1.45, 1.6 },
	-- Most zombies queued or removed in one pass, so the count changes gradually.
	MaxSpawnPerPass = 3,
	MaxDespawnPerPass = 4,
	-- Clients stop drawing zombies at ZombieVisual.RenderDistance (260), so a despawn is never seen.
	DespawnDistance = 270,
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

-- Building blocks (7DTD: place a frame, upgrade it with the stone axe; docs/REFERENCE_7DTD.md).
Config.Build = {
	-- Workspace folder of the placed blocks (zombie sight and loot bags treat them as walls and floors).
	FolderName = "Structures",
	-- Cube edge in studs; the grid shares its columns with the navigation grid (FlowField.CellSize).
	GridSize = 4,
	-- Block cap per world: also a performance limit and the natural ceiling of Trace.
	MaxPartsPerWorld = 2000,
	-- Reach for placing, from the head (PLAN; 7DTD has no single value).
	MaxPlaceDistance = 24,
	PlaceCooldown = 0.25,
	-- A ray hit point is moved this far off the surface before picking its cell.
	SurfaceOffset = 0.05,
	-- A new block may not overlap a wall, a tree or a character; touching faces are fine.
	OverlapInset = 0.15,
	-- A block is grounded when terrain or the map is inside its cell or at most this far under it.
	GroundProbe = 0.3,
	-- Blocks between a step above the ground and this height block zombies, who break through them.
	BodyHeight = 6,
	-- Block health per extra path cost, so zombies path through the weakest wall (PLAN).
	HealthPerPathCost = 70,
	-- No building inside a town building's footprint (their upper floors have their own zombie paths).
	BuildingMargin = 0,
	-- The tool that upgrades and repairs instead of damaging (7DTD stone axe: secondary action), how
	-- many of its hits one upgrade takes (UpgradeHitCount 4 - 1) and how much one hit repairs.
	UpgradeTool = "StoneAxe",
	UpgradeHits = 3,
	RepairPerHit = 100,
	-- Blocks are wood: tools damage them as wood (Config.Tools Materials).
	HarvestMaterial = "Wood" :: HarvestMaterial,
	Blocks = {
		-- frameShapes: 100 HP, upgrades with 8 Wood (4 Lumber here), repair 3 Wood.
		WoodFrame = {
			Health = 100,
			Placeable = true,
			UpgradeTo = "WoodBlock",
			Upgrade = { Id = "Lumber", Count = 4 },
			Repair = { Id = "Wood", Count = 3 },
			Material = "Wood",
			Color = { 0.72, 0.56, 0.36 },
			Transparency = 0.25,
		},
		-- woodShapes: 500 HP, repair 3 Wood; its next tier (cobblestone) comes with the stone tier.
		WoodBlock = {
			Health = 500,
			Repair = { Id = "Wood", Count = 3 },
			Material = "WoodPlanks",
			Color = { 0.6, 0.44, 0.28 },
		},
		-- ladderWood: 150 HP, 3 Wood, repair 3 Wood.
		WoodLadder = {
			Health = 150,
			Placeable = true,
			Repair = { Id = "Wood", Count = 3 },
			Climbable = true,
			Material = "Wood",
			Color = { 0.55, 0.4, 0.25 },
		},
	} :: { [string]: BlockDef },
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

-- 7DTD: stone tools are repaired with small stones, 300 durability and 0.5 s per stone.
local STONE_REPAIR: RepairDef = { Id = "SmallStone", Amount = 300, Seconds = 0.5 }

-- Recipe ingredients from an { [id] = count } table, in a stable order (by id) for display.
local function costs(counts: { [string]: number }): { ItemCount }
	local list: { ItemCount } = {}
	for id, count in counts do
		table.insert(list, { Id = id, Count = count })
	end
	table.sort(list, function(a, b)
		return a.Id < b.Id
	end)
	return list
end

-- Items. Stack sizes and durabilities follow 7 Days to Die 1.0+ (item id in each comment); Lumber and
-- the stone pickaxe are ours (PLAN, Kararlar).
Config.Items = {
	Wood = { Stack = 6000, Color = { 0.55, 0.38, 0.22 }, Raw = true }, -- resourceWood
	SmallStone = { Stack = 6000, Color = { 0.56, 0.56, 0.54 }, Raw = true }, -- resourceRockSmall
	PlantFiber = { Stack = 6000, Color = { 0.55, 0.63, 0.3 }, Raw = true }, -- resourceYuccaFibers
	Lumber = { Stack = 6000, Color = { 0.8, 0.62, 0.4 } },
	ScrapIron = { Stack = 6000, Color = { 0.52, 0.36, 0.3 }, Raw = true }, -- resourceScrapIron
	Clay = { Stack = 6000, Color = { 0.62, 0.45, 0.33 }, Raw = true }, -- resourceClayLump
	CrushedSand = { Stack = 6000, Color = { 0.86, 0.78, 0.58 }, Raw = true }, -- resourceCrushedSand
	Cloth = { Stack = 250, Color = { 0.78, 0.72, 0.6 }, Raw = true }, -- resourceCloth
	-- 7DTD 1.x-3.2 consumables. Food heals over time at 0.5 a second (buffHealHealth); canned food gives
	-- no water since 1.0.
	-- foodCanChili
	CanChili = { Stack = 10, Color = { 0.7, 0.25, 0.15 }, Use = { Food = 15, Heal = 7, HealRate = 0.5 } },
	-- foodCanDogFood
	CanDogFood = { Stack = 10, Color = { 0.55, 0.45, 0.3 }, Use = { Food = 10, Heal = 5, HealRate = 0.5 } },
	-- drinkJarBoiledWater
	BottledWater = { Stack = 10, Color = { 0.55, 0.75, 0.95 }, Use = { Water = 20 } },
	-- drinkJarRiverWater: 5 health at once; its 12 % dysentery chance is not in yet.
	MurkyWater = { Stack = 10, Color = { 0.45, 0.5, 0.4 }, Use = { Water = 10, Damage = 5 } },
	-- medicalFirstAidBandage: 30 health over about 15 s (it also stops bleeding, which is not in yet).
	FirstAidBandage = { Stack = 5, Color = { 0.9, 0.88, 0.82 }, Use = { Heal = 30, HealRate = 2 } },
	WoodFrame = { Stack = 500, Color = { 0.72, 0.56, 0.36 } }, -- frameShapes
	WoodLadder = { Stack = 500, Color = { 0.55, 0.4, 0.25 } }, -- ladderWood
	-- meleeToolRepairT0StoneAxe
	StoneAxe = { Stack = 1, Durability = 250, Repair = STONE_REPAIR, Color = { 0.45, 0.42, 0.38 } },
	-- meleeToolShovelT0StoneShovel
	StoneShovel = { Stack = 1, Durability = 250, Repair = STONE_REPAIR, Color = { 0.5, 0.46, 0.4 } },
	StonePickaxe = { Stack = 1, Durability = 250, Repair = STONE_REPAIR, Color = { 0.42, 0.42, 0.44 } },
} :: { [string]: ItemDef }

-- Backpack crafting (7DTD 1.0-3.2 recipes.xml). Recipes are keyed by id; Order lists them for the UI.
-- The stone pickaxe and lumber recipes are ours (PLAN, Kararlar): 7DTD has neither item.
Config.Recipes = {
	StoneAxe = { Output = "StoneAxe", Count = 1, Ingredients = costs({ SmallStone = 2, PlantFiber = 2, Wood = 2 }) },
	StoneShovel = {
		Output = "StoneShovel",
		Count = 1,
		Ingredients = costs({ SmallStone = 5, PlantFiber = 3, Wood = 3 }),
	},
	StonePickaxe = {
		Output = "StonePickaxe",
		Count = 1,
		Ingredients = costs({ SmallStone = 4, PlantFiber = 3, Wood = 3 }),
	},
	-- Two wood per lumber keeps 7DTD's wood costs when building parts ask for lumber.
	Lumber = { Output = "Lumber", Count = 1, Ingredients = costs({ Wood = 2 }) },
	-- 7DTD: a frame is 2 Wood and a ladder 3 Wood; here building parts take Lumber (PLAN), same wood.
	WoodFrame = { Output = "WoodFrame", Count = 1, Ingredients = costs({ Lumber = 1 }), Seconds = 0.4 },
	WoodLadder = {
		Output = "WoodLadder",
		Count = 1,
		Ingredients = costs({ Lumber = 1, Wood = 1 }),
		Seconds = 0.6,
	},
} :: { [string]: Recipe }

Config.Crafting = {
	Order = { "StoneAxe", "StoneShovel", "StonePickaxe", "Lumber", "WoodFrame", "WoodLadder" },
	-- 7DTD: a 4-slot queue; only the first slot works at a time.
	QueueSlots = 4,
	-- Most crafts one queue slot may hold (7DTD's cap is unconfirmed).
	MaxCount = 500,
	-- 7DTD CraftingIngredientTime: seconds each ingredient adds to a craft, 1 when not listed.
	IngredientSeconds = { Wood = 0.2, SmallStone = 0.2, PlantFiber = 0.2 } :: { [string]: number },
	DefaultIngredientSeconds = 1,
}

-- Melee stats by item id. "Fist" is the empty hand; any held item without an entry here (wood,
-- stone...) also hits like the fist. 7DTD item names in the comments; the stone pickaxe is ours
-- (7DTD has none): between the stone axe and the iron pickaxe (11.2 / 42 / 65 APM / 2.4 m), with the
-- iron pickaxe's material multipliers.
Config.Tools = {
	-- meleeHandPlayer
	Fist = {
		EntityDamage = 5,
		BlockDamage = 2.2,
		AttacksPerMinute = 80,
		Range = 2.0,
		StaminaLoss = 10.5,
		Materials = { Wood = 1, Earth = 0.5, Stone = 0.5 },
	},
	-- meleeToolRepairT0StoneAxe
	StoneAxe = {
		EntityDamage = 6,
		BlockDamage = 22,
		AttacksPerMinute = 105,
		Range = 2.4,
		StaminaLoss = 8,
		Materials = { Wood = 1, Earth = 0.15, Stone = 0.67 },
	},
	-- meleeToolShovelT0StoneShovel
	StoneShovel = {
		EntityDamage = 9,
		BlockDamage = 38,
		AttacksPerMinute = 50,
		Range = 2.6,
		StaminaLoss = 16.2,
		Materials = { Wood = 0.3, Earth = 1, Stone = 0.2 },
	},
	StonePickaxe = {
		EntityDamage = 7,
		BlockDamage = 26,
		AttacksPerMinute = 70,
		Range = 2.4,
		StaminaLoss = 14,
		Materials = { Wood = 0.2, Earth = 0.2, Stone = 1 },
	},
} :: { [string]: ToolDef }

local function drop(id: string, min: number, max: number?): Drop
	return { Id = id, Min = min, Max = max or min }
end

-- Gathering. Health and drops follow 7DTD 1.0-3.2 blocks.xml (block names in the comments); see
-- docs/REFERENCE_7DTD.md, Part B sections 0-3.
Config.Harvest = {
	Nodes = {
		-- Tree sizes by 7DTD tree-wood material: MtreeWoodSmall, Medium, Large, Full.
		TreeSmall = { Material = "Wood", Health = 300, Harvest = { drop("Wood", 30) }, Destroy = {} },
		TreeMedium = { Material = "Wood", Health = 600, Harvest = { drop("Wood", 70) }, Destroy = {} },
		TreeLarge = { Material = "Wood", Health = 900, Harvest = { drop("Wood", 110) }, Destroy = {} },
		TreeFull = { Material = "Wood", Health = 1200, Harvest = { drop("Wood", 150) }, Destroy = {} },
		-- treeDeadPineLeaf, treeAzalea, plantShrub
		Bush = { Material = "Earth", Health = 1, Harvest = { drop("Wood", 1, 3) }, Destroy = {} },
		-- treeTallGrassDiagonal
		Grass = { Material = "Earth", Health = 1, Harvest = { drop("PlantFiber", 2) }, Destroy = {} },
		-- rock01-07: also picked up with the interact key.
		LooseRock = { Material = "Stone", Health = 1, Harvest = {}, Destroy = { drop("SmallStone", 1) } },
		-- resourceRock01-03
		Boulder = { Material = "Stone", Health = 400, Harvest = { drop("SmallStone", 22) }, Destroy = {} },
	} :: { [string]: HarvestNode },
	-- Forest trees are scaled 0.8-1.3; a tree takes the first size whose MaxScale it does not exceed.
	-- Our trees are 4-6.5 m tall against 7DTD's 4-48 m, so size follows the scale, not the height.
	TreeSizes = {
		{ MaxScale = 0.925, Node = "TreeSmall" },
		{ MaxScale = 1.05, Node = "TreeMedium" },
		{ MaxScale = 1.175, Node = "TreeLarge" },
		{ MaxScale = math.huge, Node = "TreeFull" },
	},
	-- A felled tree falls away from the player for this long, then fades out (7DTD: at least 3 s, then
	-- a 1 s fade).
	FallSeconds = 2.5,
	FadeSeconds = 1,
	-- Loose rocks are picked up with the interact key from this far (studs), at most this often.
	PickupDistance = 8,
	PickupsPerSecond = 4,
}

-- Digging the ground (7DTD 1.0-3.2 terrain blocks; docs/REFERENCE_7DTD.md, Part B 4). A dig takes one
-- 4-stud voxel off the top of a terrain column; 7DTD's block is 1 m, ours is 1.4 m.
Config.Dig = {
	-- Diggable terrain by Enum.Material name: health, damage category and yield of one voxel. Asphalt,
	-- pavement and water are not here, so they cannot be dug (7DTD asphalt: 1500 HP, ours: never).
	Materials = {
		-- terrForestGround
		Grass = {
			Material = "Earth",
			Health = 250,
			Harvest = { drop("Clay", 22), drop("PlantFiber", 2) },
			Destroy = {},
		},
		LeafyGrass = {
			Material = "Earth",
			Health = 250,
			Harvest = { drop("Clay", 22), drop("PlantFiber", 2) },
			Destroy = {},
		},
		-- terrDirt
		Ground = { Material = "Earth", Health = 200, Harvest = { drop("Clay", 22) }, Destroy = {} },
		Mud = { Material = "Earth", Health = 200, Harvest = { drop("Clay", 22) }, Destroy = {} },
		-- terrSand
		Sand = {
			Material = "Earth",
			Health = 100,
			Harvest = { drop("CrushedSand", 11), drop("Clay", 2) },
			Destroy = {},
		},
		-- terrGravel
		Pebble = {
			Material = "Earth",
			Health = 200,
			Harvest = { drop("CrushedSand", 8), drop("SmallStone", 9) },
			Destroy = {},
		},
		-- terrSnow (its snowballs are not in)
		Snow = { Material = "Earth", Health = 160, Harvest = {}, Destroy = {} },
		-- terrStone
		Rock = { Material = "Stone", Health = 500, Harvest = { drop("SmallStone", 55) }, Destroy = {} },
		Slate = { Material = "Stone", Health = 500, Harvest = { drop("SmallStone", 55) }, Destroy = {} },
	} :: { [string]: HarvestNode },
	-- Whole voxels that always stay above the terrain bottom (7DTD: 3 layers of bedrock). With the
	-- bottom at -24 a column at height 0 can be dug four deep.
	BedrockLayers = 1,
	-- A hit digs its column only this close (studs) under the column's surface; lower hits are on the
	-- wall of a hole and do nothing (no tunnels, PLAN).
	TopReach = 6,
	-- A column is dug at most this many studs below any of its four side neighbours, so going deeper
	-- takes a wider hole. Roblox terrain rounds a steeper step off: a one-column hole dug 12 deep shows
	-- 8 deep, a 3 x 3 hole with a 16-deep centre shows it (measured).
	MaxStep = 8,
	-- A ray hit point is moved this far into the ground before picking its column.
	SurfaceOffset = 0.05,
	-- Studs around a town building's footprint that cannot be dug (its walls stand on that ground).
	BuildingMargin = 4,
	-- Collidable map parts (trees, rocks, props) closer than this to a column's sides keep it from
	-- being dug.
	OverlapInset = 0.15,
	-- How far above a column's surface (studs) map parts and placed blocks are looked for.
	ClearanceHeight = 4,
	-- Around a dug column the ground height is read with a ray from this far above and below the grid's
	-- estimate (studs): Roblox meshes holes rounder than the grid's straight lines.
	RoughRayReach = 8,
}

-- Loot bags (7DTD 1.x-3.2 entityclasses.xml and loot.xml; docs/REFERENCE_7DTD.md, Part A 4).
Config.Loot = {
	-- A dying zombie drops a bag this often. 7DTD: 2-4 %; ours is more generous because sessions are
	-- short (PLAN, Kararlar).
	ZombieBagChance = 0.2,
	-- What a zombie bag holds. 7DTD's regular bag always rolls one pick from a common group (scrap,
	-- cobblestones, food, drinks, medical, duct tape...) and has a 50 % group that includes tiered
	-- tools. We only have raw resources and stone tools yet: one common pick, and a stone tool at a
	-- worn share of its durability.
	-- 7DTD zPackReg picks food, drinks and medical about 15 % of the time each. Its drinks are juices and
	-- teas we do not have, so water stands in; the medical share is halved (only the healing bandage
	-- exists here).
	ZombieCommon = {
		{ Id = "ScrapIron", Min = 3, Max = 10, Weight = 3 },
		{ Id = "Cloth", Min = 2, Max = 6, Weight = 3 },
		{ Id = "SmallStone", Min = 5, Max = 15, Weight = 2 },
		{ Id = "CanChili", Min = 1, Max = 1, Weight = 1.2 },
		{ Id = "CanDogFood", Min = 1, Max = 1, Weight = 1 },
		{ Id = "BottledWater", Min = 1, Max = 1, Weight = 1.2 },
		{ Id = "MurkyWater", Min = 1, Max = 1, Weight = 1 },
		{ Id = "FirstAidBandage", Min = 1, Max = 1, Weight = 1 },
	} :: { LootPick },
	ZombieToolChance = 0.15,
	ZombieTools = { "StoneAxe", "StoneShovel", "StonePickaxe" },
	ToolDurabilityMin = 0.3,
	ToolDurabilityMax = 1,
	-- Bags vanish after this many seconds (7DTD 1.x TimeStayAfterDeath; 2.6+ uses 3600).
	BagSeconds = 1200,
	-- 7DTD bags are 6 x 3 slots.
	BagSlots = 18,
	-- Searching holds the interact key this long (7DTD open time 1 s), from this far (studs), at most
	-- this often per player.
	SearchSeconds = 1,
	SearchDistance = 8,
	SearchesPerSecond = 4,
	-- Most bags in the world at once; a new bag past the cap removes the oldest (hordes of 120).
	MaxBags = 60,
	-- Items with no room in the inventory drop in a bag at the player's feet; a bag within this many
	-- studs is topped up instead of dropping another.
	MergeDistance = 6,
	-- Searchable furniture in town buildings (7DTD loot containers), by the BuildingKit "Furniture"
	-- attribute. Ours: 7DTD cupboards and fridges are mostly spoiled food and trash and its zombies
	-- rarely drop food; here searching a few houses feeds a player for a day (PLAN, Kararlar).
	ContainerFurniture = {
		Fridge = "Fridge",
		KitchenCounter = "Cupboard",
		Counter = "Cupboard",
		StoreShelf = "Shelf",
		Wardrobe = "Clothes",
		Dresser = "Clothes",
		MedicineCabinet = "Medicine",
		Crates = "Storage",
		StorageRack = "Storage",
		Workbench = "Storage",
		Lockers = "Storage",
	} :: { [string]: string },
	Containers = {
		Fridge = {
			Rolls = 1,
			EmptyChance = 0.3,
			Bonus = "Food",
			Picks = {
				{ Id = "CanChili", Min = 1, Max = 1, Weight = 3 },
				{ Id = "CanDogFood", Min = 1, Max = 1, Weight = 2 },
				{ Id = "BottledWater", Min = 1, Max = 2, Weight = 3 },
				{ Id = "MurkyWater", Min = 1, Max = 1, Weight = 2 },
			},
		},
		Cupboard = {
			Rolls = 1,
			EmptyChance = 0.35,
			Bonus = "Food",
			Picks = {
				{ Id = "CanChili", Min = 1, Max = 1, Weight = 2 },
				{ Id = "CanDogFood", Min = 1, Max = 1, Weight = 3 },
				{ Id = "BottledWater", Min = 1, Max = 1, Weight = 1 },
				{ Id = "MurkyWater", Min = 1, Max = 1, Weight = 1 },
				{ Id = "Cloth", Min = 1, Max = 2, Weight = 1 },
			},
		},
		Shelf = {
			Rolls = 1,
			EmptyChance = 0.3,
			Bonus = "Food",
			Picks = {
				{ Id = "CanChili", Min = 1, Max = 2, Weight = 3 },
				{ Id = "CanDogFood", Min = 1, Max = 1, Weight = 2 },
				{ Id = "BottledWater", Min = 1, Max = 2, Weight = 3 },
				{ Id = "Cloth", Min = 1, Max = 3, Weight = 1 },
			},
		},
		Clothes = {
			Rolls = 1,
			EmptyChance = 0.35,
			Bonus = "Fabric",
			Picks = {
				{ Id = "Cloth", Min = 2, Max = 6, Weight = 1 },
			},
		},
		Medicine = {
			Rolls = 1,
			EmptyChance = 0.25,
			Bonus = "Medical",
			Picks = {
				{ Id = "FirstAidBandage", Min = 1, Max = 1, Weight = 3 },
				{ Id = "Cloth", Min = 1, Max = 3, Weight = 2 },
				{ Id = "BottledWater", Min = 1, Max = 1, Weight = 1 },
			},
		},
		Storage = {
			Rolls = 1,
			EmptyChance = 0.3,
			Bonus = "Metal",
			Picks = {
				{ Id = "ScrapIron", Min = 2, Max = 8, Weight = 4 },
				{ Id = "Cloth", Min = 1, Max = 4, Weight = 2 },
				{ Id = "SmallStone", Min = 3, Max = 10, Weight = 2 },
				{ Id = "StoneAxe", Min = 1, Max = 1, Weight = 0.5 },
				{ Id = "StoneShovel", Min = 1, Max = 1, Weight = 0.5 },
				{ Id = "StonePickaxe", Min = 1, Max = 1, Weight = 0.5 },
			},
		},
	} :: { [string]: ContainerDef },
	-- A container fills again this many in-game days after it was last filled (7DTD LootRespawnDays).
	ContainerRespawnDays = 7,
	-- A container's prompt floats this far (studs) in front of its furniture, at half its height but
	-- no higher than ContainerPromptMaxHeight above the floor.
	ContainerPromptGap = 0.4,
	ContainerPromptMaxHeight = 3,
}

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

-- Player survival stats (7DTD playerMale, buffStatusHungry01-03 and buffStatusThirsty01-03 in 1.0-3.2;
-- docs/REFERENCE_7DTD.md part B section 6). Health is the Humanoid's (max 100); the rest is server state.
Config.Survival = {
	MaxStamina = 100,
	MaxFood = 100,
	MaxWater = 100,
	-- The server updates every player this often (7DTD ticks stats every 0.5 s).
	TickSeconds = 0.5,
	-- StaminaChangeOT: 10 a second, scaled by the water band. Sprinting nets -4.5 a second
	-- (perc_add -1.45) while moving; each jump costs 20.
	StaminaRegen = 10,
	SprintDrain = 4.5,
	JumpCost = 20,
	-- 7DTD drains 30 food and 40 water and heals about 60 health per real hour, one day at its default
	-- day length; here the same amounts go per in-game day (Config.DayNight.CycleSeconds).
	FoodPerDay = 30,
	WaterPerDay = 40,
	HealthPerDay = 60,
	-- What regenerating costs: food and water per stamina point, water per health point.
	FoodPerStamina = 0.00408,
	WaterPerStamina = 0.00453,
	WaterPerHealth = 0.06,
	-- Eaten food goes in at this many points a second (buffHealFood).
	FoodPerSecond = 1,
	-- Hunger and thirst stages, buffStatusHungry01-03 / Thirsty01-03. Hunger and thirst block stamina
	-- separately and the two add up.
	Stages = {
		{ Enter = 0.5, Leave = 0.52, Block = 0.2 },
		{ Enter = 0.25, Leave = 0.27, Block = 0.4 },
		{ Enter = 0.02, Leave = 0.04, Block = 0.6 },
	} :: { SurvivalStage },
	-- The last stage (starving, dehydrated): this much health every StarveInterval seconds for each of
	-- the two (real time), no natural healing, and starving cuts stamina regen by StarveRegenCut.
	StarveDamage = 0.25,
	StarveInterval = 2.2,
	StarveRegenCut = 0.1,
	-- Water bands on stamina and health regen (EntityStats.GetWaterPercent): the first band whose Min
	-- share the water reaches; empty water stops all regen.
	WaterBands = {
		{ Min = 0.5, Factor = 1 },
		{ Min = 0.25, Factor = 0.5 },
		{ Min = 0, Factor = 0.25 },
	} :: { { Min: number, Factor: number } },
	-- Blocked stamina never takes the bar below this. Ours: the 7DTD floor is unknown, and both stats
	-- at their last stage would block all of it.
	MinStaminaCap = 10,
	-- Speeds in studs a second. 7DTD gives no m/s; walking keeps the Roblox default (the horde's jog
	-- is slower, PLAN) and sprinting is half again as fast.
	WalkSpeed = 16,
	SprintSpeed = 24,
	-- A sprint starts only with this much stamina and ends at 0.
	SprintMinStamina = 5,
	-- The character counts as sprinting while its ground speed is this much above WalkSpeed.
	SprintSpeedMargin = 1,
	-- A sprinting player makes a Sprint noise (Config.Threat.Events) this often.
	SprintNoiseSeconds = 2,
	-- A jump is counted when the character rises faster than this share of its jump speed.
	JumpDetectShare = 0.6,
	-- Eating, drinking and using medicine take this long (one use at a time).
	UseSeconds = 1,
	-- Drinking from a lake or river with the bare hand (meleeHandPlayer "Drink"): like murky water.
	-- Reach is from the head, in studs.
	LakeDrink = { Water = 10, Damage = 5 } :: UseDef,
	DrinkReach = 9,
	-- Death (PLAN): this share of each carried raw resource drops in a bag that lasts DeathBagSeconds;
	-- equipment stays. Stats come back full on respawn (the default 7DTD death penalty).
	DeathDropShare = 0.5,
	DeathBagSeconds = 300,
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
	-- Pickup feed: seconds a "+N item" line stays up, and the most lines shown at once.
	FeedSeconds = 3,
	FeedLines = 5,
}

Config.Remotes = {
	-- Per-player rate limits (requests per second) for client -> server remotes.
	BuildRequestsPerSecond = 6,
	DebugRequestsPerSecond = 2,
	-- Moves while sorting the backpack and slot changes from number keys come in quick bursts.
	InventoryRequestsPerSecond = 20,
	-- The fastest tool swings under 2 times a second; the cooldown is checked separately.
	UseToolRequestsPerSecond = 4,
	-- Queueing, cancelling and repairing.
	CraftRequestsPerSecond = 6,
	-- Sprint on / off.
	SprintRequestsPerSecond = 8,
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
		{ Id = "Lumber", Count = 20 },
		{ Id = "WoodFrame", Count = 30 },
		{ Id = "WoodLadder", Count = 5 },
		{ Id = "CanChili", Count = 3 },
		{ Id = "BottledWater", Count = 3 },
		{ Id = "MurkyWater", Count = 3 },
		{ Id = "FirstAidBandage", Count = 2 },
	} :: { ItemCount },
}

return Config
