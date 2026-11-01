--!strict
-- Original survival equipment, with readable silhouettes, bevelled profiles and functional details.
-- Geometry is authored in an upright workbench space (Y = handle, X = blade, Z = thickness), then
-- placed in HeldItems' handle space. All detail is cosmetic; hit volumes remain server-owned.

local V = Vector3.new
local C = CFrame.new
local A = CFrame.Angles
local RGB = Color3.fromRGB
local WOOD = Enum.Material.Wood
local METAL = Enum.Material.Metal
local STONE = Enum.Material.Slate
local CLOTH = Enum.Material.Fabric
local P = {
	wood = RGB(103, 70, 42), woodLight = RGB(141, 103, 65), grain = RGB(64, 44, 30),
	stone = RGB(70, 72, 68), flint = RGB(96, 99, 93), edge = RGB(132, 133, 122),
	steel = RGB(78, 84, 83), bright = RGB(163, 169, 161), dark = RGB(34, 37, 36),
	rust = RGB(116, 65, 37), rope = RGB(161, 142, 101), tape = RGB(79, 81, 62), red = RGB(144, 44, 34),
}
local BASIS = CFrame.fromMatrix(Vector3.zero, V(0, -1, 0), V(0, 0, -1), V(1, 0, 0))
local IDENTITY = CFrame.identity

type Shop = { model: Model, root: BasePart, basis: CFrame, texturedHandle: boolean }
type Point = { number }
type Builder = (Shop, number) -> ()

local EquipmentModels = {}
local EquipmentMeshes = require("./EquipmentMeshes")

local function add(s: Shop, name: string, size: Vector3, at: CFrame, color: Color3,
	material: Enum.Material, shape: Enum.PartType?, wedge: boolean?): BasePart
	local p: BasePart
	if wedge then
		p = Instance.new("WedgePart")
	else
		local block = Instance.new("Part")
		block.Shape = shape or Enum.PartType.Block
		p = block
	end
	p.Name, p.Size, p.Color, p.Material = name, size, color, material
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.Massless, p.CastShadow = true, false
	local offset = s.basis * at
	p.CFrame = s.root.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0, weld.Part1, weld.C0 = s.root, p, offset
	weld.Parent = p
	p.Parent = s.model
	return p
end

local function box(s: Shop, name: string, size: Vector3, pos: Vector3, color: Color3,
	material: Enum.Material, rotation: CFrame?): BasePart
	return add(s, name, size, C(pos) * (rotation or IDENTITY), color, material)
end

local function rod(s: Shop, name: string, a: Vector3, b: Vector3, diameter: number,
	color: Color3, material: Enum.Material): BasePart
	return add(s, name, V((b - a).Magnitude, diameter, diameter),
		CFrame.lookAt((a + b) / 2, b) * A(0, math.pi / 2, 0), color, material, Enum.PartType.Cylinder)
end

-- Two triangular prisms make a filled triangle, allowing authored blade outlines without assets.
local function triangle(s: Shop, name: string, a: Vector3, b: Vector3, c: Vector3,
	thickness: number, color: Color3, material: Enum.Material)
	local ab, ac, bc = b - a, c - a, c - b
	if ab.Magnitude > ac.Magnitude and ab.Magnitude > bc.Magnitude then
		c, a = a, c
	elseif ac.Magnitude > bc.Magnitude then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local normal = ac:Cross(ab)
	if normal.Magnitude < 0.00001 then return end
	local right, back = normal.Unit, bc.Unit
	local up = back:Cross(right).Unit
	local height = math.abs(ab:Dot(up))
	local left, rightLength = math.abs(ab:Dot(back)), math.abs(ac:Dot(back))
	if left > 0.0001 then
		add(s, name, V(thickness, height, left), CFrame.fromMatrix((a + b) / 2, right, up, back), color, material, nil, true)
	end
	if rightLength > 0.0001 then
		add(s, name, V(thickness, height, rightLength), CFrame.fromMatrix((a + c) / 2, -right, up, -back), color, material, nil, true)
	end
