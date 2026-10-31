--!strict
-- Reconstructs original, published equipment meshes from the versioned asset manifest.
-- File meshes are cosmetic Parts, so they need no runtime InsertService, HTTP or asset loading code.
-- Keeping the source mesh dimensions allows a uniform scale rather than distorting the silhouette.

local Assets = require("./EquipmentAssets")
local V = Vector3.new
local BASIS = CFrame.fromMatrix(Vector3.zero, V(0, -1, 0), V(0, 0, -1), V(1, 0, 0))

local EquipmentMeshes = {}

function EquipmentMeshes.build(id: string, model: Model, root: BasePart, length: number): (boolean, boolean)
	local asset = Assets[id]
	if asset == nil then return false, false end
	local bounds = asset.bounds
	local center = V(bounds[1], bounds[2], bounds[3])
	local scale = asset.span / (if asset.kind == "Gun" then bounds[6] else bounds[5])
	local origin = center
	local placement = CFrame.identity
	if asset.kind == "Tool" then
		placement = BASIS * CFrame.new(0, (asset.span - length) / 2, 0)
	elseif asset.kind == "Gun" then
		origin = V(asset.grip[1], asset.grip[2], asset.grip[3])
	end
	local rotation = CFrame.Angles(math.rad(asset.pitch), math.rad(asset.yaw), 0)
	for _, source in asset.parts do
		local transform = source.transform
		local sourceCF = CFrame.new(
			transform[1], transform[2], transform[3],
			transform[4], transform[5], transform[6],
			transform[7], transform[8], transform[9],
			transform[10], transform[11], transform[12]
		)
		local offset = placement * rotation * CFrame.new((sourceCF.Position - origin) * scale) * sourceCF.Rotation
		local size = V(source.size[1], source.size[2], source.size[3]) * scale
		local native = V(source.native[1], source.native[2], source.native[3])
		local p = Instance.new("Part")
		p.Name = source.name
		p.Size = size
		p.Color = Color3.new(1, 1, 1)
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		p.Massless, p.CastShadow = true, false
		p.CFrame = root.CFrame * offset
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.MeshId, mesh.TextureId = source.mesh, source.texture
		mesh.Scale = size / native
		mesh.Parent = p
		local weld = Instance.new("Weld")
		weld.Part0, weld.Part1, weld.C0 = root, p, offset
		weld.Parent = p
		p.Parent = model
	end
	model:SetAttribute("ItemId", id)
	model:SetAttribute("VisualRevision", 3)
	model:SetAttribute("SourceAsset", asset.asset)
	return true, asset.hybrid
end

return EquipmentMeshes
