--!strict
-- StationService: fire stations, the campfire and the forge (7DTD workstations that burn fuel). A
-- station is a build block (BuildService); this service gives it fuel and fire. Three prompts sit on
-- it: craft (the client opens the crafting panel on the station's tab), add fuel (a few of its fuel
-- items from the inventory, up to what it holds) and light / put out. Lighting needs fuel and either a lighter,
-- which wears, or a little plant fibre as tinder. A lit station burns a second of fuel per second and
-- goes out when it runs dry; while lit it shows fire and light and adds Trace (PLAN: fire gives a
-- base away). Station recipes need a lit station of their kind nearby (CraftingService, `litNear`);
-- the job then runs in the player's queue. The block carries the Lit and Fuel attributes for the
-- client, and why a request failed goes back as a Notice. Nothing is saved yet (persistence step).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Fuel = require(Shared.Fuel)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local BuildService = require(script.Parent.BuildService)
local InventoryService = require(script.Parent.InventoryService)
local ThreatService = require(script.Parent.ThreatService)
local PersistenceService = require(script.Parent.PersistenceService)

local SC = Config.Stations
local BC = Config.Build
local TRACE_SOURCE = "Fire"

-- Campfire look.
local FIRE_COLOR = Color3.fromRGB(255, 140, 50)
local FIRE_SMOKE = Color3.fromRGB(70, 60, 55)
local FIRE_SIZE = 2.5
local FIRE_HEAT = 6
local FIRE_LIGHT_RANGE = 16
local FIRE_LIGHT_BRIGHTNESS = 1.4
local LOG_SIZE = Vector3.new(0.5, 0.5, 2.6)
local LOG_COLOR = Color3.fromRGB(80, 55, 35)
-- Forge look: a chimney on top and a mouth in the front face whose coals glow while it burns.
local CHIMNEY_SIZE = Vector3.new(0.9, 1.4, 0.9)
local CHIMNEY_COLOR = Color3.fromRGB(70, 60, 55)
local MOUTH_SIZE = Vector3.new(1.6, 1.1, 0.2)
local COAL_COLOR = Color3.fromRGB(45, 42, 40)
local ASH_COLOR = Color3.fromRGB(20, 18, 18)
local EMBER_COLOR = Color3.fromRGB(255, 110, 40)
local FORGE_FIRE_SIZE = 1.2
local FORGE_LIGHT_RANGE = 12
-- The prompts stack downwards this many pixels apart.
local PROMPT_SPACING = 76

