--!strict
-- Power: pure generator and wiring math (7DTD generator bank, wire tool, relays and powered blocks).
-- Plain numbers only, so the Lune tests can run it.

local Config = require("./Config")

local Power = {}

-- Gas `watts` in use burn over `seconds` (Config.Power: per watt per in-game day).
function Power.burn(watts: number, seconds: number): number
	return watts * Config.Power.FuelPerWattDay * seconds / Config.DayNight.CycleSeconds
end

-- Gas one refuel pours into a generator holding `fuel` from `carried` gas: one step at most, never
-- past the tank.
function Power.refuel(fuel: number, carried: number): number
	local room = math.floor(Config.Power.FuelCapacity - fuel)
	return math.max(0, math.min(Config.Power.RefuelStep, room, carried))
end

-- A powered block in the wire network. Sources make watts while running; relays pass power on and
-- take a little themselves; consumers (lamps, turrets, fence posts) only take.
export type NodeKind = "Source" | "Relay" | "Consumer"
export type Node = { key: number, kind: NodeKind, watts: number, running: boolean? }

-- Whether a wire may run from `parent` to `child` (7DTD: power flows from a source or relay to a
-- relay or consumer; every block has at most one input, and wires never loop back).
-- `parents` maps a child key to the key wired into it.
function Power.canLink(nodes: { [number]: Node }, parents: { [number]: number }, parent: number, child: number): boolean
	local from, to = nodes[parent], nodes[child]
	if from == nil or to == nil or parent == child then
		return false
	end
	if from.kind == "Consumer" or to.kind == "Source" then
		return false
	end
	-- Walking up from the parent must never reach the child.
	local at: number? = parent
	local steps = 0
	while at ~= nil do
		if at == child then
			return false
		end
		at = parents[at]
		steps += 1
		if steps > 10000 then
			return false
		end
	end
	return true
end

-- Which blocks have power, and the watts each source carries. From each running source, its wired
-- blocks are visited in key order (depth first); a block is powered when the source still has its
-- watts to spare, and only a powered relay passes power on. Returns powered[key] and load[sourceKey].
function Power.flow(nodes: { [number]: Node }, parents: { [number]: number }): ({ [number]: boolean }, { [number]: number })
	local children: { [number]: { number } } = {}
	for child, parent in parents do
		if nodes[child] and nodes[parent] then
			local list = children[parent]
			if list == nil then
				list = {}
				children[parent] = list
			end
			table.insert(list, child)
		end
	end
	for _, list in children do
		table.sort(list)
	end
	local powered: { [number]: boolean } = {}
	local load: { [number]: number } = {}
	local sourceKeys: { number } = {}
	for key, node in nodes do
		if node.kind == "Source" and node.running then
			table.insert(sourceKeys, key)
		end
	end
	table.sort(sourceKeys)
	for _, sourceKey in sourceKeys do
		local spare = nodes[sourceKey].watts
		powered[sourceKey] = true
		load[sourceKey] = 0
		local function visit(key: number)
			for _, child in children[key] or {} do
				local node = nodes[child]
				if not powered[child] and node.watts <= spare then
					spare -= node.watts
					load[sourceKey] += node.watts
					powered[child] = true
					if node.kind == "Relay" then
						visit(child)
					end
				end
			end
		end
		visit(sourceKey)
	end
	return powered, load
end

-- Squared distance from point (px, pz) to the segment (ax, az)-(bx, bz) on the ground plane (an
-- electric fence wire between two posts).
function Power.segmentDistanceSq(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
	local dx, dz = bx - ax, bz - az
	local lengthSq = dx * dx + dz * dz
	local t = if lengthSq > 0 then math.clamp(((px - ax) * dx + (pz - az) * dz) / lengthSq, 0, 1) else 0
	local cx, cz = ax + dx * t - px, az + dz * t - pz
	return cx * cx + cz * cz
end

-- Whether a turret facing yaw `facing` (radians, 0 = -Z) may aim at a target `dx, dz` away: within
-- its arc of +-`halfArc` radians.
function Power.inArc(facingX: number, facingZ: number, dx: number, dz: number, halfArc: number): boolean
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-6 then
		return true
	end
	return (facingX * dx + facingZ * dz) / length >= math.cos(halfArc)
end

return Power
