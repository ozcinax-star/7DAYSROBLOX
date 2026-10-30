--!strict
-- Grid + flow field navigation for hordes. Pure Luau (no Roblox APIs) so it is unit tested with Lune.
--
-- One flow field is built per target (all players, or one sound point) and shared by every zombie
-- heading there: a zombie reads its cell, picks the neighbour with the lowest distance and walks to it.
-- This replaces per-zombie PathfindingService calls.

local NavGrid = {}
NavGrid.__index = NavGrid

local BLOCKED = 0
local NORMAL = 1
local UNREACHABLE = 65535
local MAX_DIST = 65534
-- How far (cells) a blocked field source looks for a walkable neighbour.
local SOURCE_SEARCH_RADIUS = 3

-- 8-neighbour offsets; the first four are orthogonal.
local NEIGHBOUR_DX = { 1, -1, 0, 0, 1, 1, -1, -1 }
local NEIGHBOUR_DZ = { 0, 0, 1, -1, 1, -1, 1, -1 }

export type Field = {
	-- u16 distance per cell of the window; UNREACHABLE where no source can be reached.
	dist: buffer,
	-- Window origin and size in grid cells.
	x0: number,
	z0: number,
	w: number,
	h: number,
}

export type NavGrid = typeof(setmetatable(
	{} :: {
		cellSize: number,
		halfExtent: number,
		width: number,
		cellCount: number,
		structureCost: number,
		-- u8 per cell: 0 = blocked, 1 = open, >1 = extra entry cost (player structure).
		cost: buffer,
	},
	NavGrid
))

-- `initialCost` fills every cell (default NORMAL); a layer that only has a few open cells, such as
-- the upper floors of buildings, starts BLOCKED and opens them one by one.
function NavGrid.new(cellSize: number, halfExtent: number, structureCost: number, initialCost: number?): NavGrid
	local width = math.floor(halfExtent * 2 / cellSize)
	local cellCount = width * width
	local cost = buffer.create(cellCount)
	buffer.fill(cost, 0, initialCost or NORMAL)
	return setmetatable({
		cellSize = cellSize,
		halfExtent = halfExtent,
		width = width,
		cellCount = cellCount,
		structureCost = structureCost,
		cost = cost,
	}, NavGrid)
end

-- Returns the 0-based cell index for a world position, or nil when outside the grid.
function NavGrid.cellAt(self: NavGrid, x: number, z: number): number?
	local cx = math.floor((x + self.halfExtent) / self.cellSize)
	local cz = math.floor((z + self.halfExtent) / self.cellSize)
	if cx < 0 or cz < 0 or cx >= self.width or cz >= self.width then
		return nil
	end
	return cz * self.width + cx
end

function NavGrid.cellCenter(self: NavGrid, index: number): (number, number)
	local cx = index % self.width
	local cz = index // self.width
	return (cx + 0.5) * self.cellSize - self.halfExtent, (cz + 0.5) * self.cellSize - self.halfExtent
end

function NavGrid.isWalkable(self: NavGrid, x: number, z: number): boolean
	local index = self:cellAt(x, z)
	return index ~= nil and buffer.readu8(self.cost, index) ~= BLOCKED
end

function NavGrid.getCost(self: NavGrid, index: number): number
	return buffer.readu8(self.cost, index)
end

function NavGrid.setCost(self: NavGrid, index: number, cost: number)
	buffer.writeu8(self.cost, index, cost)
end

-- Marks every cell overlapping the world-space rectangle with `cost` (0 blocks it).
function NavGrid.fillRect(self: NavGrid, minX: number, minZ: number, maxX: number, maxZ: number, cost: number)
	local size = self.cellSize
	local half = self.halfExtent
	local x0 = math.max(0, math.floor((minX + half) / size))
	local z0 = math.max(0, math.floor((minZ + half) / size))
	local x1 = math.min(self.width - 1, math.ceil((maxX + half) / size) - 1)
	local z1 = math.min(self.width - 1, math.ceil((maxZ + half) / size) - 1)
	for cz = z0, z1 do
		for cx = x0, x1 do
			buffer.writeu8(self.cost, cz * self.width + cx, cost)
		end
	end
end

function NavGrid.blockRect(self: NavGrid, minX: number, minZ: number, maxX: number, maxZ: number)
	self:fillRect(minX, minZ, maxX, maxZ, BLOCKED)
end

