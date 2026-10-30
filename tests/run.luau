--!strict
-- Minimal test runner for pure modules. Run with: lune run tests/run

local NavGrid = require("../src/shared/NavGrid")
local ZombieProtocol = require("../src/shared/ZombieProtocol")
local HeightField = require("../src/shared/World/HeightField")
local WorldLayout = require("../src/shared/World/WorldLayout")
local BuildingTemplates = require("../src/server/World/BuildingTemplates")
local FloorPlan = require("../src/server/World/FloorPlan")
local Config = require("../src/shared/Config")
local ZombieLook = require("../src/shared/ZombieLook")

local passed, failed = 0, 0

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print(`  ok   {name}`)
	else
		failed += 1
		print(`  FAIL {name}\n       {err}`)
	end
end

local function expectEq(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(`{label or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function expectNear(actual: number, expected: number, tolerance: number, label: string?)
	if math.abs(actual - expected) > tolerance then
		error(`{label or "value"}: expected ~{expected}, got {actual}`, 2)
	end
end

print("NavGrid")

test("cellAt / cellCenter round trip", function()
	local grid = NavGrid.new(4, 32, 8)
	local index = grid:cellAt(5, -9) :: number
	local x, z = grid:cellCenter(index)
	expectEq(x, 6, "x")
	expectEq(z, -10, "z")
	expectEq(grid:cellAt(40, 0), nil, "outside")
end)

test("field distance grows away from source", function()
	local grid = NavGrid.new(4, 32, 8)
	local source = grid:cellAt(0, 0) :: number
	local field = grid:buildField({ source })
	expectEq(grid:distanceAt(field, source), 0, "source")
	local neighbour = grid:cellAt(4, 0) :: number
	expectEq(grid:distanceAt(field, neighbour), 1, "neighbour")
end)

test("walls are routed around", function()
	local grid = NavGrid.new(4, 32, 8)
	-- Vertical wall at x in [8, 12), leaving a gap at the top edge.
	grid:blockRect(8, -32, 12, 24)
	local source = grid:cellAt(20, 0) :: number
	local field = grid:buildField({ source })
	local start = grid:cellAt(0, 0) :: number
	local d = grid:distanceAt(field, start)
	-- Straight line would be 5 steps; going around the wall must be longer.
	assert(d > 5 and d ~= NavGrid.UNREACHABLE, `detour distance {d}`)
	-- Walking the field from start must reach the source without entering a blocked cell.
	local x, z = grid:cellCenter(start)
	for _ = 1, 200 do
		local wx, wz = grid:nextWaypoint(field, x, z)
		if wx == nil then
			break
		end
		x, z = wx :: number, wz :: number
		assert(grid:isWalkable(x, z), "walked into wall")
	end
	expectEq(grid:cellAt(x, z), source, "reached source")
end)

test("structure cells cost more than open cells", function()
	local grid = NavGrid.new(4, 32, 8)
	local source = grid:cellAt(0, 0) :: number
	grid:fillRect(4, 0, 8, 4, 8)
	local field = grid:buildField({ source })
	expectEq(grid:distanceAt(field, grid:cellAt(4, 0) :: number), 8, "entering the structure cell")
	-- Going around (3 open steps + 1) beats breaking through (8 + 1).
	expectEq(grid:distanceAt(field, grid:cellAt(8, 0) :: number), 4, "detour around structure")
end)

test("enclosed cells are unreachable", function()
	local grid = NavGrid.new(4, 32, 8)
	grid:blockRect(-8, -8, 8, -4)
	grid:blockRect(-8, 4, 8, 8)
	grid:blockRect(-8, -4, -4, 4)
	grid:blockRect(4, -4, 8, 4)
	local field = grid:buildField({ grid:cellAt(20, 20) :: number })
	expectEq(grid:distanceAt(field, grid:cellAt(0, 0) :: number), NavGrid.UNREACHABLE, "inside box")
	local wx = grid:nextWaypoint(field, 0, 0)
	expectEq(wx, nil, "no waypoint")
end)

test("windowed field only covers its window", function()
	local grid = NavGrid.new(4, 64, 8)
	local source = grid:cellAt(0, 0) :: number
	local field = grid:buildField({ source }, grid:windowAround(0, 0, 16))
	expectEq(grid:distanceAt(field, grid:cellAt(8, 0) :: number), 2, "inside window")
	expectEq(grid:distanceAt(field, grid:cellAt(40, 0) :: number), NavGrid.UNREACHABLE, "outside window")
	expectEq(grid:nextWaypoint(field, 40, 0), nil, "no waypoint outside window")
end)

test("a blocked source falls back to the nearest walkable cell", function()
	local grid = NavGrid.new(4, 64, 8)
	-- Target stands against furniture: its own cell is blocked.
	grid:blockRect(0, 0, 4, 4)
	local field = grid:buildField({ grid:cellAt(1, 1) :: number })
	local d = grid:distanceAt(field, grid:cellAt(20, 1) :: number)
	assert(d ~= NavGrid.UNREACHABLE, "field is not empty")
end)

print("HeightField")

test("town and roads are flat", function()
	expectNear(HeightField.heightAt(300, 180), 0, 0.01, "town centre")
	expectNear(HeightField.heightAt(-600, 180), 0, 0.01, "highway in the forest")
	expectEq(HeightField.surfaceAt(300, 180, 0), "Asphalt", "main street")
	expectEq(HeightField.regionAt(300, 180), "Town")
	expectEq(HeightField.regionAt(-600, -600), "Forest")
end)

test("lake, quarry and mountains have depth and height", function()
	local lake = WorldLayout.Lake
	assert(HeightField.heightAt(lake.x, lake.z) < lake.waterLevel - lake.depth / 2, "lake bed")
	assert(HeightField.isWater(lake.x, lake.z), "lake is water")
	local quarry = WorldLayout.Quarry
	assert(HeightField.heightAt(quarry.x, quarry.z) < -quarry.depth / 2, "quarry floor")
	assert(HeightField.heightAt(1000, 0) > WorldLayout.MountainHeight / 2, "mountain at the edge")
	assert(not HeightField.isPlayable(1000, 0), "edge not playable")
end)

test("heights are deterministic", function()
	expectEq(HeightField.heightAt(-321.5, 77.25), HeightField.heightAt(-321.5, 77.25))
end)

print("Buildings")

local CELL = 4

local function templateNames(): { string }
	local names = {}
	for name in BuildingTemplates do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

local function cellKey(row: number, col: number): number
	return row * 1000 + col
end

-- Cells a player walks on: open floor and doorways. Furniture and stair flights block.
local function walkable(char: string): boolean
	return char == "." or char == "D"
end

test("templates are well formed", function()
	for _, name in templateNames() do
		local template = BuildingTemplates[name]
		local rows, cols = FloorPlan.size(template.floors[1])
		for index, plan in template.floors do
			local where = `{name} floor {index}`
			expectEq(#plan, rows, `{where} rows`)
			for row, line in plan do
				expectEq(#line, cols, `{where} row {row} length`)
				for col = 1, cols do
					local char = string.sub(line, col, col)
					assert(FloorPlan.isKnown(char), `{where} ({row},{col}): unknown symbol '{char}'`)
				end
			end
			for _, stair in FloorPlan.stairs(plan) do
				local above = template.floors[index + 1]
				assert(above, `{where}: stair without a floor above`)
				for _, cell in stair.cells do
					expectEq(FloorPlan.charAt(above, cell[1], cell[2]), ".", `{where}: floor above stair cell {cell[1]},{cell[2]}`)
				end
				local entry, exit = FloorPlan.stairEnds(stair)
				expectEq(FloorPlan.charAt(plan, entry[1], entry[2]), ".", `{where}: stair entry`)
				expectEq(FloorPlan.charAt(above, exit[1], exit[2]), ".", `{where}: stair exit upstairs`)
			end
		end
	end
end)

test("doorways open onto free floor", function()
	for _, name in templateNames() do
		for index, plan in BuildingTemplates[name].floors do
			local rows, cols = FloorPlan.size(plan)
			for row = 1, rows do
				for col = 1, cols do
					if FloorPlan.charAt(plan, row, col) == "D" then
						local a, b = FloorPlan.doorSides(plan, row, col)
						assert(a and b, `{name} floor {index} ({row},{col}): doorway not in a straight wall`)
						for _, side in { a, b } do
							local char = FloorPlan.charAt(plan, side[1], side[2])
							assert(
								char == "." or char == " " or char == "D",
								`{name} floor {index} ({row},{col}): doorway blocked by '{char}'`
							)
						end
					end
				end
			end
		end
	end
end)

test("every floor cell and every piece of furniture can be walked to", function()
	for _, name in templateNames() do
		local template = BuildingTemplates[name]
		local rows, cols = FloorPlan.size(template.floors[1])
		-- Ground floor: enter through every walkable border cell (exterior doorways, open sheds).
		local starts: { { number } } = {}
		for row = 1, rows do
			for col = 1, cols do
				local border = row == 1 or row == rows or col == 1 or col == cols
				if border and walkable(FloorPlan.charAt(template.floors[1], row, col)) then
					table.insert(starts, { row, col })
				end
			end
		end
		local holes: { [number]: boolean } = {}
		for index, plan in template.floors do
			local where = `{name} floor {index}`
			local function open(row: number, col: number): boolean
				return walkable(FloorPlan.charAt(plan, row, col)) and not holes[cellKey(row, col)]
			end
			local reached: { [number]: boolean } = {}
			local queue: { { number } } = {}
			for _, cell in starts do
				if open(cell[1], cell[2]) and not reached[cellKey(cell[1], cell[2])] then
					reached[cellKey(cell[1], cell[2])] = true
					table.insert(queue, cell)
				end
			end
			local head = 1
			while head <= #queue do
				local row, col = queue[head][1], queue[head][2]
				head += 1
				for _, d in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
					local r, c = row + d[2], col + d[1]
					if open(r, c) and not reached[cellKey(r, c)] then
						reached[cellKey(r, c)] = true
						table.insert(queue, { r, c })
					end
				end
			end

			for row = 1, rows do
				for col = 1, cols do
					local char = FloorPlan.charAt(plan, row, col)
					if open(row, col) then
						assert(reached[cellKey(row, col)], `{where} ({row},{col}): '{char}' cannot be reached`)
					elseif FloorPlan.isFurniture(char) then
						local touched = false
						for _, d in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
							if reached[cellKey(row + d[2], col + d[1])] then
								touched = true
							end
						end
						assert(touched, `{where} ({row},{col}): '{char}' cannot be reached`)
					end
				end
			end

			-- The next floor is entered at the top of each stair.
			starts, holes = {}, {}
			for _, stair in FloorPlan.stairs(plan) do
				local entry, exit = FloorPlan.stairEnds(stair)
				assert(reached[cellKey(entry[1], entry[2])], `{where}: stair entry cannot be reached`)
				table.insert(starts, exit)
				for _, cell in stair.cells do
					holes[cellKey(cell[1], cell[2])] = true
				end
			end
		end
	end
end)

local function footprintOf(placement: WorldLayout.BuildingPlacement): (number, number)
	local plan = BuildingTemplates[placement.template].floors[1]
	local width, depth = #plan[1] * CELL, #plan * CELL
	if placement.rotation % 2 == 1 then
		return depth, width
	end
	return width, depth
end

test("buildings stay on the grid, apart, and off roads and sidewalks", function()
	local placed: { { name: string, x0: number, z0: number, x1: number, z1: number } } = {}
	for _, p in WorldLayout.Buildings do
		assert(BuildingTemplates[p.template], `{p.name}: unknown template {p.template}`)
		expectEq(p.x % CELL + p.z % CELL, 0, `{p.name} corner on the 4-stud grid`)
		local width, depth = footprintOf(p)
		local x1, z1 = p.x + width, p.z + depth
		for _, other in placed do
			local overlap = p.x < other.x1 and other.x0 < x1 and p.z < other.z1 and other.z0 < z1
			assert(not overlap, `{p.name} overlaps {other.name}`)
		end
		table.insert(placed, { name = p.name, x0 = p.x, z0 = p.z, x1 = x1, z1 = z1 })

		local inTown = HeightField.isInTown(p.x + width / 2, p.z + depth / 2)
		local clearance = if inTown then WorldLayout.Town.sidewalkWidth else 0
		local e = 0.01
		local steps = 32
		for i = 0, steps do
			local t = i / steps
			local x, z = p.x + e + (width - 2 * e) * t, p.z + e + (depth - 2 * e) * t
			for _, point in { { x, p.z + e }, { x, z1 - e }, { p.x + e, z }, { x1 - e, z } } do
				local distance = HeightField.nearestRoad(point[1], point[2])
				assert(
					distance >= clearance - 1e-6,
					`{p.name}: footprint edge at ({point[1]}, {point[2]}) is {distance} from a road`
				)
			end
		end
	end
end)

test("building footprints are flat", function()
	for _, p in WorldLayout.Buildings do
		local width, depth = footprintOf(p)
		local low, high = math.huge, -math.huge
		for z = p.z + CELL / 2, p.z + depth, CELL do
			for x = p.x + CELL / 2, p.x + width, CELL do
				local h = HeightField.heightAt(x, z)
				low = math.min(low, h)
				high = math.max(high, h)
			end
		end
		assert(high - low <= 0.5, `{p.name}: ground varies by {high - low} studs under the footprint`)
	end
end)

print("ZombieProtocol")

test("encode / decode round trip", function()
	local entries = {
		{ id = 1, x = 10.5, y = 3, z = -20.25, state = "Chase" },
		{ id = 65535, x = -4000, y = 0, z = 4000, state = "Search" },
	}
	local packet = ZombieProtocol.encode(123.5, entries, 1, 2, 8)
	expectEq(buffer.len(packet), ZombieProtocol.packetSize(2), "size")
	local decoded = {}
	local time = ZombieProtocol.decode(packet, 8, function(id, x, y, z, state)
		table.insert(decoded, { id = id, x = x, y = y, z = z, state = state })
	end)
	expectEq(time, 123.5, "time")
	expectEq(#decoded, 2, "count")
	expectEq(decoded[1].id, 1)
	expectNear(decoded[1].x, 10.5, 1 / 8)
	expectNear(decoded[1].z, -20.25, 1 / 8)
	expectEq(decoded[1].state, "Chase")
	expectEq(decoded[2].id, 65535)
	expectNear(decoded[2].x, -4000, 1 / 8)
	expectEq(decoded[2].state, "Search")
end)

test("max packet fits the unreliable remote limit", function()
	assert(ZombieProtocol.packetSize(90) < 900, "packet too large")
end)

test("malformed packet is rejected", function()
	local packet = buffer.create(12)
	buffer.writeu16(packet, 8, 5)
	expectEq(ZombieProtocol.decode(packet, 8, function() end), nil, "decode")
end)

print("ZombieLook")

test("a zombie looks the same on every client", function()
	local a = ZombieLook.fromId(1234)
	local b = ZombieLook.fromId(1234)
	expectEq(a.toneIndex, b.toneIndex, "tone")
	expectEq(a.height, b.height, "height")
	expectEq(a.limpSide, b.limpSide, "limp side")
	expectEq(a.shirt, b.shirt, "shirt")
end)

test("skin tones follow their spawn weights", function()
	local tones = Config.ZombieVisual.SkinTones
	local total = 0
	for _, tone in tones do
		total += tone.Weight
	end
	local counts = table.create(#tones, 0)
	local samples = 20000
	for id = 1, samples do
		local index = ZombieLook.fromId(id).toneIndex
		counts[index] += 1
	end
	for index, tone in tones do
		expectNear(counts[index] / samples, tone.Weight / total, 0.02, `tone {index} share`)
	end
end)

test("weighted pick covers the whole range", function()
	expectEq(ZombieLook.pickWeighted({ 1, 3 }, 0), 1, "lowest roll")
	expectEq(ZombieLook.pickWeighted({ 1, 3 }, 0.2), 1, "inside the first weight")
	expectEq(ZombieLook.pickWeighted({ 1, 3 }, 0.3), 2, "inside the second weight")
	expectEq(ZombieLook.pickWeighted({ 1, 3 }, 0.999), 2, "highest roll")
end)

print(`\n{passed} passed, {failed} failed`)
if failed > 0 then
	error("tests failed")
end