end

local function profile(s: Shop, name: string, points: { Point }, thickness: number, z: number,
	color: Color3, material: Enum.Material)
	local first = V(points[1][1], points[1][2], z)
	for i = 2, #points - 1 do
		triangle(s, name, first, V(points[i][1], points[i][2], z), V(points[i + 1][1], points[i + 1][2], z), thickness, color, material)
	end
end

local function wrap(s: Shop, y: number, count: number, diameter: number, color: Color3)
	for i = 0, count - 1 do
		local at = y + i * 0.058
		rod(s, "GripBinding", V(0, at, 0), V(0, at + 0.045, 0), diameter, color, CLOTH)
	end
end

local function handle(s: Shop, length: number, primitive: boolean)
	local bend = if primitive then 0.055 else 0.025
	rod(s, "WoodenHaft", V(0, 0, 0), V(-bend, length * 0.45, 0), 0.19, P.wood, WOOD)
	rod(s, "WoodenHaft", V(-bend, length * 0.45, 0), V(bend, length * 0.77, 0), 0.21, P.woodLight, WOOD)
	rod(s, "WoodenHaft", V(bend, length * 0.77, 0), V(0, length, 0), 0.19, P.wood, WOOD)
	rod(s, "WornButt", V(0, -0.025, 0), V(0, 0.07, 0), 0.23, P.grain, WOOD)
	for i = 1, 4 do
		local side = if i % 2 == 0 then -1 else 1
		rod(s, "WoodGrain", V(0.035 * side, 0.82 + i * 0.12, 0.096),
			V(0.012 * side, 1.22 + i * 0.1, 0.096), 0.012, P.grain, WOOD)
	end
	wrap(s, 0.2, 6, 0.225, if primitive then P.rope else P.tape)
end

local function lash(s: Shop, y: number)
	wrap(s, y - 0.23, 5, 0.26, P.rope)
	rod(s, "CrossLashing", V(-0.16, y - 0.16, 0.15), V(0.26, y + 0.18, 0.15), 0.052, P.rope, CLOTH)
	rod(s, "CrossLashing", V(0.26, y - 0.17, 0.17), V(-0.16, y + 0.17, 0.17), 0.052, P.rope, CLOTH)
	rod(s, "BindingKnot", V(-0.13, y - 0.14, -0.17), V(0.22, y + 0.15, -0.17), 0.052, P.rope, CLOTH)
end

local function rivet(s: Shop, x: number, y: number, z: number)
	rod(s, "Rivet", V(x, y, z - 0.02), V(x, y, z + 0.02), 0.065, P.bright, METAL)
end

local BUILDERS: { [string]: Builder } = {}

BUILDERS.StoneAxe = function(s, length)
	if not s.texturedHandle then handle(s, length, true) end
	local y = length - 0.14
	profile(s, "KnappedCuttingEdge", { { -0.22, y + 0.16 }, { 0.18, y + 0.28 }, { 0.57, y + 0.12 },
		{ 0.7, y - 0.12 }, { 0.61, y - 0.46 }, { 0.4, y - 0.51 }, { -0.2, y - 0.15 } }, 0.12, 0, P.edge, STONE)
	profile(s, "FlintCheek", { { -0.19, y + 0.12 }, { 0.16, y + 0.2 }, { 0.46, y + 0.07 },
		{ 0.51, y - 0.15 }, { 0.4, y - 0.37 }, { -0.16, y - 0.1 } }, 0.25, 0, P.stone, STONE)
	profile(s, "FlakedRidge", { { 0.12, y + 0.13 }, { 0.41, y + 0.03 }, { 0.22, y - 0.25 } }, 0.015, 0.133, P.flint, STONE)
	lash(s, y)
end

