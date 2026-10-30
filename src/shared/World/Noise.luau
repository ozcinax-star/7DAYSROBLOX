--!strict
-- Deterministic 2D value noise. Pure Luau (no math.noise) so terrain heights are identical in Roblox
-- and in Lune tests, and server/client agree on the ground height.

local Noise = {}

local UINT32 = 4294967296

-- (a * b) mod 2^32 without losing precision in doubles (b is split into 16-bit halves).
local function mul32(a: number, b: number): number
	local lo = b % 65536
	local hi = (b - lo) / 65536
	return (a * lo + ((a * hi) % 65536) * 65536) % UINT32
end

local function hash(ix: number, iz: number, seed: number): number
	-- Integer hash -> [0, 1)
	local h = (mul32(ix % UINT32, 374761393) + mul32(iz % UINT32, 668265263) + mul32(seed % UINT32, 2246822519))
		% UINT32
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = mul32(h, 1274126177)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h / UINT32
end

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

-- Value noise in [0, 1].
function Noise.value(x: number, z: number, seed: number): number
	local ix = math.floor(x)
	local iz = math.floor(z)
	local fx = smooth(x - ix)
	local fz = smooth(z - iz)
	local a = hash(ix, iz, seed)
	local b = hash(ix + 1, iz, seed)
	local c = hash(ix, iz + 1, seed)
	local d = hash(ix + 1, iz + 1, seed)
	local top = a + (b - a) * fx
	local bottom = c + (d - c) * fx
	return top + (bottom - top) * fz
end

-- Fractal noise in roughly [0, 1]: `octaves` layers, each at double frequency and half amplitude.
function Noise.fractal(x: number, z: number, seed: number, octaves: number): number
	local sum, amplitude, frequency, total = 0, 1, 1, 0
	for octave = 1, octaves do
		sum += Noise.value(x * frequency, z * frequency, seed + octave) * amplitude
		total += amplitude
		amplitude *= 0.5
		frequency *= 2
	end
	return sum / total
end

-- Hash of a grid position in [0, 1); used for deterministic scattering.
Noise.hash = hash

return Noise
