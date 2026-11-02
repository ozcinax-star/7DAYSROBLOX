--!strict
-- ArmorService: what each player wears in the four armour slots (Config.Armor, 7DTD 1.x). Holding a
-- piece and "using" it (ToolService) puts it on, swapping out what was in that slot; the client asks to
-- take a slot off (validated, rate limited) and the piece goes back to the backpack when it fits.
-- Zombie hits are cut by the worn rating and wear every piece (Shared/Armor). Worn pieces stay on
-- through death (PLAN: equipment is kept), are saved with the character and show as shells welded to
-- the character's limbs, so everyone sees them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Armor = require(Shared.Armor)
local Config = require(Shared.Config)
local Inventory = require(Shared.Inventory)
local Net = require(Shared.Net)

local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local InventoryService = require(script.Parent.InventoryService)
local PersistenceService = require(script.Parent.PersistenceService)
local ToolService = require(script.Parent.ToolService)
local ZombieService = require(script.Parent.ZombieService)

local AC = Config.Armor
local VISUAL_NAME = "ArmorShells"
-- Set on an avatar accessory this service hid (a hat or hair under a hood or helmet).
local HIDDEN_ATTRIBUTE = "ArmorHidden"
local HEAD_ACCESSORIES: { [Enum.AccessoryType]: boolean } = {
	[Enum.AccessoryType.Hat] = true,
	[Enum.AccessoryType.Hair] = true,
}

-- The limbs each slot covers: R15 names first, then the R6 part that stands in.
local LIMBS: { [string]: { { string } } } = {
	Head = { { "Head" } },
	Chest = { { "UpperTorso", "Torso" } },
	Hands = { { "LeftHand", "Left Arm" }, { "RightHand", "Right Arm" } },
	Feet = { { "LeftFoot", "Left Leg" }, { "RightFoot", "Right Leg" } },
}

local ArmorService = {}

local worn: { [Player]: Armor.Worn } = {}
local dirty: { [Player]: boolean } = {}
local limiter: RateLimiter.RateLimiter
local updateRemote: RemoteEvent
local noticeRemote: RemoteEvent

local function wornOf(player: Player): Armor.Worn
	local set = worn[player]
	if set == nil then
		set = Armor.empty()
		worn[player] = set
	end
	return set
end

local function limb(character: Model, names: { string }): BasePart?
	for _, name in names do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

-- A shell around `part`, welded to it; `size` and `offset` are in the part's space.
local function shell(
	folder: Folder,
	part: BasePart,
	size: Vector3,
	offset: CFrame,
	look: { Color: { number }, Material: Enum.Material }
)
	local piece = Instance.new("Part")
	piece.Name = part.Name
	piece.Size = size
	piece.CFrame = part.CFrame * offset
	piece.Color = Color3.new(look.Color[1], look.Color[2], look.Color[3])
	piece.Material = look.Material
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Massless = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.Parent = folder
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = piece
	weld.Parent = piece
end

-- A hood or helmet replaces the avatar's hat and hair (they would cover it); taking it off shows them
-- again.
local function hideHeadAccessories(character: Model, hide: boolean)
	for _, accessory in character:GetChildren() do
		if not accessory:IsA("Accessory") or not HEAD_ACCESSORIES[accessory.AccessoryType] then
			continue
		end
		local handle = accessory:FindFirstChild("Handle")
		if handle == nil or not handle:IsA("BasePart") then
			continue
		end
		if hide and handle.Transparency < 1 then
			handle:SetAttribute(HIDDEN_ATTRIBUTE, handle.Transparency)
			handle.Transparency = 1
		elseif not hide then
			local before = handle:GetAttribute(HIDDEN_ATTRIBUTE)
			if typeof(before) == "number" then
				handle.Transparency = before
				handle:SetAttribute(HIDDEN_ATTRIBUTE, nil)
			end
		end
	end
end

