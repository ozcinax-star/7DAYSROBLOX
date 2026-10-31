--!strict
-- SurvivalService: every player's stamina, food and water (Shared/Vitals), and what changes them.
-- The server owns the stats and steps them every Config.Survival.TickSeconds from what it sees of the
-- character: its speed (sprinting), its rise (jumps) and its health. Clients get the stats as Player
-- attributes for the HUD.
--
-- - Swings pay their tool's stamina through ToolService's stamina gate.
-- - Sprinting is an intent remote; the server sets WalkSpeed and ends the sprint at 0 stamina.
--   Footsteps of a sprint are a Sprint noise every Config.Survival.SprintNoiseSeconds.
-- - Food, drinks and medicine are used from the hand; a fist "use" on lake water drinks it.
-- - Death drops half of each carried raw resource in a bag (PLAN); stats are full on respawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Vitals = require(Shared.Vitals)

local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local InventoryService = require(script.Parent.InventoryService)
local LootService = require(script.Parent.LootService)
local ThreatService = require(script.Parent.ThreatService)
local ToolService = require(script.Parent.ToolService)

local SC = Config.Survival
local A = Net.Attributes
-- Attributes are rounded to tenths so they change only when the HUD would show it.
local PUBLISH_SCALE = 10
-- After running out, a held sprint starts again only at this share of max stamina.
local SPRINT_RESUME_SHARE = 0.25

type PlayerState = {
	stats: Vitals.Stats,
	-- The player holds sprint, and whether WalkSpeed is the sprint speed now.
	wantsSprint: boolean,
	sprinting: boolean,
	-- Ran out of stamina while sprinting; cleared once the bar is back to the resume share.
	winded: boolean,
	-- Rising after a counted jump (one jump per rise).
	rising: boolean,
	-- Seconds of sprinting toward the next Sprint noise.
	sprintNoiseClock: number,
	nextUseAt: number,
	connections: { RBXScriptConnection },
}

local SurvivalService = {}

local states: { [Player]: PlayerState } = {}
local sprintLimiter: RateLimiter.RateLimiter
local elapsed = 0

local function round(value: number): number
	return math.round(value * PUBLISH_SCALE) / PUBLISH_SCALE
end

local function publish(player: Player, state: PlayerState)
	local stats = state.stats
	local values = {
		[A.Stamina] = round(stats.stamina),
		[A.StaminaCap] = round(Vitals.staminaCap(stats)),
		[A.Food] = round(stats.food),
		[A.Water] = round(stats.water),
		[A.Hunger] = stats.hunger,
		[A.Thirst] = stats.thirst,
	}
	for name, value in values do
		if player:GetAttribute(name) ~= value then
			player:SetAttribute(name, value)
		end
	end
end

local function humanoidOf(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character.PrimaryPart
	if humanoid == nil or humanoid.Health <= 0 or root == nil then
		return nil, nil
	end
	return humanoid, root
end

local function setSprinting(player: Player, state: PlayerState, sprinting: boolean)
	state.sprinting = sprinting
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.WalkSpeed = if sprinting then SC.SprintSpeed else SC.WalkSpeed
	end
end

-- Starts or ends the sprint from the intent and the stamina left.
local function updateSprint(player: Player, state: PlayerState)
	local stamina = state.stats.stamina
	if state.sprinting and stamina <= 0 then
		state.winded = true
		setSprinting(player, state, false)
	elseif state.sprinting and not state.wantsSprint then
		setSprinting(player, state, false)
	end
	if state.winded and stamina >= SC.MaxStamina * SPRINT_RESUME_SHARE then
		state.winded = false
	end
	if state.wantsSprint and not state.sprinting and not state.winded and stamina >= SC.SprintMinStamina then
		setSprinting(player, state, true)
	end
end

local function step(dt: number)
	for player, state in states do
		local humanoid, root = humanoidOf(player)
		if humanoid == nil or root == nil then
			continue
		end
		local velocity = root.AssemblyLinearVelocity
		local ground = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local sprinting = state.sprinting and ground > SC.WalkSpeed + SC.SprintSpeedMargin
		if sprinting then
			state.sprintNoiseClock += dt
			if state.sprintNoiseClock >= SC.SprintNoiseSeconds then
				state.sprintNoiseClock -= SC.SprintNoiseSeconds
				ThreatService.emit("Sprint", root.Position, player)
			end
		end
		local healed, damage = Vitals.step(state.stats, dt, {
			health = humanoid.Health,
			maxHealth = humanoid.MaxHealth,
			sprinting = sprinting,
			daySeconds = Config.DayNight.CycleSeconds,
		})
		if healed > 0 then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + healed)
		end
		if damage > 0 then
			humanoid:TakeDamage(damage)
		end
		updateSprint(player, state)
		publish(player, state)
	end
end

-- Jumps are counted every frame from the root's rise: a stat tick would miss short hops.
local function watchJumps()
	for player, state in states do
		local humanoid, root = humanoidOf(player)
		if humanoid == nil or root == nil then
			continue
		end
		local jumpSpeed = if humanoid.UseJumpPower
			then humanoid.JumpPower
			else math.sqrt(2 * Workspace.Gravity * humanoid.JumpHeight)
		local threshold = jumpSpeed * SC.JumpDetectShare
		local rise = root.AssemblyLinearVelocity.Y
		if rise > threshold and not state.rising then
			state.rising = true
			Vitals.spend(state.stats, SC.JumpCost)
		elseif rise < threshold / 2 then
			state.rising = false
		end
	end
