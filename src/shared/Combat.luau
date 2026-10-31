--!strict
-- Hit zones and zombie reactions (7DTD entityclasses.xml zombie template and ItemActionAttack; see
-- docs/REFERENCE_7DTD.md 5.5-5.6). Plain numbers and injected rolls, so the Lune tests can run it.

local Combat = {}

export type Zone = "Head" | "Body" | "Legs"

-- Settings read from Config.Combat (passed in so the module stays testable).
export type Settings = {
	LegHeight: number,
	KneelShare: number,
	ProneShare: number,
	StunMinSeconds: number,
	StunMaxSeconds: number,
	LegCrippleScale: number,
	DismemberChance: number,
	HeadDismemberShare: number,
	HeadDismemberFloor: number,
}

-- Poses a hit can knock a zombie into; they travel in the zombie snapshot as these numbers.
Combat.Pose = { None = 0, Kneel = 1, Prone = 2 }

export type Reaction = {
	pose: number,
	seconds: number,
	cripple: boolean,
}

-- Zone of a hit at `height` above the zombie's root (torso centre): the head sphere wins, then the
-- legs below `LegHeight`, otherwise the body.
function Combat.zone(height: number, head: boolean, settings: Settings): Zone
	if head then
		return "Head"
	elseif height < settings.LegHeight then
		return "Legs"
	end
	return "Body"
end

-- 7DTD: a hit dealing KneelShare of max health knocks the zombie to its knees, ProneShare flat on
-- the ground, for StunMin..Max seconds; a leg hit cripples it with chance share * LegCrippleScale.
-- `poseRoll`, `crippleRoll` are uniform in [0, 1).
function Combat.react(damage: number, maxHealth: number, zone: Zone, poseRoll: number, crippleRoll: number,
	settings: Settings): Reaction
	local share = if maxHealth > 0 then damage / maxHealth else 0
	local pose = if share >= settings.ProneShare
		then Combat.Pose.Prone
		elseif share >= settings.KneelShare then Combat.Pose.Kneel
		else Combat.Pose.None
	local seconds = if pose == Combat.Pose.None
		then 0
		else settings.StunMinSeconds + (settings.StunMaxSeconds - settings.StunMinSeconds) * poseRoll
	return {
		pose = pose,
		seconds = seconds,
		cripple = zone == "Legs" and crippleRoll < share * settings.LegCrippleScale,
	}
end

-- 7DTD: a killing head hit that dealt HeadDismemberShare of max health takes the head off with chance
-- max(DismemberChance / 2, HeadDismemberFloor). `roll` is uniform in [0, 1).
function Combat.decapitates(killing: boolean, zone: Zone, damage: number, maxHealth: number, roll: number,
	settings: Settings): boolean
	if not killing or zone ~= "Head" or maxHealth <= 0 or damage / maxHealth < settings.HeadDismemberShare then
		return false
	end
	return roll < math.max(settings.DismemberChance * 0.5, settings.HeadDismemberFloor)
end

-- Snapshot state byte: the state code in the low four bits, the pose in bits 4-5, crippled in bit 6.
function Combat.packFlags(stateCode: number, pose: number, crippled: boolean): number
	return stateCode + pose * 16 + (if crippled then 64 else 0)
end

function Combat.unpackFlags(byte: number): (number, number, boolean)
	return byte % 16, math.floor(byte / 16) % 4, math.floor(byte / 64) % 2 == 1
end

return Combat
