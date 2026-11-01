--!strict
-- ZombieMeshes: cuts each textured zombie shirt (ZombieAssets.Torsos) into a body and two sleeves
-- once per client, so ZombieRig can hang each sleeve on its own upper arm. A shirt mesh is rigid:
-- drawn whole on the torso, its sleeves stayed put while the arms swung underneath them.
--
-- The cut runs in the mesh's native space: a face whose centre lies outside SleeveX and below
-- SleeveTop belongs to that side's sleeve. Pieces are MeshParts made from EditableMeshes; the rig
-- clones them. Until the cut is ready, or when the engine refuses EditableMesh (an experience
-- without mesh API access), `torso` returns nil and the rig draws a block shirt instead.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZombieAssets = require(Shared.ZombieAssets)

-- One piece of a cut shirt: a MeshPart template and its box in native mesh coordinates.
export type Piece = { part: MeshPart, center: Vector3, size: Vector3 }
-- Sleeves in the rig's arm order: left (-X), right (+X).
export type Split = { body: Piece, sleeves: { Piece } }

local ZombieMeshes = {}

local splits: { [number]: Split } = {}
-- EditableMeshes stay referenced for as long as their MeshParts are drawn.
local editables: { EditableMesh } = {}
local started = false

local function sideOf(center: Vector3, asset: ZombieAssets.Mesh): number
	local x, top = asset.sleeveX :: number, asset.sleeveTop :: number
	if center.Y >= top then
		return 0
	elseif center.X > x then
		return 1
	elseif center.X < -x then
		return -1
	end
	return 0
end

-- The faces of `asset` on `side` (0 = body) as a MeshPart template, or nil if nothing is left.
local function cut(asset: ZombieAssets.Mesh, side: number): Piece?
	local mesh = AssetService:CreateEditableMeshAsync(Content.fromUri(asset.mesh), { FixedSize = false })
	for _, face in mesh:GetFaces() do
		local center = Vector3.zero
		local vertices = mesh:GetFaceVertices(face)
		for _, vertex in vertices do
			center += mesh:GetPosition(vertex)
		end
		if sideOf(center / #vertices, asset) ~= side then
			mesh:RemoveFace(face)
		end
	end
	mesh:RemoveUnused()
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, vertex in mesh:GetVertices() do
		local p = mesh:GetPosition(vertex)
		low = low:Min(p)
		high = high:Max(p)
	end
	if low.X > high.X then
		mesh:Destroy()
		return nil
	end
	-- A MeshPart draws its mesh around the mesh origin, not around the piece's box: centre it.
	local center = (low + high) / 2
	for _, vertex in mesh:GetVertices() do
		mesh:SetPosition(vertex, mesh:GetPosition(vertex) - center)
	end
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh))
	part.TextureID = asset.texture
	table.insert(editables, mesh)
	return { part = part, center = center, size = high - low }
end

local function build(index: number, asset: ZombieAssets.Mesh)
	local ok, result = pcall(function(): Split?
		local body, left, right = cut(asset, 0), cut(asset, -1), cut(asset, 1)
		if body == nil or left == nil or right == nil then
			return nil
		end
		return { body = body, sleeves = { left, right } }
	end)
	if ok and result then
		splits[index] = result
	elseif not ok then
		warn(`ZombieMeshes: shirt {index} stays a block shirt ({result})`)
	end
end

-- Starts cutting every shirt that has sleeve cut lines; returns at once.
function ZombieMeshes.prepare()
	if started then
		return
	end
	started = true
	for index, asset in ZombieAssets.Torsos do
		if asset.sleeveX and asset.sleeveTop then
			task.spawn(build, index, asset)
		end
	end
end

-- The cut shirt `index`, or nil while it is not ready (or could not be cut).
function ZombieMeshes.torso(index: number): Split?
	return splits[index]
end

return ZombieMeshes
