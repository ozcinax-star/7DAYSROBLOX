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
local Inventory = require("../src/shared/Inventory")
local Melee = require("../src/shared/Melee")
local Harvest = require("../src/shared/Harvest")
local Ballistics = require("../src/shared/Ballistics")
local Farming = require("../src/shared/Farming")
local Crafting = require("../src/shared/Crafting")
local Loot = require("../src/shared/Loot")
local DayClock = require("../src/shared/DayClock")
local Threat = require("../src/shared/Threat")
local BuildGrid = require("../src/shared/BuildGrid")
local Vitals = require("../src/shared/Vitals")

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

test("a layer that starts blocked only walks its opened cells", function()
	-- An upper floor: a 3-cell corridor along X opened in an otherwise blocked layer.
	local grid = NavGrid.new(4, 64, 8, NavGrid.BLOCKED)
	expectEq(grid:isWalkable(0, 0), false, "closed by default")
	for x = 0, 8, 4 do
		grid:setCost(grid:cellAt(x + 1, 1) :: number, NavGrid.NORMAL)
	end
	local field = grid:buildField({ grid:cellAt(9, 1) :: number })
	expectEq(grid:distanceAt(field, grid:cellAt(1, 1) :: number), 2, "along the corridor")
	expectEq(grid:distanceAt(field, grid:cellAt(1, 5) :: number), NavGrid.UNREACHABLE, "beside the corridor")
	local wx, wz = grid:nextWaypoint(field, 1, 1)
	expectEq(wx, 6, "next cell x")
	expectEq(wz, 2, "next cell z")
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

print("Inventory")

test("items fill existing stacks, then empty slots, and report what did not fit", function()
	local inv = Inventory.new(2, 2)
	local stack = Inventory.stackSize("Wood")
	expectEq(Inventory.add(inv, "Wood", stack + 3, "Loot"), 0, "first add fits")
	expectEq(Inventory.add(inv, "Wood", 2, "Loot"), 0, "tops up the partial stack")
	expectEq(Inventory.count(inv, "Wood"), stack + 5, "count")
	local used = 0
	for _, slot in inv.slots do
		if slot then
			used += 1
		end
	end
	expectEq(used, 2, "two slots used")
	expectEq(Inventory.add(inv, "Wood", stack * 3, "Loot"), 5, "leftover when full")
	expectEq(Inventory.room(inv, "Wood", "Loot"), 0, "no room left")
end)

test("tools never stack and keep their own durability", function()
	local inv = Inventory.new(2, 2)
	local full = (Inventory.def("StoneAxe") :: any).Durability
	expectEq(Inventory.add(inv, "StoneAxe", 2, "Craft"), 0, "two axes")
	local filled = {}
	for index, slot in inv.slots do
		if slot then
			table.insert(filled, index)
		end
	end
	expectEq(#filled, 2, "one axe per slot")
	local first, second = filled[1], filled[2]
	expectEq((inv.slots[first] :: any).count, 1, "single")
	expectEq(Inventory.wear(inv, first, 3), full - 3, "worn")
	expectEq((inv.slots[second] :: any).durability, full, "the other axe is untouched")
	expectEq(Inventory.wear(inv, first, full * 2), 0, "durability stops at zero")
	expectEq(Inventory.count(inv, "StoneAxe"), 2, "broken tools are kept")
	local empty = if inv.slots[1] then 3 else 1
	expectEq(Inventory.wear(inv, empty, 1), nil, "no tool in an empty slot")
end)

test("only whole positive counts are added", function()
	local inv = Inventory.new(2, 2)
	expectEq(Inventory.add(inv, "StoneAxe", 1.5, "Craft"), 0, "fractional tool count")
	expectEq(Inventory.add(inv, "Wood", 2.2, "Loot"), 0, "fractional stack count")
	expectEq(Inventory.add(inv, "Wood", 0 / 0, "Loot"), 0, "NaN count")
	expectEq(Inventory.add(inv, "Wood", math.huge, "Loot"), 0, "infinite count")
	expectEq(Inventory.add(inv, "Wood", -3, "Loot"), 0, "negative count")
	expectEq(Inventory.add(inv, "NoSuchItem", 2, "Loot"), 2, "unknown item does not fit")
	for _, slot in inv.slots do
		expectEq(slot, false, "nothing was added")
	end
end)

test("stacks from different sources stay apart", function()
	local inv = Inventory.new(1, 3)
	Inventory.add(inv, "Wood", 5, "Loot")
	Inventory.add(inv, "Wood", 5, "Pass")
	local sources = {}
	for _, slot in inv.slots do
		if slot then
			table.insert(sources, slot.source)
		end
	end
	expectEq(#sources, 2, "two stacks")
	assert(sources[1] ~= sources[2], "different sources")
end)

test("removal is all or nothing, backpack first, and returns the sources", function()
	local inv = Inventory.new(1, 2)
	inv.slots[1] = { id = "Wood", count = 4, source = "Loot" }
	inv.slots[3] = { id = "Wood", count = 3, source = "Pass" }
	local ok = Inventory.remove(inv, "Wood", 8)
	expectEq(ok, false, "not enough")
	expectEq(Inventory.count(inv, "Wood"), 7, "nothing taken")
	local ok2, removed = Inventory.remove(inv, "Wood", 5)
	expectEq(ok2, true, "enough")
	expectEq(inv.slots[3], false, "backpack stack used up first")
	expectEq((inv.slots[1] :: any).count, 2, "toolbelt keeps the rest")
	expectEq(#removed, 2, "two source stacks")
	expectEq(removed[1].source, "Pass", "first removed source")
	local ok3 = Inventory.removeAll(inv, { Wood = 1, SmallStone = 1 })
	expectEq(ok3, false, "missing ingredient")
	expectEq(Inventory.count(inv, "Wood"), 2, "removeAll took nothing")
end)

test("moving splits, merges, swaps and rejects bad requests", function()
	local inv = Inventory.new(2, 2)
	inv.slots[1] = { id = "Wood", count = 10, source = "Loot" }
	inv.slots[2] = { id = "SmallStone", count = 4, source = "Loot" }
	expectEq(Inventory.move(inv, 1, 3, 4), true, "split into an empty slot")
	expectEq((inv.slots[1] :: any).count, 6, "split source")
	expectEq((inv.slots[3] :: any).count, 4, "split target")
	expectEq(Inventory.move(inv, 3, 1), true, "merge back")
	expectEq(inv.slots[3], false, "merged away")
	expectEq((inv.slots[1] :: any).count, 10, "merged count")
	expectEq(Inventory.move(inv, 1, 2), true, "swap whole stacks")
	expectEq((inv.slots[1] :: any).id, "SmallStone", "swapped")
	expectEq(Inventory.move(inv, 1, 2, 2), false, "part of a stack cannot swap")
	expectEq(Inventory.move(inv, 1, 9), false, "out of range")
	expectEq(Inventory.move(inv, 0 / 0, 2), false, "NaN index")
	expectEq(Inventory.move(inv, 2, 4, 0), false, "zero count")
	expectEq(Inventory.move(inv, 2, 4, 1.5), false, "fractional count")
	expectEq(Inventory.move(inv, 4, 3), false, "empty source")
end)

print("Melee")

local MC = Config.Melee
local SHAPE: Melee.Shape = {
	bottom = MC.HitBottom,
	top = MC.HitTop,
	radius = MC.HitRadius,
	headHeight = MC.HeadHeight,
	headRadius = MC.HeadRadius,
	headLean = MC.HeadLean,
}

-- A zombie root at (x, y, z) facing the attacker at the origin, or facing `fx, fz`.
local function zombie(id: number, x: number, y: number, z: number, fx: number?, fz: number?): Melee.Body
	if fx and fz then
		return { id = id, x = x, y = y, z = z, fx = fx, fz = fz }
	end
	local length = math.sqrt(x * x + z * z)
	return { id = id, x = x, y = y, z = z, fx = -x / length, fz = -z / length }
end

-- A swing from (ox, oy, oz) toward (tx, ty, tz).
local function swingAt(ox: number, oy: number, oz: number, tx: number, ty: number, tz: number): Melee.Ray
	local dx, dy, dz = tx - ox, ty - oy, tz - oz
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	return { ox = ox, oy = oy, oz = oz, dx = dx / length, dy = dy / length, dz = dz / length, range = 7 }
end

-- A swing from a head at (0, 4.5, 0) along +X (tilted by dy) with a 7-stud reach.
local function swing(dy: number?): Melee.Ray
	local y = dy or 0
	local length = math.sqrt(1 + y * y)
	return { ox = 0, oy = 4.5, oz = 0, dx = 1 / length, dy = y / length, dz = 0, range = 7 }
end

local function never(_: Melee.Hit): boolean
	return false
end

test("a swing hits the zombie straight ahead and reports the head", function()
	-- Root 3 studs above the ground at y = 0; the head leans toward the attacker.
	local body = zombie(1, 4, 3, 0)
	local hit = Melee.pick(swing(), { body }, SHAPE, never)
	assert(hit, "hit")
	expectEq(hit.id, 1, "id")
	expectNear(hit.distance, 4, 0.01, "distance to the axis")
	expectEq(hit.head, true, "head height")
	local low = Melee.pick(swing(-0.5), { body }, SHAPE, never)
	assert(low, "aimed lower")
	expectEq(low.head, false, "body hit")
end)

test("a lunging zombie's head counts from above, its pelvis does not", function()
	-- Measured in Play: attacker's head 2.31 above the zombie root, zombie 3.02 away and lunging;
	-- its head is drawn 1.02 above the root and 0.92 toward the attacker.
	local body = zombie(1, 3.02, 0, 0)
	local atHead = Melee.pick(swingAt(0, 2.31, 0, 2.1, 1.02, 0), { body }, SHAPE, never)
	assert(atHead, "head aim hits")
	expectEq(atHead.head, true, "head")
	local atPelvis = Melee.pick(swingAt(0, 2.31, 0, 3.02, -0.7, 0), { body }, SHAPE, never)
	assert(atPelvis, "pelvis aim hits")
	expectEq(atPelvis.head, false, "body")
	local fromBehind = Melee.pick(swingAt(0, 2.31, 0, 2.1, 1.02, 0), { zombie(2, 3.02, 0, 0, 1, 0) }, SHAPE, never)
	assert(fromBehind, "a zombie facing away is still hit")
	expectEq(fromBehind.head, false, "its head leans away from the swing")
end)

test("zombies out of reach, beside the swing or a floor above are missed", function()
	expectEq(Melee.pick(swing(), { zombie(1, 9, 3, 0) }, SHAPE, never), nil, "beyond reach")
	expectEq(Melee.pick(swing(), { zombie(2, 4, 3, 3) }, SHAPE, never), nil, "to the side")
	expectEq(Melee.pick(swing(), { zombie(3, 3, 15, 0) }, SHAPE, never), nil, "upstairs")
	expectEq(Melee.pick(swing(), { zombie(4, -3, 3, 0) }, SHAPE, never), nil, "behind")
	expectEq(Melee.pick(swing(), { zombie(5, -0.5, 3, 0.3) }, SHAPE, never), nil, "pressed behind")
	expectEq(Melee.pick(swing(1.5), { zombie(6, 3, 3, 0) }, SHAPE, never), nil, "swing over the head")
	local close = Melee.pick(swing(), { zombie(7, 0.6, 3, 0) }, SHAPE, never)
	assert(close, "pressed against the front still counts")
end)

test("the nearest zombie is hit unless a wall blocks it", function()
	local bodies = { zombie(1, 6, 3, 0.5), zombie(2, 3, 3, -0.5) }
	local hit = Melee.pick(swing(), bodies, SHAPE, never)
	assert(hit, "hit")
	expectEq(hit.id, 2, "nearer zombie")
	local wallAt = 4
	local function wall(h: Melee.Hit): boolean
		return h.distance > wallAt
	end
	local blocked = Melee.pick(swing(), bodies, SHAPE, wall)
	assert(blocked, "the nearer one is in front of the wall")
	expectEq(blocked.id, 2, "still the nearer zombie")
	expectEq(Melee.pick(swing(), { bodies[1] }, SHAPE, wall), nil, "zombie behind the wall")
end)

test("aim vectors must be finite unit vectors", function()
	local tol = MC.AimTolerance
	expectEq(Melee.isUnit(0, 0, -1, tol), true, "unit")
	expectEq(Melee.isUnit(0.6, 0, 0.8, tol), true, "unit diagonal")
	expectEq(Melee.isUnit(0, 0, 0, tol), false, "zero")
	expectEq(Melee.isUnit(0, 50, 0, tol), false, "too long")
	expectEq(Melee.isUnit(0 / 0, 0, 1, tol), false, "NaN")
	expectEq(Melee.isUnit(math.huge, 0, 0, tol), false, "infinite")
	expectNear(Melee.interval(Config.Tools.StoneAxe.AttacksPerMinute, MC.SwingDelay), 60 / 105 + 0.1, 1e-9, "interval")
end)

print("Harvest")

local Nodes = Config.Harvest.Nodes

-- Hits a node with the same damage until it breaks; returns the items paid and the number of hits.
local function chop(node: Config.HarvestNode, damage: number): (number, number, number)
	local count = node.Harvest[1].Max
	local total, hits, last = 0, 0, 0
	local done = 0
	while done < node.Health do
		local after = math.min(node.Health, done + damage)
		last = Harvest.payout(count, node.Health, done, after)
		total += last
		hits += 1
		done = after
	end
	return total, hits, last
end

local function toolDamage(toolId: string, material: Config.HarvestMaterial): number
	local tool = Config.Tools[toolId]
	return Harvest.blockDamage(tool.BlockDamage, tool.Materials[material])
end

test("block damage is truncated, at least 1, and matches 7DTD's hit counts", function()
	expectEq(toolDamage("Fist", "Wood"), 2, "fist on wood")
	expectEq(toolDamage("Fist", "Stone"), 1, "fist on stone")
	expectEq(toolDamage("StoneAxe", "Earth"), 3, "axe on earth")
	expectEq(toolDamage("StoneAxe", "Stone"), 14, "axe on stone")
	expectEq(toolDamage("StoneShovel", "Stone"), 7, "shovel on stone")
	expectEq(Harvest.blockDamage(2.2, 0.2), 1, "never below 1")
	local _, smallTreeHits = chop(Nodes.TreeSmall, toolDamage("StoneAxe", "Wood"))
	expectEq(smallTreeHits, 14, "stone axe fells a small tree in 14 hits")
	local _, fistHits = chop(Nodes.TreeSmall, toolDamage("Fist", "Wood"))
	expectEq(fistHits, 150, "the fist needs 150")
	local _, axeBoulderHits = chop(Nodes.Boulder, toolDamage("StoneAxe", "Stone"))
	expectEq(axeBoulderHits, 29, "stone axe breaks a boulder in 29 hits")
	local _, pickBoulderHits = chop(Nodes.Boulder, toolDamage("StonePickaxe", "Stone"))
	expectEq(pickBoulderHits, 16, "stone pickaxe in 16")
	local _, clubTreeHits = chop(Nodes.TreeSmall, toolDamage("WoodenClub", "Wood"))
	expectEq(clubTreeHits, 28, "a wooden club fells a small tree in 28 hits")
end)

test("clubs and spears gather a quarter of wood, stone and clay but all the fibre", function()
	local club, spear = Config.Tools.WoodenClub, Config.Tools.StoneSpear
	expectEq(Harvest.toolCount(150, club, "Wood"), 37, "club on a full tree")
	expectEq(Harvest.toolCount(22, spear, "SmallStone"), 5, "spear on a boulder")
	expectEq(Harvest.toolCount(22, spear, "Clay"), 5, "spear digging dirt")
	expectEq(Harvest.toolCount(2, club, "PlantFiber"), 2, "club on grass")
	expectEq(Harvest.toolCount(3, club, "Wood"), 0, "club on a bush")
	expectEq(Harvest.toolCount(150, Config.Tools.StoneAxe, "Wood"), 150, "tools get everything")
	-- 7DTD weapon stats and recipes.
	expectEq(club.EntityDamage, 12, "club damage")
	expectEq(spear.EntityDamage, 12, "spear damage")
	expectEq(Config.Items.WoodenClub.Durability, 100, "club durability")
	expectEq(Config.Items.StoneSpear.Repair and Config.Items.StoneSpear.Repair.Id, "SmallStone", "spear repair")
	expectEq(Config.Recipes.WoodenClub.Ingredients[1].Id, "Wood", "club is wood")
	expectEq(Config.Recipes.WoodenClub.Ingredients[1].Count, 5, "5 wood")
	expectEq(#Config.Recipes.StoneSpear.Ingredients, 3, "spear takes stone, fibre and wood")
end)

test("any tool gets the whole yield; a third of it comes on the killing hit", function()
	for _, name in { "TreeSmall", "TreeMedium", "TreeLarge", "TreeFull", "Boulder" } do
		local node = Nodes[name]
		local count = node.Harvest[1].Max
		for _, toolId in { "Fist", "StoneAxe", "StoneShovel", "StonePickaxe" } do
			local total, _, last = chop(node, toolDamage(toolId, node.Material))
			expectEq(total, count, `{name} with {toolId}`)
			assert(last >= count // 3, `{name} with {toolId}: the last hit pays the lump`)
		end
	end
	-- A full tree pays 1 wood per 12 damage while it stands: 2 for the first stone axe hit, then the
	-- lump of 50 on the fell.
	expectEq(Harvest.payout(150, 1200, 0, 22), 2, "first axe hit on a full tree")
	expectEq(Harvest.payout(150, 1200, 1188, 1200), 1 + 50, "felling hit")
end)

test("mixed hits add up, overkill pays nothing, one-hit objects pay in full", function()
	local node = Nodes.TreeMedium
	local total, done, i = 0, 0, 0
	while done < node.Health do
		i += 1
		local after = math.min(node.Health, done + (if i % 3 == 0 then 22 else 2))
		total += Harvest.payout(70, node.Health, done, after)
		done = after
	end
	expectEq(total, 70, "fist and axe in turns")
	expectEq(Harvest.payout(70, 600, 600, 600), 0, "hitting a broken object pays nothing")
	expectEq(Harvest.payout(2, 1, 0, 1), 2, "grass")
	for count = 1, 3 do
		expectEq(Harvest.payout(count, 1, 0, 1), count, `bush rolled {count}`)
	end
	expectEq(Harvest.payout(0, 1, 0, 1), 0, "nothing to pay")
end)

test("every node, tree size and tool is well formed", function()
	for name, node in Nodes do
		assert(node.Health >= 1, `{name} health`)
		for _, list in { node.Harvest, node.Destroy } do
			for _, d in list do
				assert(Config.Items[d.Id], `{name} drops unknown item {d.Id}`)
				assert(d.Min >= 0 and d.Max >= d.Min and d.Max % 1 == 0 and d.Min % 1 == 0, `{name} drop range`)
			end
		end
	end
	local previous = 0
	for _, size in Config.Harvest.TreeSizes do
		assert(Nodes[size.Node], `tree size {size.Node}`)
		assert(size.MaxScale > previous, "tree sizes ascend")
		previous = size.MaxScale
	end
	for toolId, tool in Config.Tools do
		for _, material in { "Wood", "Earth", "Stone" } do
			assert((tool.Materials :: any)[material] > 0, `{toolId} {material} multiplier`)
		end
	end
end)

test("a dug voxel pays 7DTD's yield and the shovel digs earth fastest", function()
	local Dig = Config.Dig.Materials
	local _, shovelHits = chop(Dig.Ground, toolDamage("StoneShovel", "Earth"))
	expectEq(shovelHits, 6, "stone shovel digs dirt in 6 hits")
	local _, pickHits = chop(Dig.Ground, toolDamage("StonePickaxe", "Earth"))
	expectEq(pickHits, 40, "stone pickaxe needs 40")
	local _, stoneHits = chop(Dig.Rock, toolDamage("StonePickaxe", "Stone"))
	expectEq(stoneHits, 20, "stone pickaxe digs stone in 20")
	for name, node in Dig do
		assert(node.Health >= 1, `{name} health`)
		for _, d in node.Harvest do
			assert(Config.Items[d.Id], `{name} drops unknown item {d.Id}`)
			local total = 0
			local done = 0
			while done < node.Health do
				local after = math.min(node.Health, done + toolDamage("StoneShovel", node.Material))
				total += Harvest.payout(d.Max, node.Health, done, after)
				done = after
			end
			expectEq(total, d.Max, `{name} pays all its {d.Id}`)
		end
	end
	expectEq(Dig.Asphalt, nil, "roads cannot be dug")
	expectEq(Dig.Water, nil, "water cannot be dug")
	-- 7DTD: a dug dirt block gives 22 clay, crafting one back costs 16.
	local dirt = Config.Recipes.Dirt
	expectEq(#dirt.Ingredients, 1, "dirt takes one ingredient")
	expectEq(dirt.Ingredients[1].Id, "Clay", "dirt is made of clay")
	expectEq(dirt.Ingredients[1].Count, 16, "16 clay per dirt")
	expectEq(Config.Items.Dirt.Fill, "Ground", "dirt fills holes with ground")
end)

print("Ballistics")

test("a stone arrow from the primitive bow keeps 7DTD's damage, speed and recipes", function()
	local bow = Config.Ranged.Weapons.PrimitiveBow
	local arrow = Config.Ranged.Ammo.StoneArrow
	expectEq(Ballistics.damage(bow, arrow), 30, "35 arrow damage, -5 from the bow")
	local speed = Ballistics.speed(bow, arrow)
	assert(math.abs(speed - 31.5 * Config.Melee.StudsPerMeter) < 1e-6, "45 m/s, 30 % slower from the bow")
	local gravity = Ballistics.gravity(arrow)
	-- At 30 studs the arrow has dropped well under a head's height; at 100 m it is far below.
	local drop = Ballistics.drop(30, speed, gravity)
	assert(drop > 0.3 and drop < 1, `drop at 30 studs {drop}`)
	assert(Ballistics.drop(100 * Config.Melee.StudsPerMeter, speed, gravity) > 10, "drop at full range")
	local x, y, z = Ballistics.position(0, 10, 0, speed, 0, 0, gravity, 1)
	expectEq(x, speed, "flies at its speed")
	expectEq(z, 0, "no sideways drift")
	assert(math.abs(y - (10 - gravity / 2)) < 1e-9, "falls under gravity")
	expectEq(Config.Items.PrimitiveBow.Durability, 100, "bow durability")
	expectEq(Config.Items.StoneArrow.Stack, 150, "arrow stack")
	local recipe = Config.Recipes.StoneArrow
	expectEq(recipe.Seconds, 1.4, "arrow craft time")
	expectEq(#recipe.Ingredients, 3, "stone, wood and a fibre for the missing feather")
	for _, ammoId in bow.Ammo do
		assert(Config.Ranged.Ammo[ammoId] and Config.Items[ammoId], `ammo {ammoId}`)
	end
	assert(Config.Tools.PrimitiveBow == nil, "a bow is not swung")
end)

print("Farming")

test("crops ripen in two 7DTD stages and pay 2-3 produce and their seed back", function()
	local stage = Farming.stageSeconds()
	expectEq(stage, 1.05 * Config.DayNight.CycleSeconds, "63 of 60 minutes: 1.05 days a stage")
	expectEq(Farming.ripeSeconds(), stage * 2, "two stages to ripe")
	expectEq(Farming.stageAt(0), 1, "planted")
	expectEq(Farming.stageAt(stage - 1), 1, "still a sprout")
	expectEq(Farming.stageAt(stage), 2, "growing")
	expectEq(Farming.stageAt(stage * 2), 3, "ripe")
	expectEq(Farming.stageAt(stage * 99), 3, "stays ripe")
	local corn = Config.Farming.Crops.Corn
	expectEq(Farming.harvestCount(corn, 0.49), 3, "bonus corn")
	expectEq(Farming.harvestCount(corn, 0.5), 2, "no bonus")
	for name, crop in Config.Farming.Crops do
		assert(Config.Items[crop.Produce] and Config.Items[crop.Produce].Use, `{name} produce is food`)
		expectEq(Config.Items[crop.Seed].Seed, name, `{name} seed plants it`)
		local recipe = Config.Recipes[crop.Seed]
		expectEq(recipe.Ingredients[1].Id, crop.Produce, `{name} seed is made of its produce`)
		expectEq(recipe.Ingredients[1].Count, 5, `5 {crop.Produce} per seed`)
		assert(crop.SeedBack >= 1, `{name} gives its seed back`)
	end
	local plot = Config.Build.Blocks.FarmPlot
	assert(plot.Plot and plot.Placeable, "the farm plot is a placeable plot")
	expectEq(plot.Health, 250, "Mfarmland 250 HP")
	-- The slab sits on the cell floor, or on ground that rises into the cell, never above the cell.
	local h = Config.Build.PlotHeight
	local function slabY(groundY: number): number
		return BuildGrid.plotCFrame(0, 0, 0, groundY, h).Position.Y
	end
	assert(math.abs(slabY(-3) - h / 2) < 1e-4, "ground below: on the floor")
	assert(math.abs(slabY(1.5) - (1.5 + h / 2)) < 1e-4, "ground inside: on the ground")
	assert(math.abs(slabY(9) - (Config.Build.GridSize - h / 2)) < 1e-4, "kept in its cell")
end)

print("Crafting")

local Recipes = Config.Recipes

test("craft times follow 7DTD's ingredient times", function()
	expectNear(Crafting.unitSeconds(Recipes.StoneAxe), 1.2, 1e-9, "stone axe")
	expectNear(Crafting.unitSeconds(Recipes.StoneShovel), 2.2, 1e-9, "stone shovel")
	expectNear(Crafting.unitSeconds(Recipes.StonePickaxe), 2.0, 1e-9, "stone pickaxe")
	expectNear(Crafting.unitSeconds(Recipes.Lumber), 0.4, 1e-9, "lumber")
	local explicit: Config.Recipe = { Output = "Wood", Count = 1, Ingredients = {}, Seconds = 5 }
	expectEq(Crafting.unitSeconds(explicit), 5, "explicit time")
	local unknown: Config.Recipe = { Output = "Wood", Count = 1, Ingredients = { { Id = "Lumber", Count = 3 } } }
	expectEq(Crafting.unitSeconds(unknown), 3, "unlisted ingredients take 1 s each")
end)

test("costs scale with the count and the stock caps how many can be made", function()
	local costs = Crafting.costs(Recipes.StoneShovel, 3)
	expectEq(costs.SmallStone, 15, "stone")
	expectEq(costs.PlantFiber, 9, "fibre")
	expectEq(costs.Wood, 9, "wood")
	local stock = { SmallStone = 11, PlantFiber = 20, Wood = 7 }
	local function countOf(id: string): number
		return (stock :: any)[id] or 0
	end
	expectEq(Crafting.maxCount(Recipes.StoneAxe, countOf), 3, "wood runs out first")
	expectEq(Crafting.maxCount(Recipes.Lumber, function()
		return 1e6
	end), Config.Crafting.MaxCount, "capped")
	expectEq(Crafting.maxCount(Recipes.StoneShovel, function()
		return 0
	end), 0, "nothing on hand")
end)

test("a job's pool pays each craft from the first stacks and keeps the rest for refunds", function()
	local pool: { Inventory.Stack } = {
		{ id = "Wood", count = 3, source = "Loot" },
		{ id = "Wood", count = 5, source = "Craft" },
		{ id = "SmallStone", count = 4, source = "Loot" },
	}
	Crafting.draw(pool, { Wood = 4, SmallStone = 2 })
	expectEq(#pool, 2, "the first wood stack is used up")
	expectEq(pool[1].count, 4, "wood left")
	expectEq(pool[1].source, "Craft", "source kept")
	expectEq(pool[2].count, 2, "stone left")
	Crafting.draw(pool, { Wood = 4, SmallStone = 2 })
	expectEq(#pool, 0, "all used")
end)

test("repairs take whole stones and tools come out of their slot", function()
	expectEq(Crafting.repairUnits(250, 300), 1, "a broken stone axe needs 1 stone")
	expectEq(Crafting.repairUnits(500, 300), 2, "two when more than 300 is missing")
	expectEq(Crafting.repairUnits(1, 300), 1, "any damage needs one")
	local inv = Inventory.new(2, 2)
	Inventory.add(inv, "StoneAxe", 1, "Craft", 40)
	local index = 0
	for i, slot in inv.slots do
		if slot then
			index = i
		end
	end
	local stack = Inventory.takeSlot(inv, index)
	assert(stack, "taken")
	expectEq(stack.durability, 40, "durability kept")
	expectEq(inv.slots[index], false, "slot emptied")
	expectEq(Inventory.takeSlot(inv, index), nil, "empty slot")
	expectEq(Inventory.takeSlot(inv, 99), nil, "invalid slot")
end)

test("a cancelled job goes back all or nothing, a tool into its old slot", function()
	-- Slot 2 is where the tool came from; plain adds fill slot 1 or 3 first (FillToolbeltFirst).
	local inv = Inventory.new(2, 1)
	local axe: Inventory.Stack = { id = "StoneAxe", count = 1, source = "Craft", durability = 40 }
	expectEq(Inventory.putSlot(inv, 99, axe), false, "invalid slot")
	local ok = Inventory.addAll(inv, {
		{ stack = axe, slot = 2 },
		{ stack = { id = "SmallStone", count = 2, source = "Loot" }, slot = nil },
	})
	expectEq(ok, true, "fits")
	local home = inv.slots[2]
	expectEq(home and home.id, "StoneAxe", "tool back in its slot")
	expectEq(home and home.durability, 40, "durability kept")
	expectEq(Inventory.putSlot(inv, 2, axe), false, "taken slot")
	local before = Inventory.copySlots(inv)
	local fits, id, left = Inventory.addAll(inv, {
		{ stack = { id = "Wood", count = 3, source = "Loot" }, slot = nil },
		{ stack = { id = "StonePickaxe", count = 1, source = "Loot", durability = 9 }, slot = 2 },
	})
	expectEq(fits, false, "no room for the pickaxe")
	expectEq(id, "StonePickaxe", "what had no room")
	expectEq(left, 1, "how many")
	for index, slot in inv.slots do
		local was = before[index]
		expectEq(slot and slot.count, was and was.count, `slot {index} unchanged`)
	end
end)

test("every recipe and repair is well formed", function()
	local listed = {}
	for _, id in Config.Crafting.Order do
		assert(Recipes[id], `order lists unknown recipe {id}`)
		listed[id] = true
	end
	for id, recipe in Recipes do
		assert(listed[id], `recipe {id} is not in Config.Crafting.Order`)
		assert(Config.Items[recipe.Output], `{id} makes unknown item`)
		assert(recipe.Count >= 1 and recipe.Count % 1 == 0, `{id} count`)
		for _, ingredient in recipe.Ingredients do
			assert(Config.Items[ingredient.Id], `{id} needs unknown item {ingredient.Id}`)
		end
	end
	for id, item in Config.Items do
		if item.Repair then
			assert(item.Durability, `{id} repairs but has no durability`)
			assert(Config.Items[item.Repair.Id], `{id} repairs with an unknown item`)
		end
	end
end)

print("Loot")

test("zombies drop a bag about as often as Config says, with valid stacks", function()
	math.randomseed(7)
	local rolls, bags, tools = 10000, 0, 0
	for _ = 1, rolls do
		local stacks = Loot.rollZombie(math.random)
		if stacks then
			bags += 1
			for _, stack in stacks do
				local item = Config.Items[stack.id]
				assert(item, `unknown item {stack.id}`)
				assert(stack.count >= 1 and stack.count <= item.Stack, `{stack.id} count {stack.count}`)
				if item.Durability then
					tools += 1
					local durability = stack.durability or 0
					assert(durability >= 1 and durability <= item.Durability, `{stack.id} durability {durability}`)
				end
			end
		end
	end
	expectNear(bags / rolls, Config.Loot.ZombieBagChance, 0.015, "bag rate")
	expectNear(tools / bags, Config.Loot.ZombieToolChance, 0.03, "tool rate")
end)

test("loot picks follow their weights and stay in range", function()
	math.randomseed(11)
	local picks: { Config.LootPick } = {
		{ Id = "Wood", Min = 1, Max = 1, Weight = 3 },
		{ Id = "Cloth", Min = 1, Max = 1, Weight = 1 },
	}
	local wood = 0
	for _ = 1, 8000 do
		if Loot.pick(math.random, picks).Id == "Wood" then
			wood += 1
		end
	end
	expectNear(wood / 8000, 0.75, 0.02, "weighted")
	expectEq(Loot.pick(function()
		return 0.999999
	end, picks).Id, "Cloth", "top of the range")
	for _, entry in Config.Loot.ZombieCommon do
		assert(Config.Items[entry.Id], `loot table lists unknown item {entry.Id}`)
		assert(entry.Min >= 1 and entry.Max >= entry.Min, `{entry.Id} range`)
	end
	for _, id in Config.Loot.ZombieTools do
		assert(Config.Items[id] and Config.Items[id].Durability, `{id} is not a tool`)
	end
end)

print("DayClock")

test("the clock runs from dawn to dusk by day and wraps midnight by night", function()
	local DC = Config.DayNight
	local dayLength = DC.CycleSeconds * DC.DayFraction
	local nightLength = DC.CycleSeconds - dayLength
	local dawn = DayClock.at(0)
	expectEq(dawn.day, 1, "day 1")
	expectEq(dawn.phase, "Day", "dawn is day")
	expectNear(dawn.clockTime, DC.DayStartClockTime, 1e-9, "dawn hour")
	expectNear(dawn.phaseLeft, dayLength, 1e-9, "whole day left")
	local start = DayClock.at(DayClock.secondsAt(DC.StartClockTime))
	expectNear(start.clockTime, DC.StartClockTime, 1e-9, "start hour")
	local dusk = DayClock.at(dayLength)
	expectEq(dusk.phase, "Night", "dusk is night")
	expectNear(dusk.clockTime, DC.NightStartClockTime, 1e-9, "dusk hour")
	expectNear(dusk.phaseLeft, nightLength, 1e-9, "whole night left")
	local late = DayClock.at(DC.CycleSeconds - 1e-6)
	expectEq(late.day, 1, "a night belongs to the day it starts on")
	expectNear(late.clockTime, DC.DayStartClockTime, 1e-3, "night ends at dawn")
	local nextDay = DayClock.at(DC.CycleSeconds * 2 + 1)
	expectEq(nextDay.day, 3, "day 3")
	expectEq(nextDay.phase, "Day", "day 3 morning")
	local midnight = DayClock.at(dayLength + nightLength * (24 - DC.NightStartClockTime)
		/ (24 - DC.NightStartClockTime + DC.DayStartClockTime))
	expectNear(midnight.clockTime % 24, 0, 1e-6, "midnight")
	expectEq(DayClock.at(-5).day, 1, "negative time clamps to dawn")
end)

test("horde nights come every n-th day", function()
	expectEq(DayClock.isHordeDay(7, 7), true, "day 7")
	expectEq(DayClock.isHordeDay(14, 7), true, "day 14")
	expectEq(DayClock.isHordeDay(6, 7), false, "day 6")
	expectEq(DayClock.isHordeDay(5, 5), true, "every 5")
	expectEq(DayClock.isHordeDay(3, 0), false, "never")
end)

print("Threat")

test("noise fades fast, trace rises at once and fades a few points a day", function()
	local TC = Config.Threat
	expectNear(Threat.decayNoise(100, 1), 100 * (1 - TC.Noise.DecayPerSecond), 1e-9, "one second")
	expectNear(Threat.decayNoise(100, 0), 100, 1e-9, "no time")
	expectNear(Threat.decayNoise(40, -3), 40, 1e-9, "negative time")
	expectEq(Threat.addNoise(95, 20), TC.Noise.Max, "noise cap")
	expectEq(Threat.addNoise(0, -5), 0, "never below zero")
	expectEq(Threat.stepTrace(10, 30, 0.01), 30, "rises at once")
	expectEq(Threat.stepTrace(30, 0, 1), 30 - TC.Trace.DecayPerDay, "one day of decay")
	expectEq(Threat.stepTrace(30, 28, 5), 28, "never below what is built")
	expectEq(Threat.stepTrace(0, 500, 0), TC.Trace.Max, "trace cap")
	expectNear(Threat.level(10, 20), 10 + 20 * TC.NoiseWeight, 1e-9, "level")
end)

test("threat tiers follow the thresholds and the first days are capped", function()
	local TC = Config.Threat
	local late = TC.EarlyGameDays + 1
	expectEq(Threat.tier(0, late), 1, "quiet")
	expectEq(Threat.tier(TC.TierThresholds[2] - 0.01, late), 1, "just under tier 2")
	expectEq(Threat.tier(TC.TierThresholds[2], late), 2, "tier 2")
	expectEq(Threat.tier(TC.TierThresholds[5], late), 5, "tier 5")
	expectEq(Threat.tier(500, late), 5, "above every threshold")
	expectEq(Threat.tier(500, TC.EarlyGameDays), TC.EarlyGameMaxTier, "early game cap")
	expectEq(Threat.tier(TC.TierThresholds[2], 1), 2, "low tiers are not changed early")
end)

test("the ambient target grows at night and with the tier, up to the cap", function()
	local PC = Config.Population
	expectEq(Threat.ambientTarget(0, "Night", 5), 0, "no players")
	expectEq(Threat.ambientTarget(1, "Day", 1), PC.DayPerPlayer, "one player by day")
	expectEq(Threat.ambientTarget(2, "Night", 1), 2 * PC.NightPerPlayer, "two players at night")
	expectEq(Threat.ambientTarget(1, "Night", 5), math.round(PC.NightPerPlayer * PC.TierMultipliers[5]), "tier 5")
	expectEq(Threat.ambientTarget(6, "Night", 5), PC.Max, "server cap")
	expectEq(Threat.ambientTarget(1, "Day", 9), Threat.ambientTarget(1, "Day", 5), "tier clamped")
end)

test("a horde is 20 zombies per player in waves spread over the night", function()
	local HC = Config.Horde
	expectEq(#Threat.hordeWaves(0, 300), 0, "no players, no horde")
	for _, players in { 1, 2, 3, 6 } do
		local waves = Threat.hordeWaves(players, 300)
		local total = 0
		for _, wave in waves do
			total += wave.count
		end
		expectEq(total, players * HC.ZombiesPerPlayer, `total for {players}`)
		expectEq(#waves, HC.WavesPerNight, `waves for {players}`)
		expectEq(waves[1].at, 0, "first wave at nightfall")
		expectNear(waves[#waves].at, 300 * HC.WaveSpreadFraction, 1e-9, "last wave")
		for index = 2, #waves do
			if waves[index].at <= waves[index - 1].at then
				error("waves out of order")
			end
		end
	end
end)

print("BuildGrid")

test("cells pack into keys and a block sits next to what the ray hit", function()
	local size = Config.Build.GridSize
	for _, cell in { { 0, 0, 0 }, { -3, 7, 12 }, { 255, -40, -256 }, { -1, -1, -1 } } do
		local cx, cy, cz = BuildGrid.unkey(BuildGrid.key(cell[1], cell[2], cell[3]))
		expectEq(cx, cell[1], "x")
		expectEq(cy, cell[2], "y")
		expectEq(cz, cell[3], "z")
	end
	-- Ground at 5.3: the block sinks into it rather than float above it.
	local cx, cy, cz = BuildGrid.target(10.5, 5.3, -2.2, 0, 1, 0, nil)
	expectEq(cx, 2, "ground x")
	expectEq(cz, -1, "ground z")
	expectEq(cy * size <= 5.3 and (cy + 1) * size > 5.3, true, "sinks, never floats")
	-- The side of a block: the next cell along the face.
	local hx, hy, hz = BuildGrid.target(0, 0, 0, 0.97, 0.2, 0.1, { 4, 1, 4 })
	expectEq(hx, 5, "side x")
	expectEq(hy, 1, "side y")
	expectEq(hz, 4, "side z")
	local ux, uy, uz = BuildGrid.target(0, 0, 0, 0.1, 0.99, 0, { 4, 1, 4 })
	expectEq(ux * 100 + uy * 10 + uz, 4 * 100 + 2 * 10 + 4, "top face")
	local x, y, z = BuildGrid.center(1, 2, -1)
	expectEq(x, 1.5 * size, "centre x")
	expectEq(y, 2.5 * size, "centre y")
	expectEq(z, -0.5 * size, "centre z")
end)

test("blocks across a zombie's height block it, weaker walls are cheaper to path through", function()
	local size = Config.Build.GridSize
	expectEq(BuildGrid.obstructs(10 - size, 10), false, "buried under the ground")
	expectEq(BuildGrid.obstructs(10 - 1, 10), true, "sunk by one stud")
	expectEq(BuildGrid.obstructs(10 + Config.Build.BodyHeight, 10), false, "above the head")
	expectEq(BuildGrid.obstructs(10 + 2, 10), true, "a block resting on another")
	expectEq(BuildGrid.pathCost(0), 2, "least cost")
	expectEq(BuildGrid.pathCost(1e6), Config.FlowField.StructureCellCost, "most cost")
	local weak = BuildGrid.pathCost(Config.Build.Blocks.WoodFrame.Health)
	local strong = BuildGrid.pathCost(Config.Build.Blocks.WoodBlock.Health)
	expectEq(weak < strong, true, "a frame is cheaper than a wood block")
end)

test("blocks that lose their way to the ground fall", function()
	local blocks: { [number]: BuildGrid.Support } = {}
	local function put(x: number, y: number, z: number, grounded: boolean)
		blocks[BuildGrid.key(x, y, z)] = { grounded = grounded }
	end
	-- Two pillars two blocks high, joined by a bridge on top, and a lone tower.
	put(0, 0, 0, true)
	put(0, 1, 0, false)
	put(3, 0, 0, true)
	put(3, 1, 0, false)
	put(1, 1, 0, false)
	put(2, 1, 0, false)
	put(9, 0, 9, true)
	put(9, 1, 9, false)
	put(9, 2, 9, false)
	local removed = BuildGrid.key(0, 0, 0)
	blocks[removed] = nil
	expectEq(#BuildGrid.unsupported(blocks, removed), 0, "the bridge still stands on the other pillar")
	removed = BuildGrid.key(3, 0, 0)
	blocks[removed] = nil
	expectEq(#BuildGrid.unsupported(blocks, removed), 4, "both pillars gone: bridge and tops fall")
	removed = BuildGrid.key(9, 1, 9)
	blocks[removed] = nil
	local falling = BuildGrid.unsupported(blocks, removed)
	expectEq(#falling, 1, "the top of the tower falls")
	expectEq(falling[1], BuildGrid.key(9, 2, 9), "which block")
end)

test("a door hangs on its builder's side and swings into its own cell", function()
	local size = Config.Build.GridSize
	local t = Config.Build.DoorThickness
	local mx, my, mz = BuildGrid.center(2, 0, 5)
	expectEq(BuildGrid.sideToward(2, 5, mx, mz - 10), 0, "builder on -Z")
	expectEq(BuildGrid.sideToward(2, 5, mx + 10, mz + 3), 1, "builder on +X")
	expectEq(BuildGrid.sideToward(2, 5, mx - 1, mz + 10), 2, "builder on +Z")
	expectEq(BuildGrid.sideToward(2, 5, mx - 10, mz), 3, "builder on -X")
	local panel = Vector3.new(size, size * 2, t)
	for side = 0, 3 do
		for _, open in { false, true } do
			local cf = BuildGrid.doorCFrame(2, 0, 5, side, open, t)
			-- Every corner of the panel stays inside the door's two cells.
			for _, corner in { { 1, 1, 1 }, { -1, -1, -1 }, { 1, -1, -1 }, { -1, 1, 1 } } do
				local p = cf * (panel / 2 * Vector3.new(corner[1], corner[2], corner[3]))
				local inside = math.abs(p.X - mx) <= size / 2 + 1e-6
					and math.abs(p.Z - mz) <= size / 2 + 1e-6
					and p.Y >= my - size / 2 - 1e-6
					and p.Y <= my + size * 1.5 + 1e-6
				expectEq(inside, true, `side {side} open {open}`)
			end
		end
		local closed = BuildGrid.doorCFrame(2, 0, 5, side, false, t).Position
		local outwards = { Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0) }
		local outward = outwards[side + 1]
		local offset = (closed - Vector3.new(mx, closed.Y, mz)):Dot(outward)
		expectNear(offset, size / 2 - t / 2, 1e-6, `closed door lies on side {side}`)
	end
end)

test("containers roll their own picks and one more in a matching building", function()
	local random = Random.new(7)
	local function rand(): number
		return random:NextNumber()
	end
	for furniture, kind in Config.Loot.ContainerFurniture do
		expectEq(Config.Loot.Containers[kind] ~= nil, true, `{furniture} -> {kind}`)
	end
	local runs = 2000
	local stacks, bonusStacks, food = 0, 0, 0
	for _ = 1, runs do
		local plain = Loot.rollContainer(rand, "Fridge", nil)
		local bonus = Loot.rollContainer(rand, "Fridge", "Food")
		stacks += #plain
		bonusStacks += #bonus
		for _, stack in plain do
			expectEq(Config.Items[stack.id] ~= nil, true, "known item")
			expectEq(stack.count >= 1, true, "at least one")
			local use = Config.Items[stack.id].Use
			if use and use.Food then
				food += 1
			end
		end
	end
	local fridge = Config.Loot.Containers.Fridge
	expectNear(stacks / runs, fridge.Rolls * (1 - fridge.EmptyChance), 0.05, "stacks per fridge")
	expectNear(bonusStacks / runs, (fridge.Rolls + 1) * (1 - fridge.EmptyChance), 0.07, "with the bonus roll")
	expectEq(food > 0, true, "fridges hold food")
	for _ = 1, 200 do
		for _, stack in Loot.rollContainer(rand, "Storage", "Metal") do
			local max = Config.Items[stack.id].Durability
			if max then
				expectEq(stack.count, 1, "one tool")
				expectEq((stack.durability or 0) >= 1 and (stack.durability or 0) <= max, true, "worn tool")
			end
		end
	end
	expectEq(#Loot.rollContainer(rand, "NoSuchKind", nil), 0, "unknown kind")
end)

local SC = Config.Survival
local DAY = Config.DayNight.CycleSeconds

local function run(stats: Vitals.Stats, seconds: number, input: Vitals.Input): (number, number)
	local healed, damage = 0, 0
	for _ = 1, math.round(seconds / SC.TickSeconds) do
		local h, d = Vitals.step(stats, SC.TickSeconds, input)
		healed += h
		damage += d
	end
	return healed, damage
end

test("hunger and thirst stages have 7DTD's margins", function()
	expectEq(Vitals.stage(0, 0.6), 0, "fed")
	expectEq(Vitals.stage(0, 0.5), 1, "hungry at 50 %")
	expectEq(Vitals.stage(1, 0.51), 1, "stays hungry under 52 %")
	expectEq(Vitals.stage(1, 0.53), 0, "fed again above 52 %")
	expectEq(Vitals.stage(0, 0.2), 2, "second stage at 25 %")
	expectEq(Vitals.stage(0, 0.01), 3, "starving at 2 %")
	expectEq(Vitals.stage(3, 0.03), 3, "still starving under 4 %")
	expectEq(Vitals.stage(3, 0.05), 2, "back to the second stage above 4 %")
end)

test("a day drains 30 food and 40 water; hunger and thirst block stamina together", function()
	local stats = Vitals.new()
	run(stats, DAY, { health = 100, maxHealth = 100, sprinting = false, daySeconds = DAY })
	expectNear(stats.food, SC.MaxFood - SC.FoodPerDay, 0.01, "food")
	expectNear(stats.water, SC.MaxWater - SC.WaterPerDay, 0.01, "water")
	expectEq(stats.stamina, SC.MaxStamina, "stamina stays full")
	stats.food, stats.water = 20, 40
	Vitals.consume(stats, 0, 0, 0, 0)
	expectEq(stats.hunger, 2, "hunger stage")
	expectEq(stats.thirst, 1, "thirst stage")
	expectNear(Vitals.staminaCap(stats), 40, 1e-9, "40 % and 20 % blocked")
	expectNear(stats.stamina, 40, 1e-9, "stamina cut to the cap")
	stats.food, stats.water = 1, 1
	Vitals.consume(stats, 0, 0, 0, 0)
	expectEq(Vitals.staminaCap(stats), SC.MinStaminaCap, "both at the last stage keep the floor")
end)

test("sprinting drains stamina; regen is 10 a second and costs food and water", function()
	local stats = Vitals.new()
	local sprint: Vitals.Input = { health = 100, maxHealth = 100, sprinting = true, daySeconds = 1e9 }
	run(stats, 10, sprint)
	expectNear(stats.stamina, SC.MaxStamina - SC.SprintDrain * 10, 1e-6, "after 10 s of sprinting")
	local food, water = stats.food, stats.water
	run(stats, 2, { health = 100, maxHealth = 100, sprinting = false, daySeconds = 1e9 })
	expectNear(stats.stamina, SC.MaxStamina - SC.SprintDrain * 10 + SC.StaminaRegen * 2, 1e-6, "2 s of regen")
	expectNear(food - stats.food, 20 * SC.FoodPerStamina, 1e-6, "food spent")
	expectNear(water - stats.water, 20 * SC.WaterPerStamina, 1e-6, "water spent")
	stats.water = 0
	stats.stamina = 30
	run(stats, 2, { health = 50, maxHealth = 100, sprinting = false, daySeconds = DAY })
	expectEq(stats.stamina, 30, "no stamina regen without water")
end)

test("starving hurts and stops healing; food and medicine heal over time", function()
	local stats = Vitals.new()
	stats.food = 1
	Vitals.consume(stats, 0, 0, 0, 0)
	local input: Vitals.Input = { health = 50, maxHealth = 100, sprinting = false, daySeconds = DAY }
	local healed, damage = run(stats, 23, input)
	expectEq(healed, 0, "no natural healing while starving")
	expectNear(damage, 10 * SC.StarveDamage, 1e-9, "0.25 every 2.2 s")
	stats.water = 1
	Vitals.consume(stats, 0, 0, 0, 0)
	_, damage = run(stats, 23, input)
	expectNear(damage, 20 * SC.StarveDamage, 1e-9, "starving and dehydrated add up")

	stats = Vitals.new()
	stats.food = 60
	local chili = Config.Items.CanChili.Use :: Config.UseDef
	Vitals.consume(stats, chili.Food or 0, 0, chili.Heal or 0, chili.HealRate or 0)
	healed = run(stats, 4, { health = 50, maxHealth = 100, sprinting = false, daySeconds = 1e9 })
	expectNear(stats.food, 64, 1e-6, "food goes in at 1 a second")
	expectNear(healed, 2, 1e-6, "chili heals 0.5 a second")
	run(stats, 30, { health = 50, maxHealth = 100, sprinting = false, daySeconds = 1e9 })
	expectNear(stats.food, 75, 1e-4, "all 15 food in")
	expectEq(stats.healPending, 0, "healing done")
end)

print(`\n{passed} passed, {failed} failed`)
if failed > 0 then
	error("tests failed")
end
