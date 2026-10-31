--!strict
-- Low-poly props built from parts: vegetation, vehicles, street furniture and point-of-interest
-- dressing. Each builder receives a base CFrame on the ground (y = ground height) and a scale value.

local Palette = require(script.Parent.Palette)
local PartFactory = require(script.Parent.PartFactory)

local PropKit = {}

local S = Palette.Styles
local CYLINDER = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
-- Cylinders extend along their local X axis; this turns them upright.
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)
-- Tree canopies: no collision, and swings and aim pass through them to the trunk.
local FOLIAGE: PartFactory.Options = { canCollide = false, canQuery = false }
-- Undergrowth: walked through and never blocks navigation, but swings hit it.
local UNDERGROWTH: PartFactory.Options = { canCollide = false, castShadow = false }
-- Tall grass blade heights and how far they lean out from the clump's centre.
local GRASS_BLADES = { 2.6, 2.1, 1.8 }
local GRASS_LEAN = math.rad(18)
-- Rusty veins on an iron ore boulder: size, centre (both times the scale) and tilt (radians), each
-- sunk into one face of the boulder so only a strip shows.
local IRON_VEINS = {
	{ size = Vector3.new(4.5, 0.5, 1), at = Vector3.new(-0.5, 1.4, -2.7), tilt = Vector3.new(0, 0, 0.35) },
	{ size = Vector3.new(1, 0.6, 3.5), at = Vector3.new(3.3, 0.8, -0.6), tilt = Vector3.new(0.4, 0, 0) },
	{ size = Vector3.new(3, 0.5, 1), at = Vector3.new(-1.8, 2.2, 2.7), tilt = Vector3.new(0, 0, -0.3) },
	{ size = Vector3.new(1.2, 0.5, 2.4), at = Vector3.new(2.4, 3.9, 1.2), tilt = Vector3.new(0.3, 0.6, 0.2) },
}

type Builder = (model: Model, base: CFrame, scale: number, key: string) -> ()

local function part(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	style: Palette.Style,
	options: PartFactory.Options?
): BasePart
	return PartFactory.make(model, name, size, cframe, style, options)
end

-- Box resting on the base at local offset (x, y = bottom, z).
local function block(model: Model, base: CFrame, name: string, size: Vector3, x: number, y: number, z: number, style)
	return part(model, name, size, base * CFrame.new(x, y + size.Y / 2, z), style)
end

local function car(model: Model, base: CFrame, paint: Palette.Style)
	block(model, base, "Body", Vector3.new(6, 2.2, 12), 0, 1, 0, paint)
	block(model, base, "Cabin", Vector3.new(5.6, 2, 6), 0, 3.2, 0.6, paint)
	block(model, base, "Windows", Vector3.new(5.7, 1.4, 5.4), 0, 3.4, 0.6, S.Glass)
	for _, wheel in { { -3, -4 }, { 3, -4 }, { -3, 4 }, { 3, 4 } } do
		part(model, "Wheel", Vector3.new(0.8, 2.2, 2.2), base * CFrame.new(wheel[1], 1.1, wheel[2]), S.Tire, {
			shape = CYLINDER,
		})
	end
end

