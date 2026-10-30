--!strict
-- Turns a BuildingTemplate floor plan into a furnished Model. Geometry is generated in template space
-- (x along columns, z along rows, origin at the footprint's min corner, y = 0 at ground level) and
-- then rotated/moved into place.
--
-- Walls stand on cell centre lines, so a wall blocks exactly one row of navigation cells and doorways
-- stay walkable. A wall's core carries the facade material when it faces outside; every room
-- (FloorPlan.rooms) paints its side of the wall with a thin lining and gets its own floor finish,
-- ceiling light and dressing. Casings, linings, door leaves and other trims are decor (no collision),
-- so they can never close a doorway for players or for the zombie navigation grid.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Localization = require(ReplicatedStorage.Shared.Localization)
local WorldLayout = require(ReplicatedStorage.Shared.World.WorldLayout)

local BuildingTemplates = require(script.Parent.BuildingTemplates)
local FloorPlan = require(script.Parent.FloorPlan)
local Furniture = require(script.Parent.Furniture)
local Palette = require(script.Parent.Palette)
local PartFactory = require(script.Parent.PartFactory)

local BuildingKit = {}

local S = Palette.Styles
local DECOR = PartFactory.DECOR
local CELL = Config.Build.GridSize
local OUTSIDE = FloorPlan.OUTSIDE
local WALL_REGION = FloorPlan.WALL_REGION
local V = Vector3.new

-- Architectural dimensions (studs). Heights are measured from the base of each floor.
local FLOOR_HEIGHT = 12
local WALL = 1
local LINING = 0.1
local FOUNDATION_DEPTH = 2
-- Concrete plinth (ground floor) or structural slab (upper floors), with the floor finish on top.
local SLAB_TOP = 0.8
local FINISH = 0.2
local FLOOR_TOP = SLAB_TOP + FINISH
local CEILING = 0.2
local PLINTH_LIP = 0.25
local WINDOW_SILL = 4
local WINDOW_TOP = 9
local SHOP_SILL = 2
local SHOP_TRANSOM = 7.6
local DOOR_TOP = 9
local GLASS = 0.2
local CASING = 0.5
-- Casings stand this far proud of the bare wall core (LINING less on a lined face).
local CASING_DEPTH = 0.25
local SILL_DEPTH = 0.6
local STOOL_DEPTH = 0.5
local MULLION = 0.2
local POST_MULLION = 0.35
local SHUTTER_WIDTH = 1.4
local LEAF_THICKNESS = 0.25
local STOOP_HEIGHT = 0.5
-- Stoops stay inside the footprint (the outer half of the door's own cell).
local STOOP_DEPTH = CELL / 2 - WALL / 2
local CANOPY_DEPTH = 2.6
local LAMP_OFFSET = 0.7
local AWNING_TOP = WINDOW_TOP + 0.6
local AWNING_DEPTH = 3
local AWNING_DROP = math.rad(22)
local CORNER_BOARD = 0.7
local BELT_HEIGHT = 0.5
local POST_SIZE = 1.2
local STEP_COUNT = 8
local STAIR_INSET = 0.4
local RAIL_HEIGHT = 3.2
local RAIL_THICKNESS = 0.3
local ROOF_PITCH = 0.5
local ROOF_MAX_RISE = 14
local ROOF_OVERHANG = 1.5
local ROOF_THICKNESS = 0.6
local TIE_BEAM_SPACING = 8
local FLAT_ROOF_THICKNESS = 0.8
local FLAT_ROOF_OVERHANG = 0.3
local PARAPET_HEIGHT = 1.5
local CHIMNEY_SIZE = 2.6
local CHIMNEY_ABOVE_ROOF = 3
local SIGN_HEIGHT = 2
local SIGN_MAX_WIDTH = 26
local SIGN_MARGIN = 6
local SIGN_PIXELS_PER_STUD = 40
local LIGHT_DIAMETER = 1.6
local PANEL_SPACING = 2
local PICTURE_HEIGHT = 5.2
local RUG_HEIGHT = 0.05
-- A rug covers its own cell up to this margin from the cell edge, and reaches into neighbouring
-- cells of the same room up to half its size.
local RUG_MARGIN = 0.3
-- Distance from a cell centre to the painted face of the wall in the neighbouring cell.
local WALL_FACE = CELL - WALL / 2 - LINING - 0.02

local DIRECTIONS = { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }
local KITCHEN_SYMBOLS = { k = true, g = true, i = true, f = true }
local RUG_ANCHORS = { o = true, a = true, e = true, F = true, b = true }
local RUG_SIZES: { [string]: Vector3 } = { Living = V(8, RUG_HEIGHT, 6), Bedroom = V(6, RUG_HEIGHT, 4.5) }
local PICTURE_ROOMS = { Living = true, Bedroom = true, Office = true, Hall = true }

-- Navigation data of a built building, in world coordinates.
export type Stair = {
	-- Floor the flight starts on (1 = ground floor).
	floor: number,
	-- Centre of the cell in front of the low end and of the cell beyond the high end, at the walking
	-- height of their floors.
	foot: Vector3,
	top: Vector3,
	-- Number of cells the flight covers.
	cells: number,
}

export type NavInfo = {
	stairs: { Stair },
	-- Centre of every walkable cell above the ground floor, at its walking height: floor cells
	-- (furniture included, stair holes not) and the doorways between rooms.
	upperCells: { Vector3 },
}

type Piece = { bottom: number, top: number, glass: boolean }

local function piece(bottom: number, top: number, glass: boolean?): Piece
	return { bottom = bottom, top = top, glass = glass == true }
end

-- Vertical make-up of each wall symbol.
local PIECES: { [string]: { Piece } } = {
	["#"] = { piece(0, FLOOR_HEIGHT) },
	W = { piece(0, WINDOW_SILL), piece(WINDOW_TOP, FLOOR_HEIGHT), piece(WINDOW_SILL, WINDOW_TOP, true) },
	G = { piece(0, SHOP_SILL), piece(WINDOW_TOP, FLOOR_HEIGHT), piece(SHOP_SILL, WINDOW_TOP, true) },
	D = { piece(DOOR_TOP, FLOOR_HEIGHT) },
}
local OPENING_SILL: { [string]: number } = { W = WINDOW_SILL, G = SHOP_SILL }

type RoomStyle = { wall: Palette.Style, floor: Palette.Style, kind: string }

type Floor = {
	index: number,
	plan: { string },
	rooms: FloorPlan.Rooms,
	styles: { [number]: RoomStyle },
	y0: number,
	-- Cells without floor because a stair from the floor below rises through them.
	holes: { [number]: boolean },
	isTop: boolean,
}

type Ctx = {
	model: Model,
	transform: CFrame,
	key: string,
	template: BuildingTemplates.Template,
	rows: number,
	cols: number,
	floorCount: number,
	-- Outer ring of the ground floor is all wall (false for open sheds).
	enclosed: boolean,
	-- Outer faces of the exterior walls in template space.
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	exterior: Palette.Style,
	partition: Palette.Style,
	trim: Palette.Style,
	roof: Palette.Style,
	-- Wall faces already taken by a door leaf or picture (see faceKey).
	usedFaces: { [string]: boolean },
	-- World centre of the navigation cell in front of every exterior ground-floor doorway.
	doorFronts: { Vector3 },
}

type RunCell = { index: number, kind: string, row: number, col: number }

-- One straight wall run with the extent of every cell along it.
type Run = { axis: string, fixed: number, cells: { RunCell }, lo: { number }, hi: { number } }

local function cellCenter(index: number): number
	return (index - 0.5) * CELL
end

local function cellKey(row: number, col: number): number
	return row * 1000 + col
end

local function add(
	ctx: Ctx,
	name: string,
	size: Vector3,
	cframe: CFrame,
	style: Palette.Style,
	options: PartFactory.Options?
): BasePart
	return PartFactory.make(ctx.model, name, size, ctx.transform * cframe, style, options)
end

local function decor(ctx: Ctx, name: string, size: Vector3, cframe: CFrame, style: Palette.Style): BasePart
	return PartFactory.make(ctx.model, name, size, ctx.transform * cframe, style, DECOR)
end

-- Wall face seen from floor cell (row, col) looking in direction (dx, dz).
local function faceKey(floor: Floor, row: number, col: number, dx: number, dz: number): string
	return `{floor.index}:{row},{col}|{dx},{dz}`
end

local function isFloorCell(floor: Floor, row: number, col: number): boolean
	local char = FloorPlan.charAt(floor.plan, row, col)
	return char ~= " " and not FloorPlan.isWallChar(char) and not floor.holes[cellKey(row, col)]
end

-- Frame on a wall's centre line at `along` and height y, with local +Z pointing toward `side` and
-- local X along the wall. Wall pieces are sized (length, height, thickness) in this frame.
local function wallFrame(axis: string, fixed: number, along: number, y: number, side: number): CFrame
	if axis == "x" then
		return CFrame.new(along, y, fixed) * CFrame.Angles(0, if side > 0 then 0 else math.pi, 0)
	end
	return CFrame.new(fixed, y, along) * CFrame.Angles(0, side * math.pi / 2, 0)
end

-- Sign of the frame's local X along the run direction.
local function alongSign(axis: string, side: number): number
	return if axis == "x" then side else -side
end

-- Cell beside a wall cell on `side`, perpendicular to the run axis.
local function sideCell(axis: string, row: number, col: number, side: number): (number, number)
	if axis == "x" then
		return row + side, col
	end
	return row, col + side
end

-- What lies on one side of a wall cell: a room id, OUTSIDE, or WALL_REGION for another wall.
local function sideRegion(floor: Floor, axis: string, row: number, col: number, side: number): number
	local r, c = sideCell(axis, row, col, side)
	if FloorPlan.isWall(floor.plan, r, c) then
		return WALL_REGION
	end
	return FloorPlan.regionAt(floor.rooms, r, c)
end

-- Where two runs meet in one cell only one of them may fill it, or their faces would overlap and
-- flicker. Horizontal runs always stop at the face of a crossing vertical wall; vertical runs fill
-- corners and stop only at a horizontal wall that continues past them.
local function endYields(plan: { string }, axis: string, cell: RunCell): boolean
	if axis == "x" then
		return FloorPlan.isWall(plan, cell.row - 1, cell.col) or FloorPlan.isWall(plan, cell.row + 1, cell.col)
	end
	return FloorPlan.isWall(plan, cell.row, cell.col - 1) and FloorPlan.isWall(plan, cell.row, cell.col + 1)
end

local function makeRun(plan: { string }, axis: string, fixed: number, cells: { RunCell }): Run
	local n = #cells
	local lo, hi = table.create(n), table.create(n)
	for i, cell in cells do
		local centre = cellCenter(cell.index)
		lo[i] = (cell.index - 1) * CELL
		hi[i] = cell.index * CELL
		if i == 1 then
			lo[i] = centre + (if endYields(plan, axis, cell) then WALL / 2 else -WALL / 2)
		end
		if i == n then
			hi[i] = centre + (if endYields(plan, axis, cell) then -WALL / 2 else WALL / 2)
		end
	end
	return { axis = axis, fixed = fixed, cells = cells, lo = lo, hi = hi }
end

-- Wall pieces between lo and hi; `offset` and `thickness` place them (core, or a lining on one side).
local function emitPieces(
	ctx: Ctx,
	floor: Floor,
	run: Run,
	lo: number,
	hi: number,
	kind: string,
	style: Palette.Style,
	offset: number,
	thickness: number,
	isCore: boolean
)
	for _, p in PIECES[kind] do
		if p.glass and not isCore then
			continue
		end
		local height = p.top - p.bottom
		local frame = wallFrame(run.axis, run.fixed, (lo + hi) / 2, floor.y0 + p.bottom + height / 2, 1)
		if p.glass then
			add(ctx, "Glass", V(hi - lo, height, GLASS), frame, S.Glass)
		elseif isCore then
			add(ctx, "Wall", V(hi - lo, height, thickness), frame * CFrame.new(0, 0, offset), style)
		else
			decor(ctx, "Lining", V(hi - lo, height, thickness), frame * CFrame.new(0, 0, offset), style)
		end
	end
end

-- Head and jambs around an opening on one face; `face` is centred on the opening at mid height.
local function casing(ctx: Ctx, face: CFrame, width: number, height: number)
	local z = WALL / 2 + CASING_DEPTH / 2
	decor(
		ctx,
		"Casing",
		V(width + CASING * 2, CASING, CASING_DEPTH),
		face * CFrame.new(0, height / 2 + CASING / 2, z),
		ctx.trim
	)
	decor(ctx, "Casing", V(CASING, height, CASING_DEPTH), face * CFrame.new(-width / 2 - CASING / 2, 0, z), ctx.trim)
	decor(ctx, "Casing", V(CASING, height, CASING_DEPTH), face * CFrame.new(width / 2 + CASING / 2, 0, z), ctx.trim)
end

-- Glazing bars, casings, sills, shutters and awnings of one window or shop-front segment.
local function windowDetails(ctx: Ctx, floor: Floor, run: Run, first: number, last: number, sideRegions: { number })
	local cells = run.cells
	local lo, hi = run.lo[first], run.hi[last]
	local kind = cells[first].kind
	local sill = OPENING_SILL[kind]
	local width = hi - lo
	local mid = (lo + hi) / 2
	local height = WINDOW_TOP - sill
	local centreY = floor.y0 + (sill + WINDOW_TOP) / 2
	local glassFrame = wallFrame(run.axis, run.fixed, mid, centreY, 1)
	local barDepth = GLASS + 0.1

	-- Posts between cells; house windows also get a cross per cell, shop fronts a transom.
	for k = first + 1, last do
		local x = (cells[k].index - 1) * CELL - mid
		decor(ctx, "Mullion", V(POST_MULLION, height, barDepth), glassFrame * CFrame.new(x, 0, 0), ctx.trim)
	end
	if kind == "W" then
		for k = first, last do
			local x = cellCenter(cells[k].index) - mid
			decor(ctx, "Mullion", V(MULLION, height, barDepth), glassFrame * CFrame.new(x, 0, 0), ctx.trim)
		end
		decor(ctx, "Transom", V(width, MULLION, barDepth), glassFrame, ctx.trim)
	else
		decor(
			ctx,
			"Transom",
			V(width, MULLION, barDepth),
			wallFrame(run.axis, run.fixed, mid, floor.y0 + SHOP_TRANSOM, 1),
			ctx.trim
		)
	end

	-- Shutters only beside single house windows set in solid wall.
	local solidBeside = first > 1
		and last < #cells
		and cells[first - 1].kind == "#"
		and cells[last + 1].kind == "#"
	local shutters = kind == "W" and ctx.template.shutters == true and first == last and solidBeside

	for s, side in { -1, 1 } do
		local region = sideRegions[s]
		if region == WALL_REGION then
			continue
		end
		local outside = region == OUTSIDE
		local face = wallFrame(run.axis, run.fixed, mid, centreY, side)
		casing(ctx, face, width, height)
		if kind == "W" then
			local depth = if outside then SILL_DEPTH else STOOL_DEPTH
			decor(
				ctx,
				if outside then "Sill" else "Stool",
				V(width + CASING * 2 + (if outside then 0.4 else 0), 0.25, depth),
				face * CFrame.new(0, -height / 2 - 0.125, WALL / 2 + depth / 2),
				ctx.trim
			)
		end
		if outside and shutters then
			local paint = PartFactory.pick(Palette.ShutterPaints, ctx.key)
			for _, dir in { -1, 1 } do
				decor(
					ctx,
					"Shutter",
					V(SHUTTER_WIDTH, height, 0.15),
					face * CFrame.new(dir * (width / 2 + CASING + SHUTTER_WIDTH / 2 + 0.05), 0, WALL / 2 + 0.1),
					paint
				)
			end
		end
		if outside and kind == "G" and ctx.template.awnings then
			local paint = PartFactory.pick(Palette.Awnings, ctx.key)
			local frame = wallFrame(run.axis, run.fixed, mid, floor.y0 + AWNING_TOP, side)
				* CFrame.new(0, 0, WALL / 2)
				* CFrame.Angles(AWNING_DROP, 0, 0)
				* CFrame.new(0, 0, AWNING_DEPTH / 2)
			decor(ctx, "Awning", V(width + 0.6, 0.15, AWNING_DEPTH), frame, paint)
			decor(
				ctx,
				"AwningValance",
				V(width + 0.6, 0.8, 0.1),
				frame * CFrame.new(0, -0.4, AWNING_DEPTH / 2),
				paint
			)
		end
	end
end

-- Leaves of an open door lying flat against the wall beside the opening on `side`, when that wall is
-- a full solid cell with free floor in front of it. Returns false when they do not fit.
local function doorLeaves(
	ctx: Ctx,
	floor: Floor,
	run: Run,
	first: number,
	last: number,
	side: number,
	style: Palette.Style
): boolean
	local cells = run.cells
	local lo, hi = run.lo[first], run.hi[last]
	local width = hi - lo
	if width > CELL * 2 + 0.1 then
		return false
	end
	local double = width > CELL + 0.1
	local dx = if run.axis == "z" then -side else 0
	local dz = if run.axis == "x" then -side else 0
	local usable: { { dir: number, key: string } } = {}
	for _, e in { { first - 1, -1 }, { last + 1, 1 } } do
		local index, dir = e[1], e[2]
		-- Run ends may be shortened at junctions; only middle cells are a full cell long.
		if index > 1 and index < #cells and cells[index].kind == "#" then
			local wall = cells[index]
			local r, c = sideCell(run.axis, wall.row, wall.col, side)
			local key = faceKey(floor, r, c, dx, dz)
			if FloorPlan.charAt(floor.plan, r, c) == "." and not ctx.usedFaces[key] then
				table.insert(usable, { dir = dir, key = key })
			end
		end
	end
	local needed = if double then 2 else 1
	if #usable < needed then
		return false
	end

	local leafWidth = if double then width / 2 - 0.15 else width - 0.3
	local leafHeight = DOOR_TOP - FLOOR_TOP - 0.1
	local y = floor.y0 + FLOOR_TOP + 0.05 + leafHeight / 2
	local sign = alongSign(run.axis, side)
	for i = 1, needed do
		local u = usable[i]
		ctx.usedFaces[u.key] = true
		local along = if u.dir < 0 then lo - leafWidth / 2 - 0.05 else hi + leafWidth / 2 + 0.05
		local frame = wallFrame(run.axis, run.fixed, along, y, side)
			* CFrame.new(0, 0, WALL / 2 + LINING + LEAF_THICKNESS / 2 + 0.02)
		decor(ctx, "DoorLeaf", V(leafWidth, leafHeight, LEAF_THICKNESS), frame, style)
		-- The hinge is at the opening; the knob sits near the free end, away from it.
		local knobX = u.dir * sign * (leafWidth / 2 - 0.4)
		decor(
			ctx,
			"DoorKnob",
			V(0.25, 0.25, 0.25),
			frame * CFrame.new(knobX, -0.6, LEAF_THICKNESS / 2 + 0.12),
			S.Brass
		)
	end
	return true
end

-- Casings, threshold, leaves, stoop, canopy and lamp of one doorway segment.
local function doorDetails(ctx: Ctx, floor: Floor, run: Run, first: number, last: number, sideRegions: { number })
	local cells = run.cells
	local lo, hi = run.lo[first], run.hi[last]
	local width = hi - lo
	local mid = (lo + hi) / 2
	local clear = DOOR_TOP - FLOOR_TOP
	local centreY = floor.y0 + FLOOR_TOP + clear / 2
	local exterior = sideRegions[1] == OUTSIDE or sideRegions[2] == OUTSIDE

	decor(
		ctx,
		"Threshold",
		V(width, 0.08, WALL + 0.2),
		wallFrame(run.axis, run.fixed, mid, floor.y0 + FLOOR_TOP + 0.04, 1),
		S.DarkWood
	)
	for s, side in { -1, 1 } do
		if sideRegions[s] ~= WALL_REGION then
			casing(ctx, wallFrame(run.axis, run.fixed, mid, centreY, side), width, clear)
		end
	end

	-- Exterior doors swing into the building; interior doors into whichever room has space.
	local leafStyle = if exterior then PartFactory.pick(Palette.DoorPaints, ctx.key) else S.Wood
	for s, side in { -1, 1 } do
		if sideRegions[s] > 0 and doorLeaves(ctx, floor, run, first, last, side, leafStyle) then
			break
		end
	end

	if not exterior or floor.index ~= 1 then
		return
	end
	local side = if sideRegions[1] == OUTSIDE then -1 else 1
	local face = wallFrame(run.axis, run.fixed, mid, 0, side)
	table.insert(ctx.doorFronts, (ctx.transform * face * CFrame.new(0, 0, CELL)).Position)
	add(
		ctx,
		"Stoop",
		V(width + 1.2, STOOP_HEIGHT, STOOP_DEPTH),
		face * CFrame.new(0, STOOP_HEIGHT / 2, WALL / 2 + STOOP_DEPTH / 2),
		S.Foundation
	)
	if ctx.template.porch then
		local canopyY = DOOR_TOP + 1
		decor(
			ctx,
			"Canopy",
			V(width + 2, 0.3, CANOPY_DEPTH),
			face * CFrame.new(0, canopyY, WALL / 2 + CANOPY_DEPTH / 2),
			ctx.roof
		)
		for _, dir in { -1, 1 } do
			decor(
				ctx,
				"Bracket",
				V(0.3, 1.2, 1.4),
				face * CFrame.new(dir * (width / 2 + 0.6), canopyY - 0.75, WALL / 2 + 0.7),
				ctx.trim
			)
		end
	end
	-- Wall lamp on the solid wall beside the door.
	local along: number? = nil
	if last < #cells and cells[last + 1].kind == "#" then
		along = hi + CASING + LAMP_OFFSET
	elseif first > 1 and cells[first - 1].kind == "#" then
		along = lo - CASING - LAMP_OFFSET
	end
	if along then
		decor(
			ctx,
			"WallLamp",
			V(0.5, 0.8, 0.4),
			wallFrame(run.axis, run.fixed, along, DOOR_TOP - 1.4, side) * CFrame.new(0, 0, WALL / 2 + 0.2),
			S.Lamp
		)
	end
end

-- Wall cores merged per (symbol, style), plus a lining per side at half-cell resolution, so a lining
-- runs on through junctions and changes colour exactly where the room on that side changes.
local function buildRun(ctx: Ctx, floor: Floor, run: Run)
	local cells = run.cells
	local n = #cells
	local sides: { { number } } = {}
	local cores: { Palette.Style } = {}
	for i, cell in cells do
		local a = sideRegion(floor, run.axis, cell.row, cell.col, -1)
		local b = sideRegion(floor, run.axis, cell.row, cell.col, 1)
		sides[i] = { a, b }
		cores[i] = if a == OUTSIDE or b == OUTSIDE then ctx.exterior else ctx.partition
	end

	local first = 1
	for i = 1, n do
		if i == n or cells[i + 1].kind ~= cells[i].kind or cores[i + 1] ~= cores[i] then
			local kind = cells[i].kind
			emitPieces(ctx, floor, run, run.lo[first], run.hi[i], kind, cores[i], 0, WALL, true)
			if kind == "W" or kind == "G" then
				windowDetails(ctx, floor, run, first, i, sides[first])
			elseif kind == "D" then
				doorDetails(ctx, floor, run, first, i, sides[first])
			end
			first = i + 1
		end
	end

	for s, side in { -1, 1 } do
		-- false = no lining (outside, or the room paint matches the core); inherit = another wall.
		local styleAt: { Palette.Style | false } = {}
		local inherit: { boolean } = {}
		for i = 1, n do
			local region = sides[i][s]
			inherit[i] = region == WALL_REGION
			if region > 0 then
				local paint = floor.styles[region].wall
				styleAt[i] = if paint == cores[i] then false else paint
			else
				styleAt[i] = false
			end
		end
		local function resolve(i: number, step: number): Palette.Style | false
			local j = i + step
			while j >= 1 and j <= n do
				if not inherit[j] then
					return styleAt[j]
				end
				j += step
			end
			return false
		end

		local spanStart, spanEnd = 0, 0
		local spanStyle: Palette.Style | false = false
		local spanKind = ""
		local function flush()
			if spanStyle and spanEnd - spanStart > 1e-6 then
				local offset = side * (WALL / 2 + LINING / 2)
				emitPieces(ctx, floor, run, spanStart, spanEnd, spanKind, spanStyle, offset, LINING, false)
			end
		end
		local function push(lo: number, hi: number, style: Palette.Style | false, kind: string)
			if hi - lo < 1e-6 then
				return
			end
			if style == spanStyle and kind == spanKind and math.abs(lo - spanEnd) < 1e-6 then
				spanEnd = hi
			else
				flush()
				spanStart, spanEnd, spanStyle, spanKind = lo, hi, style, kind
			end
		end
		for i = 1, n do
			local lo, hi = run.lo[i], run.hi[i]
			local mid = math.clamp(cellCenter(cells[i].index), lo, hi)
			local a, b = styleAt[i], styleAt[i]
			if inherit[i] then
				a, b = resolve(i, -1), resolve(i, 1)
				if i == 1 then
					a = b
				end
				if i == n then
					b = a
				end
			end
			push(lo, mid, a, cells[i].kind)
			push(mid, hi, b, cells[i].kind)
		end
		flush()
	end
end

local function buildWalls(ctx: Ctx, floor: Floor)
	local plan = floor.plan
	local connected: { [number]: boolean } = {}

	-- Horizontal runs (along x).
	for row = 1, ctx.rows do
		local cells: { RunCell } = {}
		for col = 1, ctx.cols + 1 do
			local horizontal = FloorPlan.isWall(plan, row, col)
				and (FloorPlan.isWall(plan, row, col - 1) or FloorPlan.isWall(plan, row, col + 1))
			if horizontal then
				table.insert(cells, { index = col, kind = FloorPlan.charAt(plan, row, col), row = row, col = col })
				connected[cellKey(row, col)] = true
			elseif #cells > 0 then
				buildRun(ctx, floor, makeRun(plan, "x", cellCenter(row), cells))
				cells = {}
			end
		end
	end

	-- Vertical runs (along z).
	for col = 1, ctx.cols do
		local cells: { RunCell } = {}
		for row = 1, ctx.rows + 1 do
			local vertical = FloorPlan.isWall(plan, row, col)
				and (FloorPlan.isWall(plan, row - 1, col) or FloorPlan.isWall(plan, row + 1, col))
			if vertical then
				table.insert(cells, { index = row, kind = FloorPlan.charAt(plan, row, col), row = row, col = col })
				connected[cellKey(row, col)] = true
			elseif #cells > 0 then
				buildRun(ctx, floor, makeRun(plan, "z", cellCenter(col), cells))
				cells = {}
			end
		end
	end

	-- Isolated wall cells become pillars (barn stalls).
	for row = 1, ctx.rows do
		for col = 1, ctx.cols do
			if FloorPlan.isWall(plan, row, col) and not connected[cellKey(row, col)] then
				add(
					ctx,
					"Pillar",
					V(WALL * 2, FLOOR_HEIGHT, WALL * 2),
					CFrame.new(cellCenter(col), floor.y0 + FLOOR_HEIGHT / 2, cellCenter(row)),
					ctx.partition
				)
			end
		end
	end
end

local function nearKitchen(plan: { string }, row: number, col: number): boolean
	if KITCHEN_SYMBOLS[FloorPlan.charAt(plan, row, col)] then
		return true
	end
	for _, d in DIRECTIONS do
		if KITCHEN_SYMBOLS[FloorPlan.charAt(plan, row + d[2], col + d[1])] then
			return true
		end
	end
	return false
end

local function floorStyleAt(ctx: Ctx, floor: Floor, row: number, col: number): Palette.Style
	local id = FloorPlan.regionAt(floor.rooms, row, col)
	if id <= 0 then
		return S[ctx.template.floor]
	end
	local room = floor.styles[id]
	-- Open-plan living rooms get tiles around the kitchen corner.
	if room.kind == "Living" and ctx.template.interior == nil and nearKitchen(floor.plan, row, col) then
		return S.KitchenTile
	end
	return room.floor
end

-- Floor finish per row run, reaching under the walls around it up to their centre lines. Upper floors
-- also get the structural slab below, whose underside is the ceiling of the floor beneath.
local function buildFloorSlabs(ctx: Ctx, floor: Floor)
	local plan = floor.plan
	for row = 1, ctx.rows do
		local col = 1
		while col <= ctx.cols do
			if not isFloorCell(floor, row, col) then
				col += 1
				continue
			end
			local style = floorStyleAt(ctx, floor, row, col)
			local up = FloorPlan.isWall(plan, row - 1, col)
			local down = FloorPlan.isWall(plan, row + 1, col)
			local last = col
			while
				last < ctx.cols
				and isFloorCell(floor, row, last + 1)
				and floorStyleAt(ctx, floor, row, last + 1) == style
				and FloorPlan.isWall(plan, row - 1, last + 1) == up
				and FloorPlan.isWall(plan, row + 1, last + 1) == down
			do
				last += 1
			end
			local x0 = (col - 1) * CELL - (if FloorPlan.isWall(plan, row, col - 1) then CELL / 2 else 0)
			local x1 = last * CELL + (if FloorPlan.isWall(plan, row, last + 1) then CELL / 2 else 0)
			local z0 = (row - 1) * CELL - (if up then CELL / 2 else 0)
			local z1 = row * CELL + (if down then CELL / 2 else 0)
			local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
			add(ctx, "Floor", V(x1 - x0, FINISH, z1 - z0), CFrame.new(cx, floor.y0 + SLAB_TOP + FINISH / 2, cz), style)
			if floor.index > 1 then
				add(ctx, "Slab", V(x1 - x0, SLAB_TOP, z1 - z0), CFrame.new(cx, floor.y0 + SLAB_TOP / 2, cz), S.Ceiling)
			end
			col = last + 1
		end
	end
end

local function buildPosts(ctx: Ctx, floor: Floor)
	for row = 1, ctx.rows do
		for col = 1, ctx.cols do
			if FloorPlan.charAt(floor.plan, row, col) == "P" then
				add(
					ctx,
					"Post",
					V(POST_SIZE, FLOOR_HEIGHT, POST_SIZE),
					CFrame.new(cellCenter(col), floor.y0 + FLOOR_HEIGHT / 2, cellCenter(row)),
					ctx.trim
				)
			end
		end
	end
end

-- Visible steps, an invisible ramp to walk on, balustrades on open sides, and railings around the
-- hole in the floor above.
local function buildStairs(ctx: Ctx, floor: Floor, above: Floor?)
	for _, stair in FloorPlan.stairs(floor.plan) do
		local count = #stair.cells
		local length = count * CELL
		local width = CELL - STAIR_INSET
		local dx, dz = stair.dx, stair.dz
		local first, last = stair.cells[1], stair.cells[count]
		local centerX = (cellCenter(first[2]) + cellCenter(last[2])) / 2
		local centerZ = (cellCenter(first[1]) + cellCenter(last[1])) / 2
		local startX = centerX - dx * length / 2
		local startZ = centerZ - dz * length / 2
		local base = floor.y0 + FLOOR_TOP
		local tread = length / STEP_COUNT
		for step = 1, STEP_COUNT do
			local height = FLOOR_HEIGHT * step / STEP_COUNT
			local along = (step - 0.5) * tread
			add(
				ctx,
				"Step",
				if dx ~= 0 then V(tread, height, width) else V(width, height, tread),
				CFrame.new(startX + dx * along, base + height / 2, startZ + dz * along),
				S.DarkWood,
				{ canCollide = false }
			)
		end
		-- The ramp runs through the middle of every riser, so feet stay within half a step of the
		-- treads. A WedgePart rises toward its local +Z side.
		local lift = tread / 2
		local ramp = add(
			ctx,
			"StairRamp",
			V(width, FLOOR_HEIGHT, length),
			CFrame.new(centerX, base + lift + FLOOR_HEIGHT / 2, centerZ) * CFrame.Angles(0, math.atan2(dx, dz), 0),
			S.DarkWood,
			{ className = "WedgePart" }
		)
		ramp.Transparency = 1

		-- Balustrade on each open side; an invisible guard stops stepping onto the flight sideways.
		local px, pz = math.abs(dz), math.abs(dx)
		for _, side in { -1, 1 } do
			local open = false
			for _, cell in stair.cells do
				if not FloorPlan.isWall(floor.plan, cell[1] + side * pz, cell[2] + side * px) then
					open = true
				end
			end
			if open then
				local ox, oz = side * px * (width / 2 - 0.15), side * pz * (width / 2 - 0.15)
				local guardHeight = FLOOR_HEIGHT - 0.2
				local guard = add(
					ctx,
					"StairGuard",
					if dx ~= 0 then V(length, guardHeight, 0.2) else V(0.2, guardHeight, length),
					CFrame.new(centerX + ox, base + guardHeight / 2, centerZ + oz),
					S.DarkWood
				)
				guard.Transparency = 1
				local railBase = base + lift + RAIL_HEIGHT / 2
				local low = V(startX + ox, railBase, startZ + oz)
				local high = V(startX + dx * length + ox, railBase + FLOOR_HEIGHT, startZ + dz * length + oz)
				local slope = CFrame.lookAt((low + high) / 2, high)
				local span = (high - low).Magnitude
				decor(ctx, "Balustrade", V(0.2, RAIL_HEIGHT - 0.4, span), slope, S.Wood)
				decor(ctx, "Handrail", V(0.35, 0.3, span), slope * CFrame.new(0, RAIL_HEIGHT / 2, 0), S.DarkWood)
				decor(
					ctx,
					"Newel",
					V(0.5, RAIL_HEIGHT + 0.6, 0.5),
					CFrame.new(low.X, base + (RAIL_HEIGHT + 0.6) / 2, low.Z),
					S.DarkWood
				)
			end
		end

		if above then
			local holes: { [number]: boolean } = {}
			for _, cell in stair.cells do
				holes[cellKey(cell[1], cell[2])] = true
			end
			local _, exit = FloorPlan.stairEnds(stair)
			local railY = above.y0 + FLOOR_TOP + RAIL_HEIGHT / 2
			for _, cell in stair.cells do
				for _, d in DIRECTIONS do
					local r, c = cell[1] + d[2], cell[2] + d[1]
					local isExit = r == exit[1] and c == exit[2]
					if not holes[cellKey(r, c)] and not isExit and isFloorCell(above, r, c) then
						local ex = cellCenter(cell[2]) + d[1] * (CELL / 2 - RAIL_THICKNESS / 2)
						local ez = cellCenter(cell[1]) + d[2] * (CELL / 2 - RAIL_THICKNESS / 2)
						local alongX = d[1] == 0
						add(
							ctx,
							"Railing",
							if alongX then V(CELL, RAIL_HEIGHT, RAIL_THICKNESS) else V(RAIL_THICKNESS, RAIL_HEIGHT, CELL),
							CFrame.new(ex, railY, ez),
							S.Wood
						)
						decor(
							ctx,
							"RailCap",
							if alongX
								then V(CELL, 0.25, RAIL_THICKNESS + 0.15)
								else V(RAIL_THICKNESS + 0.15, 0.25, CELL),
							CFrame.new(ex, railY + RAIL_HEIGHT / 2 + 0.125, ez),
							S.DarkWood
						)
					end
				end
			end
		end
	end
end

local function buildFurniture(ctx: Ctx, floor: Floor)
	local plan = floor.plan
	for row = 1, ctx.rows do
		for col = 1, ctx.cols do
			local symbol = FloorPlan.charAt(plan, row, col)
			if Furniture.has(symbol) then
				local dx, dz, against = FloorPlan.facing(plan, row, col)
				local base = ctx.transform
					* CFrame.new(cellCenter(col), floor.y0 + FLOOR_TOP, cellCenter(row))
					* CFrame.Angles(0, math.atan2(dx, dz), 0)
				local solidBack = FloorPlan.charAt(plan, row + dz, col + dx) == "#"
				Furniture.build(
					symbol,
					ctx.model,
					base,
					if against then WALL_FACE else nil,
					solidBack,
					ctx.key,
					`{floor.index}:{row}:{col}`
				)
			end
		end
	end
end

local function inRoom(floor: Floor, id: number, row: number, col: number): boolean
	return FloorPlan.regionAt(floor.rooms, row, col) == id and not floor.holes[cellKey(row, col)]
end

-- A wall cell in the middle of a solid run: its whole face toward a room is flat and free.
local function isPlainWall(plan: { string }, row: number, col: number, dx: number, dz: number): boolean
	local wr, wc = row + dz, col + dx
	return FloorPlan.charAt(plan, wr, wc) == "#"
		and FloorPlan.isWall(plan, wr + dx, wc + dz)
		and FloorPlan.isWall(plan, wr - dx, wc - dz)
end

local function ceilingLights(ctx: Ctx, floor: Floor, room: FloorPlan.Room)
	local ceilingY = floor.y0 + FLOOR_HEIGHT - (if floor.isTop then CEILING else 0)
	-- Shops and offices: fluorescent panels in a grid.
	if ctx.template.panels then
		local placed = false
		for _, cell in room.cells do
			local row, col = cell[1], cell[2]
			if row % PANEL_SPACING == 0 and col % PANEL_SPACING == 0 and not floor.holes[cellKey(row, col)] then
				decor(
					ctx,
					"LightPanel",
					V(CELL * 0.8, 0.15, 1),
					CFrame.new(cellCenter(col), ceilingY - 0.075, cellCenter(row)),
					S.Lamp
				)
				placed = true
			end
		end
		if placed then
			return
		end
	end
	-- One round fitting on the cell nearest the room's centroid.
	local sx, sz = 0, 0
	for _, cell in room.cells do
		sx += cell[2]
		sz += cell[1]
	end
	sx /= #room.cells
	sz /= #room.cells
	local best, bestDistance = room.cells[1], math.huge
	for _, cell in room.cells do
		local d = (cell[2] - sx) ^ 2 + (cell[1] - sz) ^ 2
		if d < bestDistance and not floor.holes[cellKey(cell[1], cell[2])] then
			best, bestDistance = cell, d
		end
	end
	PartFactory.make(
		ctx.model,
		"CeilingLight",
		V(0.25, LIGHT_DIAMETER, LIGHT_DIAMETER),
		ctx.transform
			* CFrame.new(cellCenter(best[2]), ceilingY - 0.125, cellCenter(best[1]))
			* CFrame.Angles(0, 0, math.pi / 2),
		S.Lamp,
		{ shape = Enum.PartType.Cylinder, decor = true }
	)
end

-- Rug on the free cell beside the most sofas, chairs and beds, kept inside the room.
local function rug(ctx: Ctx, floor: Floor, room: FloorPlan.Room, size: Vector3)
	local plan = floor.plan
	local best, bestScore = nil, 0
	for _, cell in room.cells do
		if FloorPlan.charAt(plan, cell[1], cell[2]) == "." and not floor.holes[cellKey(cell[1], cell[2])] then
			local score = 0
			for dr = -1, 1 do
				for dc = -1, 1 do
					if RUG_ANCHORS[FloorPlan.charAt(plan, cell[1] + dr, cell[2] + dc)] then
						score += 1
					end
				end
			end
			if score > bestScore then
				best, bestScore = cell, score
			end
		end
	end
	if best == nil then
		return
	end
	local row, col = best[1], best[2]
	local function reach(r: number, c: number, half: number): number
		return if inRoom(floor, room.id, r, c) then half else CELL / 2 - RUG_MARGIN
	end
	local left, right = reach(row, col - 1, size.X / 2), reach(row, col + 1, size.X / 2)
	local front, back = reach(row - 1, col, size.Z / 2), reach(row + 1, col, size.Z / 2)
	decor(
		ctx,
		"Rug",
		V(left + right, RUG_HEIGHT, front + back),
		CFrame.new(
			cellCenter(col) + (right - left) / 2,
			floor.y0 + FLOOR_TOP + RUG_HEIGHT / 2,
			cellCenter(row) + (back - front) / 2
		),
		PartFactory.pick(Palette.Rugs, `{ctx.key}{floor.index}{room.id}`)
	)
end

-- One picture on a free stretch of plain wall.
local function picture(ctx: Ctx, floor: Floor, room: FloorPlan.Room)
	local plan = floor.plan
	for _, cell in room.cells do
		local row, col = cell[1], cell[2]
		if FloorPlan.charAt(plan, row, col) == "." and not floor.holes[cellKey(row, col)] then
			for _, d in DIRECTIONS do
				local key = faceKey(floor, row, col, d[1], d[2])
				if isPlainWall(plan, row, col, d[1], d[2]) and not ctx.usedFaces[key] then
					ctx.usedFaces[key] = true
					local offset = WALL_FACE - 0.04
					local frame = CFrame.new(
						cellCenter(col) + d[1] * offset,
						floor.y0 + FLOOR_TOP + PICTURE_HEIGHT,
						cellCenter(row) + d[2] * offset
					) * CFrame.Angles(0, math.atan2(d[1], d[2]), 0)
					decor(ctx, "PictureFrame", V(2.6, 1.9, 0.12), frame, S.DarkWood)
					decor(
						ctx,
						"Picture",
						V(2.2, 1.5, 0.05),
						frame * CFrame.new(0, 0, -0.07),
						PartFactory.pick(Palette.Goods, `{ctx.key}{floor.index}{room.id}picture`)
					)
					return
				end
			end
		end
	end
end

local function buildRoomDecor(ctx: Ctx, floor: Floor)
	for _, room in floor.rooms.list do
		local kind = floor.styles[room.id].kind
		if not ctx.template.open then
			ceilingLights(ctx, floor, room)
		end
		local rugSize = RUG_SIZES[kind]
		if rugSize and not ctx.template.panels then
			rug(ctx, floor, room, rugSize)
		end
		if PICTURE_ROOMS[kind] then
			picture(ctx, floor, room)
		end
	end
end

local function buildCeiling(ctx: Ctx, topY: number)
	if not ctx.enclosed or ctx.template.open then
		return
	end
	-- Edges stop at the exterior wall centre lines, hidden inside the walls.
	local x0, x1 = cellCenter(1), cellCenter(ctx.cols)
	local z0, z1 = cellCenter(1), cellCenter(ctx.rows)
	add(
		ctx,
		"Ceiling",
		V(x1 - x0, CEILING, z1 - z0),
		CFrame.new((x0 + x1) / 2, topY - CEILING / 2, (z0 + z1) / 2),
		S.Ceiling,
		{ castShadow = false }
	)
end

-- Chimney position: above the fireplace when the top floor has one, else near a back corner.
local function chimneySpot(ctx: Ctx): (number, number)
	local plan = ctx.template.floors[ctx.floorCount]
	for row = 1, ctx.rows do
		for col = 1, ctx.cols do
			if FloorPlan.charAt(plan, row, col) == "F" then
				local dx, dz = FloorPlan.facing(plan, row, col)
				local reach = WALL_FACE - CHIMNEY_SIZE / 2
				return cellCenter(col) + dx * reach, cellCenter(row) + dz * reach
			end
		end
	end
	return ctx.maxX - CHIMNEY_SIZE - 1, (ctx.minZ + ctx.maxZ) / 2 + CHIMNEY_SIZE
end

local function buildGableRoof(ctx: Ctx, topY: number)
	local width = ctx.maxX - ctx.minX
	local half = (ctx.maxZ - ctx.minZ) / 2
	local cx, midZ = (ctx.minX + ctx.maxX) / 2, (ctx.minZ + ctx.maxZ) / 2
	local rise = math.min(ROOF_MAX_RISE, half * ROOF_PITCH)
	local slope = rise / half
	local angle = math.atan(slope)
	local run = half + ROOF_OVERHANG
	local length = run / math.cos(angle)
	local planeWidth = width + ROOF_OVERHANG * 2
	local eaveY = topY - ROOF_OVERHANG * slope
	local roofThickness = ROOF_THICKNESS / math.cos(angle)

	for _, side in { -1, 1 } do
		-- The underside runs from the eave to the ridge through the top outer edge of the wall.
		local cf = CFrame.new(cx, (eaveY + topY + rise) / 2, midZ + side * run / 2)
			* CFrame.Angles(if side < 0 then -angle else angle, 0, 0)
			* CFrame.new(0, ROOF_THICKNESS / 2, 0)
		add(ctx, "Roof", V(planeWidth, ROOF_THICKNESS, length), cf, ctx.roof)
		decor(
			ctx,
			"Fascia",
			V(planeWidth, 0.7, 0.25),
			CFrame.new(cx, eaveY + 0.1, midZ + side * (run + 0.1)),
			ctx.trim
		)
	end
	decor(
		ctx,
		"RidgeCap",
		V(planeWidth, 0.5, 1.4),
		CFrame.new(cx, topY + rise + roofThickness - 0.1, midZ),
		ctx.roof
	)

	if ctx.enclosed then
		-- Triangular gable walls; a WedgePart is full height at its +Z end.
		for _, x in { ctx.minX + WALL / 2, ctx.maxX - WALL / 2 } do
			for _, side in { -1, 1 } do
				local cf = CFrame.new(x, topY + rise / 2, midZ + side * half / 2)
					* (if side > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity)
				add(ctx, "Gable", V(WALL, rise, half), cf, ctx.exterior, { className = "WedgePart" })
			end
			local out = if x < cx then -1 else 1
			decor(
				ctx,
				"GableVent",
				V(0.2, 1.4, 2.2),
				CFrame.new(x + out * (WALL / 2 + 0.1), topY + rise * 0.4, midZ),
				ctx.trim
			)
		end
	end

	-- Open sheds and barns show their trusses: tie beams with a king post.
	if ctx.template.open then
		local x = ctx.minX + TIE_BEAM_SPACING
		while x < ctx.maxX - TIE_BEAM_SPACING / 2 do
			decor(ctx, "TieBeam", V(0.6, 0.8, ctx.maxZ - ctx.minZ), CFrame.new(x, topY - 0.4, midZ), S.DarkWood)
			decor(ctx, "KingPost", V(0.5, rise, 0.5), CFrame.new(x, topY + rise / 2, midZ), S.DarkWood)
			x += TIE_BEAM_SPACING
		end
	end

	if ctx.template.chimney then
		local x, z = chimneySpot(ctx)
		-- Clear the roof on the chimney's uphill side.
		local distance = math.max(0, math.abs(z - midZ) - CHIMNEY_SIZE / 2)
		local top = topY + rise - distance * slope + roofThickness + CHIMNEY_ABOVE_ROOF
		add(ctx, "Chimney", V(CHIMNEY_SIZE, top - topY, CHIMNEY_SIZE), CFrame.new(x, (top + topY) / 2, z), S.Brick)
		decor(
			ctx,
			"ChimneyCap",
			V(CHIMNEY_SIZE + 0.6, 0.4, CHIMNEY_SIZE + 0.6),
			CFrame.new(x, top + 0.2, z),
			S.Concrete
		)
	end
end

local function buildFlatRoof(ctx: Ctx, topY: number)
	local width, depth = ctx.maxX - ctx.minX, ctx.maxZ - ctx.minZ
	local cx, cz = (ctx.minX + ctx.maxX) / 2, (ctx.minZ + ctx.maxZ) / 2
	add(
		ctx,
		"Roof",
		V(width + FLAT_ROOF_OVERHANG * 2, FLAT_ROOF_THICKNESS, depth + FLAT_ROOF_OVERHANG * 2),
		CFrame.new(cx, topY + FLAT_ROOF_THICKNESS / 2, cz),
		ctx.roof
	)
	local y = topY + FLAT_ROOF_THICKNESS + PARAPET_HEIGHT / 2
	local capY = y + PARAPET_HEIGHT / 2 + 0.125
	for _, side in { -1, 1 } do
		local z = cz + side * (depth / 2 - WALL / 2)
		add(ctx, "Parapet", V(width, PARAPET_HEIGHT, WALL), CFrame.new(cx, y, z), ctx.exterior)
		decor(ctx, "ParapetCap", V(width + 0.4, 0.25, WALL + 0.4), CFrame.new(cx, capY, z), S.Concrete)
		local x = cx + side * (width / 2 - WALL / 2)
		add(ctx, "Parapet", V(WALL, PARAPET_HEIGHT, depth - WALL * 2), CFrame.new(x, y, cz), ctx.exterior)
		decor(ctx, "ParapetCap", V(WALL + 0.4, 0.25, depth - WALL * 2), CFrame.new(x, capY, cz), S.Concrete)
	end
	-- Rooftop air conditioner, vent and hatch; mirrored per building.
	local roofY = topY + FLAT_ROOF_THICKNESS
	local shift = if PartFactory.pick({ true, false }, ctx.key) then 1 else -1
	local unitX, unitZ = cx + shift * width * 0.22, cz + depth * 0.15
	add(ctx, "RoofUnit", V(4, 2.4, 3), CFrame.new(unitX, roofY + 1.2, unitZ), S.Steel)
	decor(ctx, "RoofUnitFan", V(2.6, 0.2, 2.2), CFrame.new(unitX, roofY + 2.5, unitZ), S.Screen)
	decor(ctx, "Vent", V(0.8, 2, 0.8), CFrame.new(cx - shift * width * 0.25, roofY + 1, cz - depth * 0.2), S.Steel)
	decor(ctx, "Hatch", V(3, 0.5, 3), CFrame.new(cx - shift * width * 0.1, roofY + 0.25, cz + depth * 0.28), S.Steel)
end

local function buildSign(ctx: Ctx, key: string)
	local width = ctx.maxX - ctx.minX
	local board = decor(
		ctx,
		"Sign",
		V(math.min(SIGN_MAX_WIDTH, width - SIGN_MARGIN), SIGN_HEIGHT, 0.3),
		CFrame.new((ctx.minX + ctx.maxX) / 2, FLOOR_HEIGHT - 0.3 - SIGN_HEIGHT / 2, ctx.minZ - 0.15),
		S.SignBoard
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = SIGN_PIXELS_PER_STUD
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.92, 0.78)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(244, 232, 196)
	label.Text = Localization.get(key)
	label:SetAttribute("TextKey", key)
	label.Parent = gui
	gui.Parent = board
end

-- Facade dressing: corner boards, belt courses between floors, street sign.
local function buildFacade(ctx: Ctx, topY: number)
	if not ctx.enclosed then
		return
	end
	local width, depth = ctx.maxX - ctx.minX, ctx.maxZ - ctx.minZ
	local cx, cz = (ctx.minX + ctx.maxX) / 2, (ctx.minZ + ctx.maxZ) / 2
	if ctx.template.shutters then
		local inset = CORNER_BOARD / 2 - 0.1
		local height = topY - SLAB_TOP
		for _, x in { ctx.minX + inset, ctx.maxX - inset } do
			for _, z in { ctx.minZ + inset, ctx.maxZ - inset } do
				decor(
					ctx,
					"CornerBoard",
					V(CORNER_BOARD, height, CORNER_BOARD),
					CFrame.new(x, SLAB_TOP + height / 2, z),
					ctx.trim
				)
			end
		end
	end
	for index = 2, ctx.floorCount do
		local y = (index - 1) * FLOOR_HEIGHT + SLAB_TOP / 2
		for _, side in { -1, 1 } do
			decor(ctx, "Belt", V(width + 0.3, BELT_HEIGHT, 0.3), CFrame.new(cx, y, cz + side * depth / 2), ctx.trim)
			decor(ctx, "Belt", V(0.3, BELT_HEIGHT, depth + 0.3), CFrame.new(cx + side * width / 2, y, cz), ctx.trim)
		end
	end
	if ctx.template.sign then
		buildSign(ctx, ctx.template.sign)
	end
end

local function roomStyleFor(ctx: Ctx, kind: string, salt: string): RoomStyle
	local template = ctx.template
	if kind == "Bathroom" then
		return { wall = S.BathTile, floor = S.BathFloor, kind = kind }
	end
	if template.interior then
		return { wall = S[template.interior], floor = S[template.floor], kind = kind }
	end
	if kind == "Kitchen" then
		return { wall = S.KitchenPaint, floor = S.KitchenTile, kind = kind }
	end
	if kind == "Hall" then
		return { wall = S.Plaster, floor = S[template.floor], kind = kind }
	end
	local paint = PartFactory.pick(Palette.Paints, ctx.key .. salt)
	if kind == "Bedroom" then
		return { wall = paint, floor = PartFactory.pick(Palette.Carpets, ctx.key .. salt), kind = kind }
	end
	return { wall = paint, floor = S[template.floor], kind = kind }
end

local function isEnclosed(plan: { string }): boolean
	local rows, cols = FloorPlan.size(plan)
	for row = 1, rows do
		for col = 1, cols do
			local border = row == 1 or row == rows or col == 1 or col == cols
			if border and not FloorPlan.isWall(plan, row, col) then
				return false
			end
		end
	end
	return true
end

-- Size of a template footprint after rotation, in studs (x, z).
function BuildingKit.footprint(templateName: string, rotation: number): (number, number)
	local plan = BuildingTemplates[templateName].floors[1]
	local width, depth = #plan[1] * CELL, #plan * CELL
	if rotation % 2 == 1 then
		return depth, width
	end
	return width, depth
end

-- Terrain surface to lay under a template's footprint.
function BuildingKit.apron(templateName: string): string
	return BuildingTemplates[templateName].apron or "Ground"
end

-- Stairs and upper-floor cells in world space, for the zombie navigation of upper floors.
local function navInfo(ctx: Ctx, floors: { Floor }): NavInfo
	local info: NavInfo = { stairs = {}, upperCells = {} }
	for index, floor in floors do
		local surface = floor.y0 + FLOOR_TOP
		if index > 1 then
			for row = 1, ctx.rows do
				for col = 1, ctx.cols do
					if isFloorCell(floor, row, col) or FloorPlan.charAt(floor.plan, row, col) == "D" then
						table.insert(info.upperCells, ctx.transform * V(cellCenter(col), surface, cellCenter(row)))
					end
				end
			end
		end
		if floors[index + 1] then
			for _, stair in FloorPlan.stairs(floor.plan) do
				local entry, exit = FloorPlan.stairEnds(stair)
				table.insert(info.stairs, {
					floor = index,
					foot = ctx.transform * V(cellCenter(entry[2]), surface, cellCenter(entry[1])),
					top = ctx.transform * V(cellCenter(exit[2]), surface + FLOOR_HEIGHT, cellCenter(exit[1])),
					cells = #stair.cells,
				})
			end
		end
	end
	return info
end

-- Builds the placement on ground height baseY. Also returns the world point in front of every
-- exterior doorway, which street furniture must leave free, and the stairs and upper-floor cells.
function BuildingKit.build(
	placement: WorldLayout.BuildingPlacement,
	baseY: number,
	parent: Instance
): (Model, { Vector3 }, NavInfo)
	local template = BuildingTemplates[placement.template]
	assert(template, `unknown building template {placement.template}`)
	local plan1 = template.floors[1]
	local rows, cols = FloorPlan.size(plan1)
	local width, depth = cols * CELL, rows * CELL

	-- Rotate the template box around Y (quarter turns, front -Z -> +X -> +Z -> -X) and move its
	-- rotated min corner onto the placement corner.
	local rotation = CFrame.Angles(0, -placement.rotation * math.pi / 2, 0)
	local minX, minZ = math.huge, math.huge
	for _, corner in { Vector3.zero, V(width, 0, 0), V(0, 0, depth), V(width, 0, depth) } do
		local p = rotation * corner
		minX = math.min(minX, p.X)
		minZ = math.min(minZ, p.Z)
	end

	local model = Instance.new("Model")
	model.Name = placement.name
	model:SetAttribute("Template", placement.template)
	model:SetAttribute("Loot", placement.loot)
	model:SetAttribute("Floors", #template.floors)

	local key = placement.name
	local ctx: Ctx = {
		model = model,
		transform = CFrame.new(placement.x - minX, baseY, placement.z - minZ) * rotation,
		key = key,
		template = template,
		rows = rows,
		cols = cols,
		floorCount = #template.floors,
		enclosed = isEnclosed(plan1),
		minX = cellCenter(1) - WALL / 2,
		maxX = cellCenter(cols) + WALL / 2,
		minZ = cellCenter(1) - WALL / 2,
		maxZ = cellCenter(rows) + WALL / 2,
		exterior = if template.wall == "Siding" then PartFactory.pick(Palette.Siding, key) else S[template.wall],
		partition = if template.interior then S[template.interior] else S.Plaster,
		trim = S[template.trim or "Trim"],
		roof = if template.roofStyle == "Shingles"
			then PartFactory.pick(Palette.Shingles, key)
			else S[template.roofStyle],
		usedFaces = {},
		doorFronts = {},
	}

	-- Foundation plinth: just past the walls (a small lip) for closed buildings, the whole footprint
	-- for open sheds. It reaches below ground so slopes never show a gap.
	local x0, x1, z0, z1 = 0, width, 0, depth
	if ctx.enclosed then
		x0, x1 = ctx.minX - PLINTH_LIP, ctx.maxX + PLINTH_LIP
		z0, z1 = ctx.minZ - PLINTH_LIP, ctx.maxZ + PLINTH_LIP
	end
	local foundation = add(
		ctx,
		"Foundation",
		V(x1 - x0, FOUNDATION_DEPTH + SLAB_TOP, z1 - z0),
		CFrame.new((x0 + x1) / 2, (SLAB_TOP - FOUNDATION_DEPTH) / 2, (z0 + z1) / 2),
		S.Foundation
	)
	model.PrimaryPart = foundation

	local floors: { Floor } = {}
	local holes: { [number]: boolean } = {}
	for index, plan in template.floors do
		local floor: Floor = {
			index = index,
			plan = plan,
			rooms = FloorPlan.rooms(plan),
			styles = {},
			y0 = (index - 1) * FLOOR_HEIGHT,
			holes = holes,
			isTop = index == #template.floors,
		}
		for _, room in floor.rooms.list do
			floor.styles[room.id] = roomStyleFor(ctx, room.kind, `{index}:{room.id}`)
		end
		table.insert(floors, floor)
		-- Stairs on this floor open holes in the next one.
		holes = {}
		for _, stair in FloorPlan.stairs(plan) do
			for _, cell in stair.cells do
				holes[cellKey(cell[1], cell[2])] = true
			end
		end
	end

	for index, floor in floors do
		buildFloorSlabs(ctx, floor)
		buildWalls(ctx, floor)
		buildPosts(ctx, floor)
		buildStairs(ctx, floor, floors[index + 1])
		buildFurniture(ctx, floor)
		buildRoomDecor(ctx, floor)
	end

	local topY = #floors * FLOOR_HEIGHT
	buildCeiling(ctx, topY)
	if template.roof == "Gable" then
		buildGableRoof(ctx, topY)
	else
		buildFlatRoof(ctx, topY)
	end
	buildFacade(ctx, topY)

	model.Parent = parent
	return model, ctx.doorFronts, navInfo(ctx, floors)
end

BuildingKit.FloorHeight = FLOOR_HEIGHT
-- Walking surface of the ground floor above the building's base height.
BuildingKit.FloorTop = FLOOR_TOP
-- Steps per flight; the walking ramp runs half a riser above the straight line between floors.
BuildingKit.StepCount = STEP_COUNT

return BuildingKit
