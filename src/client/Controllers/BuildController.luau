--!strict
-- BuildController: while a block item is in the hand, a see-through cube (a panel for a door, a slab
-- for a farm plot, a smaller box for a generator or lamp) shows where "use" will put it, green when
-- the spot looks free and supported, red otherwise. The cell comes from the same raycast and
-- Shared/BuildGrid math as the server's (a block may sink into the floor it stands on; inside a town
-- building only its ground storey takes blocks); the server decides. Plain cubes go up as a wall of
-- the chosen size (Config.Build.WallSizes; Z, D-pad up or the Size button), one ghost per cell.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildGrid = require(Shared.BuildGrid)
local Config = require(Shared.Config)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

local InventoryController = require(script.Parent.InventoryController)
local ToolController = require(script.Parent.ToolController)

local BC = Config.Build
local GHOST_TRANSPARENCY = 0.65
local GHOST_INSET = 0.04
local VALID_COLOR = Color3.fromRGB(110, 220, 120)
local INVALID_COLOR = Color3.fromRGB(230, 80, 70)

local BuildController = {}

local player = Players.LocalPlayer
local ghost: Part
-- Ghosts for the other cells of a wall, made as needed.
local extraGhosts: { Part } = {}
local sizeIndex = 1
local sizeLabel: TextLabel
local sizeButton: TextButton
local structures: Folder
-- Terrain and the map, what carries a block (the server's groundParams).
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.RespectCanCollide = true
groundParams.IgnoreWater = true

local function cellOfPart(part: Instance): { number }?
	if not part:IsDescendantOf(structures) then
		return nil
	end
	local x, y, z = part:GetAttribute("CellX"), part:GetAttribute("CellY"), part:GetAttribute("CellZ")
	if typeof(x) == "number" and typeof(y) == "number" and typeof(z) == "number" then
		return { x, y, z }
	end
	return nil
end

-- The server's indoor rule, from the attributes it puts on town building models.
local function indoorBlocked(cx: number, cy: number, cz: number): boolean
	for _, model in CollectionService:GetTagged(BC.BuildingTag) do
		local low, high = model:GetAttribute("BuildMin"), model:GetAttribute("BuildMax")
		local top = model:GetAttribute("BuildTop")
		if
			typeof(low) == "Vector2"
			and typeof(high) == "Vector2"
			and typeof(top) == "number"
			and BuildGrid.indoorBlocked(cx, cy, cz, low.X, low.Y, high.X, high.Y, top)
		then
			return true
		end
	end
	return false
end

local function occupied(cx: number, cy: number, cz: number): boolean
	if indoorBlocked(cx, cy, cz) then
		return true
	end
	local x, _, z = BuildGrid.center(cx, cy, cz)
	local ignored: { Instance } = { ghost }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignored, other.Character)
		end
	end
	-- What the cell stands on (map or terrain only), so it may sink into a floor slab or kerb.
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { structures, Workspace.CurrentCamera, table.unpack(ignored) }
	rayParams.RespectCanCollide = true
	rayParams.IgnoreWater = true
	local rx, ry, rz, length = BuildGrid.sinkRay(cx, cy, cz)
	local surface = Workspace:Raycast(Vector3.new(rx, ry, rz), Vector3.new(0, -length, 0), rayParams)
	local bottom, top = BuildGrid.clearSpan(cy, if surface then surface.Position.Y else nil)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignored
	params.RespectCanCollide = true
	local size = Vector3.new(BC.GridSize - BC.OverlapInset * 2, top - bottom, BC.GridSize - BC.OverlapInset * 2)
	return #Workspace:GetPartBoundsInBox(CFrame.new(x, (bottom + top) / 2, z), size, params) > 0
end

