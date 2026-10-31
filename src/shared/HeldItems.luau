--!strict
-- Builds the stylized model of an item held in the right hand. Tools get a handle and a head, bows a
-- limb and string, guns a grip and barrel; anything else is a small block in the item's colour. Parts are massless, non-colliding and welded
-- to the hand, so they replicate with the character and never push it around.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local HeldItems = {}

local V = Vector3.new
local HANDLE_COLOR = Color3.fromRGB(110, 78, 48)
local STONE_COLOR = Color3.fromRGB(128, 126, 120)
local LASHING_COLOR = Color3.fromRGB(150, 140, 96)
local PIPE_COLOR = Color3.fromRGB(95, 95, 100)

-- The handle points forward out of the fist, tilted up by this angle (the arm hangs at the side
-- until the tool-use step adds a swing pose).
local HOLD_TILT = math.rad(30)
-- Where along the handle the fist holds it (share of the length from the bottom end).
local GRIP_SHARE = 0.2

-- Shape of a held tool, in handle space: the handle runs along Z with its top end at -Z. The head's
-- offset is measured from that top end.
type Shape = {
	handle: number,
	head: Vector3,
	headOffset: Vector3,
	headColor: Color3,
	headMaterial: Enum.Material?,
	lashing: boolean,
}

local SHAPES: { [string]: Shape } = {
	-- Blade below the top end, on the side facing the ground.
	StoneAxe = {
		handle = 2.2,
		head = V(0.18, 0.7, 0.45),
		headOffset = V(0, -0.3, 0.2),
		headColor = STONE_COLOR,
		lashing = true,
	},
	-- Head across the top end, pointing both ways.
	StonePickaxe = {
		handle = 2.2,
		head = V(0.18, 1.4, 0.22),
		headOffset = V(0, 0, 0.1),
		headColor = STONE_COLOR,
		lashing = true,
	},
	-- Flat blade continuing past the top end.
	StoneShovel = {
		handle = 2.6,
		head = V(0.65, 0.1, 0.85),
		headOffset = V(0, 0, -0.4),
		headColor = STONE_COLOR,
		lashing = true,
	},
	-- A thick wooden end on a short handle.
	WoodenClub = {
		handle = 1.8,
		head = V(0.42, 0.42, 1.1),
		headOffset = V(0, 0, 0.45),
		headColor = HANDLE_COLOR,
		headMaterial = Enum.Material.Wood,
		lashing = false,
	},
	-- A bow is built by `bow` below.
	-- A long shaft with a stone point past the top end.
	StoneSpear = {
		handle = 4.2,
		head = V(0.2, 0.12, 0.6),
		headOffset = V(0, 0, -0.3),
		headColor = STONE_COLOR,
		lashing = true,
	},
}

local function part(model: Model, name: string, size: Vector3, color: Color3, material: Enum.Material): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Parent = model
	return p
end

local function weld(part0: BasePart, part1: BasePart, c0: CFrame)
	local w = Instance.new("Weld")
	w.Part0 = part0
	w.Part1 = part1
	w.C0 = c0
	w.Parent = part1
end

-- An upright wooden limb in the fist with its string toward the player.
local function bow(model: Model, hand: BasePart, fist: CFrame): BasePart
	local limb = part(model, "Limb", V(0.16, 3.2, 0.22), HANDLE_COLOR, Enum.Material.Wood)
	weld(hand, limb, fist)
	local cord = part(model, "String", V(0.04, 3, 0.04), Color3.fromRGB(225, 220, 200), Enum.Material.Fabric)
	weld(limb, cord, CFrame.new(0, 0, 0.45))
	return limb
end

-- A gun (a ranged weapon with a magazine): a wooden grip in the fist and a metal pipe barrel above it,
-- pointing forward.
local function gun(model: Model, hand: BasePart, fist: CFrame): BasePart
	local grip = part(model, "Grip", V(0.22, 0.6, 0.3), HANDLE_COLOR, Enum.Material.Wood)
	weld(hand, grip, fist * CFrame.new(0, -0.1, 0))
	local barrel = part(model, "Barrel", V(0.18, 0.18, 1.3), PIPE_COLOR, Enum.Material.Metal)
	weld(grip, barrel, CFrame.new(0, 0.38, -0.45))
	return grip
end

-- The model for item `id`, welded to `hand` at `grip` (hand space; only its position is used, since
-- grip attachments are rotated differently between rigs). The caller parents and later destroys it.
function HeldItems.build(id: string, hand: BasePart, grip: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "HeldItem"
	local shape = SHAPES[id]
	local fist = CFrame.new(grip.Position)
	local weapon = Config.Ranged.Weapons[id]
	if weapon and weapon.Magazine then
		model.PrimaryPart = gun(model, hand, fist)
	elseif weapon then
		model.PrimaryPart = bow(model, hand, fist)
	elseif shape then
		local handle = part(model, "Handle", V(0.22, 0.22, shape.handle), HANDLE_COLOR, Enum.Material.Wood)
		local fromCenter = shape.handle * (0.5 - GRIP_SHARE)
		weld(hand, handle, fist * CFrame.Angles(HOLD_TILT, 0, 0) * CFrame.new(0, 0, -fromCenter))
		local top = CFrame.new(0, 0, -shape.handle / 2)
		local head = part(model, "Head", shape.head, shape.headColor, shape.headMaterial or Enum.Material.Slate)
		weld(handle, head, top * CFrame.new(shape.headOffset))
		if shape.lashing then
			local lashing = part(model, "Lashing", V(0.3, 0.3, 0.3), LASHING_COLOR, Enum.Material.Fabric)
			weld(handle, lashing, top)
		end
		model.PrimaryPart = handle
	else
		local def = Config.Items[id]
		local c = if def then def.Color else { 0.5, 0.5, 0.5 }
		local color = Color3.new(c[1], c[2], c[3])
		local block = part(model, "Block", V(0.6, 0.6, 0.6), color, Enum.Material.SmoothPlastic)
		weld(hand, block, fist * CFrame.new(0, -0.3, 0))
		model.PrimaryPart = block
	end
	return model
end

return HeldItems
