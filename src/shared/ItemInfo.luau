--!strict
-- ItemInfo: the numbers an item's info panel shows, read from Config (7DTD shows a selected item's
-- stats under its description): a melee tool's damage, durability, what food, drink or medicine
-- gives, a placed block's hit points and the ammo a weapon takes. Each line is a Localization key and
-- its value; the client formats them.

local Config = require("./Config")

export type Line = { key: string, value: string }

local ItemInfo = {}

local function number(value: number): string
	return string.format("%g", math.floor(value * 10 + 0.5) / 10)
end

local function signed(value: number): string
	return if value > 0 then `+{number(value)}` else number(value)
end

function ItemInfo.lines(id: string): { Line }
	local lines: { Line } = {}
	local item = Config.Items[id]
	if item == nil then
		return lines
	end
	local tool = Config.Tools[id]
	if tool then
		table.insert(lines, { key = "InfoDamage", value = number(tool.EntityDamage) })
		table.insert(lines, { key = "InfoBlockDamage", value = number(tool.BlockDamage) })
	end
	local weapon = Config.Ranged.Weapons[id]
	if weapon then
		local names = table.create(#weapon.Ammo)
		for _, ammo in weapon.Ammo do
			table.insert(names, ammo)
		end
		table.insert(lines, { key = "InfoAmmo", value = table.concat(names, ",") })
	end
	if item.Durability then
		table.insert(lines, { key = "InfoDurability", value = number(item.Durability) })
	end
	local use = item.Use
	if use then
		if use.Food and use.Food ~= 0 then
			table.insert(lines, { key = "InfoFood", value = signed(use.Food) })
		end
		if use.Water and use.Water ~= 0 then
			table.insert(lines, { key = "InfoWater", value = signed(use.Water) })
		end
		local health = (use.Heal or 0) - (use.Damage or 0)
		if health ~= 0 then
			table.insert(lines, { key = "InfoHeal", value = signed(health) })
		end
	end
	local block = Config.Build.Blocks[id]
	if block then
		table.insert(lines, { key = "InfoHitPoints", value = number(block.Health) })
	end
	return lines
end

return ItemInfo
