--!strict
-- Turns a BuildingTemplate floor plan into a Model. Geometry is generated in template space (x along
-- columns, z along rows, origin at the footprint's min corner) and then rotated/moved into place.
-- Walls run along cell centre lines, so a wall blocks exactly one row of navigation cells and
-- doorways stay walkable.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local WorldLayout = require(ReplicatedStorage.Shared.World.WorldLayout)

local BuildingTemplates = require(script.Parent.BuildingTemplates)
local Palette = require(script.Parent.Palette)
local PartFactory = require(script.Parent.PartFactory)

local BuildingKit = {}

local S = Palette.Styles
local CELL = Config.Build.GridSize

-- Architectural dimensions (studs).
local FLOOR_HEIGHT = 12
local WALL_THICKNESS = 1
local FLOOR_THICKNESS = 0.6
local FOUNDATION_DEPTH = 2
local WINDOW_SILL = 4
local WINDOW_TOP = 9
local DOOR_TOP = 9
local SHOP_SILL = 1
local GLASS_THICKNESS = 0.3
local POST_SIZE = 1.2
local STEP_COUNT = 8
local STAIR_INSET = 0.4
local ROOF_PITCH = 0.5
local ROOF_MAX_HEIGHT = 14
local ROOF_OVERHANG = 1.5
local ROOF_THICKNESS = 0.8
local PARAPET_HEIGHT = 1.5

local WALL_CHARS = { ["#"] = true, W = true, D = true, G = true }
local STAIR_DIRECTIONS: { [string]: { number } } = {
	["^"] = { 0, -1 },
	["v"] = { 0, 1 },
	["<"] = { -1, 0 },
	[">"] = { 1, 0 },
}

type Ctx = {
	model: Model,
	transform: CFrame,
	baseY: number,
	wallStyle: Palette.Style,
	floorStyle: Palette.Style,
	name: string,
}

local function add(
	ctx: Ctx,
	name: string,
	size: Vector3,
	localCFrame: CFrame,
	style: Palette.Style,
	options: PartFactory.Options?
): BasePart
	return PartFactory.make(ctx.model, name, size, ctx.transform * localCFrame, style, options)
end

local function cellCenter(index: number): number
	return (index - 0.5) * CELL
end

local function charAt(plan: { string }, row: number, col: number): string
	local line = plan[row]
	if line == nil or col < 1 or col > #line then
		return " "
	end
	return string.sub(line, col, col)
end

local function isWall(plan: { string }, row: number, col: number): boolean
	return WALL_CHARS[charAt(plan, row, col)] == true
end

-- Vertical pieces of one wall segment: { bottom, top, style, thickness }.
local function wallPieces(kind: string, wallStyle: Palette.Style): { { any } }
	if kind == "W" then
		return {
			{ 0, WINDOW_SILL, wallStyle, WALL_THICKNESS },
			{ WINDOW_TOP, FLOOR_HEIGHT, wallStyle, WALL_THICKNESS },
			{ WINDOW_SILL, WINDOW_TOP, S.Glass, GLASS_THICKNESS },
		}
	elseif kind == "G" then
		return {
			{ 0, SHOP_SILL, wallStyle, WALL_THICKNESS },
			{ WINDOW_TOP, FLOOR_HEIGHT, wallStyle, WALL_THICKNESS },
			{ SHOP_SILL, WINDOW_TOP, S.Glass, GLASS_THICKNESS },
		}
	elseif kind == "D" then
		return { { DOOR_TOP, FLOOR_HEIGHT, wallStyle, WALL_THICKNESS } }
	end
	return { { 0, FLOOR_HEIGHT, wallStyle, WALL_THICKNESS } }
end

-- Emits a wall segment along `axis` ("x" or "z") from lo to hi at the fixed cross coordinate.
local function emitSegment(ctx: Ctx, axis: string, lo: number, hi: number, fixed: number, kind: string, y0: number)
	local length = hi - lo
	local center = (lo + hi) / 2
	for _, piece in wallPieces(kind, ctx.wallStyle) do
		local bottom, top, style, thickness = piece[1], piece[2], piece[3], piece[4]
		local height = top - bottom
		local y = y0 + bottom + height / 2
		if axis == "x" then
			add(ctx, "Wall", Vector3.new(length, height, thickness), CFrame.new(center, y, fixed), style)
		else
			add(ctx, "Wall", Vector3.new(thickness, height, length), CFrame.new(fixed, y, center), style)
		end
	end
end

-- Builds one straight run of wall cells, merging neighbouring cells of the same kind.
local function emitRun(ctx: Ctx, axis: string, cells: { { any } }, fixed: number, y0: number)
	-- cells: { index, kind } in order; ends stop at the end cell's centre (+ half thickness).
	local first, last = cells[1][1], cells[#cells][1]
	local segmentKind: string? = nil
	local segmentLo = 0
	local segmentHi = 0
	for _, cell in cells do
		local index, kind = cell[1], cell[2]
		local lo = if index == first then cellCenter(index) - WALL_THICKNESS / 2 else (index - 1) * CELL
		local hi = if index == last then cellCenter(index) + WALL_THICKNESS / 2 else index * CELL
		if kind == segmentKind then
			segmentHi = hi
		else
			if segmentKind then
				emitSegment(ctx, axis, segmentLo, segmentHi, fixed, segmentKind, y0)
			end
			segmentKind, segmentLo, segmentHi = kind, lo, hi
		end
	end
	if segmentKind then
		emitSegment(ctx, axis, segmentLo, segmentHi, fixed, segmentKind, y0)
	end
end

local function buildWalls(ctx: Ctx, plan: { string }, y0: number)
	local rows = #plan
	local cols = #plan[1]
	local connected: { [number]: boolean } = {}

	-- Horizontal runs (along x).
	for row = 1, rows do
		local run: { { any } } = {}
		for col = 1, cols + 1 do
			local horizontal = isWall(plan, row, col)
				and (isWall(plan, row, col - 1) or isWall(plan, row, col + 1))
			if horizontal then
				table.insert(run, { col, charAt(plan, row, col) })
				connected[row * 1000 + col] = true
			elseif #run > 0 then
				emitRun(ctx, "x", run, cellCenter(row), y0)
				run = {}
			end
		end
	end

	-- Vertical runs (along z).
	for col = 1, cols do
		local run: { { any } } = {}
		for row = 1, rows + 1 do
			local vertical = isWall(plan, row, col)
				and (isWall(plan, row - 1, col) or isWall(plan, row + 1, col))
			if vertical then
				table.insert(run, { row, charAt(plan, row, col) })
				connected[row * 1000 + col] = true
			elseif #run > 0 then
				emitRun(ctx, "z", run, cellCenter(col), y0)
				run = {}
			end
		end
	end

	-- Isolated wall cells become short pillars.
	for row = 1, rows do
		for col = 1, cols do
			if isWall(plan, row, col) and not connected[row * 1000 + col] then
				add(
					ctx,
					"Pillar",
					Vector3.new(WALL_THICKNESS * 2, FLOOR_HEIGHT, WALL_THICKNESS * 2),
					CFrame.new(cellCenter(col), y0 + FLOOR_HEIGHT / 2, cellCenter(row)),
					ctx.wallStyle
				)
			end
		end
	end
end

-- Floor slab for an upper floor, skipping holes above stairs; merged per row.
local function buildUpperFloor(ctx: Ctx, plan: { string }, holes: { [number]: boolean }, y0: number)
	for row = 1, #plan do
		local startCol: number? = nil
		local cols = #plan[row]
		for col = 1, cols + 1 do
			local solid = col <= cols and charAt(plan, row, col) ~= " " and not holes[row * 1000 + col]
			if solid and startCol == nil then
				startCol = col
			elseif not solid and startCol then
				local from = startCol :: number
				local width = (col - from) * CELL
				add(
					ctx,
					"Floor",
					Vector3.new(width, FLOOR_THICKNESS, CELL),
					CFrame.new((from - 1) * CELL + width / 2, y0 + FLOOR_THICKNESS / 2, cellCenter(row)),
					ctx.floorStyle
				)
				startCol = nil
			end
		end
	end
end

local function buildStairs(ctx: Ctx, plan: { string }, y0: number, holes: { [number]: boolean })
	local visited: { [number]: boolean } = {}
	for row = 1, #plan do
		for col = 1, #plan[row] do
			local char = charAt(plan, row, col)
			local dir = STAIR_DIRECTIONS[char]
			if dir and not visited[row * 1000 + col] then
				-- Collect the run along the stair axis.
				local cells = {}
				local r, c = row, col
				while charAt(plan, r, c) == char do
					visited[r * 1000 + c] = true
					holes[r * 1000 + c] = true
					table.insert(cells, { r, c })
					r += math.abs(dir[2])
					c += math.abs(dir[1])
				end
				local count = #cells
				local length = count * CELL
				local width = CELL - STAIR_INSET
				local firstRow, firstCol = cells[1][1], cells[1][2]
				local lastRow, lastCol = cells[count][1], cells[count][2]
				local centerX = (cellCenter(firstCol) + cellCenter(lastCol)) / 2
				local centerZ = (cellCenter(firstRow) + cellCenter(lastRow)) / 2
				local dx, dz = dir[1], dir[2]
				-- Start of the climb (low end) along the run.
				local startX = centerX - dx * length / 2
				local startZ = centerZ - dz * length / 2
				local tread = length / STEP_COUNT
				for step = 1, STEP_COUNT do
					local height = FLOOR_HEIGHT * step / STEP_COUNT
					local along = (step - 0.5) * tread
					local size = if dx ~= 0
						then Vector3.new(tread, height, width)
						else Vector3.new(width, height, tread)
					add(
						ctx,
						"Step",
						size,
						CFrame.new(startX + dx * along, y0 + height / 2, startZ + dz * along),
						S.DarkWood,
						{ canCollide = false }
					)
				end
				-- Invisible ramp for smooth walking; a WedgePart rises toward its +Z (local) side.
				local yaw = math.atan2(-dx, -dz) + math.pi
				local ramp = add(
					ctx,
					"StairRamp",
					Vector3.new(width, FLOOR_HEIGHT, length),
					CFrame.new(centerX, y0 + FLOOR_HEIGHT / 2, centerZ) * CFrame.Angles(0, yaw, 0),
					S.DarkWood,
					{ className = "WedgePart" }
				)
				ramp.Transparency = 1
			end
		end
	end
end

type FurnitureBuilder = (ctx: Ctx, x: number, y: number, z: number) -> ()

local function box(ctx: Ctx, name: string, size: Vector3, x: number, y: number, z: number, style: Palette.Style)
	add(ctx, name, size, CFrame.new(x, y + size.Y / 2, z), style)
end

local Furniture: { [string]: FurnitureBuilder } = {
	b = function(ctx, x, y, z)
		box(ctx, "BedFrame", Vector3.new(3, 1.2, 3.6), x, y, z, S.Wood)
		box(ctx, "Mattress", Vector3.new(2.8, 0.6, 3.4), x, y + 1.2, z, S.Sheet)
		box(ctx, "Blanket", Vector3.new(2.9, 0.2, 2.2), x, y + 1.8, z + 0.6, S.Fabric)
	end,
	t = function(ctx, x, y, z)
		box(ctx, "TableLeg", Vector3.new(0.6, 2.8, 0.6), x, y, z, S.DarkWood)
		box(ctx, "TableTop", Vector3.new(3.2, 0.3, 3.2), x, y + 2.8, z, S.Wood)
	end,
	s = function(ctx, x, y, z)
		box(ctx, "Shelf", Vector3.new(3.6, 6, 1.6), x, y, z, S.Steel)
		box(ctx, "Goods", Vector3.new(3.2, 1, 1.2), x, y + 2, z, S.Goods)
		box(ctx, "Goods", Vector3.new(3.2, 1, 1.2), x, y + 4, z, S.GoodsAlt)
	end,
	k = function(ctx, x, y, z)
		box(ctx, "Counter", Vector3.new(3.8, 3, 2.4), x, y, z, S.Wood)
		box(ctx, "CounterTop", Vector3.new(3.9, 0.3, 2.5), x, y + 3, z, S.Appliance)
	end,
	f = function(ctx, x, y, z)
		box(ctx, "Fridge", Vector3.new(2.6, 6.4, 2.4), x, y, z, S.Appliance)
	end,
	o = function(ctx, x, y, z)
		box(ctx, "SofaSeat", Vector3.new(3.6, 1.6, 2.2), x, y, z, S.Fabric)
		box(ctx, "SofaBack", Vector3.new(3.6, 2.2, 0.7), x, y + 1.6, z + 0.75, S.Fabric)
	end,
	r = function(ctx, x, y, z)
		box(ctx, "Bookshelf", Vector3.new(3.6, 7, 1.2), x, y, z, S.DarkWood)
		box(ctx, "Books", Vector3.new(3.2, 1.2, 1), x, y + 4.5, z, S.Red)
	end,
	x = function(ctx, x, y, z)
		box(ctx, "Crate", Vector3.new(3, 3, 3), x, y, z, S.Wood)
	end,
	h = function(ctx, x, y, z)
		box(ctx, "HospitalBed", Vector3.new(2.8, 2, 3.6), x, y, z, S.Steel)
		box(ctx, "Sheet", Vector3.new(2.6, 0.4, 3.4), x, y + 2, z, S.Sheet)
	end,
	m = function(ctx, x, y, z)
		box(ctx, "MedCabinet", Vector3.new(3, 6, 1.4), x, y, z, S.Appliance)
		box(ctx, "MedCross", Vector3.new(1.4, 0.4, 1.5), x, y + 4.5, z, S.Red)
	end,
	C = function(ctx, x, y, z)
		box(ctx, "Checkout", Vector3.new(3.8, 3.4, 2), x, y, z, S.DarkWood)
	end,
	w = function(ctx, x, y, z)
		box(ctx, "Workbench", Vector3.new(3.6, 3, 2.2), x, y, z, S.Wood)
		box(ctx, "Vise", Vector3.new(0.8, 0.8, 0.8), x + 1, y + 3, z, S.Steel)
	end,
	d = function(ctx, x, y, z)
		box(ctx, "Desk", Vector3.new(3.4, 2.8, 2), x, y, z, S.DarkWood)
		box(ctx, "Monitor", Vector3.new(1.4, 1, 0.3), x, y + 2.8, z, S.Tire)
	end,
	B = function(ctx, x, y, z)
		box(ctx, "Booth", Vector3.new(3.6, 1.8, 3.4), x, y, z, S.Red)
	end,
	H = function(ctx, x, y, z)
		box(ctx, "HayBale", Vector3.new(3.6, 2.4, 2.6), x, y, z, S.Hay)
	end,
}

local function buildFurniture(ctx: Ctx, plan: { string }, y0: number)
	for row = 1, #plan do
		for col = 1, #plan[row] do
			local builder = Furniture[charAt(plan, row, col)]
			if builder then
				builder(ctx, cellCenter(col), y0 + FLOOR_THICKNESS, cellCenter(row))
			end
		end
	end
end

local function buildPosts(ctx: Ctx, plan: { string }, y0: number)
	for row = 1, #plan do
		for col = 1, #plan[row] do
			if charAt(plan, row, col) == "P" then
				add(
					ctx,
					"Post",
					Vector3.new(POST_SIZE, FLOOR_HEIGHT, POST_SIZE),
					CFrame.new(cellCenter(col), y0 + FLOOR_HEIGHT / 2, cellCenter(row)),
					S.DarkWood
				)
			end
		end
	end
end

local function buildRoof(ctx: Ctx, template: BuildingTemplates.Template, width: number, depth: number, top: number)
	local style = S[template.roofStyle]
	if template.roof == "Gable" then
		local halfDepth = depth / 2 + ROOF_OVERHANG
		local height = math.min(ROOF_MAX_HEIGHT, halfDepth * ROOF_PITCH)
		local size = Vector3.new(width + ROOF_OVERHANG * 2, height, halfDepth)
		local y = top + height / 2
		-- A WedgePart slopes down toward its -Z side; the back half is the same wedge turned around.
		add(ctx, "RoofFront", size, CFrame.new(width / 2, y, depth / 2 - halfDepth / 2), style, {
			className = "WedgePart",
		})
		add(
			ctx,
			"RoofBack",
			size,
			CFrame.new(width / 2, y, depth / 2 + halfDepth / 2) * CFrame.Angles(0, math.pi, 0),
			style,
			{ className = "WedgePart" }
		)
	else
		add(
			ctx,
			"Roof",
			Vector3.new(width, ROOF_THICKNESS, depth),
			CFrame.new(width / 2, top + ROOF_THICKNESS / 2, depth / 2),
			style
		)
		local y = top + ROOF_THICKNESS + PARAPET_HEIGHT / 2
		local parapetStyle = ctx.wallStyle
		add(ctx, "Parapet", Vector3.new(width, PARAPET_HEIGHT, WALL_THICKNESS), CFrame.new(width / 2, y, 0.5), parapetStyle)
		add(
			ctx,
			"Parapet",
			Vector3.new(width, PARAPET_HEIGHT, WALL_THICKNESS),
			CFrame.new(width / 2, y, depth - 0.5),
			parapetStyle
		)
		add(ctx, "Parapet", Vector3.new(WALL_THICKNESS, PARAPET_HEIGHT, depth), CFrame.new(0.5, y, depth / 2), parapetStyle)
		add(
			ctx,
			"Parapet",
			Vector3.new(WALL_THICKNESS, PARAPET_HEIGHT, depth),
			CFrame.new(width - 0.5, y, depth / 2),
			parapetStyle
		)
	end
end

-- Size of a template footprint after rotation, in studs (x, z).
function BuildingKit.footprint(templateName: string, rotation: number): (number, number)
	local template = BuildingTemplates[templateName]
	local plan = template.floors[1]
	local width, depth = #plan[1] * CELL, #plan * CELL
	if rotation % 2 == 1 then
		return depth, width
	end
	return width, depth
end

function BuildingKit.build(placement: WorldLayout.BuildingPlacement, baseY: number, parent: Instance): Model
	local template = BuildingTemplates[placement.template]
	assert(template, `unknown building template {placement.template}`)
	local plan1 = template.floors[1]
	local width, depth = #plan1[1] * CELL, #plan1 * CELL

	-- Rotate the template box around Y (quarter turns, front -Z -> +X -> +Z -> -X) and move its
	-- rotated min corner onto the placement corner.
	local rotation = CFrame.Angles(0, -placement.rotation * math.pi / 2, 0)
	local minX, minZ = math.huge, math.huge
	for _, corner in { Vector3.zero, Vector3.new(width, 0, 0), Vector3.new(0, 0, depth), Vector3.new(width, 0, depth) } do
		local p = rotation * corner
		minX = math.min(minX, p.X)
		minZ = math.min(minZ, p.Z)
	end
	local transform = CFrame.new(placement.x - minX, baseY, placement.z - minZ) * rotation

	local model = Instance.new("Model")
	model.Name = placement.name
	model:SetAttribute("Template", placement.template)
	model:SetAttribute("Loot", placement.loot)

	local wallStyle = if template.wall == "Siding"
		then PartFactory.pick(Palette.Siding, placement.name)
		else S[template.wall]
	local ctx: Ctx = {
		model = model,
		transform = transform,
		baseY = baseY,
		wallStyle = wallStyle,
		floorStyle = S[template.floor],
		name = placement.name,
	}

	-- Foundation doubles as the ground floor.
	local foundation = add(
		ctx,
		"Foundation",
		Vector3.new(width, FOUNDATION_DEPTH + FLOOR_THICKNESS, depth),
		CFrame.new(width / 2, (FLOOR_THICKNESS - FOUNDATION_DEPTH) / 2, depth / 2),
		ctx.floorStyle
	)
	model.PrimaryPart = foundation

	local holes: { [number]: boolean } = {}
	for index, plan in template.floors do
		local y0 = (index - 1) * FLOOR_HEIGHT
		if index > 1 then
			buildUpperFloor(ctx, plan, holes, y0)
			holes = {}
		end
		buildWalls(ctx, plan, y0)
		buildPosts(ctx, plan, y0)
		buildStairs(ctx, plan, y0, holes)
		buildFurniture(ctx, plan, y0)
	end

	buildRoof(ctx, template, width, depth, #template.floors * FLOOR_HEIGHT)
	model.Parent = parent
	return model
end

BuildingKit.FloorHeight = FLOOR_HEIGHT

return BuildingKit
