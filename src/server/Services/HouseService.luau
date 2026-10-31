--!strict
-- HouseService: town house walls can be broken, repaired and reinforced (7DTD: any POI can become a
-- base). BuildingKit builds each wall run from long core parts with decorative linings, all tagged
-- with the run's number ("WallRun"). The first hit on a core cuts it, and the linings on its faces,
-- into cell-wide pieces, so part counts only grow where players work.
--
-- A tool hit damages the piece by its BlockDamage and the material it bites (Config.House); the
-- stone axe repairs a damaged piece for a share of the material's repair cost and, at full health,
-- reinforces it a tier (Config.House.Tiers: planks, then iron plates), adding its base health again.
-- A broken piece drops materials to the breaker and its ground cells open for the zombie paths.
-- Zombies still use doorways (their building navigation is built at start). Nothing is saved yet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Harvest = require(Shared.Harvest)

local InventoryService = require(script.Parent.InventoryService)
local MapService = require(script.Parent.MapService)
local ThreatService = require(script.Parent.ThreatService)
local ToolService = require(script.Parent.ToolService)
local ZombieService = require(script.Parent.ZombieService)

local HC = Config.House
local CELL = Config.Build.GridSize
-- A lining belongs to a core when their centres sit this close in height and depth (studs).
local MATCH = 0.05
local PLANK_COLOR = Color3.fromRGB(120, 86, 52)
local PLATE_COLOR = Color3.fromRGB(96, 100, 98)

type Piece = {
	part: BasePart,
	material: string,
	health: number,
	maxHealth: number,
	tier: number,
	upgrade: number,
	linings: { BasePart },
}

local HouseService = {}

local pieces: { [BasePart]: Piece } = {}
local random = Random.new()

local function materialOf(part: BasePart): string?
	return HC.MaterialOf[part.Material.Name]
end