local Builders: { [string]: Builder } = {
	Pine = function(model, base, scale)
		local height = 14 * scale
		part(
			model,
			"Trunk",
			Vector3.new(height, 1.6 * scale, 1.6 * scale),
			base * CFrame.new(0, height / 2, 0) * UPRIGHT,
			S.Bark,
			{ shape = CYLINDER }
		)
		-- Three stacked, turned blocks read as a stylized conifer.
		for tier = 1, 3 do
			local size = (10 - tier * 2.4) * scale
			part(
				model,
				"Leaves",
				Vector3.new(size, 4 * scale, size),
				base * CFrame.new(0, height * 0.35 + tier * 3.6 * scale, 0) * CFrame.Angles(0, math.rad(tier * 30), 0),
				S.PineLeaves,
				FOLIAGE
			)
		end
	end,
	Oak = function(model, base, scale)
		local height = 10 * scale
		part(
			model,
			"Trunk",
			Vector3.new(height, 2 * scale, 2 * scale),
			base * CFrame.new(0, height / 2, 0) * UPRIGHT,
			S.Bark,
			{ shape = CYLINDER }
		)
		part(model, "Crown", Vector3.one * 11 * scale, base * CFrame.new(0, height + 2 * scale, 0), S.OakLeaves, {
			shape = BALL,
			canCollide = false,
			canQuery = false,
		})
		part(
			model,
			"Crown",
			Vector3.one * 7 * scale,
			base * CFrame.new(2.5 * scale, height + 5 * scale, 1.5 * scale),
			S.OakLeaves,
			{ shape = BALL, canCollide = false, canQuery = false }
		)
	end,
	Bush = function(model, base, scale)
		part(model, "Bush", Vector3.new(5, 3.4, 5) * scale, base * CFrame.new(0, 1.2 * scale, 0), S.Bush, {
			shape = BALL,
			canCollide = false,
		})
	end,
	Rock = function(model, base, scale)
		block(model, base, "Rock", Vector3.new(7, 4, 6) * scale, 0, -0.5, 0, S.Rock)
		part(
			model,
			"Rock",
			Vector3.new(4, 3, 4) * scale,
			base * CFrame.new(2 * scale, 2.5 * scale, 1 * scale) * CFrame.Angles(0.3, 0.6, 0.2),
			S.Rock
		)
	end,
	-- The boulder's shape in iron ore colours, with rusty veins set into its faces.
	IronRock = function(model, base, scale)
		block(model, base, "Rock", Vector3.new(7, 4, 6) * scale, 0, -0.5, 0, S.IronOre)
		part(
			model,
			"Rock",
			Vector3.new(4, 3, 4) * scale,
			base * CFrame.new(2 * scale, 2.5 * scale, 1 * scale) * CFrame.Angles(0.3, 0.6, 0.2),
			S.IronOre
		)
		for _, vein in IRON_VEINS do
			local tilt = CFrame.Angles(vein.tilt.X, vein.tilt.Y, vein.tilt.Z)
			part(model, "Vein", vein.size * scale, base * CFrame.new(vein.at * scale) * tilt, S.OreVein)
		end
	end,
	-- Three wedge blades fanned out and leaning outward, waist high so a swing from the head reaches
	-- them.
	TallGrass = function(model, base, scale)
		for i, height in GRASS_BLADES do
			local size = Vector3.new(0.12, height, 1.3) * scale
			part(
				model,
				"Blade",
				size,
				base
					* CFrame.Angles(0, i * math.pi * 2 / #GRASS_BLADES, 0)
					* CFrame.new(0, 0, -0.3 * scale)
					* CFrame.Angles(-GRASS_LEAN, 0, 0)
					* CFrame.new(0, size.Y / 2, 0),
				S.TallGrass,
				{ className = "WedgePart", canCollide = false, castShadow = false }
			)
		end
	end,
	LooseRock = function(model, base, scale)
		part(
			model,
			"Stone",
			Vector3.new(1.5, 0.9, 1.2) * scale,
			base * CFrame.new(0, 0.45 * scale, 0) * CFrame.Angles(0.2, 0, 0.15),
			S.LooseRock,
			UNDERGROWTH
		)
	end,
	FallenLog = function(model, base, scale)
		part(model, "Log", Vector3.new(14 * scale, 2.2, 2.2), base * CFrame.new(0, 1, 0), S.Bark, { shape = CYLINDER })
	end,
	Car = function(model, base, _scale, key)
		car(model, base, PartFactory.pick(Palette.CarPaints, key))
	end,
	Truck = function(model, base)
		block(model, base, "Chassis", Vector3.new(7, 2.4, 20), 0, 1, 0, S.Rust)
		block(model, base, "Cab", Vector3.new(7, 4, 6), 0, 3.4, -6.5, S.CarPaint)
		block(model, base, "Bed", Vector3.new(7, 1.4, 12), 0, 3.4, 3.5, S.Rust)
		for i = 1, 3 do
			part(
				model,
				"Log",
				Vector3.new(12, 1.8, 1.8),
				base * CFrame.new(-2.2 + i * 1.1, 5.7, 3.5) * CFrame.Angles(0, math.pi / 2, 0),
				S.Bark,
				{ shape = CYLINDER }
			)
		end
	end,
	Tractor = function(model, base)
		block(model, base, "Body", Vector3.new(4, 3, 8), 0, 2, 0, S.Red)
		block(model, base, "Cab", Vector3.new(4, 3.4, 3.4), 0, 5, 1.8, S.Glass)
		part(model, "BigWheel", Vector3.new(1.4, 6, 6), base * CFrame.new(-2.6, 3, 2), S.Tire, { shape = CYLINDER })
		part(model, "BigWheel", Vector3.new(1.4, 6, 6), base * CFrame.new(2.6, 3, 2), S.Tire, { shape = CYLINDER })
		part(model, "Wheel", Vector3.new(1, 3, 3), base * CFrame.new(-2.4, 1.5, -3), S.Tire, { shape = CYLINDER })
		part(model, "Wheel", Vector3.new(1, 3, 3), base * CFrame.new(2.4, 1.5, -3), S.Tire, { shape = CYLINDER })
	end,
	GasCanopy = function(model, base)
		for _, p in { { -14, -8 }, { 14, -8 }, { -14, 8 }, { 14, 8 } } do
			block(model, base, "Pillar", Vector3.new(1.4, 14, 1.4), p[1], 0, p[2], S.Concrete)
		end
		block(model, base, "Canopy", Vector3.new(34, 1.6, 22), 0, 14, 0, S.Trim)
		block(model, base, "Stripe", Vector3.new(34.2, 0.6, 22.2), 0, 14.5, 0, S.Red)
	end,
	GasPump = function(model, base)
		block(model, base, "Island", Vector3.new(4, 0.6, 8), 0, 0, 0, S.Concrete)
		block(model, base, "Pump", Vector3.new(2, 5, 1.6), 0, 0.6, 0, S.Red)
		block(model, base, "Display", Vector3.new(1.6, 1.2, 1.7), 0, 4, 0, S.Lamp)
	end,
	Barricade = function(model, base)
		block(model, base, "Barrier", Vector3.new(10, 3, 1.4), 0, 0, 0, S.Concrete)
		block(model, base, "Stripe", Vector3.new(10.1, 0.6, 1.5), 0, 2, 0, S.Hazard)
	end,
	Bench = function(model, base)
		block(model, base, "Seat", Vector3.new(6, 0.5, 2), 0, 1.6, 0, S.Wood)
		block(model, base, "Back", Vector3.new(6, 2, 0.4), 0, 2.1, 0.8, S.Wood)
		block(model, base, "Leg", Vector3.new(0.4, 1.6, 1.6), -2.5, 0, 0, S.Steel)
		block(model, base, "Leg", Vector3.new(0.4, 1.6, 1.6), 2.5, 0, 0, S.Steel)
	end,
	Fountain = function(model, base)
		part(model, "Basin", Vector3.new(2, 14, 14), base * CFrame.new(0, 1, 0) * UPRIGHT, S.Stone, { shape = CYLINDER })
		part(model, "Water", Vector3.new(0.4, 12, 12), base * CFrame.new(0, 2, 0) * UPRIGHT, S.Water, {
			shape = CYLINDER,
			canCollide = false,
		})
		block(model, base, "Column", Vector3.new(2, 6, 2), 0, 0, 0, S.Stone)
	end,
	LogPile = function(model, base)
		local layers = { 4, 3, 2 }
		for layer, count in layers do
			for i = 1, count do
				local offset = (i - (count + 1) / 2) * 2.4
				part(
					model,
					"Log",
					Vector3.new(16, 2.4, 2.4),
					base * CFrame.new(0, 1.2 + (layer - 1) * 2.1, offset),
					S.Bark,
					{ shape = CYLINDER }
				)
			end
		end
	end,
	StonePile = function(model, base)
		for i = 1, 5 do
			local angle = i * 1.3
			part(
				model,
				"Stone",
				Vector3.new(5, 4, 5),
				base * CFrame.new(math.cos(angle) * 4, 1.5 + (i % 2) * 2, math.sin(angle) * 4) * CFrame.Angles(
					angle,
					angle * 2,
					0
				),
				S.Stone
			)
		end
	end,
	Crane = function(model, base)
		block(model, base, "Base", Vector3.new(6, 2, 6), 0, 0, 0, S.Hazard)
		block(model, base, "Mast", Vector3.new(2, 30, 2), 0, 2, 0, S.Hazard)
		block(model, base, "Jib", Vector3.new(2, 2, 32), 0, 32, -10, S.Hazard)
		block(model, base, "Cable", Vector3.new(0.3, 18, 0.3), 0, 14, -24, S.Steel)
		block(model, base, "Hook", Vector3.new(4, 3, 4), 0, 11, -24, S.Stone)
	end,
	ScrapStack = function(model, base, _scale, key)
		for level = 1, 3 do
			block(
				model,
				base,
				"CrushedCar",
				Vector3.new(6, 2.6, 11),
				0,
				(level - 1) * 2.6,
				0,
				PartFactory.pick(Palette.CarPaints, key .. level)
			)
		end
	end,
	JunkFence = function(model, base, scale)
		-- Square fence ring of corrugated panels with a gate gap on the -Z side.
		local half = scale / 2
		local panel = 12
		for side = 0, 3 do
			local turn = CFrame.Angles(0, side * math.pi / 2, 0)
			local count = math.floor(scale / panel)
			for i = 0, count - 1 do
				local along = -half + (i + 0.5) * panel
				local isGate = side == 0 and math.abs(along) < panel
				if not isGate then
					block(model, base * turn, "Fence", Vector3.new(panel, 8, 0.6), along, 0, -half, S.MetalRoof)
				end
			end
		end
	end,
	Tent = function(model, base)
		local size = Vector3.new(8, 5, 4)
		part(model, "TentSide", size, base * CFrame.new(0, 2.5, -2), S.Canvas, { className = "WedgePart" })
		part(model, "TentSide", size, base * CFrame.new(0, 2.5, 2) * CFrame.Angles(0, math.pi, 0), S.Canvas, {
			className = "WedgePart",
		})
	end,
	Campfire = function(model, base)
		for i = 1, 6 do
			local angle = i * math.pi / 3
			block(model, base, "Stone", Vector3.new(1.2, 1, 1.2), math.cos(angle) * 2.4, 0, math.sin(angle) * 2.4, S.Stone)
		end
		part(model, "Log", Vector3.new(4, 0.8, 0.8), base * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0.6, 0), S.Bark, {
			shape = CYLINDER,
		})
		part(model, "Log", Vector3.new(4, 0.8, 0.8), base * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, -0.6, 0), S.Bark, {
			shape = CYLINDER,
		})
	end,
	PicnicTable = function(model, base)
		block(model, base, "Top", Vector3.new(8, 0.5, 3), 0, 2.6, 0, S.Wood)
		block(model, base, "Bench", Vector3.new(8, 0.5, 1.2), 0, 1.5, -2.4, S.Wood)
		block(model, base, "Bench", Vector3.new(8, 0.5, 1.2), 0, 1.5, 2.4, S.Wood)
		block(model, base, "Legs", Vector3.new(6, 2.6, 0.6), 0, 0, 0, S.DarkWood)
	end,
	Outhouse = function(model, base)
		block(model, base, "Booth", Vector3.new(4, 7, 4), 0, 0, 0, S.Planks)
		part(model, "Roof", Vector3.new(5, 1.4, 5), base * CFrame.new(0, 7.7, 0), S.MetalRoof, {
			className = "WedgePart",
		})
	end,
	Dock = function(model, base, scale)
		block(model, base, "Deck", Vector3.new(8, 0.8, scale), 0, 0.2, 0, S.Planks)
		for i = 0, math.floor(scale / 10) do
			local z = -scale / 2 + i * 10
			block(model, base, "Post", Vector3.new(1, 6, 1), -4, -5, z, S.DarkWood)
			block(model, base, "Post", Vector3.new(1, 6, 1), 4, -5, z, S.DarkWood)
		end
	end,
	Boat = function(model, base)
		block(model, base, "Hull", Vector3.new(4, 1.6, 10), 0, -1.2, 0, S.Wood)
		part(model, "Bow", Vector3.new(4, 1.6, 3), base * CFrame.new(0, -0.4, -6.5), S.Wood, { className = "WedgePart" })
	end,
	WatchTower = function(model, base)
		for _, p in { { -4, -4 }, { 4, -4 }, { -4, 4 }, { 4, 4 } } do
			block(model, base, "Leg", Vector3.new(1.2, 26, 1.2), p[1], 0, p[2], S.DarkWood)
		end
		block(model, base, "Platform", Vector3.new(10, 1, 10), 0, 26, 0, S.Planks)
		block(model, base, "Railing", Vector3.new(10, 3, 0.5), 0, 27, -4.75, S.Planks)
		block(model, base, "Railing", Vector3.new(10, 3, 0.5), 0, 27, 4.75, S.Planks)
		block(model, base, "Railing", Vector3.new(0.5, 3, 10), -4.75, 27, 0, S.Planks)
		part(model, "Roof", Vector3.new(11, 3, 11), base * CFrame.new(0, 33, 0), S.MetalRoof, {
			className = "WedgePart",
		})
		for _, p in { { -4.5, -4.5 }, { 4.5, 4.5 } } do
			block(model, base, "RoofPost", Vector3.new(0.6, 4.5, 0.6), p[1], 27, p[2], S.DarkWood)
		end
		local ladder = part(
			model,
			"Ladder",
			Vector3.new(3, 27, 0.6),
			base * CFrame.new(0, 13.5, 6) * CFrame.Angles(math.rad(-8), 0, 0),
			S.Wood
		)
		ladder:SetAttribute("Climbable", true)
		local truss = Instance.new("TrussPart")
		truss.Name = "LadderTruss"
		truss.Anchored = true
		truss.Size = Vector3.new(2, 26, 2)
		truss.CFrame = base * CFrame.new(0, 13, 5.6)
		truss.Transparency = 1
		truss.Parent = model
	end,
	Silo = function(model, base)
		part(model, "Silo", Vector3.new(30, 12, 12), base * CFrame.new(0, 15, 0) * UPRIGHT, S.Steel, { shape = CYLINDER })
		part(model, "Dome", Vector3.one * 12, base * CFrame.new(0, 30, 0), S.Steel, { shape = BALL })
	end,
	CropField = function(model, base, _scale)
		-- Rows across the farm field; no collision so they never block movement.
		for i = -4, 4 do
			part(model, "CropRow", Vector3.new(170, 2.4, 2), base * CFrame.new(0, 1.2, i * 8), S.Crop, {
				canCollide = false,
				castShadow = false,
			})
		end
	end,
	RadioMast = function(model, base)
		local sections = 6
		for i = 1, sections do
			local width = 5 - i * 0.6
			block(model, base, "MastSection", Vector3.new(width, 10, width), 0, (i - 1) * 10, 0, S.Steel)
		end
		block(model, base, "Beacon", Vector3.new(1.4, 1.4, 1.4), 0, sections * 10, 0, S.Signal)
		block(model, base, "Dish", Vector3.new(4, 4, 0.6), 0, 30, -2.6, S.Appliance)
	end,
	Shed = function(model, base)
		block(model, base, "Shed", Vector3.new(8, 7, 6), 0, 0, 0, S.MetalRoof)
		block(model, base, "Door", Vector3.new(3, 6, 0.2), 0, 0, -3.05, S.DarkWood)
	end,
	StreetLamp = function(model, base)
		block(model, base, "Pole", Vector3.new(0.6, 14, 0.6), 0, 0, 0, S.Steel)
		block(model, base, "Arm", Vector3.new(0.4, 0.4, 3), 0, 13.6, -1.4, S.Steel)
		block(model, base, "Lamp", Vector3.new(1.4, 0.6, 1.4), 0, 13, -2.6, S.Lamp)
	end,
	PowerPole = function(model, base)
		block(model, base, "Pole", Vector3.new(1, 22, 1), 0, 0, 0, S.DarkWood)
		block(model, base, "Crossbar", Vector3.new(8, 0.6, 0.6), 0, 19.5, 0, S.DarkWood)
	end,
	Mailbox = function(model, base)
		block(model, base, "Post", Vector3.new(0.4, 3.4, 0.4), 0, 0, 0, S.DarkWood)
		block(model, base, "Box", Vector3.new(1, 1, 1.8), 0, 3.4, 0, S.Steel)
	end,
	TrashBin = function(model, base)
		block(model, base, "Bin", Vector3.new(2.4, 3.2, 2.4), 0, 0, 0, S.GoodsAlt)
	end,
}

function PropKit.has(kind: string): boolean
	return Builders[kind] ~= nil
end

-- Builds a prop model at (x, groundY, z). `key` makes colour choices deterministic.
function PropKit.build(
	kind: string,
	x: number,
	groundY: number,
	z: number,
	yawDegrees: number,
	scale: number,
	key: string,
	parent: Instance
): Model
	local builder = Builders[kind]
	assert(builder, `unknown prop kind {kind}`)
	local model = Instance.new("Model")
	model.Name = kind
	builder(model, CFrame.new(x, groundY, z) * CFrame.Angles(0, math.rad(yawDegrees), 0), scale, key)
	model.Parent = parent
	return model
end

return PropKit