BUILDERS.StonePickaxe = function(s, length)
	if not s.texturedHandle then handle(s, length, true) end
	local y = length - 0.06
	profile(s, "LeftKnappedPick", { { 0, y + 0.16 }, { -0.46, y + 0.08 },
		{ -0.9, y - 0.22 }, { -0.48, y - 0.08 }, { 0, y - 0.04 } }, 0.18, 0, P.stone, STONE)
	profile(s, "RightKnappedPick", { { 0, y + 0.16 }, { 0.46, y + 0.08 },
		{ 0.86, y - 0.24 }, { 0.45, y - 0.08 }, { 0, y - 0.04 } }, 0.18, 0, P.flint, STONE)
	lash(s, y)
end

local function shovel(s: Shop, length: number, iron: boolean)
	handle(s, length, not iron)
	local y = length - 0.02
	local edge, cheek = if iron then P.bright else P.edge, if iron then P.steel else P.stone
	local mat = if iron then METAL else STONE
	profile(s, "ShovelBlade", { { -0.28, y }, { 0.28, y }, { 0.39, y + 0.28 },
		{ 0.33, y + 0.68 }, { 0, y + 0.85 }, { -0.33, y + 0.68 }, { -0.39, y + 0.28 } }, 0.065, 0, edge, mat)
	profile(s, "RecessedBlade", { { -0.23, y + 0.07 }, { 0.23, y + 0.07 }, { 0.3, y + 0.29 },
		{ 0.26, y + 0.6 }, { 0, y + 0.73 }, { -0.26, y + 0.6 }, { -0.3, y + 0.29 } }, 0.075, 0.02, cheek, mat)
	if iron then
		rod(s, "ForgedSocket", V(0, y - 0.3, 0), V(0, y + 0.28, 0.04), 0.23, P.steel, METAL)
		rod(s, "BladeSpine", V(0, y + 0.16, 0.08), V(0, y + 0.59, 0.08), 0.045, P.bright, METAL)
		box(s, "BootStep", V(0.63, 0.07, 0.16), V(0, y + 0.05, 0), P.steel, METAL)
		rivet(s, 0, y - 0.13, 0.13)
	else
		lash(s, y)
	end
end

BUILDERS.StoneShovel = function(s, length) shovel(s, length, false) end
BUILDERS.IronShovel = function(s, length) shovel(s, length, true) end

BUILDERS.IronFireaxe = function(s, length)
	handle(s, length, false)
	local y = length - 0.13
	profile(s, "SharpenedSteelEdge", { { -0.3, y + 0.18 }, { 0.26, y + 0.23 }, { 0.71, y + 0.4 },
		{ 0.8, y + 0.03 }, { 0.73, y - 0.45 }, { 0.3, y - 0.29 }, { -0.3, y - 0.13 } }, 0.095, 0, P.bright, METAL)
	profile(s, "PaintedAxeHead", { { -0.28, y + 0.15 }, { 0.26, y + 0.19 }, { 0.57, y + 0.3 },
		{ 0.64, y + 0.01 }, { 0.58, y - 0.32 }, { 0.27, y - 0.24 }, { -0.28, y - 0.1 } }, 0.2, 0, P.red, METAL)
	profile(s, "RearPick", { { -0.2, y + 0.15 }, { -0.68, y + 0.29 }, { -0.28, y - 0.06 } }, 0.16, 0, P.steel, METAL)
	rod(s, "HeadSocket", V(0, y - 0.23, 0), V(0, y + 0.2, 0), 0.255, P.steel, METAL)
	for _, side in { -1, 1 } do
		rivet(s, 0, y + 0.04, side * 0.14)
		box(s, "ChippedPaint", V(0.15, 0.025, 0.012), V(0.34, y + 0.08, side * 0.107), P.rust, METAL, A(0, 0, -0.24))
		box(s, "SteelScratch", V(0.12, 0.013, 0.014), V(0.43, y - 0.12, side * 0.107), P.bright, METAL, A(0, 0, 0.5))
	end
end

