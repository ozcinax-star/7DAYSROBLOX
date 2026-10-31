--!strict
-- Appearance and gait personality of a zombie, derived from its id. Pure Luau: every client computes
-- the same look for the same id without extra bytes on the wire, and Lune tests the skin-tone mix.

local Config = require("./Config")
local Noise = require("./World/Noise")
local ZombieAssets = require("./ZombieAssets")

local VC = Config.ZombieVisual

-- Seed salt so zombie looks never correlate with map scatter hashes.
local SEED = 9173

export type Color = { number }

export type Look = {
	toneIndex: number,
	-- Skin of the torso and upper limbs, of hands/forearms (more rotten) and of the face.
	skin: Color,
	extremity: Color,
	face: Color,
	shirt: Color,
	pants: Color,
	bareArms: boolean,
	bareShins: boolean,
	height: number,
	hunch: number,
	limp: number,
	-- -1 = left leg drags, 1 = right leg drags.
	limpSide: number,
	headTilt: number,
	-- 0 = both arms reach, -1 / 1 = left / right arm hangs dead.
	deadArm: number,
	-- Starting gait phase and facing (radians), so a crowd does not move in lockstep.
	phase: number,
	yaw: number,
	twitchSeed: number,
	-- Textured head (index into ZombieAssets.Heads) and torso (index into ZombieAssets.Torsos, 0 = a
	-- shirt-coloured block).
	headMesh: number,
	torsoMesh: number,
}

local ZombieLook = {}

local function roll(id: number, salt: number): number
	return Noise.hash(id, salt, SEED)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function mix(a: Color, b: Color, t: number): Color
	return { lerp(a[1], b[1], t), lerp(a[2], b[2], t), lerp(a[3], b[3], t) }
end

local function scale(c: Color, k: number): Color
	return { c[1] * k, c[2] * k, c[3] * k }
end

local function brightness(c: Color): number
	return (c[1] + c[2] + c[3]) / 3
end

-- Index of the entry that `r` (in [0, 1)) falls into, by weight.
function ZombieLook.pickWeighted(weights: { number }, r: number): number
	local total = 0
	for _, w in weights do
		total += w
	end
	local target = r * total
	local acc = 0
	for index, w in weights do
		acc += w
		if target < acc then
			return index
		end
	end
	return #weights
end

local toneWeights: { number } = {}
for index, tone in VC.SkinTones do
	toneWeights[index] = tone.Weight
end

function ZombieLook.fromId(id: number): Look
	local toneIndex = ZombieLook.pickWeighted(toneWeights, roll(id, 1))
	local base = VC.SkinTones[toneIndex].Color
	-- Decay greys the skin toward RotColor taken down to the skin's own brightness, so dark skin
	-- stays dark instead of washing out to grey.
	local rotColor = scale(VC.RotColor, math.min(1, brightness(base) / brightness(VC.RotColor)))
	local rot = lerp(VC.RotMin, VC.RotMax, roll(id, 2))
	local skin = mix(base, rotColor, rot)
	local extremity = mix(base, rotColor, math.min(1, rot + VC.ExtremityRot))
	local shirts = VC.ShirtColors
	local pants = VC.PantsColors
	local deadArm = 0
	if roll(id, 9) < VC.DeadArmChance then
		deadArm = if roll(id, 10) < 0.5 then -1 else 1
	end
	return {
		toneIndex = toneIndex,
		skin = skin,
		extremity = extremity,
		face = scale(mix(base, rotColor, math.min(1, rot + VC.ExtremityRot / 2)), VC.FaceShade),
		shirt = shirts[math.floor(roll(id, 3) * #shirts) + 1],
		pants = pants[math.floor(roll(id, 4) * #pants) + 1],
		bareArms = roll(id, 5) < VC.BareArmChance,
		bareShins = roll(id, 6) < VC.BareShinChance,
		height = lerp(VC.HeightScaleMin, VC.HeightScaleMax, roll(id, 7)),
		hunch = lerp(VC.HunchMin, VC.HunchMax, roll(id, 8)),
		limp = lerp(VC.LimpMin, VC.LimpMax, roll(id, 11)),
		limpSide = if roll(id, 12) < 0.5 then -1 else 1,
		headTilt = (roll(id, 13) * 2 - 1) * VC.HeadTiltMax,
		deadArm = deadArm,
		phase = roll(id, 14) * math.pi * 2,
		yaw = roll(id, 15) * math.pi * 2,
		twitchSeed = math.floor(roll(id, 16) * 1000),
		headMesh = math.floor(roll(id, 18) * #ZombieAssets.Heads) + 1,
		torsoMesh = if roll(id, 19) < VC.MeshTorsoChance then math.floor(roll(id, 20) * #ZombieAssets.Torsos) + 1 else 0,
	}
end

return ZombieLook
