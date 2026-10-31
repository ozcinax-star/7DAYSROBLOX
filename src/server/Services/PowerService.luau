--!strict
-- PowerService: generators and electric lamps (7DTD generator bank and light bulbs, without wires;
-- PLAN keeps the wire network for later). Both are build blocks (BuildService); this service gives
-- them their behaviour. A generator turns on and off with the interact key and runs while it has gas;
-- gas in the hand is poured in with "use". A running generator lights the lamps within its radius up
-- to its watts (Shared/Power), burns gas for the watts in use, makes noise whether loaded or not and
-- adds Trace, as do lit lamps (PLAN: a running generator is a decision, not a free upgrade). Nothing
-- is saved yet (persistence step).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Localization = require(Shared.Localization)
local Power = require(Shared.Power)

local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local BuildService = require(script.Parent.BuildService)
local InventoryService = require(script.Parent.InventoryService)
local ThreatService = require(script.Parent.ThreatService)
local ToolService = require(script.Parent.ToolService)

local PC = Config.Power
local BC = Config.Build
local TRACE_SOURCE = "Power"
local OFF_COLOR = Color3.fromRGB(120, 120, 115)
local RUNNING_COLOR = Color3.fromRGB(90, 230, 90)
local STOPPED_COLOR = Color3.fromRGB(200, 60, 50)

type Generator = {
	key: number,
	part: BasePart,
	on: boolean,
	fuel: number,
	prompt: ProximityPrompt,
	indicator: BasePart,
	-- The fuel and state last shown on the prompt, so it is rewritten only when they change.
	shown: number,
	shownOn: boolean,
	noiseAt: number,
	source: string,
}

type Lamp = {
	key: number,
	part: BasePart,
	head: BasePart,
	light: PointLight,
	lit: boolean,
}

local PowerService = {}

local generators: { [number]: Generator } = {}
local lamps: { [number]: Lamp } = {}
local nextFuelAt: { [Player]: number } = {}
local limiter: RateLimiter.RateLimiter
local lastCheck = 0

