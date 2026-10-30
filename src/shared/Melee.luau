--!strict
-- Melee hit math. Zombies have no parts on the server, so a swing is tested against an upright
-- cylinder around each zombie's root. Plain numbers only, so the Lune tests can run it.

local Melee = {}

-- A swing from the attacker's head: unit direction and reach (studs).
export type Ray = {
	ox: number,
	oy: number,
	oz: number,
	dx: number,
	dy: number,
	dz: number,
	range: number,
}

-- A zombie's root (torso centre) and the horizontal unit direction it faces (0, 0 when unknown).
export type Body = { id: number, x: number, y: number, z: number, fx: number, fz: number }

-- Body: an upright cylinder from `bottom` to `top` (heights relative to the root) with `radius`.
-- Head: a sphere of `headRadius` at `headHeight` above the root, `headLean` ahead of the root in the
-- facing direction (zombies hunch forward and lunge when they attack).
export type Shape = {
	bottom: number,
	top: number,
	radius: number,
	headHeight: number,
	headRadius: number,
	headLean: number,
}

-- A body the swing passes through: distance along the swing to the body's axis, whether the head
-- was hit, and the point where the swing passes the axis (for the line-of-sight check).
export type Hit = {
	id: number,
	distance: number,
	head: boolean,
	px: number,
	py: number,
	pz: number,
}

-- True when (x, y, z) is a finite vector of length 1 +- tolerance.
function Melee.isUnit(x: number, y: number, z: number, tolerance: number): boolean
	local length = math.sqrt(x * x + y * y + z * z)
	return length == length and math.abs(length - 1) <= tolerance
end

-- Seconds between two swings of a tool: 60 / attacks per minute plus a fixed delay (7DTD adds 0.1).
function Melee.interval(attacksPerMinute: number, delay: number): number
	return 60 / attacksPerMinute + delay
end

-- True when the swing passes through the body's head within its reach.
local function hitsHead(ray: Ray, body: Body, shape: Shape): boolean
	local cx = body.x + body.fx * shape.headLean
	local cy = body.y + shape.headHeight
	local cz = body.z + body.fz * shape.headLean
	local mx, my, mz = ray.ox - cx, ray.oy - cy, ray.oz - cz
	local b = mx * ray.dx + my * ray.dy + mz * ray.dz
	local c = mx * mx + my * my + mz * mz - shape.headRadius * shape.headRadius
	if c > 0 and b > 0 then
		return false
	end
	local disc = b * b - c
	if disc < 0 then
		return false
	end
	return -b - math.sqrt(disc) <= ray.range
end

-- Where the swing crosses the body, or nil when it misses. Bodies are upright, so the test is done
-- from above: the body must be in front of the attacker and within `radius` of the swing's line,
-- the swing must reach the near side of the body, and the swing's height where it passes the
-- body's axis must be between its feet and the top of its head. A body pressed against the attacker
-- still counts only when it is in front. It is a head hit when the swing also crosses the head.
function Melee.hitBody(ray: Ray, body: Body, shape: Shape): Hit?
	local flat = math.sqrt(ray.dx * ray.dx + ray.dz * ray.dz)
	if flat < 1e-6 then
		-- Straight up or down: nothing to swing at.
		return nil
	end
	local ux, uz = ray.dx / flat, ray.dz / flat
	local wx, wz = body.x - ray.ox, body.z - ray.oz
	local along = wx * ux + wz * uz
	if along <= 0 then
		return nil
	end
	local lateralSq = wx * wx + wz * wz - along * along
	local radiusSq = shape.radius * shape.radius
	if lateralSq > radiusSq then
		return nil
	end
	-- Distances along the swing: to the near side of the body and to its axis.
	local entry = (along - math.sqrt(radiusSq - math.max(0, lateralSq))) / flat
	if entry > ray.range then
		return nil
	end
	local distance = along / flat
	local y = ray.oy + ray.dy * math.min(distance, ray.range)
	local height = y - body.y
	if height < shape.bottom or height > shape.top then
		return nil
	end
	return {
		id = body.id,
		distance = distance,
		head = hitsHead(ray, body, shape),
		px = body.x,
		py = y,
		pz = body.z,
	}
end

-- The nearest body the swing hits that `isBlocked` does not reject (a wall in between), or nil.
function Melee.pick(ray: Ray, bodies: { Body }, shape: Shape, isBlocked: (Hit) -> boolean): Hit?
	local hits: { Hit } = {}
	for _, body in bodies do
		local hit = Melee.hitBody(ray, body, shape)
		if hit then
			table.insert(hits, hit)
		end
	end
	table.sort(hits, function(first, second)
		return first.distance < second.distance
	end)
	for _, hit in hits do
		if not isBlocked(hit) then
			return hit
		end
	end
	return nil
end

return Melee
