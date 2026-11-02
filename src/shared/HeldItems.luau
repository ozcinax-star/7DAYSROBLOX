--!strict
-- Shared third-person and first-person equipment factory. Geometry lives in EquipmentModels;
-- the grip contract stays here so InventoryService and ViewmodelController use the same model.
-- Every part is cosmetic, massless and welded; gameplay never raycasts against held equipment.

local CollectionService = game:GetService("CollectionService")
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

-- Adds a torch's light and fire to `head` (placed torches and held ones share it). `share` scales the
-- light's range.
function HeldItems.addFlame(head: BasePart, share: number)
	local def = Config.Build.Torch
	local light = Instance.new("PointLight")
	light.Range = def.Range * share
	light:SetAttribute("BaseRange", light.Range)
	light.Brightness = def.Brightness
	light.Color = Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3])
	light.Shadows = true
	light.Parent = head
	-- Clients make tagged torch lights flicker (DayNightController).
	CollectionService:AddTag(light, def.Tag)
	local fire = Instance.new("Fire")
	fire.Size = 1.6
	fire.Heat = 4
	fire.Color = Color3.fromRGB(255, 140, 50)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 120)
	fire.Parent = head
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
	elseif id == "Torch" then
		-- A wooden stick with a burning head; its light goes wherever the hand goes.
		local stick = part(model, "Stick", V(0.16, 1.6, 0.16), Color3.fromRGB(89, 61, 38))
		stick.Material = Enum.Material.Wood
		weld(hand, stick, fist * CFrame.Angles(math.rad(-15), 0, 0) * CFrame.new(0, 0.45, 0))
		local head = part(model, "Flame", V(0.32, 0.36, 0.32), Color3.fromRGB(255, 150, 60))
		head.Material = Enum.Material.Neon
		weld(stick, head, CFrame.new(0, 0.95, 0))
		HeldItems.addFlame(head, Config.Build.Torch.HeldShare)
		model.PrimaryPart = stick
	else
		local def = Config.Items[id]
		local c = if def then def.Color else { 0.5, 0.5, 0.5 }
		local block = part(model, "Block", V(0.6, 0.6, 0.6), Color3.new(c[1], c[2], c[3]))
		weld(hand, block, fist * CFrame.new(0, -0.3, 0))
		model.PrimaryPart = block
	end
	local handling = Config.WeaponHandling.Items[id]
	if handling and model.PrimaryPart then
		-- An open rear notch and a narrow front post sit on the measured sight line.
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
		sight("FrontSight", V(0.024, 0.12, 0.045), V(0, line.Y - 0.06, handling.Muzzle[3] + 0.12))
	end
	if model.PrimaryPart then
		local root = model.PrimaryPart
		local points = if handling then { SupportGrip = handling.Support, Sight = handling.Sight, Muzzle = handling.Muzzle }
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

return HeldItems
