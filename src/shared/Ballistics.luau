--!strict
-- Ballistics: pure arrow and bullet flight math (7DTD projectiles: a launch speed, then constant
-- gravity), gun magazines and spread. The server flies shots with it and every client draws the same
-- arc. Plain numbers only, so the Lune tests can run it.

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

-- After a shot that brings the rounds fired from the magazine to `fired`: seconds until the next
-- shot and the count to keep. A spent magazine adds the reload and starts again (7DTD MagazineSize).
function Ballistics.afterShot(weapon: Config.RangedDef, fired: number): (number, number)
	if weapon.Magazine and fired >= weapon.Magazine then
		return math.max(weapon.ShotSeconds, weapon.ReloadSeconds or 0), 0
	end
	return weapon.ShotSeconds, fired
end

-- Unit direction (dx, dy, dz) turned by a random angle inside a cone of `degrees`: `r1` and `r2` in
-- [0, 1) pick the angle (spread evenly over the cone's disc) and its side.
function Ballistics.spread(
	dx: number,
	dy: number,
	dz: number,
	degrees: number,
	r1: number,
	r2: number
): (number, number, number)
	local angle = math.rad(degrees) * math.sqrt(r1)
	local around = 2 * math.pi * r2
	-- Two unit vectors at right angles to the direction.
	local ax, ay, az = 0, 1, 0
	if math.abs(dy) > 0.9 then
		ax, ay, az = 1, 0, 0
	end
	local ux, uy, uz = dy * az - dz * ay, dz * ax - dx * az, dx * ay - dy * ax
	local ul = math.sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / ul, uy / ul, uz / ul
	local vx, vy, vz = dy * uz - dz * uy, dz * ux - dx * uz, dx * uy - dy * ux
	local s, c = math.sin(angle), math.cos(angle)
	local cu, su = math.cos(around) * s, math.sin(around) * s
	return dx * c + ux * cu + vx * su, dy * c + uy * cu + vy * su, dz * c + uz * cu + vz * su
end

-- How far below its aim line a level shot has fallen after `distance` studs.
function Ballistics.drop(distance: number, speed: number, gravity: number): number
	local t = distance / speed
	return gravity * t * t / 2
end

return Ballistics
