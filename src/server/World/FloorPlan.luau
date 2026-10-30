--!strict
-- Reads building floor plans: cells, rooms, furniture orientation and stairs. Pure Luau with no
-- requires, so the Lune tests check every template with the same code the building kit uses.
--
-- A plan is a list of equal-length strings; row 1 is the front (-Z) and cells are addressed
-- (row, col). Walls (# W G D) stand on cell centre lines. Doorways count as walls, so a room ends at
-- its doors. Floor that touches the plan border or a space cell is outside, not a room.

local FloorPlan = {}

FloorPlan.OUTSIDE = -1
-- Region id of wall cells.
FloorPlan.WALL_REGION = 0

local WALLS = { ["#"] = true, W = true, D = true, G = true }

-- Stair symbol -> direction of rise (dx along columns, dz along rows).
FloorPlan.STAIRS = {
	["^"] = { 0, -1 },
	v = { 0, 1 },
	["<"] = { -1, 0 },
	[">"] = { 1, 0 },
} :: { [string]: { number } }

-- Every furniture symbol and the room kind it hints at ("" = no hint).
local FURNITURE: { [string]: string } = {
	b = "Bedroom",
	y = "Bedroom",
	c = "Bedroom",
	T = "Bathroom",
	U = "Bathroom",
	n = "Bathroom",
	k = "Kitchen",
	g = "Kitchen",
	i = "Kitchen",
	f = "",
	o = "Living",
	a = "Living",
	e = "Living",
	F = "Living",
	t = "",
	r = "",
	l = "",
	p = "",
	h = "Ward",
	m = "Ward",
	d = "Office",
	A = "Office",
	q = "",
	s = "Shop",
	C = "Shop",
	B = "Shop",
	L = "Storage",
	x = "Storage",
	R = "Storage",
	w = "Storage",
	H = "Storage",
}

-- The first kind present in a room wins. Living beats Kitchen so an open-plan living room with a
-- kitchen corner reads as a living room.
local KIND_PRIORITY = { "Bathroom", "Bedroom", "Living", "Kitchen", "Ward", "Office", "Shop", "Storage" }
local DEFAULT_KIND = "Hall"

-- Symbols that line up into one long piece of furniture (counters, shelf aisles).
local RUN_GROUP: { [string]: string } = { k = "counter", g = "counter", i = "counter", C = "checkout" }

-- How much a furniture back likes each wall: solid wall > window > shop glass; never a doorway.
local WALL_SCORE: { [string]: number } = { ["#"] = 3, W = 2, G = 1 }
local FACES_ROOM_BONUS = 0.5

-- Orthogonal neighbours as (dx, dz): front, back, left, right.
local DIRECTIONS = { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }

export type Room = {
	id: number,
	kind: string,
	-- { row, col } of every cell in the room, furniture and stairs included.
	cells: { { number } },
}

export type Rooms = {
	-- Region per cell: room id (> 0), OUTSIDE, or WALL_REGION.
	ids: { { number } },
	list: { Room },
}

export type Stair = {
	symbol: string,
	dx: number,
	dz: number,
	cells: { { number } },
	-- { row, col } of the lowest and highest step cell.
	low: { number },
	high: { number },
}

function FloorPlan.size(plan: { string }): (number, number)
	return #plan, #plan[1]
end

function FloorPlan.charAt(plan: { string }, row: number, col: number): string
	local line = plan[row]
	if line == nil or col < 1 or col > #line then
		return " "
	end
	return string.sub(line, col, col)
end

function FloorPlan.isWallChar(char: string): boolean
	return WALLS[char] == true
end

function FloorPlan.isWall(plan: { string }, row: number, col: number): boolean
	return WALLS[FloorPlan.charAt(plan, row, col)] == true
end

function FloorPlan.isFurniture(char: string): boolean
	return FURNITURE[char] ~= nil
end

-- True for every symbol the plans may use.
function FloorPlan.isKnown(char: string): boolean
	return WALLS[char] == true
		or FURNITURE[char] ~= nil
		or FloorPlan.STAIRS[char] ~= nil
		or char == "."
		or char == " "
		or char == "P"
end

-- Floods the non-wall cells into regions and classifies each enclosed one by its furniture.
function FloorPlan.rooms(plan: { string }): Rooms
	local rows, cols = FloorPlan.size(plan)
	local ids: { { number } } = table.create(rows)
	for row = 1, rows do
		ids[row] = table.create(cols, FloorPlan.WALL_REGION)
	end
	local visited: { [number]: boolean } = {}
	local list: { Room } = {}

	for startRow = 1, rows do
		for startCol = 1, cols do
			local char = FloorPlan.charAt(plan, startRow, startCol)
			if char == " " then
				ids[startRow][startCol] = FloorPlan.OUTSIDE
			elseif not WALLS[char] and not visited[startRow * 1000 + startCol] then
				local cells = { { startRow, startCol } }
				visited[startRow * 1000 + startCol] = true
				local outside = false
				local head = 1
				while head <= #cells do
					local row, col = cells[head][1], cells[head][2]
					head += 1
					for _, d in DIRECTIONS do
						local r, c = row + d[2], col + d[1]
						local neighbour = FloorPlan.charAt(plan, r, c)
						if neighbour == " " then
							outside = true
						elseif not WALLS[neighbour] and not visited[r * 1000 + c] then
							visited[r * 1000 + c] = true
							table.insert(cells, { r, c })
						end
					end
				end

				local id = FloorPlan.OUTSIDE
				if not outside then
					local hints: { [string]: boolean } = {}
					for _, cell in cells do
						local hint = FURNITURE[FloorPlan.charAt(plan, cell[1], cell[2])]
						if hint and hint ~= "" then
							hints[hint] = true
						end
					end
					local kind = DEFAULT_KIND
					for _, candidate in KIND_PRIORITY do
						if hints[candidate] then
							kind = candidate
							break
						end
					end
					id = #list + 1
					table.insert(list, { id = id, kind = kind, cells = cells })
				end
				for _, cell in cells do
					ids[cell[1]][cell[2]] = id
				end
			end
		end
	end
	return { ids = ids, list = list }
end

-- Region of a cell; cells beyond the plan are outside.
function FloorPlan.regionAt(rooms: Rooms, row: number, col: number): number
	local line = rooms.ids[row]
	if line == nil or line[col] == nil then
		return FloorPlan.OUTSIDE
	end
	return line[col]
end

local function sameRun(a: string, b: string): boolean
	if a == b then
		return true
	end
	local group = RUN_GROUP[a]
	return group ~= nil and group == RUN_GROUP[b]
end

-- Orientation of the furniture at (row, col): the direction (dx, dz) its back points to, and whether
-- the back rests against a wall. Pieces that line up with the same kind of neighbour (counters, shelf
-- aisles) keep their long side along that line.
function FloorPlan.facing(plan: { string }, row: number, col: number): (number, number, boolean)
	local here = FloorPlan.charAt(plan, row, col)
	local alongX = sameRun(here, FloorPlan.charAt(plan, row, col - 1)) or sameRun(here, FloorPlan.charAt(plan, row, col + 1))
	local alongZ = not alongX
		and (sameRun(here, FloorPlan.charAt(plan, row - 1, col)) or sameRun(here, FloorPlan.charAt(plan, row + 1, col)))

	local bestScore = 0
	local bestDx, bestDz = 0, 0
	for _, d in DIRECTIONS do
		local dx, dz = d[1], d[2]
		-- A run along x may only rest against a wall in front or behind it, and vice versa.
		local allowed = (not alongX or dx == 0) and (not alongZ or dz == 0)
		local score = if allowed then WALL_SCORE[FloorPlan.charAt(plan, row + dz, col + dx)] or 0 else 0
		if score > 0 then
			if FloorPlan.charAt(plan, row - dz, col - dx) == "." then
				score += FACES_ROOM_BONUS
			end
			if score > bestScore then
				bestScore, bestDx, bestDz = score, dx, dz
			end
		end
	end
	if bestScore > 0 then
		return bestDx, bestDz, true
	end
	-- Free-standing: the long side (local X) follows the run.
	if alongZ then
		return 1, 0, false
	end
	return 0, 1, false
end

-- Straight stair runs of one floor.
function FloorPlan.stairs(plan: { string }): { Stair }
	local rows, cols = FloorPlan.size(plan)
	local seen: { [number]: boolean } = {}
	local result: { Stair } = {}
	for row = 1, rows do
		for col = 1, cols do
			local symbol = FloorPlan.charAt(plan, row, col)
			local dir = FloorPlan.STAIRS[symbol]
			if dir and not seen[row * 1000 + col] then
				local dx, dz = dir[1], dir[2]
				local cells = {}
				local r, c = row, col
				while FloorPlan.charAt(plan, r, c) == symbol do
					seen[r * 1000 + c] = true
					table.insert(cells, { r, c })
					r += math.abs(dz)
					c += math.abs(dx)
				end
				local first, last = cells[1], cells[#cells]
				-- Cells were collected toward +row / +col; the low end is the one the stair rises away from.
				local rising = dx + dz > 0
				table.insert(result, {
					symbol = symbol,
					dx = dx,
					dz = dz,
					cells = cells,
					low = if rising then first else last,
					high = if rising then last else first,
				})
			end
		end
	end
	return result
end

-- Cell in front of the low end (where you step on) and beyond the high end (where you arrive upstairs).
function FloorPlan.stairEnds(stair: Stair): ({ number }, { number })
	local entry = { stair.low[1] - stair.dz, stair.low[2] - stair.dx }
	local exit = { stair.high[1] + stair.dz, stair.high[2] + stair.dx }
	return entry, exit
end

-- For a doorway cell: the two cells it connects, or nil when the doorway is not inside a straight wall.
function FloorPlan.doorSides(plan: { string }, row: number, col: number): ({ number }?, { number }?)
	local horizontal = FloorPlan.isWall(plan, row, col - 1) or FloorPlan.isWall(plan, row, col + 1)
	local vertical = FloorPlan.isWall(plan, row - 1, col) or FloorPlan.isWall(plan, row + 1, col)
	if horizontal and not vertical then
		return { row - 1, col }, { row + 1, col }
	elseif vertical and not horizontal then
		return { row, col - 1 }, { row, col + 1 }
	end
	return nil, nil
end

return FloorPlan