end

-- Half of each carried raw resource goes into a bag where the player died (PLAN).
local function dropRaw(player: Player, position: Vector3)
	local costs: { [string]: number } = {}
	local any = false
	for id, def in Config.Items do
		if def.Raw then
			local count = math.floor(InventoryService.count(player, id) * SC.DeathDropShare)
			if count > 0 then
				costs[id] = count
				any = true
			end
		end
	end
	if not any then
		return
	end
	local ok, removed = InventoryService.take(player, costs)
	if ok then
		LootService.drop(position, removed, false, SC.DeathBagSeconds)
	end
end

local function onCharacter(player: Player, character: Model)
	local state = states[player]
	if state == nil then
		return
	end
	for _, connection in state.connections do
		connection:Disconnect()
	end
	table.clear(state.connections)
	state.stats = Vitals.new()
	state.sprinting = false
	state.winded = false
	state.rising = false
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.WalkSpeed = SC.WalkSpeed
	table.insert(
		state.connections,
		humanoid.Died:Connect(function()
			local root = character.PrimaryPart
			if root and states[player] == state then
				dropRaw(player, root.Position)
			end
		end)
	)
	updateSprint(player, state)
	publish(player, state)
end

local function onPlayerAdded(player: Player)
	if states[player] then
		return
	end
	local state: PlayerState = {
		stats = Vitals.new(),
		wantsSprint = false,
		sprinting = false,
		winded = false,
		rising = false,
		sprintNoiseClock = 0,
		nextUseAt = 0,
		connections = {},
	}
	states[player] = state
	publish(player, state)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

local function onSprintIntent(player: Player, wants: unknown)
	local state = states[player]
	if state == nil or not sprintLimiter:allow(player) or typeof(wants) ~= "boolean" then
		return
	end
	state.wantsSprint = wants
	updateSprint(player, state)
end

-- Applies a food, drink or medicine effect.
local function apply(player: Player, state: PlayerState, use: Config.UseDef)
	Vitals.consume(state.stats, use.Food or 0, use.Water or 0, use.Heal or 0, use.HealRate or 0)
	local humanoid = humanoidOf(player)
	if humanoid and use.Damage then
		humanoid:TakeDamage(use.Damage)
	end
	publish(player, state)
end

local function ready(player: Player): PlayerState?
	local state = states[player]
	local now = os.clock()
	if state == nil or now < state.nextUseAt then
		return nil
	end
	return state
end

local function onUseItem(player: Player, _origin: Vector3, _direction: Vector3, itemId: string)
	local state = ready(player)
	local use = Config.Items[itemId].Use
	if state == nil or use == nil then
		return
	end
	if InventoryService.consumeHeld(player, 1) then
		state.nextUseAt = os.clock() + SC.UseSeconds * (1 - Config.Melee.CooldownTolerance)
		apply(player, state, use)
	end
end

-- A bare-hand "use" aimed at water within reach drinks it (7DTD meleeHandPlayer).
local function onFistUse(player: Player, origin: Vector3, direction: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignored: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignored, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignored
	params.IgnoreWater = false
	local result = Workspace:Raycast(origin, direction * SC.DrinkReach, params)
	if result == nil or result.Instance ~= Workspace.Terrain or result.Material ~= Enum.Material.Water then
		return false
	end
	local state = ready(player)
	if state then
		state.nextUseAt = os.clock() + SC.UseSeconds * (1 - Config.Melee.CooldownTolerance)
		apply(player, state, SC.LakeDrink)
	end
	-- Aimed at water: never a punch, even while the last drink is still going down.
	return true
end

-- The stamina gate of every swing (7DTD: no swing below its cost).
local function payStamina(player: Player, cost: number): boolean
	local state = states[player]
	if state == nil or not Vitals.canSpend(state.stats, cost) then
		return false
	end
	Vitals.spend(state.stats, cost)
	publish(player, state)
	return true
end

function SurvivalService.init()
	sprintLimiter = RateLimiter.new(Config.Remotes.SprintRequestsPerSecond)
	Net.event("SprintIntent")
end

function SurvivalService.start()
	Net.event("SprintIntent").OnServerEvent:Connect(onSprintIntent)
	for id, def in Config.Items do
		if def.Use then
			ToolService.onUse(id, onUseItem)
		end
	end
	ToolService.onFistUse(onFistUse)
	ToolService.setStaminaGate(payStamina)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local state = states[player]
		if state then
			for _, connection in state.connections do
				connection:Disconnect()
			end
		end
		states[player] = nil
	end)
	RunService.Heartbeat:Connect(function(dt)
		watchJumps()
		elapsed += dt
		if elapsed >= SC.TickSeconds then
			step(elapsed)
			elapsed = 0
		end
	end)
end

-- Puts food and water at the given values (debug commands); nil leaves one as it is.
function SurvivalService.setStats(player: Player, food: number?, water: number?)
	local state = states[player]
	if state == nil then
		return
	end
	state.stats.food = math.clamp(food or state.stats.food, 0, SC.MaxFood)
	state.stats.water = math.clamp(water or state.stats.water, 0, SC.MaxWater)
	Vitals.consume(state.stats, 0, 0, 0, 0)
	publish(player, state)
end

return SurvivalService