-- How a station shows its state: parts seen only while it has fuel (campfire logs), a part whose
-- coals glow while it burns (the forge's mouth), and fire, smoke and light that burn while lit.
type Look = {
	fuelParts: { BasePart },
	glow: BasePart?,
	effects: { Fire | Smoke | PointLight },
}

type Station = {
	key: number,
	kind: string,
	part: BasePart,
	fuel: number,
	lit: boolean,
	look: Look,
	fuelPrompt: ProximityPrompt,
	lightPrompt: ProximityPrompt,
	-- Whole fuel seconds last shown, so the labels are rewritten only when they change.
	shown: number,
	-- When it was last lit or put out (os.clock).
	toggledAt: number,
}

local StationService = {}

local stations: { [number]: Station } = {}
local limiter: RateLimiter.RateLimiter
local noticeRemote: RemoteEvent
local lastCheck = 0

local function itemName(id: string): string
	return Localization.get(`Item{id}`)
end

-- The station's fuels by name: "Wood or Charcoal".
local function fuelNames(def: Config.StationDef): string
	local names: { string } = {}
	for _, id in def.Fuels do
		table.insert(names, itemName(id))
	end
	local last = table.remove(names) :: string
	if #names == 0 then
		return last
	end
	return Localization.get("ListOr", { first = table.concat(names, ", "), last = last })
end

local function notify(player: Player, key: string, params: { [string]: string | number })
	noticeRemote:FireClient(player, key, params)
end

local function label(station: Station)
	station.shown = math.ceil(station.fuel)
	local status = if station.lit then "StationBurning" else "StationFuel"
	station.fuelPrompt.ObjectText = Localization.get(status, { time = Fuel.clock(station.fuel) })
	station.lightPrompt.ActionText = Localization.get(if station.lit then "StationPutOut" else "StationLight")
	station.part:SetAttribute(Net.Attributes.StationFuel, station.shown)
	local look = station.look
	for _, part in look.fuelParts do
		part.Transparency = if station.fuel > 0 then 0 else 1
	end
	local glow = look.glow
	if glow then
		glow.Material = if station.lit then Enum.Material.Neon else Enum.Material.Slate
		glow.Color = if station.lit then EMBER_COLOR elseif station.fuel > 0 then COAL_COLOR else ASH_COLOR
	end
end

local function setLit(station: Station, lit: boolean)
	station.lit = lit
	station.toggledAt = os.clock()
	for _, effect in station.look.effects do
		effect.Enabled = lit
	end
	station.part:SetAttribute(Net.Attributes.StationLit, lit)
	label(station)
end

local function refreshTrace()
	local lit = 0
	for _, station in stations do
		if station.lit then
			lit += 1
		end
	end
	ThreatService.setTraceSource(TRACE_SOURCE, lit * Config.Threat.Trace.PerFire)
end

-- Whether `player` may act on `station` now: within the rate limit, alive and within prompt reach.
local function canReach(player: Player, station: Station): boolean
	if not limiter:allow(player) or stations[station.key] ~= station then
		return false
	end
	local character = player.Character
	local root = character and character.PrimaryPart
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root == nil or humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	return (root.Position - station.part.Position).Magnitude <= SC.PromptReach + BC.GridSize
end

local function onAddFuel(player: Player, station: Station)
	if not canReach(player, station) then
		return
	end
	local def = SC.Kinds[station.kind]
	if Fuel.full(station.fuel, def, SC.FuelSeconds) then
		notify(player, "NoticeFuelFull", { station = itemName(station.kind) })
		return
	end
	local takes, added = Fuel.feed(station.fuel, def, SC.FuelSeconds, SC.FuelPerAdd, function(id)
		return InventoryService.count(player, id)
	end)
	if added <= 0 then
		notify(player, "NoticeNoFuel", { fuels = fuelNames(def) })
		return
	end
	if InventoryService.take(player, takes) then
		station.fuel += added
		label(station)
	end
end

local function onLight(player: Player, station: Station)
	if not canReach(player, station) or os.clock() - station.toggledAt < SC.ToggleSeconds then
		return
	end
	if station.lit then
		setLit(station, false)
		refreshTrace()
		return
	end
	if station.fuel <= 0 then
		notify(player, "NoticeNeedsFuel", { fuels = fuelNames(SC.Kinds[station.kind]) })
		return
	end
	local tinder = SC.Tinder
	if
		InventoryService.wearItem(player, SC.Lighter, SC.LighterWear) == nil
		and not InventoryService.take(player, { [tinder.Id] = tinder.Count })
	then
		notify(player, "NoticeNoTinder", { count = tinder.Count, tinder = itemName(tinder.Id) })
		return
	end
	setLit(station, true)
	refreshTrace()
end

-- A part decorating a station: no collisions or queries, so rays and hits go to the block itself.
local function detail(parent: BasePart, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Slate
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function addLight(parent: Instance, range: number, shadows: boolean): PointLight
	local light = Instance.new("PointLight")
	light.Color = FIRE_COLOR
	light.Range = range
	light.Brightness = FIRE_LIGHT_BRIGHTNESS
	light.Shadows = shadows
	light.Parent = parent
	return light
end

local function addFire(parent: Instance, size: number): Fire
	local flame = Instance.new("Fire")
	flame.Color = FIRE_COLOR
	flame.SecondaryColor = FIRE_SMOKE
	flame.Size = size
	flame.Heat = FIRE_HEAT
	flame.Parent = parent
	return flame
end

-- A campfire: two crossed logs on top of the stone ring, an open fire and its light.
local function campfireLook(part: BasePart): Look
	local logs: { BasePart } = {}
	local top = part.CFrame * CFrame.new(0, part.Size.Y / 2, 0)
	for _, angle in { 45, -45 } do
		local cframe = top * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, LOG_SIZE.Y / 2, 0)
		local log = detail(part, "Log", LOG_SIZE, cframe, LOG_COLOR)
		log.Material = Enum.Material.Wood
		table.insert(logs, log)
	end
	local effects = { addFire(part, FIRE_SIZE), addLight(part, FIRE_LIGHT_RANGE, true) }
	return { fuelParts = logs, glow = nil, effects = effects }
end

-- A forge: a chimney that smokes and a mouth in the front face where the coals glow and burn.
local function forgeLook(part: BasePart): Look
	local size = part.Size
	local top = part.CFrame * CFrame.new(0, size.Y / 2, 0)
	local chimney = detail(
		part,
		"Chimney",
		CHIMNEY_SIZE,
		top * CFrame.new(0, CHIMNEY_SIZE.Y / 2, size.Z / 4),
		CHIMNEY_COLOR
	)
	local front = part.CFrame * CFrame.new(0, -size.Y / 2 + MOUTH_SIZE.Y, -size.Z / 2 - MOUTH_SIZE.Z / 2 + 0.05)
	local mouth = detail(part, "Mouth", MOUTH_SIZE, front, ASH_COLOR)
	local smoke = Instance.new("Smoke")
	smoke.Color = FIRE_SMOKE
	smoke.Opacity = 0.15
	smoke.RiseVelocity = 4
	smoke.Size = 1
	smoke.Parent = chimney
	return {
		fuelParts = {},
		glow = mouth,
		effects = { addFire(mouth, FORGE_FIRE_SIZE), smoke, addLight(mouth, FORGE_LIGHT_RANGE, false) },
	}
end

local LOOKS: { [string]: (part: BasePart) -> Look } = {
	Campfire = campfireLook,
	Forge = forgeLook,
}

local function addPrompt(
	part: BasePart,
	name: string,
	key: Enum.KeyCode,
	pad: Enum.KeyCode,
	row: number
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.KeyboardKeyCode = key
	prompt.GamepadKeyCode = pad
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = SC.PromptReach
	prompt.RequiresLineOfSight = false
	prompt.UIOffset = Vector2.new(0, row * PROMPT_SPACING)
	prompt.Parent = part
	return prompt
end

local function onPlaced(key: number, kind: string, part: BasePart)
	local makeLook = LOOKS[kind]
	if SC.Kinds[kind] == nil or makeLook == nil then
		return
	end
	-- The client opens the crafting panel when "Craft" is triggered; the server checks the station
	-- again on every queue.
	local craft = addPrompt(part, "Craft", Enum.KeyCode.E, Enum.KeyCode.ButtonX, 0)
	craft.ActionText = Localization.get(`StationCraft{kind}`)
	craft.ObjectText = itemName(kind)
	local fuelPrompt = addPrompt(part, "AddFuel", Enum.KeyCode.T, Enum.KeyCode.DPadUp, 1)
	fuelPrompt.ActionText = Localization.get("StationAddFuel")
	local lightPrompt = addPrompt(part, "Light", Enum.KeyCode.F, Enum.KeyCode.DPadDown, 2)
	local station: Station = {
		key = key,
		kind = kind,
		part = part,
		fuel = 0,
		lit = false,
		look = makeLook(part),
		fuelPrompt = fuelPrompt,
		lightPrompt = lightPrompt,
		shown = -1,
		toggledAt = 0,
	}
	fuelPrompt.Triggered:Connect(function(player)
		onAddFuel(player, station)
	end)
	lightPrompt.Triggered:Connect(function(player)
		onLight(player, station)
	end)
	stations[key] = station
	setLit(station, false)
end

local function onRemoved(key: number)
	if stations[key] then
		stations[key] = nil
		refreshTrace()
	end
end

local function step()
	local now = os.clock()
	local dt = now - lastCheck
	if dt < SC.CheckSeconds then
		return
	end
	lastCheck = now
	local wentOut = false
	for _, station in stations do
		if station.lit then
			station.fuel = math.max(0, station.fuel - dt)
			if station.fuel <= 0 then
				setLit(station, false)
				wentOut = true
			elseif math.ceil(station.fuel) ~= station.shown then
				label(station)
			end
		end
	end
	if wentOut then
		refreshTrace()
	end
end

-- Whether a lit station of `kind` stands within `radius` studs of `position`.
function StationService.litNear(kind: string, position: Vector3, radius: number): boolean
	for _, station in stations do
		if station.lit and station.kind == kind and (station.part.Position - position).Magnitude <= radius then
			return true
		end
	end
	return false
end

-- Debug and tests: the station at `key`, if any (fuel seconds, lit).
function StationService.get(key: number): (number?, boolean?)
	local station = stations[key]
	if station == nil then
		return nil, nil
	end
	return station.fuel, station.lit
end

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Saved world part "Stations": fuel (seconds) and whether each fire burns, by block key.
local function saveStations(): any
	local rows = {}
	for key, station in stations do
		table.insert(rows, { key, station.fuel, if station.lit then 1 else 0 })
	end
	return rows
end

local function loadStations(data: any)
	if type(data) ~= "table" then
		return
	end
	for _, row in data do
		local station = stations[row[1]]
		local def = station and SC.Kinds[station.kind]
		if station and def and finite(row[2]) then
			station.fuel = math.clamp(row[2], 0, def.MaxFuel)
			setLit(station, row[3] == 1 and station.fuel > 0)
		end
	end
	refreshTrace()
end

function StationService.init()
	PersistenceService.registerWorld("Stations", { save = saveStations, load = loadStations })
	limiter = RateLimiter.new(SC.ActionsPerSecond)
	noticeRemote = Net.event("Notice")
end

function StationService.start()
	BuildService.onPlaced(onPlaced)
	BuildService.onRemoved(onRemoved)
	lastCheck = os.clock()
	RunService.Heartbeat:Connect(step)
end

return StationService
