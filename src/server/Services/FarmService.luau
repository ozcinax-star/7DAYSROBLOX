--!strict
-- FarmService: crops on farm plots (7DTD 1.0+: seeds grow only on farm plots). A seed in the hand is
-- planted with "use" on a free plot: the server rays from the head like block placement. The crop
-- grows through its stages on the server clock (Shared/Farming) and, once ripe, offers a held
-- "Harvest" prompt that pays its produce and gives the seed back; the plot stays for the next seed.
-- A plot that breaks takes its crop with it. Crops are not saved yet (persistence step).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Farming = require(Shared.Farming)
local Localization = require(Shared.Localization)
local Types = require(Shared.Types)

local BuildService = require(script.Parent.BuildService)
local InventoryService = require(script.Parent.InventoryService)
local LootService = require(script.Parent.LootService)
local ToolService = require(script.Parent.ToolService)

local FC = Config.Farming
local BC = Config.Build
local SOURCE: Types.ItemSource = "Loot"
local STALK_COLOR = Color3.fromRGB(86, 140, 60)
local LEAF_COLOR = Color3.fromRGB(70, 125, 50)

type Crop = {
	kind: string,
	plantedAt: number,
	stage: number,
	top: Vector3,
	model: Model,
}

local FarmService = {}

local folder: Folder
local crops: { [number]: Crop } = {}
local seedCrops: { [string]: string } = {}
local nextPlantAt: { [Player]: number } = {}
local nextCheckAt = 0
local random = Random.new()

local function part(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.Grass
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = model
	return p
end

local function remove(key: number)
	local crop = crops[key]
	if crop then
		crops[key] = nil
		crop.model:Destroy()
	end
end

local function onHarvest(player: Player, key: number, crop: Crop)
	if crops[key] ~= crop or crop.stage < FC.Stages then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character.PrimaryPart
	if humanoid == nil or humanoid.Health <= 0 or root == nil then
		return
	end
	if (root.Position - crop.top).Magnitude > FC.HarvestReach + BC.GridSize then
		return
	end
	local def = FC.Crops[crop.kind]
	remove(key)
	LootService.giveOrDrop(player, def.Produce, Farming.harvestCount(def, random:NextNumber()), SOURCE)
	LootService.giveOrDrop(player, def.Seed, def.SeedBack, SOURCE)
end

-- Rebuilds the crop's model for its stage: a sprout, a growing plant, then the ripe plant with its
-- produce and the harvest prompt.
local function show(key: number, crop: Crop)
	local def = FC.Crops[crop.kind]
	crop.model:ClearAllChildren()
	local share = crop.stage / FC.Stages
	local height = math.max(0.4, def.Height * share)
	local width = 0.25 + 0.2 * share
	local base = CFrame.new(crop.top)
	local stalkSize = Vector3.new(width, height, width)
	local stalk = part(crop.model, "Stalk", stalkSize, base * CFrame.new(0, height / 2, 0), STALK_COLOR)
	if crop.stage > 1 then
		local leaf = Vector3.new(height * 0.7, 0.08, 0.35)
		part(crop.model, "Leaf", leaf, base * CFrame.new(0, height * 0.45, 0) * CFrame.Angles(0, 0.6, 0.3), LEAF_COLOR)
		part(crop.model, "Leaf", leaf, base * CFrame.new(0, height * 0.65, 0) * CFrame.Angles(0, 2.4, -0.3), LEAF_COLOR)
	end
	if crop.stage < FC.Stages then
		return
	end
	local color = Color3.new(def.Color[1], def.Color[2], def.Color[3])
	for i = 1, 3 do
		local angle = i * math.pi * 2 / 3
		local offset = CFrame.new(math.cos(angle) * 0.35, height * (0.4 + 0.12 * i), math.sin(angle) * 0.35)
		part(crop.model, "Produce", Vector3.one * 0.45, base * offset, color, Enum.PartType.Ball)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Localization.get("CropHarvest")
	prompt.ObjectText = Localization.get(`Item{def.Produce}`)
	prompt.HoldDuration = FC.HarvestSeconds
	prompt.MaxActivationDistance = FC.HarvestReach
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player)
		onHarvest(player, key, crop)
	end)
	prompt.Parent = stalk
end

local function update()
	local now = os.clock()
	for key, crop in crops do
		local stage = Farming.stageAt(now - crop.plantedAt)
		if stage ~= crop.stage then
			crop.stage = stage
			show(key, crop)
		end
	end
end

-- ToolService use handler: `origin` is the server's head position, `direction` a checked unit aim.
local function onPlant(player: Player, origin: Vector3, direction: Vector3, itemId: string)
	local kind = seedCrops[itemId]
	local now = os.clock()
	if kind == nil or now < (nextPlantAt[player] or 0) then
		return
	end
	nextPlantAt[player] = now + BC.PlaceCooldown * (1 - Config.Melee.CooldownTolerance)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignored: { Instance } = { folder }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignored, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignored
	params.RespectCanCollide = true
	local result = Workspace:Raycast(origin, direction * BC.MaxPlaceDistance, params)
	if result == nil then
		return
	end
	local key, top = BuildService.plotOf(result.Instance)
	if key == nil or top == nil or crops[key] or not InventoryService.consumeHeld(player, 1) then
		return
	end
	local model = Instance.new("Model")
	model.Name = kind
	model.Parent = folder
	local crop: Crop = { kind = kind, plantedAt = now, stage = 1, top = top, model = model }
	crops[key] = crop
	show(key, crop)
end

-- Debug: makes every crop ripe now.
function FarmService.ripenAll()
	local ripeAt = os.clock() - Farming.ripeSeconds()
	for _, crop in crops do
		crop.plantedAt = math.min(crop.plantedAt, ripeAt)
	end
	update()
end

function FarmService.init()
	folder = Instance.new("Folder")
	folder.Name = FC.FolderName
	folder.Parent = Workspace
	for kind, def in FC.Crops do
		seedCrops[def.Seed] = kind
	end
end

function FarmService.start()
	for seed in seedCrops do
		ToolService.onUse(seed, onPlant)
	end
	BuildService.onRemoved(remove)
	Players.PlayerRemoving:Connect(function(player)
		nextPlantAt[player] = nil
	end)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now >= nextCheckAt then
			nextCheckAt = now + FC.CheckSeconds
			update()
		end
	end)
end

return FarmService
