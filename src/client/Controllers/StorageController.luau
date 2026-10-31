--!strict
-- StorageController: the open storage crate's panel. It takes the crafting panel's place beside the
-- backpack while a crate is open (StorageService sends its slots). Clicking a crate slot takes that
-- stack; picking a backpack slot first and then a crate slot stores the picked stack there. Closing
-- the backpack closes the crate. The server owns the crate; this only shows its copy.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Inventory = require(Shared.Inventory)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

local InventoryController = require(script.Parent.InventoryController)

local SC = Config.Storage

-- Layout (pixels).
local PADDING = 10
local TITLE_HEIGHT = 26
local BUTTON_WIDTH = 90
local GAP = 5
local HINT_HEIGHT = 34
local MAX_CELL = 52

local PANEL_COLOR = Color3.fromRGB(18, 18, 20)
local SLOT_COLOR = Color3.fromRGB(28, 28, 30)
local SLOT_STROKE = Color3.fromRGB(90, 90, 96)
local BUTTON_COLOR = Color3.fromRGB(44, 44, 48)
local TEXT_COLOR = Color3.new(1, 1, 1)
local MUTED_COLOR = Color3.fromRGB(170, 170, 176)
local DURABILITY_GOOD = Color3.fromRGB(110, 200, 90)
local DURABILITY_BAD = Color3.fromRGB(210, 70, 60)

type SlotView = { button: TextButton, icon: Frame, name: TextLabel, count: TextLabel, wear: Frame }

local StorageController = {}

local actionRemote: RemoteEvent
local panel: Frame
local grid: UIGridLayout
local holder: Frame
local views: { SlotView } = {}
local slots: { Inventory.Slot } = {}
local isOpen = false

local function label(parent: Instance, name: string, font: Enum.Font): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.TextColor3 = TEXT_COLOR
	l.Font = font
	l.TextStrokeTransparency = 0.5
	l.Parent = parent
	return l
end

local function render()
	for index, view in views do
		local slot = slots[index]
		if slot then
			local def = Inventory.def(slot.id)
			local c = if def then def.Color else { 0.5, 0.5, 0.5 }
			view.icon.BackgroundColor3 = Color3.new(c[1], c[2], c[3])
			view.icon.Visible = true
			view.name.Text = Localization.get(`Item{slot.id}`)
			view.count.Text = if slot.count > 1 then tostring(slot.count) else ""
			local max = if def then def.Durability else nil
			if slot.durability and max then
				local share = math.clamp(slot.durability / max, 0, 1)
				view.wear.Visible = true
				view.wear.Size = UDim2.new(share, -8 * share, 0, 3)
				view.wear.BackgroundColor3 = DURABILITY_BAD:Lerp(DURABILITY_GOOD, share)
			else
				view.wear.Visible = false
			end
		else
			view.icon.Visible = false
			view.name.Text = ""
			view.count.Text = ""
			view.wear.Visible = false
		end
	end
end

local function onSlot(index: number)
	local picked = InventoryController.takePicked()
	if picked then
		actionRemote:FireServer("Put", picked, index)
	elseif slots[index] then
		actionRemote:FireServer("Take", index)
	end
end

-- Fits the 6-column grid into the panel's current size.
local function fit()
	local size = holder.AbsoluteSize
	local rows = math.ceil(SC.Slots / SC.Columns)
	local byWidth = (size.X - GAP * (SC.Columns - 1)) / SC.Columns
	local byHeight = (size.Y - GAP * (rows - 1)) / rows
	local cell = math.floor(math.clamp(math.min(byWidth, byHeight), 1, MAX_CELL))
	grid.CellSize = UDim2.fromOffset(cell, cell)
end

