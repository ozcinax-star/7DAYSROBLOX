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
	WoodenClub = 2.3,
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
	local handling = Config.WeaponHandling.Items[id]
	if handling and model.PrimaryPart and not handling.MeshSights then
		-- An open rear notch on the receiver and a front post down to the barrel, on the measured line.
		local root = model.PrimaryPart
		local function sight(name: string, size: Vector3, at: Vector3)
			local p = part(model, name, size, Color3.fromRGB(47, 48, 43))
			p.Material = Enum.Material.Metal
			weld(root, p, root.CFrame:ToObjectSpace(hand.CFrame * fist * CFrame.new(at)))
		end
		local line = V(handling.Sight[1], handling.Sight[2], handling.Sight[3])
		for _, side in { -1, 1 } do
			sight("RearSight", V(0.035, 0.16, 0.075), line + V(side * 0.065, -0.08, 0))
		end
		local post = line.Y - (handling.FrontBase or line.Y - 0.12) + 0.02
		sight("FrontSight", V(0.024, post, 0.045), V(0, line.Y - post / 2, handling.Muzzle[3] + 0.12))
	end
	if model.PrimaryPart then
		local root = model.PrimaryPart
		local points = if handling then { SupportGrip = handling.Support, Sight = handling.Sight, Muzzle = handling.Muzzle }
			elseif id == "PrimitiveBow" then { SupportGrip = { 0, 0, EquipmentModels.BowStringZ } }
			else { SupportGrip = { 0, 0.38, -(length or 1) * 0.55 } }
		for name, point in points do
			local attachment = Instance.new("Attachment")
			attachment.Name = name
			attachment.CFrame = root.CFrame:ToObjectSpace(hand.CFrame * fist * CFrame.new(point[1], point[2], point[3]))
			attachment.Parent = root
		end
	end
	return model
end

-- Bow draw pulls the nock this far behind the grip at full draw (studs; about the archer's anchor).
local BOW_DRAW_Z = 1.45

-- Poses a built bow: the string halves meet at the nock, `draw` (0 rest .. 1 full) pulls the nock
-- back, the arrow rides on it while `nocked`, and the SupportGrip (the drawing hand) follows it.
-- Welded parts (a character's bow) get new weld offsets; loose ones (the viewmodel) new CFrames.
function HeldItems.poseBow(model: Model, draw: number, nocked: boolean)
	local root = model.PrimaryPart
	if root == nil then
		return
	end
	local restZ = EquipmentModels.BowStringZ
	local nock = V(0, 0, restZ + (BOW_DRAW_Z - restZ) * math.clamp(draw, 0, 1))
	local function place(part: BasePart, offset: CFrame)
		local weld = part:FindFirstChildOfClass("Weld")
		if weld and weld.Part0 == root then
			weld.C0 = offset
		else
			part.CFrame = root.CFrame * offset
		end
	end
	for _, child in model:GetChildren() do
		if not child:IsA("BasePart") then
			continue
		end
		local tip = if child.Name == "BowstringUpper" then 1 elseif child.Name == "BowstringLower" then -1 else 0
		if tip ~= 0 then
			local a = V(0, tip * EquipmentModels.BowTip, restZ)
			child.Size = V((nock - a).Magnitude, child.Size.Y, child.Size.Z)
			place(child, CFrame.lookAt((a + nock) / 2, nock, Vector3.xAxis) * CFrame.Angles(0, math.pi / 2, 0))
		elseif child.Name == "NockedArrow" then
			local offset = child:GetAttribute("NockOffset")
			if typeof(offset) == "CFrame" then
				place(child, CFrame.new(nock) * offset)
			end
			child.Transparency = if nocked then 0 else 1
		end
	end
	local hand = root:FindFirstChild("SupportGrip")
	if hand and hand:IsA("Attachment") then
		hand.Position = nock
	end
end

return HeldItems
