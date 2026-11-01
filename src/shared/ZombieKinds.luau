--!strict
-- The kind of a zombie (Config.Zombie.Kinds), derived from its id like ZombieLook. The server scales
-- health, speed, damage and hearing by it; every client poses the body by it without extra bytes on
-- the wire. Pure Luau, tested by Lune.
local Config = require("./Config")
local Noise = require("./World/Noise")

local ZombieKinds = {}
-- Seed salt, distinct from ZombieLook's, so a kind never correlates with a skin tone or shirt.
local SEED = 4421

local weights: { number } = {}
for index, name in Config.Zombie.KindOrder do
	weights[index] = Config.Zombie.Kinds[name].Weight
end

function ZombieKinds.nameOf(id: number): string
	local r = Noise.hash(id, 31, SEED)
	local total = 0
	for _, w in weights do
		total += w
	end
	local acc = 0
	for index, w in weights do
		acc += w
		if r * total < acc then
			return Config.Zombie.KindOrder[index]
		end
	end
	return Config.Zombie.KindOrder[#weights]
end

function ZombieKinds.of(id: number): Config.ZombieKind
	return Config.Zombie.Kinds[ZombieKinds.nameOf(id)]
end

return ZombieKinds
