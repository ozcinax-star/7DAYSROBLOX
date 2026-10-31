--!strict
-- Builds the stylized model of an item held in the right hand. Tools get a handle and a head, bows a
-- limb and string, guns a grip and barrel; anything else is a small block in the item's colour. Parts
-- are massless, non-colliding and welded to the hand, so they replicate with the character and never
-- push it around. The server hangs it on the character (InventoryService); the client builds the same
-- model for its first-person view (ViewmodelController).

local Config = require("./Config")

local HeldItems = {}

local V = Vector3.new
local HANDLE_COLOR = Color3.fromRGB(110, 78, 48)
local STONE_COLOR = Color3.fromRGB(128, 126, 120)
local LASHING_COLOR = Color3.fromRGB(150, 140, 96)
local PIPE_COLOR = Color3.fromRGB(95, 95, 100)
local IRON_COLOR = Color3.fromRGB(140, 143, 150)
local FIREAXE_COLOR = Color3.fromRGB(166, 46, 38)

-- The handle points forward out of the fist, tilted up by this angle (the arm hangs at the side
-- until the tool-use step adds a swing pose).
local HOLD_TILT = math.rad(30)
-- Where along the handle the fist holds it (share of the length from the bottom end).
local GRIP_SHARE = 0.2
-- The viewmodel poses tools by their handle, so it needs the tilt (ViewmodelController).
HeldItems.HoldTilt = HOLD_TILT

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
	-- Iron tools: the stone shapes with forged metal heads, riveted on instead of lashed. The fireaxe
	-- head is painted red.
	IronFireaxe = {
		handle = 2.4,
		head = V(0.16, 0.85, 0.5),
		headOffset = V(0, -0.35, 0.2),
		headColor = FIREAXE_COLOR,
		headMaterial = Enum.Material.Metal,
		lashing = false,
	},
	IronPickaxe = {
		handle = 2.4,
		head = V(0.14, 1.6, 0.18),
		headOffset = V(0, 0, 0.1),
		headColor = IRON_COLOR,
		headMaterial = Enum.Material.Metal,
		lashing = false,
	},
	IronShovel = {
		handle = 2.8,
		head = V(0.7, 0.06, 0.9),
		headOffset = V(0, 0, -0.42),
		headColor = IRON_COLOR,
		headMaterial = Enum.Material.Metal,
		lashing = false,
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

local function part(model: Model, name: string, size: Vector3, color: Color3, material: Enum.Material): Part
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

local METAL = Enum.Material.Metal
local WOOD = Enum.Material.Wood
local FABRIC = Enum.Material.Fabric
local PLASTIC = Enum.Material.SmoothPlastic
local PLATE = Enum.Material.DiamondPlate

-- A part welded to `base` at `at` (base space).
local function piece(
	model: Model,
	base: BasePart,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	at: CFrame
): Part
	local p = part(model, name, size, color, material)
	weld(base, p, at)
	return p
end

-- A round bar of `length` along base Z, centred at `at` (cylinders run along their own X).
local function tube(
	model: Model,
	base: BasePart,
	name: string,
	length: number,
	diameter: number,
	color: Color3,
	material: Enum.Material,
	at: CFrame
): Part
	local size = V(length, diameter, diameter)
	local p = piece(model, base, name, size, color, material, at * CFrame.Angles(0, math.rad(90), 0))
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A bar from `a` to `b` (base space), `width` across and `depth` deep.
local function strut(
	model: Model,
	base: BasePart,
	name: string,
	a: Vector3,
	b: Vector3,
	width: number,
	depth: number,
	color: Color3,
	material: Enum.Material
): Part
	return piece(model, base, name, V(width, depth, (b - a).Magnitude), color, material, CFrame.lookAt((a + b) / 2, b))
end

local BOW_TIP = V(0, 1.55, 0.36)
local BOW_BEND = V(0, 0.95, 0.1)

-- A bent wooden bow in the fist: a wrapped grip, two limbs of two segments each curving toward the
-- player, and a string between the tips.
local function bow(model: Model, hand: BasePart, fist: CFrame): BasePart
	local grip = part(model, "Grip", V(0.18, 0.62, 0.24), HANDLE_COLOR, WOOD)
	weld(hand, grip, fist)
	piece(model, grip, "Wrap", V(0.22, 0.4, 0.28), LASHING_COLOR, FABRIC, CFrame.identity)
	for _, side in { 1, -1 } do
		local base = V(0, 0.3 * side, 0)
		local bend = V(0, BOW_BEND.Y * side, BOW_BEND.Z)
		local tip = V(0, BOW_TIP.Y * side, BOW_TIP.Z)
		strut(model, grip, "Limb", base, bend, 0.15, 0.2, HANDLE_COLOR, WOOD)
		strut(model, grip, "Limb", bend, tip, 0.12, 0.16, HANDLE_COLOR, WOOD)
		piece(model, grip, "Nock", V(0.16, 0.1, 0.12), LASHING_COLOR, FABRIC, CFrame.new(tip))
	end
	local cordColor = Color3.fromRGB(225, 220, 200)
	local low, high = V(0, -BOW_TIP.Y, BOW_TIP.Z + 0.02), V(0, BOW_TIP.Y, BOW_TIP.Z + 0.02)
	strut(model, grip, "String", low, high, 0.035, 0.035, cordColor, FABRIC)
	return grip
end

-- Guns are improvised (7DTD pipe weapons): a pipe barrel taped and wired onto a scrap receiver, with
-- a wooden grip in the fist. Each has its own silhouette so it reads at a glance. Gun space: the grip
-- centre is the origin, the barrel points along -Z and the receiver sits on top (+Y).
local TAPE_COLOR = Color3.fromRGB(62, 62, 66)
local RUST_COLOR = Color3.fromRGB(122, 70, 44)
local DARK_METAL = Color3.fromRGB(58, 58, 62)
local BORE_COLOR = Color3.fromRGB(15, 15, 15)
local SHELL_COLOR = Color3.fromRGB(170, 40, 34)

type GunBuilder = (model: Model, grip: BasePart) -> ()

-- A trigger and its guard under the receiver, just ahead of the grip.
local function trigger(model: Model, grip: BasePart)
	piece(model, grip, "TriggerGuard", V(0.05, 0.05, 0.34), DARK_METAL, METAL, CFrame.new(0, 0.16, -0.28))
	piece(model, grip, "Trigger", V(0.04, 0.13, 0.04), DARK_METAL, METAL, CFrame.new(0, 0.24, -0.2))
end

-- A pipe barrel from z = `from` forward by `length`, with a muzzle collar and a dark bore at the end.
local function barrel(model: Model, grip: BasePart, y: number, from: number, length: number, diameter: number)
	tube(model, grip, "Barrel", length, diameter, PIPE_COLOR, METAL, CFrame.new(0, y, from - length / 2))
	local muzzle = from - length
	tube(model, grip, "Muzzle", 0.1, diameter + 0.06, RUST_COLOR, METAL, CFrame.new(0, y, muzzle + 0.05))
	tube(model, grip, "Bore", 0.02, diameter * 0.6, BORE_COLOR, PLASTIC, CFrame.new(0, y, muzzle - 0.01))
end

-- A tape or wire band around the barrel at z.
local function band(model: Model, grip: BasePart, y: number, z: number, diameter: number, color: Color3)
	local material = if color == TAPE_COLOR then FABRIC else METAL
	tube(model, grip, "Band", 0.12, diameter + 0.04, color, material, CFrame.new(0, y, z))
end

-- A wooden stock behind the receiver, its back end lowered by `drop` degrees, with a rusty butt plate.
local function stock(model: Model, grip: BasePart, length: number, drop: number)
	local at = CFrame.new(0, 0.38, 0.15) * CFrame.Angles(math.rad(drop), 0, 0)
	piece(model, grip, "Stock", V(0.2, 0.34, length), HANDLE_COLOR, WOOD, at * CFrame.new(0, -0.06, length / 2))
	piece(model, grip, "ButtPlate", V(0.22, 0.4, 0.07), RUST_COLOR, METAL, at * CFrame.new(0, -0.06, length + 0.03))
end

local GUNS: { [string]: GunBuilder } = {
	-- A short pipe on a boxy receiver, with a hammer at the back and a front sight.
	PipePistol = function(model, grip)
		piece(model, grip, "Receiver", V(0.24, 0.26, 0.66), DARK_METAL, METAL, CFrame.new(0, 0.42, -0.14))
		barrel(model, grip, 0.47, -0.42, 0.95, 0.17)
		band(model, grip, 0.47, -0.62, 0.17, TAPE_COLOR)
		local cocked = CFrame.new(0, 0.6, 0.16) * CFrame.Angles(math.rad(-25), 0, 0)
		piece(model, grip, "Hammer", V(0.08, 0.16, 0.1), RUST_COLOR, METAL, cocked)
		piece(model, grip, "Sight", V(0.04, 0.09, 0.05), DARK_METAL, METAL, CFrame.new(0, 0.59, -1.28))
		trigger(model, grip)
	end,
	-- A long thin pipe on a wooden forend, a bolt handle on the right and a full stock.
	PipeRifle = function(model, grip)
		piece(model, grip, "Receiver", V(0.24, 0.28, 0.8), DARK_METAL, METAL, CFrame.new(0, 0.42, -0.2))
		barrel(model, grip, 0.47, -0.6, 2, 0.15)
		piece(model, grip, "Forend", V(0.2, 0.16, 0.8), HANDLE_COLOR, WOOD, CFrame.new(0, 0.33, -1.0))
		band(model, grip, 0.47, -0.75, 0.15, TAPE_COLOR)
		band(model, grip, 0.47, -1.45, 0.15, RUST_COLOR)
		band(model, grip, 0.47, -2.2, 0.15, TAPE_COLOR)
		piece(model, grip, "Bolt", V(0.3, 0.05, 0.05), PIPE_COLOR, METAL, CFrame.new(0.2, 0.47, 0))
		local knob = piece(model, grip, "BoltKnob", V(0.11, 0.11, 0.11), RUST_COLOR, METAL, CFrame.new(0.37, 0.47, 0))
		knob.Shape = Enum.PartType.Ball
		stock(model, grip, 1.15, 7)
		trigger(model, grip)
	end,
	-- One fat pipe that breaks open on a hinge pin, a wooden forend, a stock and two spare shells.
	PipeShotgun = function(model, grip)
		piece(model, grip, "Receiver", V(0.28, 0.3, 0.6), DARK_METAL, METAL, CFrame.new(0, 0.42, -0.08))
		barrel(model, grip, 0.5, -0.38, 1.65, 0.27)
		local pin = piece(model, grip, "Hinge", V(0.34, 0.09, 0.09), RUST_COLOR, METAL, CFrame.new(0, 0.37, -0.42))
		pin.Shape = Enum.PartType.Cylinder
		piece(model, grip, "Forend", V(0.24, 0.2, 0.75), HANDLE_COLOR, WOOD, CFrame.new(0, 0.3, -0.95))
		band(model, grip, 0.5, -0.7, 0.27, RUST_COLOR)
		band(model, grip, 0.5, -1.7, 0.27, RUST_COLOR)
		stock(model, grip, 1, 9)
		for i = 0, 1 do
			local at = CFrame.new(0.14, 0.3, 0.55 + i * 0.16) * CFrame.Angles(0, 0, math.rad(90))
			local shell = piece(model, grip, "Shell", V(0.24, 0.1, 0.1), SHELL_COLOR, PLASTIC, at)
			shell.Shape = Enum.PartType.Cylinder
		end
		trigger(model, grip)
	end,
	-- A big receiver with a box magazine, a carry handle, a perforated heat shield around the barrel
	-- and a skeleton stock of two rods.
	PipeMachineGun = function(model, grip)
		piece(model, grip, "Receiver", V(0.3, 0.34, 1.05), DARK_METAL, METAL, CFrame.new(0, 0.44, -0.25))
		barrel(model, grip, 0.49, -0.78, 1.95, 0.13)
		tube(model, grip, "HeatShield", 1.2, 0.27, PIPE_COLOR, PLATE, CFrame.new(0, 0.49, -1.45))
		local raked = CFrame.new(0, 0.05, -0.6) * CFrame.Angles(math.rad(-8), 0, 0)
		piece(model, grip, "Magazine", V(0.16, 0.62, 0.32), RUST_COLOR, METAL, raked)
		piece(model, grip, "Handle", V(0.06, 0.06, 0.6), PIPE_COLOR, METAL, CFrame.new(0, 0.78, -0.3))
		for _, z in { -0.05, -0.55 } do
			piece(model, grip, "HandlePost", V(0.06, 0.18, 0.06), PIPE_COLOR, METAL, CFrame.new(0, 0.68, z))
		end
		for _, y in { 0.52, 0.28 } do
			piece(model, grip, "StockRod", V(0.05, 0.05, 1), PIPE_COLOR, METAL, CFrame.new(0, y, 0.75))
		end
		piece(model, grip, "ButtPlate", V(0.2, 0.42, 0.07), RUST_COLOR, METAL, CFrame.new(0, 0.4, 1.27))
		band(model, grip, 0.49, -2.35, 0.13, TAPE_COLOR)
		trigger(model, grip)
	end,
}

-- Extra detail on a tool, in handle space (`top` is the handle's top end).
local GRIP_WRAP_COLOR = Color3.fromRGB(84, 70, 56)
local DETAILS: { [string]: (model: Model, handle: BasePart, top: CFrame) -> () } = {
	-- Nails driven through the club's head, sticking out on all four sides.
	WoodenClub = function(model, handle, top)
		local head = top * CFrame.new(0, 0, 0.45)
		for _, z in { -0.3, 0.12 } do
			for _, x in { -0.25, 0.25 } do
				piece(model, handle, "Nail", V(0.18, 0.04, 0.04), PIPE_COLOR, METAL, head * CFrame.new(x, 0, z))
			end
			for _, y in { -0.25, 0.25 } do
				piece(model, handle, "Nail", V(0.04, 0.18, 0.04), PIPE_COLOR, METAL, head * CFrame.new(0, y, z - 0.2))
			end
		end
	end,
	-- A narrower second flake past the point, so the tip tapers.
	StoneSpear = function(model, handle, top)
		local tip = top * CFrame.new(0, 0, -0.74)
		piece(model, handle, "Tip", V(0.12, 0.08, 0.32), STONE_COLOR, Enum.Material.Slate, tip)
	end,
}

-- A gun (a ranged weapon with a magazine): a wooden grip in the fist and the rest built around it by
-- its GUNS entry (a bare pipe on the grip for a gun without one).
local function gun(model: Model, hand: BasePart, fist: CFrame, id: string): BasePart
	local grip = part(model, "Grip", V(0.22, 0.6, 0.3), HANDLE_COLOR, WOOD)
	weld(hand, grip, fist * CFrame.new(0, -0.1, 0))
	local build = GUNS[id]
	if build then
		build(model, grip)
	else
		barrel(model, grip, 0.38, 0.2, 1.3, 0.18)
	end
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
		model.PrimaryPart = gun(model, hand, fist, id)
	elseif weapon then
		model.PrimaryPart = bow(model, hand, fist)
	elseif shape then
		local handle = part(model, "Handle", V(0.22, 0.22, shape.handle), HANDLE_COLOR, Enum.Material.Wood)
		local fromCenter = shape.handle * (0.5 - GRIP_SHARE)
		weld(hand, handle, fist * CFrame.Angles(HOLD_TILT, 0, 0) * CFrame.new(0, 0, -fromCenter))
		local top = CFrame.new(0, 0, -shape.handle / 2)
		local head = part(model, "Head", shape.head, shape.headColor, shape.headMaterial or Enum.Material.Slate)
		weld(handle, head, top * CFrame.new(shape.headOffset))
		piece(model, handle, "GripWrap", V(0.26, 0.26, 0.5), GRIP_WRAP_COLOR, FABRIC, CFrame.new(0, 0, fromCenter))
		local detail = DETAILS[id]
		if detail then
			detail(model, handle, top)
		end
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
