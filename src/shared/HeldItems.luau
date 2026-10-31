--!strict
-- Shared third-person and first-person equipment factory. Geometry lives in EquipmentModels;
-- the grip contract stays here so InventoryService and ViewmodelController use the same model.
-- Every part is cosmetic, massless and welded; gameplay never raycasts against held equipment.

local Config = require("./Config")
local EquipmentModels = require("./EquipmentModels")

local HeldItems = {}
local V = Vector3.new
local HOLD_TILT = math.rad(30)
local GRIP_SHARE = 0.2
HeldItems.HoldTilt = HOLD_TILT

-- Visual dimensions, not melee reach. Retained from the original handles for animation compatibility.
local LENGTHS: { [string]: number } = {
	StoneAxe = 2.2,
	StonePickaxe = 2.2,
	StoneShovel = 2.6,
	IronFireaxe = 2.4,
	IronPickaxe = 2.4,
	IronShovel = 2.8,
	WoodenClub = 1.8,
	StoneSpear = 4.2,
}

local function part(model: Model, name: string, size: Vector3, color: Color3): BasePart
	local p = Instance.new("Part")
	p.Name, p.Size, p.Color = name, size, color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.Massless, p.CastShadow = true, false
	p.Parent = model
	return p
end

local function weld(part0: BasePart, part1: BasePart, c0: CFrame)
	part1.CFrame = part0.CFrame * c0
	local w = Instance.new("Weld")
	w.Part0, w.Part1, w.C0 = part0, part1, c0
	w.Parent = part1
end

-- The caller owns and parents the model. Attachment rotation is deliberately ignored: R6, R15 and
-- the viewmodel have different attachment orientations; their positions share this grip convention.
function HeldItems.build(id: string, hand: BasePart, grip: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "HeldItem"
	local fist = CFrame.new(grip.Position)
	local length = LENGTHS[id]
	local weapon = Config.Ranged.Weapons[id]
	if length or weapon then
		local root = part(model, if length then "Handle" else "Grip", V(0.1, 0.1, 0.1), Color3.new())
		root.Transparency = 1
		local offset = if length
			then fist * CFrame.Angles(HOLD_TILT, 0, 0) * CFrame.new(0, 0, -length * (0.5 - GRIP_SHARE))
			else fist
		weld(hand, root, offset)
		local built = EquipmentModels.build(id, model, root, length or 0, weapon ~= nil)
		assert(built, "Missing equipment visual: " .. id)
		model.PrimaryPart = root
	else
		local def = Config.Items[id]
		local c = if def then def.Color else { 0.5, 0.5, 0.5 }
		local block = part(model, "Block", V(0.6, 0.6, 0.6), Color3.new(c[1], c[2], c[3]))
		weld(hand, block, fist * CFrame.new(0, -0.3, 0))
		model.PrimaryPart = block
	end
	return model
end

return HeldItems
