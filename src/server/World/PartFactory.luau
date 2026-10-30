--!strict
-- Creates anchored map parts with a Palette style. All map geometry goes through here so collision,
-- shadows and surfaces are set consistently.

local Palette = require(script.Parent.Palette)

local PartFactory = {}

export type Options = {
	className: string?,
	shape: Enum.PartType?,
	canCollide: boolean?,
	castShadow: boolean?,
}

function PartFactory.make(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	style: Palette.Style,
	options: Options?
): BasePart
	local part = Instance.new(if options and options.className then options.className else "Part") :: BasePart
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = style.color
	part.Material = style.material
	part.Transparency = style.transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if options then
		if options.shape and part:IsA("Part") then
			part.Shape = options.shape
		end
		if options.canCollide ~= nil then
			part.CanCollide = options.canCollide
		end
		if options.castShadow ~= nil then
			part.CastShadow = options.castShadow
		end
	end
	part.Parent = parent
	return part
end

-- Picks a deterministic entry from `list` based on a name.
function PartFactory.pick<T>(list: { T }, key: string): T
	local h = 0
	for i = 1, #key do
		h = (h * 31 + string.byte(key, i)) % 2147483647
	end
	return list[(h % #list) + 1]
end

return PartFactory
