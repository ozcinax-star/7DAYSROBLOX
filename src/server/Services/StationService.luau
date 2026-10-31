--!strict
-- StationService: fire stations, the campfire for now (7DTD workstations that burn fuel). A station is
-- a build block (BuildService); this service gives it fuel and fire. Three prompts sit on it: craft
-- (the client opens the crafting panel on the station's tab), add fuel (a few wood or charcoal from
-- the inventory, up to what it holds) and light / put out. Lighting needs fuel and either a lighter,
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
-- The prompts stack downwards this many pixels apart.
local PROMPT_SPACING = 76

type Station = {
	key: number,
	kind: string,
	part: BasePart,
	fuel: number,
	lit: boolean,
	flame: Fire,
	light: PointLight,
	-- Logs show while there is fuel.
	logs: { BasePart },
	fuelPrompt: ProximityPrompt,
	lightPrompt: ProximityPrompt,
	-- Whole fuel seconds last shown, so the labels are rewritten only when they change.
	shown: number,
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
	for _, log in station.logs do
		log.Transparency = if station.fuel > 0 then 0 else 1
	end
end

local function setLit(station: Station, lit: boolean)
	station.lit = lit
	station.flame.Enabled = lit
	station.light.Enabled = lit
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
	if not canReach(player, station) then
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

-- Two crossed logs on top of the ring; no collisions or queries, so hits go to the block itself.
local function addLogs(part: BasePart): { BasePart }
	local logs: { BasePart } = {}
	local top = part.CFrame * CFrame.new(0, part.Size.Y / 2, 0)
	for _, angle in { 45, -45 } do
		local log = Instance.new("Part")
		log.Name = "Log"
		log.Anchored = true
		log.CanCollide = false
		log.CanQuery = false
		log.CanTouch = false
		log.Size = LOG_SIZE
		log.Material = Enum.Material.Wood
		log.Color = LOG_COLOR
		log.CFrame = top * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, LOG_SIZE.Y / 2, 0)
		log.Parent = part
		table.insert(logs, log)
	end
	return logs
end

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
	if SC.Kinds[kind] == nil then
		return
	end
	local logs = addLogs(part)
	local flame = Instance.new("Fire")
	flame.Color = FIRE_COLOR
	flame.SecondaryColor = FIRE_SMOKE
	flame.Size = FIRE_SIZE
	flame.Heat = FIRE_HEAT
	flame.Enabled = false
	flame.Parent = part
	local light = Instance.new("PointLight")
	light.Color = FIRE_COLOR
	light.Range = FIRE_LIGHT_RANGE
	light.Brightness = FIRE_LIGHT_BRIGHTNESS
	light.Shadows = true
	light.Enabled = false
	light.Parent = part
	-- The client opens the crafting panel when "Craft" is triggered; the server checks the station
	-- again on every queue.
	local craft = addPrompt(part, "Craft", Enum.KeyCode.E, Enum.KeyCode.ButtonX, 0)
	craft.ActionText = Localization.get(`StationCraft{kind}`)
	craft.ObjectText = itemName(kind)
	local fuelPrompt = addPrompt(part, "AddFuel", Enum.KeyCode.R, Enum.KeyCode.DPadUp, 1)
	fuelPrompt.ActionText = Localization.get("StationAddFuel")
	local lightPrompt = addPrompt(part, "Light", Enum.KeyCode.F, Enum.KeyCode.DPadDown, 2)
	local station: Station = {
		key = key,
		kind = kind,
		part = part,
		fuel = 0,
		lit = false,
		flame = flame,
		light = light,
		logs = logs,
		fuelPrompt = fuelPrompt,
		lightPrompt = lightPrompt,
		shown = -1,
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

function StationService.init()
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
