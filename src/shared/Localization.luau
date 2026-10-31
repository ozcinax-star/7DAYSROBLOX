--!strict
-- Every UI string lives here. Code refers to keys only; English is the source language and other
-- languages are added as extra columns (later exported to a Roblox LocalizationTable).

export type Key = string

local Strings: { [string]: { [string]: string } } = {
	en = {
		-- Threat tiers (PLAN: Quiet, Noticed, Hunted, Besieged, Targeted)
		ThreatTier1 = "Quiet",
		ThreatTier2 = "Noticed",
		ThreatTier3 = "Hunted",
		ThreatTier4 = "Besieged",
		ThreatTier5 = "Targeted",

		-- Day / night
		PhaseDay = "Day {day}",
		PhaseNight = "Night {day}",
		HordeNight = "Horde night",
		HudClock = "Day {day}  {time}",

		-- Camera
		CameraShoulder = "Shoulder",
		CameraFirstPerson = "First person",
		CameraFree = "Free mouse",
		CameraMode = "Camera: {mode}",

		-- Death
		DeathTitle = "You died",
		DeathBag = "Half of your raw resources dropped in a bag where you died. It stays for {minutes} minutes.",
		DeathKept = "You carried no raw resources, so nothing dropped.",
		DeathRespawn = "Respawning in {seconds}",
		DeathMarker = "Your bag",
		DeathMarkerDistance = "{distance} m",

		-- Debug overlay
		DebugFps = "FPS: {value}",
		DebugServerTick = "Server tick avg/max: {value} ms",
		DebugZombieCount = "Zombies: {value}",
		DebugRendered = "Rendered: {value}",
		DebugSpawn = "Spawn {value}",
		DebugNoise = "Make noise",
		DebugGodMode = "God mode on/off",
		DebugKill = "Kill nearest zombie",
		DebugGiveKit = "Give test items",
		DebugClear = "Clear",
		DebugSkipPhase = "Skip to next phase",
		DebugGrowCrops = "Grow crops",
		DebugToggleDirector = "Auto spawn on/off",
		DebugThreat = "Threat: tier {tier}, {level} (noise {noise}, trace {trace})",
		DebugAmbient = "Auto spawn {state}: {count} / {target}, horde left {horde}",
		DebugOn = "on",
		DebugOff = "off",

		-- Inventory
		InventoryBackpack = "Backpack",
		InventoryClose = "Close",
		InventorySplit = "Split",
		InventoryDrop = "Drop",
		InventoryBag = "Bag",

		-- Tools
		ToolAim = "Aim",
		ToolUse = "Hit",
		ToolBroken = "{item} is broken",
		ToolTooFar = "Too far away",
		HitHealth = "{remaining} / {maximum}",

		-- Challenges (7DTD 3.2 titles; hints are ours, for our controls)
		ChallengeGroupBasics = "Basics of Survival",
		ChallengeGroupHomesteading = "Homesteading",
		ChallengeGroupAdvancedSurvival = "Advanced Survival",
		ChallengeHeader = "{group}  {index}/{total}",
		ChallengeComplete = "Challenge complete",
		ChallengeGatherResources = "Gather Resources",
		ChallengeGatherResourcesHint = "Punch grass for fibres and bushes or trees for wood; press E on small stones.",
		ChallengeCraftStoneAxe = "Craft Tools",
		ChallengeCraftStoneAxeHint = "Press Tab to open the backpack, then craft a Stone Axe in the crafting list.",
		ChallengeStoneAxeHarvest = "Stone Axe Harvesting",
		ChallengeStoneAxeHarvestHint = "In the backpack click the axe, then a toolbelt slot. Chop trees and boulders.",
		ChallengeCraftWoodenClub = "Craft Club",
		ChallengeCraftWoodenClubHint = "Craft a Wooden Club.",
		ChallengeCraftBow = "Craft Bow",
		ChallengeCraftBowHint = "Craft a Primitive Bow.",
		ChallengeCraftArrows = "Craft Arrows",
		ChallengeCraftArrowsHint = "Craft a Stone Arrow.",
		ChallengePlaceBedroll = "Place Bedroll",
		ChallengePlaceBedrollHint = "Craft a Bedroll, put it on the toolbelt and place it. You respawn on it.",
		ChallengeCraftFrames = "Craft Building Blocks",
		ChallengeCraftFramesHint = "Craft a Wood Frame.",
		ChallengePlaceFrames = "Place Building Blocks",
		ChallengePlaceFramesHint = "Hold the Wood Frame and click the ground.",
		ChallengeUpgradeFrames = "Upgrade Blocks",
		ChallengeUpgradeFramesHint = "Hit your frame with the Stone Axe while carrying Lumber.",
		ChallengePlaceDoor = "Place Door",
		ChallengePlaceDoorHint = "Craft a Wood Door and place it.",
		ChallengePlaceStorage = "Place Storage Container",
		ChallengePlaceStorageHint = "Craft a Storage Crate and place it.",
		ChallengePlaceSpikes = "Place Spike Trap",
		ChallengePlaceSpikesHint = "Craft Wood Spikes and place them where zombies walk.",
		ChallengeUpgradeCobblestone = "Upgrade To Cobblestone",
		ChallengeUpgradeCobblestoneHint = "Hit a wood block with the Stone Axe while carrying Cobblestone Rocks.",
		ChallengePlaceCampfire = "Place Campfire",
		ChallengePlaceCampfireHint = "Craft a Campfire from small stones and place it.",
		ChallengeBoilWater = "Boil Water",
		ChallengeBoilWaterHint = "At a campfire with a Cooking Pot, boil Murky Water.",
		ChallengeDrinkWater = "Drink From Water Source",
		ChallengeDrinkWaterHint = "With an empty hand, look at a lake and click.",
		ChallengeKillZombies = "Kill Zombies",
		ChallengeKillZombiesHint = "Kill zombies with any weapon.",
		ChallengePlaceFarmPlot = "Place Farm Plot",
		ChallengePlaceFarmPlotHint = "Craft a Farm Plot and place it on flat ground.",
		ChallengeObjectiveGather = "{item}",
		ChallengeObjectiveCraft = "Craft {item}",
		ChallengeObjectiveHarvest = "{item} with {held}",
		ChallengeObjectivePlace = "Place {item}",
		ChallengeObjectiveUpgrade = "Upgrade to {item}",
		ChallengeObjectiveKill = "Zombies",
		ChallengeObjectiveDrink = "Drink from a lake",
		ChallengeProgress = "{have}/{need}",

		-- Controls panel (keyboard)
		HelpTitle = "Controls",
		HelpBackpack = "Backpack and crafting",
		HelpHit = "Hit, use, place",
		HelpAim = "Aim a gun",
		HelpInteract = "Pick up, search, open (hold)",
		HelpDrop = "Drop the held item",
		HelpRun = "Run",
		HelpToolbelt = "Toolbelt slot",
		HelpHide = "Hide or show this",
		HelpCamera = "Change the camera",
		HelpCursor = "Free the cursor (hold)",
		KeyAlt = "Alt",
		KeyTab = "Tab",
		KeyLeftMouse = "LMB",
		KeyRightMouse = "RMB",
		KeyShift = "Shift",
		KeyDigits = "1-0",
		KeyEither = "{first} / {second}",

		-- Gathering
		HarvestPickUp = "Pick up",
		InventoryGain = "+{count} {item}",
		InventoryFull = "No room for {count} {item}",

		-- Loot
		LootBag = "Loot Bag",
		ContainerFridge = "Fridge",
		ContainerCupboard = "Cupboard",
		ContainerShelf = "Shelf",
		ContainerClothes = "Wardrobe",
		ContainerMedicine = "Medicine Cabinet",
		ContainerStorage = "Storage",
		ContainerEmpty = "{name} (empty)",
		LootSearch = "Search",
		DoorOpen = "Open",
		DoorClose = "Close",

		-- Crafting
		CraftingTitle = "Crafting",
		CraftingCraft = "Craft",
		CraftingQueue = "Queue (click to cancel)",
		CraftingWaiting = "No room",
		CraftingSeconds = "{seconds}s",
		CraftingCount = "x{count}",
		CraftingRepair = "Repair",
		CraftingRepairJob = "Repair {item}",
		CraftingStation = "at a {station}",
		CraftingTool = "with {tool}",
		CampfireCook = "Cook",

		-- Items (key = "Item" .. item id)
		ItemWood = "Wood",
		ItemSmallStone = "Small Stone",
		ItemPlantFiber = "Plant Fibers",
		ItemLumber = "Lumber",
		ItemCobblestoneRocks = "Cobblestone Rocks",
		ItemScrapIron = "Scrap Iron",
		ItemClay = "Clay Soil",
		ItemCrushedSand = "Crushed Sand",
		ItemDirt = "Dirt",
		ItemCloth = "Cloth",
		ItemWoodFrame = "Wood Frame",
		ItemWoodLadder = "Wood Ladder",
		ItemWoodDoor = "Wood Door",
		ItemCanChili = "Can of Chili",
		ItemCanDogFood = "Can of Dog Food",
		ItemBottledWater = "Bottled Water",
		ItemMurkyWater = "Murky Water",
		ItemFirstAidBandage = "First Aid Bandage",

		-- Survival HUD
		VitalHealth = "Health",
		VitalStamina = "Stamina",
		VitalFood = "Food",
		VitalWater = "Water",
		OutOfStamina = "Out of stamina",
		NoAmmo = "No arrows",
		NoBullets = "No ammo",
		Reloading = "Reloading...",
		ItemPipePistol = "Pipe Pistol",
		ItemPipeRifle = "Pipe Rifle",
		ItemPipeShotgun = "Pipe Shotgun",
		ItemPipeMachineGun = "Pipe Machine Gun",
		ItemAmmo762mm = "7.62mm Ammo",
		ItemAmmoShotgunShell = "Shotgun Shell",
		ItemWoodBars = "Wood Bars",
		ItemWoodSpikes = "Wood Spikes",
		ItemBedroll = "Bedroll",
		ItemAmmo9mm = "9mm Ammo",
		ItemMetalPipe = "Metal Pipe",
		ItemGlue = "Glue",
		ItemBone = "Bone",
		SprintButton = "Run",
		DrinkHint = "Use to drink",
		ItemStoneAxe = "Stone Axe",
		ItemStoneShovel = "Stone Shovel",
		ItemStonePickaxe = "Stone Pickaxe",
		ItemWoodenClub = "Wooden Club",
		ItemStoneSpear = "Stone Spear",
		ItemPrimitiveBow = "Primitive Bow",
		ItemStoneArrow = "Stone Arrow",
		ItemCorn = "Corn",
		ItemPotato = "Potato",
		ItemBlueberries = "Blueberries",
		ItemCornSeed = "Corn Seed",
		ItemPotatoSeed = "Potato Seed",
		ItemBlueberrySeed = "Blueberry Seed",
		ItemFarmPlot = "Farm Plot",
		ItemGasCan = "Gas Can",
		ItemMechanicalParts = "Mechanical Parts",
		ItemElectricalParts = "Electrical Parts",
		ItemGenerator = "Generator",
		ItemStorageCrate = "Storage Crate",
		StorageOpen = "Open",
		StorageTakeAll = "Take all",
		StorageHint = "Click an item to take it. Pick one in your backpack, then a slot here, to store it.",
		ItemElectricLamp = "Electric Lamp",
		ItemCampfire = "Campfire",
		ItemCookingPot = "Cooking Pot",
		ItemCookingGrill = "Cooking Grill",
		ItemBakedPotato = "Baked Potato",
		ItemCornOnTheCob = "Corn on the Cob",
		GraphicsButton = "Graphics: {preset}",
		GraphicsTitle = "Graphics",
		GraphicsAuto = "Auto ({preset})",
		GraphicsLow = "Low",
		GraphicsMedium = "Medium",
		GraphicsHigh = "High",
		GraphicsAutoHint = "Picked for this device.",
		GraphicsLowHint = "Shorter zombie draw distance, no shadows or glow, quick corpses.",
		GraphicsMediumHint = "Full zombie draw distance, shadows and glow.",
		GraphicsHighHint = "More zombie detail and animation, longer corpses, wider lamp light.",
		GeneratorTurnOn = "Turn on",
		GeneratorTurnOff = "Turn off",
		GeneratorStatus = "{name}  Gas {fuel}/{max}",
		CropHarvest = "Harvest",

		-- Shop signs
		SignMarket = "MARKET",
		SignDiner = "DINER",
		SignClinic = "CLINIC",
		SignHardware = "HARDWARE",
		SignGasStation = "GAS",
		SignTownHall = "TOWN HALL",
		SignWarehouse = "STORAGE",
	},
}

local Localization = {}

local currentLocale = "en"
local FALLBACK_LOCALE = "en"

function Localization.setLocale(locale: string)
	if Strings[locale] then
		currentLocale = locale
	end
end

-- Returns the localized string for `key`, replacing {name} placeholders from `args`.
function Localization.get(key: Key, args: { [string]: any }?): string
	local text = Strings[currentLocale][key] or Strings[FALLBACK_LOCALE][key]
	if text == nil then
		warn(`[Localization] missing key: {key}`)
		return key
	end
	if args then
		text = string.gsub(text, "{(%w+)}", function(name: string): string?
			local value = args[name]
			return if value ~= nil then tostring(value) else nil
		end)
	end
	return text
end

return Localization