-- A part decorating a block: no collisions or queries, so rays and hits go to the block itself.
local function detail(parent: BasePart, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function label(generator: Generator)
	local fuel = math.floor(generator.fuel)
	generator.shown = fuel
	generator.shownOn = generator.on
	local status = { name = Localization.get("ItemGenerator"), fuel = fuel, max = PC.FuelCapacity }
	generator.prompt.ObjectText = Localization.get("GeneratorStatus", status)
	generator.prompt.ActionText = Localization.get(if generator.on then "GeneratorTurnOff" else "GeneratorTurnOn")
	generator.indicator.Color = if generator.on then RUNNING_COLOR else STOPPED_COLOR
	generator.indicator.Material = if generator.on then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

local function setLit(lamp: Lamp, lit: boolean)
	if lamp.lit == lit then
		return
	end
	lamp.lit = lit
	lamp.light.Enabled = lit
	lamp.head.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
	lamp.head.Color = if lit then Color3.new(PC.LightColor[1], PC.LightColor[2], PC.LightColor[3]) else OFF_COLOR
end

-- Lights the lamps the running generators reach, burns their gas over `dt` seconds, and sets the
-- Power trace. A generator that runs dry stops.
local function refresh(dt: number)
	local running: { Generator } = {}
	local sources: { Power.Source } = {}
	for _, generator in generators do
		if generator.on and generator.fuel > 0 then
			local p = generator.part.Position
			table.insert(running, generator)
			table.insert(sources, { x = p.X, y = p.Y, z = p.Z, watts = PC.GeneratorWatts })
		end
	end
	-- Lamps in key order, so the same lamps keep their light when watts run short.
	local order: { Lamp } = {}
	for _, lamp in lamps do
		table.insert(order, lamp)
	end
	table.sort(order, function(a, b)
		return a.key < b.key
	end)
	local points: { Power.Point } = {}
	for index, lamp in order do
		local p = lamp.part.Position
		points[index] = { x = p.X, y = p.Y, z = p.Z }
	end
	local lit = Power.assign(sources, points, PC.PowerRadius, PC.LampWatts, PC.MaxLitLamps)
	local load: { [number]: number } = {}
	local litCount = 0
	for index, lamp in order do
		local source = lit[index]
		setLit(lamp, source ~= nil)
		if source then
			load[source] = (load[source] or 0) + PC.LampWatts
			litCount += 1
		end
	end
	for index, generator in running do
		generator.fuel = math.max(0, generator.fuel - Power.burn(load[index] or 0, dt))
		if generator.fuel <= 0 then
			generator.on = false
		end
		if generator.on ~= generator.shownOn or math.floor(generator.fuel) ~= generator.shown then
			label(generator)
		end
	end
	local runningCount = 0
	for _, generator in generators do
		if generator.on then
			runningCount += 1
		end
	end
	local trace = litCount * Config.Threat.Trace.PerLight + runningCount * Config.Threat.Trace.PerGenerator
	ThreatService.setTraceSource(TRACE_SOURCE, trace)
end

-- The interact key on a generator: turns it on (when it has gas) or off.
local function onToggle(player: Player, generator: Generator)
	if not limiter:allow(player) or generators[generator.key] ~= generator then
		return
	end
	local character = player.Character
	local root = character and character.PrimaryPart
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	if (root.Position - generator.part.Position).Magnitude > PC.PromptReach + BC.GridSize then
		return
	end
	if not generator.on and generator.fuel <= 0 then
		return
	end
	generator.on = not generator.on
	generator.noiseAt = 0
	label(generator)
	refresh(0)
end

-- ToolService use handler for gas: pours one refuel step into the generator the player looks at.
local function onFuel(player: Player, origin: Vector3, direction: Vector3, itemId: string)
	local now = os.clock()
	if not Config.Items[itemId].Fuel or now < (nextFuelAt[player] or 0) then
		return
	end
	nextFuelAt[player] = now + BC.PlaceCooldown * (1 - Config.Melee.CooldownTolerance)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignored: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignored, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignored
	params.RespectCanCollide = true
	local result = Workspace:Raycast(origin, direction * PC.PromptReach, params)
	if result == nil then
		return
	end
	local key = BuildService.blockAt(result.Instance)
	local generator = if key then generators[key] else nil
	if generator == nil then
		return
	end
	local amount = Power.refuel(generator.fuel, InventoryService.count(player, itemId))
	if amount > 0 and InventoryService.take(player, { [itemId] = amount }) then
		generator.fuel += amount
		label(generator)
	end
end

local function addGenerator(key: number, part: BasePart)
	local size = part.Size
	local top = part.CFrame * CFrame.new(0, size.Y / 2, 0)
	detail(part, "Exhaust", Vector3.new(0.3, 0.9, 0.3), top * CFrame.new(size.X * 0.35, 0.45, 0), OFF_COLOR)
	local indicator =
		detail(part, "Indicator", Vector3.new(0.35, 0.2, 0.35), top * CFrame.new(-size.X * 0.3, 0.1, 0), STOPPED_COLOR)
	local prompt = Instance.new("ProximityPrompt")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PC.PromptReach
	prompt.RequiresLineOfSight = false
	local generator: Generator = {
		key = key,
		part = part,
		on = false,
		fuel = 0,
		prompt = prompt,
		indicator = indicator,
		shown = -1,
		shownOn = false,
		noiseAt = 0,
		source = `Generator{key}`,
	}
	prompt.Triggered:Connect(function(player)
		onToggle(player, generator)
	end)
	prompt.Parent = part
	generators[key] = generator
	label(generator)
end

local function addLamp(key: number, part: BasePart)
	local top = part.CFrame * CFrame.new(0, part.Size.Y / 2, 0)
	local head = detail(part, "Head", Vector3.new(1, 0.6, 1), top * CFrame.new(0, 0.3, 0), OFF_COLOR)
	local light = Instance.new("PointLight")
	light.Range = PC.LightRange
	light.Brightness = PC.LightBrightness
	light.Color = Color3.new(PC.LightColor[1], PC.LightColor[2], PC.LightColor[3])
	light.Shadows = false
	light.Enabled = false
	light.Parent = head
	lamps[key] = { key = key, part = part, head = head, light = light, lit = false }
end

local function onPlaced(key: number, kind: string, part: BasePart)
	local def = BC.Blocks[kind]
	if def.Generator then
		addGenerator(key, part)
	elseif def.Lamp then
		addLamp(key, part)
	else
		return
	end
	refresh(0)
end

local function onRemoved(key: number)
	local generator = generators[key]
	if generator then
		generators[key] = nil
		ThreatService.forgetSource(generator.source)
	elseif lamps[key] then
		lamps[key] = nil
	else
		return
	end
	refresh(0)
end

local function step()
	local now = os.clock()
	for _, generator in generators do
		if generator.on and now >= generator.noiseAt then
			generator.noiseAt = now + Config.Threat.GeneratorNoiseSeconds
			ThreatService.emit("Generator", generator.part.Position, generator.source)
		end
	end
	if now - lastCheck >= PC.CheckSeconds then
		refresh(now - lastCheck)
		lastCheck = now
	end
end

-- Debug and tests: the generator at `key`, if any (fuel, on).
function PowerService.getGenerator(key: number): (number?, boolean?)
	local generator = generators[key]
	if generator == nil then
		return nil, nil
	end
	return generator.fuel, generator.on
end

function PowerService.init()
	limiter = RateLimiter.new(PC.TogglesPerSecond)
end

function PowerService.start()
	for id, def in Config.Items do
		if def.Fuel then
			ToolService.onUse(id, onFuel)
		end
	end
	BuildService.onPlaced(onPlaced)
	BuildService.onRemoved(onRemoved)
	Players.PlayerRemoving:Connect(function(player)
		nextFuelAt[player] = nil
	end)
	lastCheck = os.clock()
	RunService.Heartbeat:Connect(step)
end

return PowerService
