--!strict
-- Writes the map terrain from HeightField in chunks. Also produces the height grid (one sample per
-- 4-stud column, matching the navigation cells) that MapService and ZombieService share.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HeightField = require(ReplicatedStorage.Shared.World.HeightField)
local WorldLayout = require(ReplicatedStorage.Shared.World.WorldLayout)

local TerrainBuilder = {}

-- Terrain voxel resolution is fixed at 4 studs by Roblox.
local VOXEL = 4
-- Voxel columns per WriteVoxels call (per axis).
local CHUNK = 64
-- Below the surface layer the ground is plain dirt (rock in the mountains), and rock deeper than
-- ROCK_DEPTH under the surface (7DTD: forest ground, 3 dirt, then stone).
local SURFACE_DEPTH = 4
local ROCK_DEPTH = 12
-- Measured in Studio: a solid column whose topmost non-empty voxel starts at b with occupancy o is
-- meshed with its surface at b + 2 + 4 * o, so solid occupancy is computed against h - 2. Water has no
-- such offset (surface = b + 4 * o).
local SOLID_SURFACE_OFFSET = 2

export type HeightGrid = {
	columns: number,
	half: number,
	heights: buffer,
	surfaces: { string },
}

local materialCache: { [string]: Enum.Material } = {}
local function material(name: string): Enum.Material
	local cached = materialCache[name]
	if cached == nil then
		cached = (Enum.Material :: any)[name]
		materialCache[name] = cached
	end
	return cached
end

-- Samples heights and surfaces for every 4-stud column. Yields between rows.
function TerrainBuilder.sample(): HeightGrid
	local half = WorldLayout.HalfSize
	local columns = math.floor(half * 2 / VOXEL)
	local heights = buffer.create(columns * columns * 4)
	local surfaces = table.create(columns * columns)
	for cz = 0, columns - 1 do
		local z = (cz + 0.5) * VOXEL - half
		for cx = 0, columns - 1 do
			local x = (cx + 0.5) * VOXEL - half
			local h = HeightField.heightAt(x, z)
			local index = cz * columns + cx
			buffer.writef32(heights, index * 4, h)
			surfaces[index + 1] = HeightField.surfaceAt(x, z, h)
		end
		if cz % 16 == 0 then
			task.wait()
		end
	end
	return { columns = columns, half = half, heights = heights, surfaces = surfaces }
end

function TerrainBuilder.build(grid: HeightGrid)
	local terrain = Workspace.Terrain
	terrain:Clear()

	local columns, half = grid.columns, grid.half
	local bottom = WorldLayout.TerrainBottom
	local waterLevel = HeightField.waterLevel()
	local airMaterial = Enum.Material.Air
	local waterMaterial = Enum.Material.Water
	local groundMaterial = Enum.Material.Ground
	local rockMaterial = Enum.Material.Rock

	for chunkZ = 0, columns - 1, CHUNK do
		for chunkX = 0, columns - 1, CHUNK do
			local sizeX = math.min(CHUNK, columns - chunkX)
			local sizeZ = math.min(CHUNK, columns - chunkZ)

			local maxH = waterLevel
			for cz = chunkZ, chunkZ + sizeZ - 1 do
				for cx = chunkX, chunkX + sizeX - 1 do
					maxH = math.max(maxH, buffer.readf32(grid.heights, (cz * columns + cx) * 4))
				end
			end
			local y0 = math.floor(bottom / VOXEL) * VOXEL
			local layers = math.ceil((maxH - y0) / VOXEL) + 1

			local materials = table.create(sizeX)
			local occupancy = table.create(sizeX)
			for ix = 1, sizeX do
				local matX = table.create(layers)
				local occX = table.create(layers)
				for iy = 1, layers do
					matX[iy] = table.create(sizeZ, airMaterial)
					occX[iy] = table.create(sizeZ, 0)
				end
				materials[ix] = matX
				occupancy[ix] = occX
			end

			for iz = 1, sizeZ do
				local cz = chunkZ + iz - 1
				for ix = 1, sizeX do
					local cx = chunkX + ix - 1
					local index = cz * columns + cx
					local h = buffer.readf32(grid.heights, index * 4)
					local surface = material(grid.surfaces[index + 1])
					local under = if surface == rockMaterial or surface == Enum.Material.Snow
						then rockMaterial
						else groundMaterial
					local x = (cx + 0.5) * VOXEL - half
					local z = (cz + 0.5) * VOXEL - half
					local water = HeightField.isWater(x, z)
					local matX = materials[ix]
					local occX = occupancy[ix]
					for iy = 1, layers do
						local voxelBottom = y0 + (iy - 1) * VOXEL
						local fill = math.clamp((h - SOLID_SURFACE_OFFSET - voxelBottom) / VOXEL, 0, 1)
						if fill > 0 then
							matX[iy][iz] = if voxelBottom + VOXEL >= h - SURFACE_DEPTH
								then surface
								elseif voxelBottom + VOXEL <= h - ROCK_DEPTH then rockMaterial
								else under
							occX[iy][iz] = fill
						end
						if water and fill < 0.5 and voxelBottom < waterLevel then
							matX[iy][iz] = waterMaterial
							occX[iy][iz] = math.clamp((waterLevel - voxelBottom) / VOXEL, 0, 1)
						end
					end
				end
			end

			local minCorner = Vector3.new(chunkX * VOXEL - half, y0, chunkZ * VOXEL - half)
			local region = Region3.new(
				minCorner,
				minCorner + Vector3.new(sizeX * VOXEL, layers * VOXEL, sizeZ * VOXEL)
			)
			terrain:WriteVoxels(region, VOXEL, materials, occupancy)
			task.wait()
		end
	end
