--!strict
-- PowerService: generators, wires and powered blocks (7DTD generator bank, wire tool, relays, lamps,
-- auto and shotgun turrets, electric fence posts). All are build blocks (BuildService); this service
-- gives them their behaviour.
--
-- Wires: the wire tool used on a generator or relay starts a wire, used on another powered block it
-- runs the wire there (Shared/Power.canLink: power flows away from sources, one input per block, no
-- loops, at most Config.Power.WireReach long) and, into a relay or fence post, carries on from it;
-- used on the selected block again (or on a lamp or turret with nothing selected) it cuts that
-- block's input. Every second
-- the network is solved (Shared/Power.flow): running generators power what is wired to them, in key
-- order, until their watts run out, and burn gas for the watts in use.
--
-- A generator turns on and off with the interact key and runs while it has gas; gas in the hand is
-- poured in with "use". A powered, switched-on turret with ammo shoots the nearest zombie in its arc
-- and line of sight (one server loop for all turrets); ammo in the hand is loaded with "use". Two
-- powered fence posts wired together shock zombies touching the wire between them (7DTD buffShocked:
-- stunned, hurt every second) and wear down. Generators, lit lamps and gunfire make Noise and Trace
-- (PLAN: power is a decision). Nothing is saved yet (persistence step).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)
local Power = require(Shared.Power)

local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local BuildService = require(script.Parent.BuildService)
local InventoryService = require(script.Parent.InventoryService)
local ThreatService = require(script.Parent.ThreatService)
local ToolService = require(script.Parent.ToolService)
local ZombieService = require(script.Parent.ZombieService)

local PC = Config.Power
local BC = Config.Build
local MC = Config.Melee
local TRACE_SOURCE = "Power"
local OFF_COLOR = Color3.fromRGB(120, 120, 115)
local RUNNING_COLOR = Color3.fromRGB(90, 230, 90)
local STOPPED_COLOR = Color3.fromRGB(200, 60, 50)
local WIRE_COLOR = Color3.fromRGB(30, 30, 28)
local FENCE_WIRE_COLOR = Color3.fromRGB(150, 150, 140)
-- Original generated turret head (Studio Mesh Generation, 2026-11-01): native size, barrel toward -Z.
local TURRET_HEAD_MESH = "rbxassetid://111259831897498"
local TURRET_HEAD_TEXTURE = "rbxassetid://138043213399007"
local TURRET_HEAD_NATIVE = Vector3.new(0.9233, 1, 1.4089)
local TURRET_HEAD_SIZE = Vector3.new(1.2, 1.3, 1.83)
-- A wire selection is forgotten after this many seconds.
local SELECTION_SECONDS = 30

type Generator = {
	key: number,
	part: BasePart,
	on: boolean,
	fuel: number,
	load: number,
	prompt: ProximityPrompt,
	indicator: BasePart,
	shown: string,
	noiseAt: number,
	source: string,
}

type Lamp = { key: number, part: BasePart, head: BasePart, light: PointLight, lit: boolean }

type Turret = {
	key: number,
	part: BasePart,
	kind: string,
	head: BasePart,
	-- Pivot of the head: turret centre top. Facing: horizontal unit vector the turret was set toward.
	pivot: CFrame,
	facing: Vector3,
	ammo: number,
	enabled: boolean,
	powered: boolean,
	nextShot: number,
	prompt: ProximityPrompt,
	shown: string,
	source: string,
}

type Post = { key: number, part: BasePart, powered: boolean }
type Relay = { key: number, part: BasePart, powered: boolean }
type Selection = { key: number, at: number }

local PowerService = {}

