--!strict
-- BuildGrid: pure math of the building grid. Blocks are cubes of Config.Build.GridSize studs on a world
-- grid that shares its columns with the navigation grid (cell x covers [x * size, (x + 1) * size)).
-- The server and the client's placement preview pick the same cell from the same raycast.

local Config = require("./Config")

local BC = Config.Build
local SIZE = BC.GridSize
-- Cell coordinates are packed into one number: each axis is offset into [0, SPAN).
local SPAN = 4096
local OFFSET = SPAN / 2

-- Face neighbours of a cell (the six directions blocks support each other in).
local NEIGHBOURS = {
	{ 1, 0, 0 },
	{ -1, 0, 0 },
	{ 0, 1, 0 },
	{ 0, -1, 0 },
	{ 0, 0, 1 },
	{ 0, 0, -1 },
}

export type Support = { grounded: boolean }

local BuildGrid = {}

BuildGrid.NEIGHBOURS = NEIGHBOURS

function BuildGrid.key(cx: number, cy: number, cz: number): number
	return ((cx + OFFSET) * SPAN + (cz + OFFSET)) * SPAN + (cy + OFFSET)
end

function BuildGrid.unkey(key: number): (number, number, number)
	local cy = key % SPAN - OFFSET
	local rest = key // SPAN
	local cz = rest % SPAN - OFFSET
	local cx = rest // SPAN - OFFSET
	return cx, cy, cz
end

-- The cell holding a world point.
function BuildGrid.cellOf(x: number, y: number, z: number): (number, number, number)
	return math.floor(x / SIZE), math.floor(y / SIZE), math.floor(z / SIZE)
end

function BuildGrid.center(cx: number, cy: number, cz: number): (number, number, number)
	return (cx + 0.5) * SIZE, (cy + 0.5) * SIZE, (cz + 0.5) * SIZE
end

-- The axis-aligned unit step closest to a surface normal.
function BuildGrid.normalStep(nx: number, ny: number, nz: number): (number, number, number)
	local ax, ay, az = math.abs(nx), math.abs(ny), math.abs(nz)
	if ay >= ax and ay >= az then
		return 0, if ny >= 0 then 1 else -1, 0
	elseif ax >= az then
		return if nx >= 0 then 1 else -1, 0, 0
	end
	return 0, 0, if nz >= 0 then 1 else -1
end

-- The cell a new block goes into for a ray that hit (x, y, z) with surface normal (nx, ny, nz): next to
-- the block that was hit (its cell given), otherwise the cell just off the surface. On the ground the
-- block sinks into the terrain by up to one cell, so it never floats.
function BuildGrid.target(
	x: number,
	y: number,
	z: number,
	nx: number,
	ny: number,
	nz: number,
	hitCell: { number }?
): (number, number, number)
	if hitCell then
		local sx, sy, sz = BuildGrid.normalStep(nx, ny, nz)
		return hitCell[1] + sx, hitCell[2] + sy, hitCell[3] + sz
	end
	local e = BC.SurfaceOffset
	return BuildGrid.cellOf(x + nx * e, y + ny * e, z + nz * e)
end

-- The ray that finds what carries a block in cell (cx, cy, cz): from just above its top down to
-- GroundProbe under its bottom (a block sunk into the terrain starts above the surface). Returns the
-- start point and the length of the downward ray.
function BuildGrid.groundRay(cx: number, cy: number, cz: number): (number, number, number, number)
	local x, y, z = BuildGrid.center(cx, cy, cz)
	return x, y + SIZE / 2 + 0.01, z, SIZE + 0.01 + BC.GroundProbe
end

-- Whether a block whose cell starts at `bottom` stands in a zombie's way on ground at `ground`: it
-- reaches above a step and starts below the top of a zombie.
function BuildGrid.obstructs(bottom: number, ground: number): boolean
	return bottom + SIZE > ground + Config.FlowField.StepHeight and bottom < ground + BC.BodyHeight
end

-- Path cost of a column whose blocking blocks have `health` in total: weaker walls are cheaper to path
-- through, so zombies go for the weakest part (PLAN). Between 2 and FlowField.StructureCellCost.
function BuildGrid.pathCost(health: number): number
	local cost = 1 + math.ceil(math.max(0, health) / BC.HealthPerPathCost)
	return math.clamp(cost, 2, Config.FlowField.StructureCellCost)
end

-- After the block at `removed` is gone, the blocks that no longer reach a grounded block through face
-- neighbours (7DTD structural support, without its span limits). `blocks` must no longer hold
-- `removed`. Returns their keys.
function BuildGrid.unsupported(blocks: { [number]: Support }, removed: number): { number }
	local falling: { number } = {}
	local checked: { [number]: boolean } = {}
	local rx, ry, rz = BuildGrid.unkey(removed)
	for _, step in NEIGHBOURS do
		local start = BuildGrid.key(rx + step[1], ry + step[2], rz + step[3])
		if blocks[start] and not checked[start] then
			-- Flood the group this neighbour belongs to; it stands if any of its blocks is grounded.
			local group = { start }
			checked[start] = true
			local grounded = false
			local index = 1
			while index <= #group do
				local key = group[index]
				index += 1
				if blocks[key].grounded then
					grounded = true
				end
				local cx, cy, cz = BuildGrid.unkey(key)
				for _, n in NEIGHBOURS do
					local other = BuildGrid.key(cx + n[1], cy + n[2], cz + n[3])
					if blocks[other] and not checked[other] then
						checked[other] = true
						table.insert(group, other)
					end
				end
			end
			if not grounded then
				table.move(group, 1, #group, #falling + 1, falling)
			end
		end
	end
	return falling
end

return BuildGrid