end

-- Lowest surface height a column may have with `layers` whole voxels left above the terrain bottom.
function TerrainBuilder.floorHeight(layers: number): number
	return math.floor(WorldLayout.TerrainBottom / VOXEL) * VOXEL + layers * VOXEL + SOLID_SURFACE_OFFSET
end

-- Centre (x, z) of column `index`.
function TerrainBuilder.columnCentre(grid: HeightGrid, index: number): (number, number)
	local cx, cz = index % grid.columns, index // grid.columns
	return (cx + 0.5) * VOXEL - grid.half, (cz + 0.5) * VOXEL - grid.half
end

-- Rewrites the voxels of dry column `index` so its surface moves from `from` to `to`. Voxels keep their
-- material; voxels that fill up from air take `fillMaterial`. Returns the material now on top. The
-- grid's walking height is left to the caller: Roblox rounds narrow holes off, so the surface it
-- meshes is not always the voxel height.
function TerrainBuilder.writeColumn(
	grid: HeightGrid,
	index: number,
	from: number,
	to: number,
	fillMaterial: Enum.Material
): Enum.Material
	local terrain = Workspace.Terrain
	local x, z = TerrainBuilder.columnCentre(grid, index)
	local y0 = math.floor(WorldLayout.TerrainBottom / VOXEL) * VOXEL
	local layers = math.ceil((math.max(from, to) - y0) / VOXEL) + 1
	local minCorner = Vector3.new(x - VOXEL / 2, y0, z - VOXEL / 2)
	local region = Region3.new(minCorner, minCorner + Vector3.new(VOXEL, layers * VOXEL, VOXEL))
	local materials, occupancy = terrain:ReadVoxels(region, VOXEL)
	local airMaterial = Enum.Material.Air
	local top = fillMaterial
	for iy = 1, layers do
		local voxelBottom = y0 + (iy - 1) * VOXEL
		local fill = math.clamp((to - SOLID_SURFACE_OFFSET - voxelBottom) / VOXEL, 0, 1)
		if fill > 0 then
			if materials[1][iy][1] == airMaterial then
				materials[1][iy][1] = fillMaterial
			end
			occupancy[1][iy][1] = fill
			top = materials[1][iy][1]
		else
			materials[1][iy][1] = airMaterial
			occupancy[1][iy][1] = 0
		end
	end
	terrain:WriteVoxels(region, VOXEL, materials, occupancy)
	grid.surfaces[index + 1] = top.Name
	return top
end

-- Walking height of column `index`.
function TerrainBuilder.heightOf(grid: HeightGrid, index: number): number
	return buffer.readf32(grid.heights, index * 4)
end

-- Sets the walking height of column `index` (MapService.heightAt and the zombies follow it).
function TerrainBuilder.setHeight(grid: HeightGrid, index: number, height: number)
	buffer.writef32(grid.heights, index * 4, height)
end

-- Index of the 4-stud column containing (x, z), or nil outside the grid.
function TerrainBuilder.columnAt(grid: HeightGrid, x: number, z: number): number?
	local cx = (x + grid.half) // VOXEL
	local cz = (z + grid.half) // VOXEL
	if cx < 0 or cz < 0 or cx >= grid.columns or cz >= grid.columns then
		return nil
	end
	return cz * grid.columns + cx
end

-- Bilinear ground height from the sampled grid (matches the terrain surface).
function TerrainBuilder.heightAt(grid: HeightGrid, x: number, z: number): number
	local columns = grid.columns
	local fx = math.clamp((x + grid.half) / VOXEL - 0.5, 0, columns - 1)
	local fz = math.clamp((z + grid.half) / VOXEL - 0.5, 0, columns - 1)
	local x0 = math.floor(fx)
	local z0 = math.floor(fz)
	local x1 = math.min(x0 + 1, columns - 1)
	local z1 = math.min(z0 + 1, columns - 1)
	local tx, tz = fx - x0, fz - z0
	local heights = grid.heights
	local a = buffer.readf32(heights, (z0 * columns + x0) * 4)
	local b = buffer.readf32(heights, (z0 * columns + x1) * 4)
	local c = buffer.readf32(heights, (z1 * columns + x0) * 4)
	local d = buffer.readf32(heights, (z1 * columns + x1) * 4)
	local top = a + (b - a) * tx
	local bottomRow = c + (d - c) * tx
	return top + (bottomRow - top) * tz
end

return TerrainBuilder
