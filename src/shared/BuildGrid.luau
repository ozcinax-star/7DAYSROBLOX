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

-- A farm plot slab `height` tall in cell (cx, cy, cz): at the bottom of the cell, lifted onto ground
-- at `groundY` that rises into the cell (blocks on the ground sink up to a cell into it).
function BuildGrid.plotCFrame(cx: number, cy: number, cz: number, groundY: number, height: number): CFrame
	local x = (cx + 0.5) * SIZE
	local z = (cz + 0.5) * SIZE
	local floor = cy * SIZE
	local bottom = math.clamp(groundY, floor, floor + SIZE - height)
	return CFrame.new(x, bottom + height / 2, z)
end

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

-- The side of cell (cx, cz) facing the point (x, z): 0 = -Z, 1 = +X, 2 = +Z, 3 = -X. A door hangs on
-- the side its builder stood on.
function BuildGrid.sideToward(cx: number, cz: number, x: number, z: number): number
	local mx, _, mz = BuildGrid.center(cx, 0, cz)
	local dx, dz = x - mx, z - mz
	if math.abs(dz) >= math.abs(dx) then
		return if dz < 0 then 0 else 2
	end
	return if dx > 0 then 1 else 3
end

-- Where the panel of a door in cell (cx, cy, cz) (and the cell above) sits: flat on side `side`
-- when closed, swung into the cell around its hinge corner when open. The panel's size is
-- (cell, two cells, `thickness`).
function BuildGrid.doorCFrame(
	cx: number,
	cy: number,
	cz: number,
	side: number,
	open: boolean,
	thickness: number
): CFrame
	local x, y, z = BuildGrid.center(cx, cy, cz)
	local half = SIZE / 2
	-- In the frame of side 0 (the -Z face), hinged at the -X end of that face.
	local placed = if open
		then CFrame.new(-half + thickness / 2, half, 0) * CFrame.Angles(0, math.pi / 2, 0)
		else CFrame.new(0, half, -half + thickness / 2)
	return CFrame.new(x, y, z) * CFrame.Angles(0, -side * math.pi / 2, 0) * placed
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

-- The probe for what cell (cx, cy, cz) stands on: a ray from SinkDepth above the cell floor down to
-- just below it (origin x, y, z and length).
function BuildGrid.sinkRay(cx: number, cy: number, cz: number): (number, number, number, number)
	local x, _, z = BuildGrid.center(cx, cy, cz)
	local floor = cy * SIZE
	return x, floor + BC.SinkDepth, z, BC.SinkDepth + 0.01
end

-- The height span a new block in cell `cy` must find empty (bottom, top): the cell less OverlapInset,
-- starting on `surfaceY` (the sinkRay hit) when that lies in the bottom SinkDepth of the cell.
function BuildGrid.clearSpan(cy: number, surfaceY: number?): (number, number)
	local floor = cy * SIZE
	local bottom = floor
	if surfaceY and surfaceY > floor and surfaceY <= floor + BC.SinkDepth then
		bottom = surfaceY
	end
	return bottom + BC.OverlapInset, floor + SIZE - BC.OverlapInset
end

-- Whether cell (cx, cy, cz) is closed to blocks by a town building with this footprint: inside it
-- (grown by BuildingMargin) only cells whose floor is at or below `buildTop` take blocks.
function BuildGrid.indoorBlocked(
	cx: number,
	cy: number,
	cz: number,
	minX: number,
	minZ: number,
	maxX: number,
	maxZ: number,
	buildTop: number
): boolean
	local x, z = cx * SIZE, cz * SIZE
	local m = BC.BuildingMargin
	if x + SIZE <= minX - m or x >= maxX + m or z + SIZE <= minZ - m or z >= maxZ + m then
		return false
	end
	return cy * SIZE > buildTop
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

-- The horizontal axis a wall runs along when the player looks along (dx, dz): across the view.
function BuildGrid.wallAxis(dx: number, dz: number): "X" | "Z"
	return if math.abs(dx) > math.abs(dz) then "Z" else "X"
end

-- Cells of a `width` x `height` wall whose bottom row is centred on (cx, cy, cz) along `axis`, bottom
-- row first (so every cell is placed after the one it stands on).
function BuildGrid.wallCells(cx: number, cy: number, cz: number, width: number, height: number, axis: "X" | "Z"): { { number } }
	local cells: { { number } } = {}
	local first = -math.floor((width - 1) / 2)
	for row = 0, height - 1 do
		for column = first, first + width - 1 do
			if axis == "X" then
				table.insert(cells, { cx + column, cy + row, cz })
			else
				table.insert(cells, { cx, cy + row, cz + column })
			end
		end
	end
	return cells
end

return BuildGrid