BUILDERS.IronPickaxe = function(s, length)
	if not s.texturedHandle then handle(s, length, false) end
	local y = length - 0.07
	profile(s, "LeftForgedPick", { { 0, y + 0.12 }, { -0.5, y + 0.06 },
		{ -0.97, y - 0.24 }, { -0.53, y - 0.07 }, { 0, y - 0.04 } }, 0.14, 0, P.steel, METAL)
	profile(s, "RightForgedPick", { { 0, y + 0.12 }, { 0.52, y + 0.06 },
		{ 0.97, y - 0.18 }, { 0.53, y - 0.06 }, { 0, y - 0.04 } }, 0.14, 0, P.steel, METAL)
	profile(s, "WornPickTip", { { -0.97, y - 0.24 }, { -0.74, y - 0.1 }, { -0.68, y - 0.16 } }, 0.145, 0, P.bright, METAL)
	profile(s, "MattockEdge", { { 0.7, y - 0.05 }, { 0.99, y - 0.3 }, { 0.76, y - 0.22 } }, 0.21, 0, P.bright, METAL)
	rod(s, "ForgedEye", V(0, y - 0.16, 0), V(0, y + 0.2, 0), 0.3, P.steel, METAL)
	rivet(s, 0, y, 0.16)
	box(s, "Oxidation", V(0.25, 0.03, 0.012), V(0.33, y + 0.025, 0.077), P.rust, METAL, A(0, 0, -0.15))
end

BUILDERS.WoodenClub = function(s, length)
	if not s.texturedHandle then handle(s, length, true) end
	local taper = { { 0.4, 0.2 }, { 0.48, 0.23 }, { 0.56, 0.26 }, { 0.64, 0.29 }, { 0.72, 0.32 },
		{ 0.8, 0.34 }, { 0.88, 0.36 }, { 1.0, 0.37 } }
	for i = 1, #taper - 1 do
		local a, b = taper[i], taper[i + 1]
		rod(s, "TaperedClub", V(0, length * a[1], 0), V(0, length * b[1], 0), (a[2] + b[2]) / 2,
			if i % 2 == 0 then P.wood else P.woodLight, WOOD)
	end
	add(s, "RoundedClubEnd", V(0.37, 0.18, 0.37), C(0, length * 1.0, 0), P.wood, WOOD, Enum.PartType.Ball)
	for i = 1, 4 do
		local angle = i * math.pi / 2 + 0.4
		local x, z = math.cos(angle) * 0.17, math.sin(angle) * 0.17
		rod(s, "WoodGrain", V(x * 0.8, length * 0.6, z * 0.8), V(x, length * 0.95, z), 0.02, P.grain, WOOD)
	end
	box(s, "BranchKnot", V(0.07, 0.12, 0.1), V(0.17, length * 0.78, 0), P.grain, WOOD, A(0, 0, -0.2))
	box(s, "DentedEdge", V(0.06, 0.2, 0.08), V(-0.17, length * 0.9, 0.04), P.grain, WOOD, A(0, 0, 0.15))
end

BUILDERS.StoneSpear = function(s, length)
	handle(s, length, true)
	local y = length - 0.08
	profile(s, "SpearCuttingEdges", { { 0, y + 0.71 }, { 0.22, y + 0.2 }, { 0.13, y - 0.08 },
		{ -0.13, y - 0.08 }, { -0.22, y + 0.2 } }, 0.085, 0, P.edge, STONE)
	profile(s, "FlintSpearRidge", { { 0, y + 0.63 }, { 0.14, y + 0.19 }, { 0.08, y - 0.04 },
		{ -0.08, y - 0.04 }, { -0.14, y + 0.19 } }, 0.145, 0, P.stone, STONE)
	wrap(s, y - 0.22, 6, 0.21, P.rope)
	rod(s, "BindingTail", V(0.09, y - 0.25, 0.06), V(0.13, y - 0.42, 0.08), 0.03, P.rope, CLOTH)
	wrap(s, length * 0.48, 5, 0.23, P.rope)
end