-- A copy of `source` covering local X from a to b (source's own X runs along the wall).
local function slice(source: BasePart, a: number, b: number): BasePart
	local copy = source:Clone()
	local length = source.Size.X
	copy.Size = Vector3.new(b - a, source.Size.Y, source.Size.Z)
	copy.CFrame = source.CFrame * CFrame.new((a + b) / 2 - length / 2, 0, 0)
	copy.Parent = source.Parent
	return copy
end

-- Cuts `core` into cell-wide pieces and the linings of its run on its faces at the same cuts. A lining
-- reaching past the core keeps its outside parts whole for a later cut.
local function cut(core: BasePart): { Piece }
	local material = materialOf(core) or "Plaster"
	local def = HC.Materials[material]
	local length = core.Size.X
	local count = math.max(1, math.round(length / CELL))
	local width = length / count
	local run = core:GetAttribute("WallRun")
	local model = core.Parent
	local made: { Piece } = {}
	for i = 1, count do
		local part = slice(core, (i - 1) * width, i * width)
		part:SetAttribute("WallPiece", true)
		local piece: Piece = {
			part = part,
			material = material,
			health = def.Health,
			maxHealth = def.Health,
			tier = 0,
			upgrade = 0,
			linings = {},
		}
		pieces[part] = piece
		made[i] = piece
	end
	if model then
		for _, child in model:GetChildren() do
			if not (child:IsA("BasePart") and child.Name == "Lining" and child:GetAttribute("WallRun") == run) then
				continue
			end
			-- In the core's frame: the lining must run along it, at its height, on one of its faces.
			local offset = core.CFrame:PointToObjectSpace(child.Position)
			local along = math.abs(core.CFrame.RightVector:Dot(child.CFrame.RightVector))
			if along < 0.99 or math.abs(offset.Y) > MATCH or math.abs(child.Size.Y - core.Size.Y) > MATCH then
				continue
			end
			if math.abs(offset.Z) > core.Size.Z / 2 + child.Size.Z + MATCH then
				continue
			end
			-- The lining's span in the core's X (0 .. length).
			local lo = offset.X + length / 2 - child.Size.X / 2
			local hi = lo + child.Size.X
			if hi <= MATCH or lo >= length - MATCH then
				continue
			end
			local flip = core.CFrame.RightVector:Dot(child.CFrame.RightVector) < 0
			local function lining(a: number, b: number): BasePart
				-- a, b in the core's X; slice() works in the lining's own X.
				local la, lb = a - lo, b - lo
				if flip then
					la, lb = child.Size.X - (b - lo), child.Size.X - (a - lo)
				end
				return slice(child, la, lb)
			end
			if lo < -MATCH then
				lining(lo, 0)
			end
			if hi > length + MATCH then
				lining(length, hi)
			end
			for i, piece in made do
				local a, b = math.max(lo, (i - 1) * width), math.min(hi, i * width)
				if b - a > MATCH then
					table.insert(piece.linings, lining(a, b))
				end
			end
			child:Destroy()
		end
	end
	core:Destroy()
	return made
end

-- The piece of a wall `part` the hit landed on, cutting the wall on its first hit.
local function pieceAt(part: BasePart, position: Vector3): Piece?
	local piece = pieces[part]
	if piece then
		return piece
	end
	if part:GetAttribute("WallPiece") or part.Name ~= "Wall" or typeof(part:GetAttribute("WallRun")) ~= "number" then
		return nil
	end
	local best, bestDistance = nil :: Piece?, math.huge
	for _, made in cut(part) do
		local distance = (made.part.Position - position).Magnitude
		if distance < bestDistance then
			best, bestDistance = made, distance
		end
	end
	return best
end

-- Planks across both faces for tier 1, a steel plate over each face for tier 2 (decoration only).
local function dress(piece: Piece)
	local part = piece.part
	local size = part.Size
	-- Plates replace the planks.
	for _, child in part:GetChildren() do
		if child.Name == "Reinforcement" then
			child:Destroy()
		end
	end
	for _, side in { -1, 1 } do
		local face = part.CFrame * CFrame.new(0, 0, side * (size.Z / 2 + 0.08))
		if piece.tier == 1 then
			for _, y in { -0.3, 0, 0.3 } do
				local plank = Instance.new("Part")
				plank.Name = "Reinforcement"
				plank.Anchored, plank.CanCollide, plank.CanQuery, plank.CanTouch = true, false, false, false
				plank.Material = Enum.Material.WoodPlanks
				plank.Color = PLANK_COLOR
				plank.Size = Vector3.new(size.X * 0.96, math.min(1.2, size.Y * 0.18), 0.15)
				plank.CFrame = face * CFrame.new(0, y * size.Y, 0) * CFrame.Angles(0, 0, math.rad(if y == 0 then -6 else 4))
				plank.Parent = part
			end
		elseif piece.tier == 2 then
			local plate = Instance.new("Part")
			plate.Name = "Reinforcement"
			plate.Anchored, plate.CanCollide, plate.CanQuery, plate.CanTouch = true, false, false, false
			plate.Material = Enum.Material.DiamondPlate
			plate.Color = PLATE_COLOR
			plate.Size = Vector3.new(size.X * 0.94, size.Y * 0.9, 0.12)
			plate.CFrame = face
			plate.Parent = part
		end
	end
end

local function breakPiece(piece: Piece, player: Player)
	local part = piece.part
	pieces[part] = nil
	local p, size = part.Position, part.Size
	local reach = math.max(size.X, size.Z) / 2
	for _, lining in piece.linings do
		lining:Destroy()
	end
	part:Destroy()
	for _, drop in HC.Materials[piece.material].Drops do
		local count = random:NextInteger(drop.Min, drop.Max)
		if count > 0 then
			InventoryService.give(player, drop.Id, count, "Loot")
		end
	end
	-- Only the ground floor has open-air paths; upper floors keep their own.
	if p.Y - size.Y / 2 < MapService.heightAt(p.X, p.Z) + CELL then
		ZombieService.reopenArea(p.X - reach, p.Z - reach, p.X + reach, p.Z + reach)
	end
end

-- The stone axe: repair a damaged piece, or reinforce a whole one by a tier.
local function work(piece: Piece, player: Player)
	local def = HC.Materials[piece.material]
	if piece.health < piece.maxHealth then
		local repaired = math.min(HC.RepairPerHit, piece.maxHealth - piece.health)
		local cost = math.ceil(repaired * def.Repair.Count / def.Health)
		if InventoryService.take(player, { [def.Repair.Id] = cost }) then
			piece.health += repaired
		end
		return
	end
	local tier = HC.Tiers[piece.tier + 1]
	if tier == nil or InventoryService.count(player, tier.Id) < tier.Count then
		return
	end
	piece.upgrade += 1
	if piece.upgrade < HC.UpgradeHits then
		return
	end
	if InventoryService.take(player, { [tier.Id] = tier.Count }) then
		piece.tier += 1
		piece.upgrade = 0
		piece.maxHealth = def.Health * (1 + piece.tier)
		piece.health = piece.maxHealth
		dress(piece)
	end
end

local function onWorldHit(player: Player, result: RaycastResult, toolId: string, tool: Config.ToolDef)
	local part = result.Instance
	if not part:IsA("BasePart") then
		return
	end
	local piece = pieceAt(part, result.Position)
	if piece == nil then
		return
	end
	if toolId == Config.Build.UpgradeTool then
		work(piece, player)
	else
		local def = HC.Materials[piece.material]
		ThreatService.emit("Harvest", result.Position, player)
		piece.health -= Harvest.blockDamage(tool.BlockDamage, tool.Materials[def.Harvest])
		if piece.health <= 0 then
			ToolService.reportHit(player, 0, piece.maxHealth)
			breakPiece(piece, player)
			return
		end
	end
	ToolService.reportHit(player, piece.health, piece.maxHealth)
end

function HouseService.init() end

function HouseService.start()
	ToolService.onWorldHit(onWorldHit)
end

return HouseService