local function supported(cx: number, cy: number, cz: number): boolean
	for _, step in BuildGrid.NEIGHBOURS do
		local x, y, z = BuildGrid.center(cx + step[1], cy + step[2], cz + step[3])
		for _, part in Workspace:GetPartBoundsInRadius(Vector3.new(x, y, z), 0.5) do
			if part:IsDescendantOf(structures) then
				return true
			end
		end
	end
	local x, y, z, length = BuildGrid.groundRay(cx, cy, cz)
	return Workspace:Raycast(Vector3.new(x, y, z), Vector3.new(0, -length, 0), groundParams) ~= nil
end

local function isPlain(def: Config.BlockDef): boolean
	return not (def.Door or def.Plot or def.Size or def.Bed or def.Climbable)
end

local function ghostAt(index: number): Part
	if index == 1 then
		return ghost
	end
	local extra = extraGhosts[index - 1]
	if extra == nil then
		extra = ghost:Clone()
		extraGhosts[index - 1] = extra
	end
	return extra
end

local function hideGhosts(from: number)
	if from <= 1 then
		ghost.Parent = nil
	end
	for i = math.max(1, from - 1), #extraGhosts do
		extraGhosts[i].Parent = nil
	end
end

local function sizeText(): string
	local size = BC.WallSizes[sizeIndex]
	return Localization.get("BuildSize", {
		width = size[1],
		height = size[2],
		key = UserInputService:GetStringForKeyCode(Enum.KeyCode.Z),
	})
end

local function changeSize()
	local held = InventoryController.getHeld()
	local def = held and BC.Blocks[held.id]
	if def == nil or not isPlain(def) then
		return
	end
	sizeIndex = sizeIndex % #BC.WallSizes + 1
	Net.event("BuildSize"):FireServer(sizeIndex)
	sizeLabel.Text = sizeText()
end

