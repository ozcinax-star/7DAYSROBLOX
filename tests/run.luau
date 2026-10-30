--!strict
-- Minimal test runner for pure modules. Run with: lune run tests/run

local NavGrid = require("../src/shared/NavGrid")
local ZombieProtocol = require("../src/shared/ZombieProtocol")

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

print(`\n{passed} passed, {failed} failed`)
if failed > 0 then
	error("tests failed")
end
