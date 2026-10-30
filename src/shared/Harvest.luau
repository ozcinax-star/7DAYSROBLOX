--!strict
-- Harvest: pure 7DTD gathering math (GameUtils.HarvestOnAttack, docs/REFERENCE_7DTD.md Part B 0).
-- A world object has health and a fixed yield. Two thirds of the yield are paid while it is hit, in
-- proportion to its cumulative damage; the last third comes as a lump on the killing hit. A better
-- tool only gets there faster.

local Harvest = {}

-- Damage of one hit on a world object: the tool's block damage times its material multiplier,
-- truncated to a whole number, at least 1.
function Harvest.blockDamage(blockDamage: number, multiplier: number): number
	return math.max(1, math.floor(blockDamage * multiplier))
end

-- Items a Harvest drop rolled at `count` pays for one hit that takes the object's cumulative damage
-- from `before` to `after` (both capped at `health`, so overkill pays nothing extra). Rounding is
-- done on cumulative damage, so the hits of a fixed count add up to exactly `count`.
function Harvest.payout(count: number, health: number, before: number, after: number): number
	local lump = count // 3
	local pool = count - lump
	local paid = 0
	if pool > 0 then
		local damagePerItem = health / pool
		paid = math.round(after / damagePerItem) - math.round(before / damagePerItem)
	end
	if after >= health and before < health then
		paid += lump
	end
	return paid
end

return Harvest
