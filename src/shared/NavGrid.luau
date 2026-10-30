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

-- 8-neighbour offsets; the first four are orthogonal.
local NEIGHBOUR_DX = { 1, -1, 0, 0, 1, 1, -1, -1 }
local NEIGHBOUR_DZ = { 0, 0, 1, -1, 1, -1, 1, -1 }

export type Field = {
	dist: buffer,
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

function NavGrid.new(cellSize: number, halfExtent: number, structureCost: number): NavGrid
	local width = math.floor(halfExtent * 2 / cellSize)
	local cellCount = width * width
	local cost = buffer.create(cellCount)
	buffer.fill(cost, 0, NORMAL)
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
function NavGrid.buildField(self: NavGrid, sources: { number }): Field
	local width = self.width
	local costBuf = self.cost
	local dist = buffer.create(self.cellCount * 2)
	buffer.fill(dist, 0, 255)

	local bucketCount = math.max(self.structureCost, NORMAL) + 1
	local buckets: { { number } } = table.create(bucketCount)
	for i = 1, bucketCount do
		buckets[i] = {}
	end

	local pending = 0
	for _, source in sources do
		if source >= 0 and source < self.cellCount and buffer.readu8(costBuf, source) ~= BLOCKED then
			buffer.writeu16(dist, source * 2, 0)
			table.insert(buckets[1], source)
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
		local cx = item % width
		local cz = item // width
		for n = 1, 4 do
			local nx = cx + NEIGHBOUR_DX[n]
			local nz = cz + NEIGHBOUR_DZ[n]
			if nx >= 0 and nz >= 0 and nx < width and nz < width then
				local neighbour = nz * width + nx
				local stepCost = buffer.readu8(costBuf, neighbour)
				if stepCost ~= BLOCKED then
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

	return { dist = dist }
end

function NavGrid.distanceAt(self: NavGrid, field: Field, index: number): number
	return buffer.readu16(field.dist, index * 2)
end

-- Returns the world position of the next cell to walk to from (x, z), or nil when the position is
-- outside the grid, already at a source, or cannot reach any source.
function NavGrid.nextWaypoint(self: NavGrid, field: Field, x: number, z: number): (number?, number?)
	local index = self:cellAt(x, z)
	if index == nil then
		return nil, nil
	end
	local width = self.width
	local dist = field.dist
	local costBuf = self.cost
	local best = buffer.readu16(dist, index * 2)
	if best == 0 or best == UNREACHABLE then
		return nil, nil
	end
	local cx = index % width
	local cz = index // width
	local bestIndex = -1
	for n = 1, 8 do
		local dx = NEIGHBOUR_DX[n]
		local dz = NEIGHBOUR_DZ[n]
		local nx = cx + dx
		local nz = cz + dz
		if nx >= 0 and nz >= 0 and nx < width and nz < width then
			local neighbour = nz * width + nx
			local nd = buffer.readu16(dist, neighbour * 2)
			if nd < best then
				-- Diagonals may not cut a blocked corner.
				local diagonalOk = n <= 4
					or (
						buffer.readu8(costBuf, cz * width + nx) ~= BLOCKED
						and buffer.readu8(costBuf, nz * width + cx) ~= BLOCKED
					)
				if diagonalOk then
					best = nd
					bestIndex = neighbour
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