local function makeSlot(index: number): SlotView
	local button = Instance.new("TextButton")
	button.Name = `Slot{index}`
	button.Text = ""
	button.AutoButtonColor = true
	button.BackgroundColor3 = SLOT_COLOR
	button.BackgroundTransparency = 0.15
	button.LayoutOrder = index
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = SLOT_STROKE
	stroke.Thickness = 1.5
	stroke.Parent = button
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.42)
	icon.Size = UDim2.fromScale(0.42, 0.42)
	icon.BorderSizePixel = 0
	icon.Visible = false
	icon.Parent = button
	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 4)
	iconCorner.Parent = icon
	local name = label(button, "Name", Enum.Font.GothamBold)
	name.Position = UDim2.new(0, 2, 0.66, 0)
	name.Size = UDim2.new(1, -4, 0.22, 0)
	name.TextScaled = true
	local count = label(button, "Count", Enum.Font.GothamBold)
	count.AnchorPoint = Vector2.new(1, 0)
	count.Position = UDim2.new(1, -3, 0, 2)
	count.Size = UDim2.new(0.6, 0, 0.26, 0)
	count.TextScaled = true
	count.TextXAlignment = Enum.TextXAlignment.Right
	local wear = Instance.new("Frame")
	wear.Name = "Durability"
	wear.AnchorPoint = Vector2.new(0, 1)
	wear.Position = UDim2.new(0, 4, 1, -3)
	wear.BorderSizePixel = 0
	wear.Visible = false
	wear.Parent = button
	button.Activated:Connect(function()
		onSlot(index)
	end)
	button.Parent = holder
	return { button = button, icon = icon, name = name, count = count, wear = wear }
end

local function buildPanel()
	panel = Instance.new("Frame")
	panel.Name = "Storage"
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local title = label(panel, "Title", Enum.Font.GothamBold)
	title.Position = UDim2.fromOffset(PADDING, PADDING)
	title.Size = UDim2.new(1, -(PADDING * 3 + BUTTON_WIDTH), 0, TITLE_HEIGHT)
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = Localization.get("ItemStorageCrate")

	local takeAll = Instance.new("TextButton")
	takeAll.Name = "TakeAll"
	takeAll.AnchorPoint = Vector2.new(1, 0)
	takeAll.Position = UDim2.new(1, -PADDING, 0, PADDING)
	takeAll.Size = UDim2.fromOffset(BUTTON_WIDTH, TITLE_HEIGHT)
	takeAll.BackgroundColor3 = BUTTON_COLOR
	takeAll.Font = Enum.Font.GothamBold
	takeAll.TextSize = 14
	takeAll.TextColor3 = TEXT_COLOR
	takeAll.Text = Localization.get("StorageTakeAll")
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 6)
	buttonCorner.Parent = takeAll
	takeAll.Activated:Connect(function()
		actionRemote:FireServer("TakeAll")
	end)
	takeAll.Parent = panel

	holder = Instance.new("Frame")
	holder.Name = "Slots"
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(PADDING, PADDING * 2 + TITLE_HEIGHT)
	holder.Size = UDim2.new(1, -PADDING * 2, 1, -(PADDING * 4 + TITLE_HEIGHT + HINT_HEIGHT))
	holder.Parent = panel
	grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(GAP, GAP)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = holder
	for index = 1, SC.Slots do
		views[index] = makeSlot(index)
	end
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

	local hint = label(panel, "Hint", Enum.Font.Gotham)
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.new(0, PADDING, 1, -PADDING)
	hint.Size = UDim2.new(1, -PADDING * 2, 0, HINT_HEIGHT)
	hint.TextSize = 13
	hint.TextColor3 = MUTED_COLOR
	hint.TextWrapped = true
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextYAlignment = Enum.TextYAlignment.Top
	hint.Text = Localization.get("StorageHint")
end

local function onUpdate(newSlots: { Inventory.Slot } | false)
	if newSlots == false then
		if isOpen then
			isOpen = false
			InventoryController.showSidePanel(nil)
		end
		return
	end
	slots = newSlots
	if not isOpen then
		isOpen = true
		InventoryController.showSidePanel(panel)
		InventoryController.setBackpackOpen(true)
		fit()
	end
	render()
end

-- True while a crate is open.
function StorageController.isOpen(): boolean
	return isOpen
end

function StorageController.init()
	actionRemote = Net.event("StorageAction")
end

function StorageController.start()
	buildPanel()
	Net.event("StorageUpdate").OnClientEvent:Connect(onUpdate)
	InventoryController.onBackpackChanged(function(open)
		if not open and isOpen then
			isOpen = false
			InventoryController.showSidePanel(nil)
			actionRemote:FireServer("Close")
		end
	end)
end

return StorageController