-- Builds a distance field from the given source cells using Dial's algorithm (bucketed Dijkstra with
-- small integer costs). Cost of a step = cost of the cell being entered.
-- The field only covers the window [minCx..maxCx] x [minCz..maxCz] (whole grid when omitted), which
-- keeps rebuilds cheap on a large map: zombies outside the window steer straight at their target.
function NavGrid.buildField(
	self: NavGrid,
	sources: { number },
	minCx: number?,
	minCz: number?,
	maxCx: number?,
	maxCz: number?
): Field
	local gridWidth = self.width
	local x0 = math.max(0, minCx or 0)
	local z0 = math.max(0, minCz or 0)
	local x1 = math.min(gridWidth - 1, maxCx or gridWidth - 1)
	local z1 = math.min(gridWidth - 1, maxCz or gridWidth - 1)
	local w = math.max(0, x1 - x0 + 1)
	local h = math.max(0, z1 - z0 + 1)
	local costBuf = self.cost
	local dist = buffer.create(math.max(1, w * h) * 2)
	buffer.fill(dist, 0, 255)

	local bucketCount = math.max(self.structureCost, NORMAL) + 1
	local buckets: { { number } } = table.create(bucketCount)
	for i = 1, bucketCount do
		buckets[i] = {}
	end

	local pending = 0
	for _, requested in sources do
		-- A target standing against a wall or furniture may sit in a blocked cell; use the closest
		-- walkable cell instead, otherwise the whole field would be empty.
		local source = self:nearestWalkable(requested, SOURCE_SEARCH_RADIUS) or requested
		local sx = source % gridWidth
		local sz = source // gridWidth
		if
			source >= 0
			and source < self.cellCount
			and sx >= x0
			and sx <= x1
			and sz >= z0
			and sz <= z1
			and buffer.readu8(costBuf, source) ~= BLOCKED
		then
			local localIndex = (sz - z0) * w + (sx - x0)
			buffer.writeu16(dist, localIndex * 2, 0)
			table.insert(buckets[1], localIndex)
			pending += 1
		end
	end

	local current = 0
	while pending > 0 do
		local bucket = buckets[(current % bucketCount) + 1]
		local item = table.remove(bucket)
		if item == nil then
			current += 1
			if current > MAX_DIST then
				break
			end
			continue
		end
		pending -= 1
		local d = buffer.readu16(dist, item * 2)
		if d ~= current then
			-- Stale entry: the cell was already reached by a shorter route.
			continue
		end
		local lx = item % w
		local lz = item // w
		for n = 1, 4 do
			local nx = lx + NEIGHBOUR_DX[n]
			local nz = lz + NEIGHBOUR_DZ[n]
			if nx >= 0 and nz >= 0 and nx < w and nz < h then
				local stepCost = buffer.readu8(costBuf, (nz + z0) * gridWidth + nx + x0)
				if stepCost ~= BLOCKED then
					local neighbour = nz * w + nx
					local nd = d + stepCost
					if nd < buffer.readu16(dist, neighbour * 2) and nd <= MAX_DIST then
						buffer.writeu16(dist, neighbour * 2, nd)
						table.insert(buckets[(nd % bucketCount) + 1], neighbour)
						pending += 1
					end
				end
			end
		end
	end

	return { dist = dist, x0 = x0, z0 = z0, w = w, h = h }
end

-- Closest walkable cell to `index` within `radius` cells (ring search), or nil.
function NavGrid.nearestWalkable(self: NavGrid, index: number, radius: number): number?
	if index < 0 or index >= self.cellCount then
		return nil
	end
	if buffer.readu8(self.cost, index) ~= BLOCKED then
		return index
	end
	local width = self.width
	local cx = index % width
	local cz = index // width
	for ring = 1, radius do
		for dz = -ring, ring do
			for dx = -ring, ring do
				if math.max(math.abs(dx), math.abs(dz)) == ring then
					local nx, nz = cx + dx, cz + dz
					if nx >= 0 and nz >= 0 and nx < width and nz < width then
						local candidate = nz * width + nx
						if buffer.readu8(self.cost, candidate) ~= BLOCKED then
							return candidate
						end
					end
				end
			end
		end
	end
	return nil
end

-- Cell window (minCx, minCz, maxCx, maxCz) covering a square of `radius` studs around (x, z).
function NavGrid.windowAround(self: NavGrid, x: number, z: number, radius: number): (number, number, number, number)
	local size = self.cellSize
	local half = self.halfExtent
	return math.floor((x - radius + half) / size),
		math.floor((z - radius + half) / size),
		math.floor((x + radius + half) / size),
		math.floor((z + radius + half) / size)
end

-- Distance of grid cell (cx, cz) in the field; UNREACHABLE outside the field window.
local function fieldDistance(field: Field, cx: number, cz: number): number
	local lx = cx - field.x0
	local lz = cz - field.z0
	if lx < 0 or lz < 0 or lx >= field.w or lz >= field.h then
		return UNREACHABLE
	end
	return buffer.readu16(field.dist, (lz * field.w + lx) * 2)
end

function NavGrid.distanceAt(self: NavGrid, field: Field, index: number): number
	return fieldDistance(field, index % self.width, index // self.width)
end

-- Returns the world position of the next cell to walk to from (x, z), or nil when the position is
-- outside the grid or the field window, already at a source, or cannot reach any source.
function NavGrid.nextWaypoint(self: NavGrid, field: Field, x: number, z: number): (number?, number?)
	local index = self:cellAt(x, z)
	if index == nil then
		return nil, nil
	end
	local width = self.width
	local costBuf = self.cost
	local cx = index % width
	local cz = index // width
	local best = fieldDistance(field, cx, cz)
	if best == 0 or best == UNREACHABLE then
		return nil, nil
	end
	local bestIndex = -1
	for n = 1, 8 do
		local nx = cx + NEIGHBOUR_DX[n]
		local nz = cz + NEIGHBOUR_DZ[n]
		if nx >= 0 and nz >= 0 and nx < width and nz < width then
			local nd = fieldDistance(field, nx, nz)
			if nd < best then
				-- Diagonals may not cut a blocked corner.
				local diagonalOk = n <= 4
					or (
						buffer.readu8(costBuf, cz * width + nx) ~= BLOCKED
						and buffer.readu8(costBuf, nz * width + cx) ~= BLOCKED
					)
				if diagonalOk then
					best = nd
					bestIndex = nz * width + nx
				end
			end
		end
	end
	if bestIndex < 0 then
		return nil, nil
	end
	local wx, wz = self:cellCenter(bestIndex)
	return wx, wz
end

NavGrid.BLOCKED = BLOCKED
NavGrid.NORMAL = NORMAL
NavGrid.UNREACHABLE = UNREACHABLE

return NavGrid