local generators: { [number]: Generator } = {}
local lamps: { [number]: Lamp } = {}
local turrets: { [number]: Turret } = {}
local posts: { [number]: Post } = {}
local relays: { [number]: Relay } = {}
-- Wires: child key -> parent key, and the beam that draws each wire (parented to the child).
local parents: { [number]: number } = {}
local beams: { [number]: Beam } = {}
local selections: { [Player]: Selection } = {}
-- Shocked zombies: when the shock ends and when it next hurts.
local shocks: { [number]: { untilAt: number, nextHurt: number } } = {}
local nextFuelAt: { [Player]: number } = {}
local nextLoadAt: { [Player]: number } = {}
local limiter: RateLimiter.RateLimiter
local wireLimiter: RateLimiter.RateLimiter
local noticeRemote: RemoteEvent
local firedRemote: UnreliableRemoteEvent
local lastCheck = 0
local lastFence = 0
local lastTurret = 0

local function notify(player: Player, key: string, params: { [string]: string | number }?)
	noticeRemote:FireClient(player, key, params or {})
end

local function itemName(kind: string): string
	return Localization.get(`Item{kind}`)
end

-- A part decorating a block: no collisions or queries, so rays and hits go to the block itself.
local function detail(parent: BasePart, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function prompt(part: BasePart): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.HoldDuration = 0
	p.MaxActivationDistance = PC.PromptReach
	p.RequiresLineOfSight = false
	p.Parent = part
	return p
end

local function kindOf(key: number): string?
	if generators[key] then
		return "Generator"
	end
	local turret = turrets[key]
	if turret then
		return turret.kind
	end
	if lamps[key] then
		return "ElectricLamp"
	elseif posts[key] then
		return "FencePost"
	elseif relays[key] then
		return "PowerRelay"
	end
	return nil
end

local function partOf(key: number): BasePart?
	local block = generators[key] or lamps[key] or turrets[key] or posts[key] or relays[key]
	return if block then block.part else nil
end

-- The network as Shared/Power sees it.
local function nodes(): { [number]: Power.Node }
	local list: { [number]: Power.Node } = {}
	for key, generator in generators do
		list[key] = { key = key, kind = "Source", watts = PC.GeneratorWatts, running = generator.on and generator.fuel > 0 }
	end
	for key in relays do
		list[key] = { key = key, kind = "Relay", watts = PC.RelayWatts }
	end
	-- Fence posts pass power from post to post; the wire between two powered posts is the fence.
	for key in posts do
		list[key] = { key = key, kind = "Relay", watts = PC.FenceWatts }
	end
	for key in lamps do
		list[key] = { key = key, kind = "Consumer", watts = PC.LampWatts }
	end
	for key, turret in turrets do
		list[key] = { key = key, kind = "Consumer", watts = if turret.enabled then PC.TurretWatts else 0 }
	end
	return list
end

local function labelGenerator(generator: Generator)
	local fuel = math.floor(generator.fuel)
	local text = Localization.get("GeneratorLoad", {
		name = itemName("Generator"),
		fuel = fuel,
		max = PC.FuelCapacity,
		load = generator.load,
		watts = PC.GeneratorWatts,
	})
	-- The prompt's action and the indicator follow on/off even when the numbers stay the same.
	local shown = text .. tostring(generator.on)
	if shown == generator.shown then
		return
	end
	generator.shown = shown
	generator.prompt.ObjectText = text
	generator.prompt.ActionText = Localization.get(if generator.on then "GeneratorTurnOff" else "GeneratorTurnOn")
	generator.indicator.Color = if generator.on then RUNNING_COLOR else STOPPED_COLOR
	generator.indicator.Material = if generator.on then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

local function labelTurret(turret: Turret)
	local text = Localization.get("TurretStatus", {
		name = itemName(turret.kind),
		ammo = turret.ammo,
		max = PC.Turrets[turret.kind].Capacity,
		power = Localization.get(if turret.powered then "PowerOn" else "PowerOff"),
	})
	local action = Localization.get(if turret.enabled then "TurretDisable" else "TurretEnable")
	if text == turret.shown and turret.prompt.ActionText == action then
		return
	end
	turret.shown = text
	turret.prompt.ObjectText = text
	turret.prompt.ActionText = action
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

-- Solves the network, lights lamps, powers turrets and fences, burns gas for `dt` seconds and sets
-- the Power trace. A generator that runs dry stops.
local function refresh(dt: number)
	local powered, load = Power.flow(nodes(), parents)
	local litCount = 0
	local lampOrder: { Lamp } = {}
	for _, lamp in lamps do
		table.insert(lampOrder, lamp)
	end
	table.sort(lampOrder, function(a, b)
		return a.key < b.key
	end)
	for _, lamp in lampOrder do
		local lit = powered[lamp.key] == true and litCount < PC.MaxLitLamps
		setLit(lamp, lit)
		if lit then
			litCount += 1
		end
	end
	for key, turret in turrets do
		turret.powered = powered[key] == true
		labelTurret(turret)
	end
	for key, post in posts do
		post.powered = powered[key] == true
	end
	for key, relay in relays do
		relay.powered = powered[key] == true
	end
	local runningCount = 0
	for key, generator in generators do
		generator.load = load[key] or 0
		if generator.on and generator.fuel > 0 then
			generator.fuel = math.max(0, generator.fuel - Power.burn(generator.load, dt))
			if generator.fuel <= 0 then
				generator.on = false
			end
		end
		if generator.on then
			runningCount += 1
		end
		labelGenerator(generator)
	end
	local trace = litCount * Config.Threat.Trace.PerLight + runningCount * Config.Threat.Trace.PerGenerator
	ThreatService.setTraceSource(TRACE_SOURCE, trace)
end

-- The player's character root, when alive and within `reach` (plus a cell) of `part`.
local function nearPart(player: Player, part: BasePart, reach: number): boolean
	local character = player.Character
	local root = character and character.PrimaryPart
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root == nil or humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	return (root.Position - part.Position).Magnitude <= reach + BC.GridSize
end

-- The interact key on a generator: turns it on (when it has gas) or off.
local function onToggleGenerator(player: Player, generator: Generator)
	if not limiter:allow(player) or generators[generator.key] ~= generator then
		return
	end
	if not nearPart(player, generator.part, PC.PromptReach) then
		return
	end
	if not generator.on and generator.fuel <= 0 then
		return
	end
	generator.on = not generator.on
	generator.noiseAt = 0
	refresh(0)
end

-- The interact key on a turret: switches it on or off (off, it draws no power).
local function onToggleTurret(player: Player, turret: Turret)
	if not limiter:allow(player) or turrets[turret.key] ~= turret then
		return
	end
	if not nearPart(player, turret.part, PC.PromptReach) then
		return
	end
	turret.enabled = not turret.enabled
	refresh(0)
end

-- The block the player looks at within `reach` studs of their head, or nil.
local function lookedAt(origin: Vector3, direction: Vector3, reach: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignored: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignored, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignored
	-- Grass and bushes are queryable but not solid; blocks are solid.
	params.RespectCanCollide = true
	local result = Workspace:Raycast(origin, direction * reach, params)
	if result == nil then
		return nil
	end
	return (BuildService.blockAt(result.Instance))
end

-- ToolService use handler for gas: pours one refuel step into the generator the player looks at.
local function onFuel(player: Player, origin: Vector3, direction: Vector3, itemId: string)
	local now = os.clock()
	if not Config.Items[itemId].Fuel or now < (nextFuelAt[player] or 0) then
		return
	end
	nextFuelAt[player] = now + BC.PlaceCooldown * (1 - MC.CooldownTolerance)
	local key = lookedAt(origin, direction, PC.PromptReach)
	local generator = if key then generators[key] else nil
	if generator == nil then
		return
	end
	local amount = Power.refuel(generator.fuel, InventoryService.count(player, itemId))
	if amount > 0 and InventoryService.take(player, { [itemId] = amount }) then
		generator.fuel += amount
		labelGenerator(generator)
	end
end

-- ToolService use handler for turret ammo: loads up to LoadStep rounds into the turret looked at.
local function onLoad(player: Player, origin: Vector3, direction: Vector3, itemId: string)
	local now = os.clock()
	if now < (nextLoadAt[player] or 0) then
		return
	end
	nextLoadAt[player] = now + BC.PlaceCooldown * (1 - MC.CooldownTolerance)
	local key = lookedAt(origin, direction, PC.PromptReach)
	local turret = if key then turrets[key] else nil
	if turret == nil or PC.Turrets[turret.kind].Ammo ~= itemId then
		return
	end
	local room = PC.Turrets[turret.kind].Capacity - turret.ammo
	if room <= 0 then
		notify(player, "NoticeTurretFull", { name = itemName(turret.kind) })
		return
	end
	local amount = math.min(room, PC.LoadStep, InventoryService.count(player, itemId))
	if amount > 0 and InventoryService.take(player, { [itemId] = amount }) then
		turret.ammo += amount
		labelTurret(turret)
	end
end

local function removeWire(child: number)
	parents[child] = nil
	local beam = beams[child]
	if beam then
		beams[child] = nil
		beam:Destroy()
	end
end

-- Draws the wire from `parent` to `child`: a sagging beam between attachments on the two blocks
-- (destroyed with either block). Fence wire is bare steel; power wire is dark.
local function drawWire(parent: number, child: number)
	local from, to = partOf(parent), partOf(child)
	if from == nil or to == nil then
		return
	end
	local fence = posts[parent] ~= nil and posts[child] ~= nil
	local function anchor(part: BasePart, name: string): Attachment
		local attachment = part:FindFirstChild(name)
		if attachment and attachment:IsA("Attachment") then
			return attachment
		end
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = Vector3.new(0, part.Size.Y / 2 - (if fence then 0.4 else 0.15), 0)
		a.Parent = part
		return a
	end
	local beam = Instance.new("Beam")
	beam.Name = "Wire"
	beam.Attachment0 = anchor(from, "WireOut")
	beam.Attachment1 = anchor(to, "WireIn")
	beam.Width0, beam.Width1 = 0.08, 0.08
	beam.Color = ColorSequence.new(if fence then FENCE_WIRE_COLOR else WIRE_COLOR)
	beam.LightInfluence = 1
	beam.FaceCamera = true
	beam.CurveSize0 = if fence then 0 else -0.6
	beam.CurveSize1 = if fence then 0 else 0.6
	beam.Segments = 8
	beam.Parent = to
	beams[child] = beam
end

-- ToolService use handler for the wire tool (see the header).
local function onWire(player: Player, origin: Vector3, direction: Vector3, itemId: string)
	if not Config.Items[itemId].Wiring or not wireLimiter:allow(player) then
		return
	end
	local key = lookedAt(origin, direction, PC.WireToolReach)
	local kind = if key then kindOf(key) else nil
	if key == nil or kind == nil then
		return
	end
	local list = nodes()
	local now = os.clock()
	local selection = selections[player]
	if selection and (now - selection.at > SELECTION_SECONDS or list[selection.key] == nil) then
		selections[player] = nil
		selection = nil
	end
	if selection == nil or selection.key == key then
		if selection == nil and list[key].kind ~= "Consumer" then
			selections[player] = { key = key, at = now }
			notify(player, "NoticeWireStart", { name = itemName(kind) })
			return
		end
		-- The selected block again, or a consumer: cut its input wire.
		selections[player] = nil
		if parents[key] then
			removeWire(key)
			refresh(0)
			notify(player, "NoticeWireCut", { name = itemName(kind) })
		end
		return
	end
	if list[key].kind == "Source" then
		-- Another generator: start from that one instead.
		selections[player] = { key = key, at = now }
		notify(player, "NoticeWireStart", { name = itemName(kind) })
		return
	end
	local from, to = partOf(selection.key), partOf(key)
	if from == nil or to == nil or (from.Position - to.Position).Magnitude > PC.WireReach then
		notify(player, "NoticeWireFar")
		return
	end
	-- Rewiring a block replaces its input.
	local previous = parents[key]
	parents[key] = nil
	if not Power.canLink(list, parents, selection.key, key) then
		parents[key] = previous
		notify(player, "NoticeWireBad")
		return
	end
	removeWire(key)
	local fromKind = kindOf(selection.key) or "Generator"
	parents[key] = selection.key
	drawWire(selection.key, key)
	-- 7DTD chains: a wire run into a relay or fence post carries on from there; consumers keep the
	-- wire on the block that fed them, so several can hang off one source.
	if list[key].kind ~= "Consumer" then
		selections[player] = { key = key, at = now }
	else
		selection.at = now
	end
	refresh(0)
	notify(player, "NoticeWireDone", { from = itemName(fromKind), to = itemName(kind) })
end

local function addGenerator(key: number, part: BasePart)
	local size = part.Size
	local top = part.CFrame * CFrame.new(0, size.Y / 2, 0)
	detail(part, "Exhaust", Vector3.new(0.3, 0.9, 0.3), top * CFrame.new(size.X * 0.35, 0.45, 0), OFF_COLOR)
	local indicator = detail(part, "Indicator", Vector3.new(0.35, 0.2, 0.35), top * CFrame.new(-size.X * 0.3, 0.1, 0), STOPPED_COLOR)
	local generator: Generator = {
		key = key,
		part = part,
		on = false,
		fuel = 0,
		load = 0,
		prompt = prompt(part),
		indicator = indicator,
		shown = "",
		noiseAt = 0,
		source = `Generator{key}`,
	}
	generator.prompt.Triggered:Connect(function(player)
		onToggleGenerator(player, generator)
	end)
	generators[key] = generator
	labelGenerator(generator)
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

-- The turret faces away from the player who set it down (the nearest one), like 7DTD placement.
local function placementFacing(position: Vector3): Vector3
	local best, bestDistance = nil :: Vector3?, math.huge
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character.PrimaryPart
		if root then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = root.Position, distance
			end
		end
	end
	if best then
		local away = Vector3.new(position.X - best.X, 0, position.Z - best.Z)
		if away.Magnitude > 0.1 then
			return away.Unit
		end
	end
	return Vector3.new(0, 0, -1)
end

local function addTurret(key: number, part: BasePart, kind: string)
	-- Base: the block itself (a dark plate), a post and three splayed legs; the head turns on top.
	part.Transparency = 1
	local size = part.Size
	local floor = part.CFrame * CFrame.new(0, -size.Y / 2, 0)
	local steel = Color3.fromRGB(72, 74, 70)
	detail(part, "BasePlate", Vector3.new(1.4, 0.18, 1.4), floor * CFrame.new(0, 0.09, 0), steel, Enum.Material.DiamondPlate)
	detail(part, "Post", Vector3.new(0.35, size.Y - 1.2, 0.35), floor * CFrame.new(0, (size.Y - 1.2) / 2 + 0.18, 0), steel, Enum.Material.Metal)
	for i = 0, 2 do
		local angle = i * math.pi * 2 / 3
		local leg = floor * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.55, -0.55) * CFrame.Angles(math.rad(-40), 0, 0)
		detail(part, "Leg", Vector3.new(0.18, 1.3, 0.18), leg, steel, Enum.Material.Metal)
	end
	local pivot = floor * CFrame.new(0, size.Y - 0.6, 0)
	local facing = placementFacing(part.Position)
	local head = detail(part, "Head", TURRET_HEAD_SIZE, CFrame.lookAt(pivot.Position, pivot.Position + facing), Color3.new(1, 1, 1))
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = TURRET_HEAD_MESH
	mesh.TextureId = TURRET_HEAD_TEXTURE
	mesh.Scale = TURRET_HEAD_SIZE / TURRET_HEAD_NATIVE
	-- The shotgun turret's head is wider and darker.
	if kind == "ShotgunTurret" then
		mesh.Scale *= Vector3.new(1.15, 1, 0.9)
		mesh.VertexColor = Vector3.new(0.75, 0.6, 0.5)
	end
	mesh.Parent = head
	local turret: Turret = {
		key = key,
		part = part,
		kind = kind,
		head = head,
		pivot = pivot,
		facing = facing,
		ammo = 0,
		enabled = true,
		powered = false,
		nextShot = 0,
		prompt = prompt(part),
		shown = "",
		source = `Turret{key}`,
	}
	turret.prompt.Triggered:Connect(function(player)
		onToggleTurret(player, turret)
	end)
	turrets[key] = turret
	labelTurret(turret)
end

local function addPost(key: number, part: BasePart)
	local top = part.CFrame * CFrame.new(0, part.Size.Y / 2, 0)
	detail(part, "Insulator", Vector3.new(0.5, 0.35, 0.5), top * CFrame.new(0, -0.4, 0), Color3.fromRGB(200, 190, 150), Enum.Material.Glass)
	detail(part, "Warning", Vector3.new(0.65, 0.4, 0.05), part.CFrame * CFrame.new(0, 0, -0.33), Color3.fromRGB(220, 180, 40), Enum.Material.SmoothPlastic)
	posts[key] = { key = key, part = part, powered = false }
end

local function addRelay(key: number, part: BasePart)
	local top = part.CFrame * CFrame.new(0, part.Size.Y / 2, 0)
	detail(part, "Box", Vector3.new(0.7, 0.45, 0.5), top * CFrame.new(0, -0.3, 0), Color3.fromRGB(70, 90, 110), Enum.Material.Metal)
	relays[key] = { key = key, part = part, powered = false }
end

local function onPlaced(key: number, kind: string, part: BasePart)
	local def = BC.Blocks[kind]
	if def.Generator then
		addGenerator(key, part)
	elseif def.Lamp then
		addLamp(key, part)
	elseif def.Turret then
		addTurret(key, part, def.Turret)
	elseif def.Fence then
		addPost(key, part)
	elseif def.Relay then
		addRelay(key, part)
	else
		return
	end
	refresh(0)
end

local function onRemoved(key: number)
	local generator = generators[key]
	local turret = turrets[key]
	if generator then
		generators[key] = nil
		ThreatService.forgetSource(generator.source)
	elseif turret then
		turrets[key] = nil
		ThreatService.forgetSource(turret.source)
	elseif lamps[key] then
		lamps[key] = nil
	elseif posts[key] then
		posts[key] = nil
	elseif relays[key] then
		relays[key] = nil
	else
		return
	end
	-- Its own input wire, and every wire it fed.
	removeWire(key)
	for child, parent in parents do
		if parent == key then
			removeWire(child)
		end
	end
	for player, selection in selections do
		if selection.key == key then
			selections[player] = nil
		end
	end
	refresh(0)
end

local function worldParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignored: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignored, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignored
	params.RespectCanCollide = true
	params.CollisionGroup = BC.ShotsGroup
	return params
end

-- Every turret that may shoot picks the nearest zombie in range, in its arc and in sight, turns its
-- head there and fires (pellets each roll their own hit), using one round.
local function stepTurrets(now: number)
	local params: RaycastParams? = nil
	for _, turret in turrets do
		local def = PC.Turrets[turret.kind]
		if not (turret.enabled and turret.powered and turret.ammo > 0 and now >= turret.nextShot) then
			continue
		end
		local origin = turret.pivot.Position
		local range = def.Range * MC.StudsPerMeter
		local bestId, bestPoint, bestDistance = nil :: number?, nil :: Vector3?, math.huge
		params = params or worldParams()
		for _, body in ZombieService.bodiesNear(origin, range) do
			local point = Vector3.new(body.x, body.y, body.z)
			local offset = point - origin
			local distance = offset.Magnitude
			if distance < bestDistance and Power.inArc(turret.facing.X, turret.facing.Z, offset.X, offset.Z, math.rad(def.HalfArc)) then
				local wall = Workspace:Raycast(origin, offset, params :: RaycastParams)
				if wall == nil or wall.Distance >= distance - MC.BodyRadius then
					bestId, bestPoint, bestDistance = body.id, point, distance
				end
			end
		end
		if bestId == nil or bestPoint == nil then
			continue
		end
		turret.nextShot = now + def.Interval
		turret.ammo -= 1
		turret.head.CFrame = CFrame.lookAt(origin, bestPoint)
		for _ = 1, def.Pellets do
			ZombieService.damage(bestId, def.Damage, nil, "Body")
		end
		firedRemote:FireAllClients(origin + (bestPoint - origin).Unit * (TURRET_HEAD_SIZE.Z / 2), bestPoint)
		ThreatService.emit("Gunshot", origin, turret.source)
		labelTurret(turret)
	end
end

-- Zombies touching a powered fence wire are shocked; shocked zombies are hurt once a second.
local function stepFences(now: number)
	for child, parent in parents do
		local a, b = posts[parent], posts[child]
		if a == nil or b == nil or not (a.powered and b.powered) then
			continue
		end
		local pa, pb = a.part.Position, b.part.Position
		local middle = (pa + pb) / 2
		local reach = (pb - pa).Magnitude / 2 + PC.FenceTouchDistance + MC.HitRadius
		local touchSq = (PC.FenceTouchDistance + MC.BodyRadius) ^ 2
		for _, body in ZombieService.bodiesNear(middle, reach) do
			local shock = shocks[body.id]
			if shock and now < shock.untilAt then
				continue
			end
			if Power.segmentDistanceSq(body.x, body.z, pa.X, pa.Z, pb.X, pb.Z) <= touchSq then
				shocks[body.id] = { untilAt = now + PC.ShockSeconds, nextHurt = now }
				ZombieService.stun(body.id, PC.ShockSeconds)
				BuildService.damage(child, PC.FenceWear)
				BuildService.damage(parent, PC.FenceWear)
			end
		end
	end
	for id, shock in shocks do
		-- Ids are reused: a dead zombie's shock must not pass to the next one.
		local _, maximum = ZombieService.getHealth(id)
		if now >= shock.untilAt or maximum == 0 then
			shocks[id] = nil
		elseif now >= shock.nextHurt then
			shock.nextHurt += 1
			ZombieService.damage(id, PC.ShockDamage, nil, "Body")
		end
	end
end

local function step()
	local now = os.clock()
	for _, generator in generators do
		if generator.on and now >= generator.noiseAt then
			generator.noiseAt = now + Config.Threat.GeneratorNoiseSeconds
			ThreatService.emit("Generator", generator.part.Position, generator.source)
		end
	end
	if now - lastTurret >= PC.TurretCheckSeconds then
		lastTurret = now
		stepTurrets(now)
	end
	if now - lastFence >= PC.FenceCheckSeconds then
		lastFence = now
		stepFences(now)
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
	wireLimiter = RateLimiter.new(PC.WireUsesPerSecond)
	noticeRemote = Net.event("Notice")
	firedRemote = Net.unreliable("TurretFired")
end

function PowerService.start()
	for id, def in Config.Items do
		if def.Fuel then
			ToolService.onUse(id, onFuel)
		elseif def.Wiring then
			ToolService.onUse(id, onWire)
		end
	end
	local ammo: { [string]: boolean } = {}
	for _, def in PC.Turrets do
		ammo[def.Ammo] = true
	end
	for id in ammo do
		ToolService.onUse(id, onLoad)
	end
	BuildService.onPlaced(onPlaced)
	BuildService.onRemoved(onRemoved)
	Players.PlayerRemoving:Connect(function(player)
		nextFuelAt[player] = nil
		nextLoadAt[player] = nil
		selections[player] = nil
	end)
	lastCheck = os.clock()
	RunService.Heartbeat:Connect(step)
end

return PowerService