local function update()
	local held = InventoryController.getHeld()
	local def = held and BC.Blocks[held.id]
	local plainHeld = def ~= nil and isPlain(def) and not InventoryController.isBackpackOpen()
	sizeLabel.Visible = plainHeld
	sizeButton.Visible = plainHeld and UserInputService.TouchEnabled
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local aim = if def and not InventoryController.isBackpackOpen() then ToolController.aimDirection() else nil
	if aim == nil or character == nil or head == nil or not head:IsA("BasePart") then
		hideGhosts(1)
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, ghost }
	params.IgnoreWater = true
	params.RespectCanCollide = true
	local result = Workspace:Raycast(head.Position, aim * BC.MaxPlaceDistance, params)
	if result == nil then
		hideGhosts(1)
		return
	end
	local p, n = result.Position, result.Normal
	local cx, cy, cz = BuildGrid.target(p.X, p.Y, p.Z, n.X, n.Y, n.Z, cellOfPart(result.Instance))
	local x, y, z = BuildGrid.center(cx, cy, cz)
	local valid = not occupied(cx, cy, cz) and supported(cx, cy, cz)
	if def.Plot or def.Size then
		-- Farm plots, generators and lamps stand on the cell floor or the ground rising into it.
		local size = if def.Size
			then Vector3.new(def.Size[1], def.Size[2], def.Size[3])
			else Vector3.new(BC.GridSize, BC.PlotHeight, BC.GridSize)
		local gx, gy, gz = BuildGrid.center(cx, cy + 1, cz)
		local below = Workspace:Raycast(Vector3.new(gx, gy, gz), Vector3.new(0, -BC.GridSize * 2, 0), groundParams)
		local groundY = if below then below.Position.Y else cy * BC.GridSize
		ghost.Size = size - Vector3.one * GHOST_INSET * 2
		ghost.CFrame = BuildGrid.plotCFrame(cx, cy, cz, groundY, size.Y)
	elseif def.Door then
		local side = BuildGrid.sideToward(cx, cz, head.Position.X, head.Position.Z)
		ghost.Size = Vector3.new(BC.GridSize, BC.GridSize * 2, BC.DoorThickness) - Vector3.one * GHOST_INSET * 2
		ghost.CFrame = BuildGrid.doorCFrame(cx, cy, cz, side, false, BC.DoorThickness)
		valid = valid and not occupied(cx, cy + 1, cz)
	else
		-- A wall: every cell gets a ghost; a cell over another cell of the wall counts as supported.
		local size = BC.WallSizes[sizeIndex]
		local cells = BuildGrid.wallCells(cx, cy, cz, size[1], size[2], BuildGrid.wallAxis(aim.X, aim.Z))
		for index, cell in cells do
			local part = ghostAt(index)
			local wx, wy, wz = BuildGrid.center(cell[1], cell[2], cell[3])
			local carried = cell[2] > cy or supported(cell[1], cell[2], cell[3])
			part.Size = Vector3.one * (BC.GridSize - GHOST_INSET * 2)
			part.CFrame = CFrame.new(wx, wy, wz)
			part.Color = if not occupied(cell[1], cell[2], cell[3]) and carried then VALID_COLOR else INVALID_COLOR
			part.Parent = Workspace.CurrentCamera
		end
		hideGhosts(#cells + 1)
		return
	end
	hideGhosts(2)
	ghost.Color = if valid then VALID_COLOR else INVALID_COLOR
	ghost.Parent = Workspace.CurrentCamera
end

local function buildGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BuildHud"
	gui.ResetOnSpawn = false
	sizeLabel = Instance.new("TextLabel")
	sizeLabel.Name = "WallSize"
	sizeLabel.AnchorPoint = Vector2.new(0.5, 0)
	sizeLabel.Position = UDim2.new(0.5, 0, 0.5, 44)
	sizeLabel.Size = UDim2.fromOffset(260, 22)
	sizeLabel.BackgroundTransparency = 1
	sizeLabel.Font = Enum.Font.GothamBold
	sizeLabel.TextSize = 15
	sizeLabel.TextColor3 = Color3.new(1, 1, 1)
	sizeLabel.TextStrokeTransparency = 0.4
	sizeLabel.Text = sizeText()
	sizeLabel.Visible = false
	sizeLabel.Parent = gui
	sizeButton = Instance.new("TextButton")
	sizeButton.Name = "WallSizeButton"
	sizeButton.AnchorPoint = Vector2.new(1, 1)
	sizeButton.Position = UDim2.new(1, -170, 1, -40)
	sizeButton.Size = UDim2.fromOffset(64, 64)
	sizeButton.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
	sizeButton.BackgroundTransparency = 0.25
	sizeButton.Font = Enum.Font.GothamBold
	sizeButton.TextScaled = true
	sizeButton.TextColor3 = Color3.new(1, 1, 1)
	sizeButton.Text = Localization.get("BuildSizeButton")
	sizeButton.Visible = false
	sizeButton.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = sizeButton
	sizeButton.Activated:Connect(changeSize)
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Input Action System: Z and D-pad up change the wall size.
	local context = Instance.new("InputContext")
	context.Name = "BuildInput"
	local action = Instance.new("InputAction")
	action.Name = "WallSize"
	action.Parent = context
	for _, key in { Enum.KeyCode.Z, Enum.KeyCode.DPadUp } do
		local binding = Instance.new("InputBinding")
		binding.KeyCode = key
		binding.Parent = action
	end
	action.Pressed:Connect(changeSize)
	context.Parent = gui
end

function BuildController.init() end

function BuildController.start()
	structures = Workspace:WaitForChild(BC.FolderName) :: Folder
	groundParams.FilterDescendantsInstances = { structures, Workspace.CurrentCamera }
	ghost = Instance.new("Part")
	ghost.Name = "BuildGhost"
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.CanTouch = false
	ghost.CastShadow = false
	ghost.Material = Enum.Material.SmoothPlastic
	ghost.Transparency = GHOST_TRANSPARENCY
	ghost.Size = Vector3.one * (BC.GridSize - GHOST_INSET * 2)
	buildGui()
	RunService.PreRender:Connect(update)
end

return BuildController
