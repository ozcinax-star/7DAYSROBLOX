--!strict
-- Binary snapshot format for zombie replication. Pure Luau so Lune can test it.
--
-- Packet: f64 serverTime | u16 count | count * entry
-- Entry:  u16 id | i16 x | i16 y | i16 z | u8 flags   (positions quantized by positionScale)
-- Flags:  state code in bits 0-3, knockdown pose in bits 4-5, crippled in bit 6 (Shared/Combat).

local Combat = require("./Combat")

local ZombieProtocol = {}

local HEADER_SIZE = 10
local ENTRY_SIZE = 9
local INT16_MIN = -32768
local INT16_MAX = 32767

-- Wire codes; order is part of the protocol.
ZombieProtocol.States = {
	"Idle",
	"Wander",
	"SeekSound",
	"Search",
	"Chase",
	"AttackPlayer",
	"AttackStructure",
}

local stateToCode: { [string]: number } = {}
for code, name in ZombieProtocol.States do
	stateToCode[name] = code
end

export type Entry = {
	id: number,
	x: number,
	y: number,
	z: number,
	state: string,
	pose: number?,
	crippled: boolean?,
}

local function quantize(value: number, scale: number): number
	return math.clamp(math.round(value * scale), INT16_MIN, INT16_MAX)
end

function ZombieProtocol.packetSize(count: number): number
	return HEADER_SIZE + count * ENTRY_SIZE
end

-- Encodes entries[first..last] into one packet.
function ZombieProtocol.encode(
	serverTime: number,
	entries: { Entry },
	first: number,
	last: number,
	positionScale: number
): buffer
	local count = last - first + 1
	local b = buffer.create(ZombieProtocol.packetSize(count))
	buffer.writef64(b, 0, serverTime)
	buffer.writeu16(b, 8, count)
	local offset = HEADER_SIZE
	for i = first, last do
		local e = entries[i]
		buffer.writeu16(b, offset, e.id)
		buffer.writei16(b, offset + 2, quantize(e.x, positionScale))
		buffer.writei16(b, offset + 4, quantize(e.y, positionScale))
		buffer.writei16(b, offset + 6, quantize(e.z, positionScale))
		buffer.writeu8(b, offset + 8, Combat.packFlags(stateToCode[e.state] or 1, e.pose or 0, e.crippled == true))
		offset += ENTRY_SIZE
	end
	return b
end

-- Decodes a packet; calls onEntry for each zombie. Returns the server time, or nil if malformed.
function ZombieProtocol.decode(
	b: buffer,
	positionScale: number,
	onEntry: (id: number, x: number, y: number, z: number, state: string, pose: number, crippled: boolean) -> ()
): number?
	local length = buffer.len(b)
	if length < HEADER_SIZE then
		return nil
	end
	local serverTime = buffer.readf64(b, 0)
	local count = buffer.readu16(b, 8)
	if length ~= ZombieProtocol.packetSize(count) then
		return nil
	end
	local offset = HEADER_SIZE
	for _ = 1, count do
		local id = buffer.readu16(b, offset)
		local x = buffer.readi16(b, offset + 2) / positionScale
		local y = buffer.readi16(b, offset + 4) / positionScale
		local z = buffer.readi16(b, offset + 6) / positionScale
		local code, pose, crippled = Combat.unpackFlags(buffer.readu8(b, offset + 8))
		local state = ZombieProtocol.States[code] or "Idle"
		onEntry(id, x, y, z, state, pose, crippled)
		offset += ENTRY_SIZE
	end
	return serverTime
end

return ZombieProtocol
