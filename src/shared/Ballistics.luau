--!strict
-- Ballistics: pure arrow flight math (7DTD projectiles: a launch speed, then constant gravity). The
-- server flies arrows with it and every client draws the same arc. Plain numbers only, so the Lune
-- tests can run it.

local Config = require("./Config")

local Ballistics = {}

-- Entity damage of `ammo` shot from `weapon` (7DTD: the bow adds its offset to the arrow's damage).
function Ballistics.damage(weapon: Config.RangedDef, ammo: Config.AmmoDef): number
	return math.max(1, ammo.EntityDamage + weapon.DamageOffset)
end

-- Launch speed in studs a second of `ammo` shot from `weapon`.
function Ballistics.speed(weapon: Config.RangedDef, ammo: Config.AmmoDef): number
	return ammo.Speed * weapon.SpeedShare * Config.Melee.StudsPerMeter
end

-- Downward acceleration of `ammo` in studs a second squared.
function Ballistics.gravity(ammo: Config.AmmoDef): number
	return ammo.Gravity * Config.Melee.StudsPerMeter
end

-- Position `t` seconds after leaving (px, py, pz) at velocity (vx, vy, vz) under `gravity`.
function Ballistics.position(
	px: number,
	py: number,
	pz: number,
	vx: number,
	vy: number,
	vz: number,
	gravity: number,
	t: number
): (number, number, number)
	return px + vx * t, py + vy * t - gravity * t * t / 2, pz + vz * t
end

-- How far below its aim line a level shot has fallen after `distance` studs.
function Ballistics.drop(distance: number, speed: number, gravity: number): number
	local t = distance / speed
	return gravity * t * t / 2
end

return Ballistics
