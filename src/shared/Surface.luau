--!strict
-- Surface: the colour of what a ray struck, for impact effects (ToolService sends it with a melee hit,
-- ArrowController finds it where a bullet stopped). Terrain gives its material colour.

local Surface = {}

-- Dust colour when the struck thing has none of its own (studs of air, water, a mesh's texture).
Surface.DEFAULT_COLOR = Color3.fromRGB(120, 105, 85)

function Surface.color(result: RaycastResult): Color3
	local instance = result.Instance
	if instance:IsA("Terrain") then
		-- Some materials (air, water) have no material colour.
		local ok, color = pcall(instance.GetMaterialColor, instance, result.Material)
		return if ok and typeof(color) == "Color3" then color else Surface.DEFAULT_COLOR
	end
	if instance:IsA("BasePart") then
		return instance.Color
	end
	return Surface.DEFAULT_COLOR
end

return Surface