-- The bow in grip space: the hand on the grip at the origin, the limbs bending back toward the archer
-- (+Z) so the string runs behind the grip, and an arrow nocked on the string pointing at -Z.
-- HeldItems.poseBow draws the two string halves, the arrow and the drawing hand from the draw amount.
local BOW_TIP = 1.7
local BOW_STRING_Z = 0.48
EquipmentModels.BowTip = BOW_TIP
EquipmentModels.BowStringZ = BOW_STRING_Z

BUILDERS.PrimitiveBow = function(s, _length)
	local points = { V(0, -BOW_TIP, BOW_STRING_Z), V(0, -1.42, 0.41), V(0, -1.04, 0.19),
		V(0, -0.55, 0.03), V(0, 0, 0), V(0, 0.55, 0.03), V(0, 1.04, 0.19),
		V(0, 1.42, 0.41), V(0, BOW_TIP, BOW_STRING_Z) }
	for i = 1, #points - 1 do
		local diameter = if i == 1 or i == #points - 1 then 0.09 else 0.14
		rod(s, "CarvedBowLimb", points[i], points[i + 1], diameter, if i % 2 == 0 then P.wood else P.woodLight, WOOD)
	end
	rod(s, "BowGrip", V(0, -0.26, 0), V(0, 0.26, 0), 0.2, P.grain, WOOD)
	for i = -3, 3 do
		rod(s, "LeatherBowWrap", V(0, i * 0.06 - 0.022, 0), V(0, i * 0.06 + 0.022, 0), 0.215, P.tape, CLOTH)
	end
	local nock = V(0, 0, BOW_STRING_Z)
	rod(s, "BowstringUpper", points[#points], nock, 0.026, P.rope, CLOTH)
	rod(s, "BowstringLower", points[1], nock, 0.026, P.rope, CLOTH)
	for _, y in { -1.64, 1.64 } do
		rod(s, "TipBinding", V(0, y - 0.035, BOW_STRING_Z - 0.015), V(0, y + 0.035, BOW_STRING_Z - 0.015), 0.125, P.rope, CLOTH)
	end
	-- The nocked arrow, offsets kept relative to the nock (it rests on the left of the grip).
	local function arrowPart(part: BasePart)
		local offset = CFrame.new(nock):Inverse() * s.root.CFrame:ToObjectSpace(part.CFrame)
		part:SetAttribute("NockOffset", offset)
		part.Name = "NockedArrow"
	end
	arrowPart(rod(s, "Shaft", nock + V(-0.07, 0, 0), nock + V(-0.07, 0, -2.2), 0.05, P.woodLight, WOOD))
	arrowPart(add(s, "Head", V(0.04, 0.12, 0.26), C(nock + V(-0.07, 0, -2.3)) * A(math.pi / 2, 0, 0), P.flint, STONE, nil, true))
	for _, angle in { 0, math.pi / 2 } do
		arrowPart(box(s, "Fletch", V(0.012, 0.12, 0.3), nock + V(-0.07, 0, -0.22), P.red, CLOTH, A(0, 0, angle)))
	end
end

-- Firearms use native grip space: -Z muzzle, +Z stock, +Y sights. Separate silhouettes are deliberate.
local function pipe(s: Shop, z: number, length: number, diameter: number)
	rod(s, "PipeBarrel", V(0, 0.38, z - length / 2), V(0, 0.38, z + length / 2), diameter, P.steel, METAL)
	local muzzle = z - length / 2
	rod(s, "MuzzleRim", V(0, 0.38, muzzle - 0.035), V(0, 0.38, muzzle + 0.045), diameter + 0.055, P.rust, METAL)
	rod(s, "DarkMuzzleBore", V(0, 0.38, muzzle - 0.041), V(0, 0.38, muzzle - 0.036), diameter * 0.68, P.dark, METAL)
	for i = 1, 3 do
		rod(s, "PipeThread", V(0, 0.38, muzzle + 0.07 + i * 0.035), V(0, 0.38, muzzle + 0.086 + i * 0.035),
			diameter + 0.025, P.bright, METAL)
	end
	box(s, "FrontSight", V(0.055, 0.12, 0.08), V(0, 0.38 + diameter / 2 + 0.04, muzzle + 0.19), P.dark, METAL)
end

local function gunGrip(s: Shop)
	box(s, "WoodGrip", V(0.25, 0.64, 0.31), V(0, -0.12, 0.02), P.wood, WOOD, A(-0.2, 0, 0))
	for i = 1, 4 do
		box(s, "GripTape", V(0.27, 0.07, 0.33), V(0, -0.29 + i * 0.105, 0.055 - i * 0.021), P.tape, CLOTH, A(-0.2, 0, 0))
	end
	for _, x in { -0.132, 0.132 } do
		rod(s, "GripScrew", V(x - 0.012, -0.29, 0.07), V(x + 0.012, -0.29, 0.07), 0.06, P.bright, METAL)
	end
	rod(s, "TriggerGuardFront", V(0, -0.07, -0.43), V(0, 0.2, -0.43), 0.055, P.dark, METAL)
	rod(s, "TriggerGuardBase", V(0, -0.07, -0.43), V(0, -0.07, -0.16), 0.055, P.dark, METAL)
	rod(s, "Trigger", V(0, 0.18, -0.25), V(0, 0.02, -0.3), 0.047, P.bright, METAL)
end

local function receiver(s: Shop, length: number)
	box(s, "WeldedReceiver", V(0.31, 0.27, length), V(0, 0.27, -0.16), P.steel, METAL)
	box(s, "ReceiverTop", V(0.28, 0.035, length * 0.86), V(0, 0.425, -0.16), P.bright, METAL)
	for _, x in { -0.165, 0.165 } do
		for _, z in { -0.37, 0.04 } do
			rod(s, "ReceiverBolt", V(x - 0.015, 0.28, z), V(x + 0.015, 0.28, z), 0.065, P.bright, METAL)
		end
		box(s, "RustPatch", V(0.012, 0.07, 0.2), V(x, 0.21, -0.18), P.rust, METAL)
	end
	box(s, "RearSight", V(0.22, 0.075, 0.07), V(0, 0.49, 0.13), P.dark, METAL)
end

local function stock(s: Shop, length: number)
	box(s, "StockWrist", V(0.2, 0.23, 0.43), V(0, 0.15, 0.43), P.wood, WOOD, A(0.15, 0, 0))
	box(s, "SalvagedWoodStock", V(0.27, 0.42, length), V(0, 0.03, 0.61 + length / 2), P.wood, WOOD, A(0.05, 0, 0))
	box(s, "StockButtplate", V(0.3, 0.48, 0.065), V(0, 0.02, 0.62 + length), P.dark, METAL)
	box(s, "StockGrain", V(0.012, 0.025, length * 0.75), V(0.142, 0.06, 0.63 + length / 2), P.grain, WOOD, A(0.05, 0, 0))
	for i = 1, 2 do
		box(s, "StockBinding", V(0.29, 0.46, 0.055), V(0, 0.035, 0.73 + i * 0.12), P.tape, CLOTH)
	end
end

BUILDERS.PipePistol = function(s, _length)
	gunGrip(s)
	receiver(s, 0.67)
	pipe(s, -0.74, 0.92, 0.15)
	rod(s, "RevolverCylinder", V(0, 0.32, -0.47), V(0, 0.32, -0.05), 0.43, P.steel, METAL)
	for i = 0, 5 do
		local angle = i * math.pi / 3
		local x, y = math.cos(angle) * 0.16, 0.32 + math.sin(angle) * 0.16
		rod(s, "CylinderFlute", V(x, y, -0.44), V(x, y, -0.08), 0.058, P.dark, METAL)
	end
	box(s, "Hammer", V(0.1, 0.18, 0.12), V(0, 0.5, 0.19), P.dark, METAL, A(-0.28, 0, 0))
end

BUILDERS.PipeRifle = function(s, _length)
	gunGrip(s)
	receiver(s, 0.85)
	pipe(s, -1.32, 1.75, 0.14)
	stock(s, 0.87)
	box(s, "WoodForearm", V(0.26, 0.23, 0.86), V(0, 0.24, -0.96), P.wood, WOOD)
	for _, z in { -0.73, -1.22 } do
		rod(s, "BarrelBand", V(0, 0.34, z - 0.035), V(0, 0.34, z + 0.035), 0.31, P.dark, METAL)
	end
	rod(s, "BoltStem", V(0.17, 0.36, 0.04), V(0.38, 0.33, 0.04), 0.07, P.bright, METAL)
	add(s, "BoltKnob", V(0.13, 0.13, 0.13), C(0.39, 0.33, 0.04), P.dark, METAL, Enum.PartType.Ball)
end

BUILDERS.PipeShotgun = function(s, _length)
	gunGrip(s)
	receiver(s, 0.78)
	pipe(s, -1.02, 1.45, 0.27)
	stock(s, 0.62)
	box(s, "BroadWoodForearm", V(0.34, 0.28, 0.61), V(0, 0.19, -0.92), P.woodLight, WOOD)
	for i = 1, 4 do
		box(s, "ForearmGroove", V(0.35, 0.025, 0.035), V(0, 0.332, -0.65 - i * 0.11), P.grain, WOOD)
	end
	rod(s, "BreakActionHinge", V(-0.22, 0.17, -0.48), V(0.22, 0.17, -0.48), 0.14, P.bright, METAL)
	box(s, "BreechLatch", V(0.14, 0.075, 0.24), V(0, 0.48, -0.3), P.rust, METAL)
end

BUILDERS.PipeMachineGun = function(s, _length)
	gunGrip(s)
	receiver(s, 1.06)
	pipe(s, -1.15, 1.25, 0.16)
	stock(s, 0.57)
	rod(s, "HeatShroud", V(0, 0.38, -1.35), V(0, 0.38, -0.67), 0.3, P.dark, METAL)
	for i = 1, 5 do
		for _, x in { -0.151, 0.151 } do
			box(s, "ShroudVent", V(0.012, 0.075, 0.073), V(x, 0.38, -0.66 - i * 0.11), P.steel, METAL)
		end
	end
	box(s, "BoxMagazine", V(0.23, 0.64, 0.31), V(0, -0.17, -0.56), P.steel, METAL, A(0.12, 0, 0))
	box(s, "MagazineFloorplate", V(0.27, 0.055, 0.35), V(0, -0.49, -0.6), P.dark, METAL)
	for _, x in { -0.122, 0.122 } do
		box(s, "MagazineRib", V(0.018, 0.43, 0.045), V(x, -0.16, -0.56), P.bright, METAL, A(0.12, 0, 0))
	end
	rod(s, "ChargingHandle", V(-0.15, 0.38, -0.11), V(-0.34, 0.38, -0.11), 0.08, P.bright, METAL)
	box(s, "EjectionPort", V(0.015, 0.12, 0.23), V(0.165, 0.3, -0.22), P.dark, METAL)
end

-- The root is at the previous tool-handle centre, preserving all existing grip and swing poses.
function EquipmentModels.build(id: string, model: Model, root: BasePart, length: number, native: boolean): boolean
	local meshBuilt, hybrid = EquipmentMeshes.build(id, model, root, length)
	if meshBuilt and not hybrid then return true end
	local builder = BUILDERS[id]
	if builder == nil then return false end
	local basis = if native then IDENTITY else BASIS * C(0, -length / 2, 0)
	builder({ model = model, root = root, basis = basis, texturedHandle = meshBuilt }, length)
	model:SetAttribute("VisualRevision", if meshBuilt then 3 else 2)
	model:SetAttribute("ItemId", id)
	return true
end

return EquipmentModels