-- Rebuilds the shells of what `player` wears on their character.
local function refreshLook(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local old = character:FindFirstChild(VISUAL_NAME)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = VISUAL_NAME
	local scale = AC.ShellScale
	for slot, stack in wornOf(player) do
		if not stack then
			continue
		end
		local def = Config.Items[stack.id].Armor
		local look = def and AC.Sets[def.Set]
		if look == nil then
			continue
		end
		for _, names in LIMBS[slot] do
			local part = limb(character, names)
			if part then
				local size = part.Size * scale
				local offset = CFrame.identity
				if slot == "Head" then
					-- A hood or helmet covers the top of the head and leaves the face below it.
					local cover = part.Size.Y * AC.HeadCoverShare
					size = Vector3.new(size.X, cover * scale, size.Z)
					offset = CFrame.new(0, (part.Size.Y - cover) / 2, 0)
				end
				shell(folder, part, size, offset, look)
			end
		end
	end
	folder.Parent = character
	hideHeadAccessories(character, wornOf(player).Head ~= false)
end

local function changed(player: Player)
	dirty[player] = true
end

-- What the owner sees: each slot's piece (id and durability) or false.
local function publish(player: Player)
	local rows: { [string]: any } = {}
	for slot, stack in wornOf(player) do
		rows[slot] = if stack then { id = stack.id, durability = stack.durability } else false
	end
	updateRemote:FireClient(player, rows)
end

local function flush()
	for player in dirty do
		dirty[player] = nil
		if player.Parent == Players then
			publish(player)
			refreshLook(player)
		end
	end
end

-- "Use" on a held armour piece: it goes on, and what was in its slot takes its place in the hand.
local function onWear(player: Player, _origin: Vector3, _direction: Vector3, id: string)
	if not limiter:allow(player) then
		return
	end
	local slot = Armor.slotOf(id)
	local held, index = InventoryService.getHeld(player)
	if slot == nil or held == nil or held.id ~= id then
		return
	end
	local taken = InventoryService.takeSlot(player, index)
	if taken == nil then
		return
	end
	local set = wornOf(player)
	local previous = set[slot]
	set[slot] = taken
	if previous then
		InventoryService.putSlot(player, index, previous)
	end
	changed(player)
end

-- The client asks to take off what is in `slot`; it goes back to the backpack only when it fits.
local function onTakeOff(player: Player, slot: unknown)
	if not limiter:allow(player) then
		return
	end
	if typeof(slot) ~= "string" or table.find(AC.Slots, slot) == nil then
		return
	end
	local set = wornOf(player)
	local stack = set[slot]
	if not stack then
		return
	end
	if InventoryService.room(player, stack.id, stack.source) < 1 then
		noticeRemote:FireClient(player, "NoticeArmorNoRoom", {})
		return
	end
	set[slot] = false
	local left = InventoryService.give(player, stack.id, 1, stack.source, stack.durability, stack)
	if left > 0 then
		-- Defensive: room was checked; put it back on rather than lose it.
		set[slot] = stack
	end
	changed(player)
end

-- What reaches `player` of a zombie hit of `damage`. God mode (a ForceField) takes the hit itself, so
-- armour neither cuts nor wears then.
local function absorb(player: Player, damage: number): number
	local character = player.Character
	if character and character:FindFirstChildOfClass("ForceField") then
		return damage
	end
	local set = worn[player]
	if set == nil then
		return damage
	end
	local before = Armor.rating(set)
	if before <= 0 then
		return damage
	end
	local left = Armor.absorb(set, damage)
	changed(player)
	return left
end

-- Saved character part "Armor": the worn pieces as inventory rows, slot order = Config.Armor.Slots.
-- Rows that fail validation, or hold a piece in the wrong slot, are dropped.
local function save(player: Player): any
	local holder = Inventory.new(0, #AC.Slots)
	for index, slot in AC.Slots do
		local stack = wornOf(player)[slot]
		holder.slots[index] = if stack then stack else false
	end
	return Inventory.serialize(holder)
end

local function load(player: Player, data: any)
	local holder = Inventory.new(0, #AC.Slots)
	Inventory.deserialize(holder, data)
	local set = wornOf(player)
	for index, slot in AC.Slots do
		local stack = holder.slots[index]
		set[slot] = if stack and Armor.slotOf(stack.id) == slot then stack else false
	end
	changed(player)
end

function ArmorService.init()
	limiter = RateLimiter.new(AC.ChangesPerSecond)
	updateRemote = Net.event("ArmorUpdate")
	noticeRemote = Net.event("Notice")
	Net.event("ArmorTakeOff")
	PersistenceService.registerCharacter("Armor", { save = save, load = load })
end

-- Debug and tests: the total rating `player` wears.
function ArmorService.rating(player: Player): number
	local set = worn[player]
	return if set then Armor.rating(set) else 0
end

function ArmorService.start()
	for id, item in Config.Items do
		if item.Armor then
			ToolService.onUse(id, onWear)
		end
	end
	ZombieService.setPlayerDamageFilter(absorb)
	Net.event("ArmorTakeOff").OnServerEvent:Connect(onTakeOff)
	local function watch(player: Player)
		wornOf(player)
		changed(player)
		player.CharacterAdded:Connect(function(character)
			-- Avatar accessories load after the character: a new hat is hidden under a worn helmet too.
			-- The connection belongs to the character and goes when it is destroyed on respawn.
			character.ChildAdded:Connect(function(child)
				if child:IsA("Accessory") then
					changed(player)
				end
			end)
			-- The limbs arrive with the character; shells are rebuilt once it is in the workspace.
			character:WaitForChild("Head", 10)
			changed(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		worn[player] = nil
		dirty[player] = nil
	end)
	RunService.Heartbeat:Connect(flush)
end

return ArmorService
