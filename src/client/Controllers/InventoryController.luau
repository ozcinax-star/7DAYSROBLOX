--!strict
-- InventoryController: toolbelt along the bottom of the screen and a backpack panel (I,
-- gamepad Y, or the Bag button on touch). The server owns the inventory; this controller only shows
-- the copy it receives and sends move / select requests.
--
-- Moving items works the same with mouse, touch and gamepad cursor: pick a slot, then pick the slot
-- to put it in (picking the same slot again cancels). Right-click, or the Split toggle on touch,
-- picks up half a stack. With the backpack closed, a toolbelt slot (click, tap, 1-9/0, or the
-- gamepad bumpers) becomes the active one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Inventory = require(Shared.Inventory)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

local IC = Config.Inventory

-- Layout (pixels).
local SLOT_SIZE = 58
local SLOT_GAP = 6
local MIN_SLOT_SIZE = 40
local SCREEN_MARGIN = 16
local BOTTOM_OFFSET = 10
local BACKPACK_COLUMNS = 9
local PANEL_PADDING = 12
local TITLE_HEIGHT = 30
local BUTTON_WIDTH = 90
local NAME_HEIGHT = 24
local DURABILITY_HEIGHT = 4
local NAME_SHOW_SECONDS = 1.6

local SLOT_COLOR = Color3.fromRGB(28, 28, 30)
local SLOT_STROKE = Color3.fromRGB(90, 90, 96)
local SELECTED_STROKE = Color3.fromRGB(235, 220, 160)
local PICKED_STROKE = Color3.fromRGB(120, 200, 255)
local TEXT_COLOR = Color3.new(1, 1, 1)
local PANEL_COLOR = Color3.fromRGB(18, 18, 20)
local DURABILITY_GOOD = Color3.fromRGB(110, 200, 90)
local DURABILITY_BAD = Color3.fromRGB(210, 70, 60)

local SLOT_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
	Enum.KeyCode.Zero,
}

type SlotView = {
	button: TextButton,
	stroke: UIStroke,
	icon: Frame,
	name: TextLabel,
	count: TextLabel,
	durability: Frame,
	durabilityFill: Frame,
}

local InventoryController = {}

local slots: { Inventory.Slot } = {}
local selected = 1
local views: { [number]: SlotView } = {}
local picked: number? = nil
local pickHalf = false
local backpackOpen = false

local gui: ScreenGui
local toolbelt: Frame
local backpack: Frame
local backpackGrid: UIGridLayout
local nameLabel: TextLabel
local splitButton: TextButton
local moveRemote: RemoteEvent
local selectRemote: RemoteEvent
local nameToken = 0

local function itemName(id: string): string
	return Localization.get(`Item{id}`)
end

local function makeLabel(parent: Instance, name: string): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.TextColor3 = TEXT_COLOR
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.5
	label.Parent = parent
	return label
end

local function makeSlot(parent: Instance, index: number, order: number, keyText: string?): SlotView
	local button = Instance.new("TextButton")
	button.Name = `Slot{index}`
	button.Text = ""
	button.AutoButtonColor = true
	button.BackgroundColor3 = SLOT_COLOR
	button.BackgroundTransparency = 0.15
	button.LayoutOrder = order
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
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

	local name = makeLabel(button, "Name")
	name.Position = UDim2.new(0, 2, 0.66, 0)
	name.Size = UDim2.new(1, -4, 0.22, 0)
	name.TextScaled = true

	local count = makeLabel(button, "Count")
	count.AnchorPoint = Vector2.new(1, 0)
	count.Position = UDim2.new(1, -3, 0, 2)
	count.Size = UDim2.new(0.6, 0, 0.26, 0)
	count.TextScaled = true
	count.TextXAlignment = Enum.TextXAlignment.Right

	if keyText then
		local key = makeLabel(button, "Key")
		key.Position = UDim2.new(0, 3, 0, 2)
		key.Size = UDim2.new(0.3, 0, 0.24, 0)
		key.TextScaled = true
		key.TextXAlignment = Enum.TextXAlignment.Left
		key.TextTransparency = 0.35
		key.Text = keyText
	end

	local durability = Instance.new("Frame")
	durability.Name = "Durability"
	durability.AnchorPoint = Vector2.new(0.5, 1)
	durability.Position = UDim2.new(0.5, 0, 1, -3)
	durability.Size = UDim2.new(1, -8, 0, DURABILITY_HEIGHT)
	durability.BackgroundColor3 = Color3.new(0, 0, 0)
	durability.BorderSizePixel = 0
	durability.Visible = false
	durability.Parent = button
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = durability

	return {
		button = button,
		stroke = stroke,
		icon = icon,
		name = name,
		count = count,
		durability = durability,
		durabilityFill = fill,
	}
end

local function showName(text: string)
	nameToken += 1
	local token = nameToken
	nameLabel.Text = text
	nameLabel.Visible = text ~= ""
	task.delay(NAME_SHOW_SECONDS, function()
		if token == nameToken then
			nameLabel.Visible = false
		end
	end)
end

local function render()
	for index, view in views do
		local slot = slots[index]
		if slot then
			local def = Inventory.def(slot.id)
			local c = if def then def.Color else { 0.5, 0.5, 0.5 }
			view.icon.BackgroundColor3 = Color3.new(c[1], c[2], c[3])
			view.icon.Visible = true
			view.name.Text = itemName(slot.id)
			view.count.Text = if slot.count > 1 then tostring(slot.count) else ""
			local maxDurability = if def then def.Durability else nil
			if slot.durability and maxDurability then
				local share = math.clamp(slot.durability / maxDurability, 0, 1)
				view.durability.Visible = true
				view.durabilityFill.Size = UDim2.fromScale(share, 1)
				view.durabilityFill.BackgroundColor3 = DURABILITY_BAD:Lerp(DURABILITY_GOOD, share)
			else
				view.durability.Visible = false
			end
		else
			view.icon.Visible = false
			view.name.Text = ""
			view.count.Text = ""
			view.durability.Visible = false
		end
		local stroke = view.stroke
		if picked == index then
			stroke.Color = PICKED_STROKE
			stroke.Thickness = 3
		elseif index == selected then
			stroke.Color = SELECTED_STROKE
			stroke.Thickness = 3
		else
			stroke.Color = SLOT_STROKE
			stroke.Thickness = 1.5
		end
	end
	splitButton.BackgroundColor3 = if pickHalf then PICKED_STROKE else SLOT_COLOR
end

local function selectSlot(index: number)
	if index < 1 or index > IC.ToolbeltSlots then
		return
	end
	selected = index
	selectRemote:FireServer(index)
	local slot = slots[index]
	showName(if slot then itemName(slot.id) else "")
	render()
end

local function setBackpackOpen(open: boolean)
	backpackOpen = open
	backpack.Visible = open
	picked = nil
	render()
end

local function onSlotActivated(index: number, half: boolean)
	if not backpackOpen then
		if index <= IC.ToolbeltSlots then
			selectSlot(index)
		end
		return
	end
	if picked == nil then
		if slots[index] then
			picked = index
			pickHalf = pickHalf or half
		end
	elseif picked == index then
		picked = nil
	else
		local from = picked :: number
		local stack = slots[from]
		local count: number? = nil
		if stack and pickHalf and stack.count > 1 then
			count = math.floor(stack.count / 2)
		end
		moveRemote:FireServer(from, index, count)
		picked = nil
		pickHalf = false
	end
	render()
end

local function slotSize(): number
	local camera = workspace.CurrentCamera
	local width = if camera then camera.ViewportSize.X else 1024
	local fit = (width - SCREEN_MARGIN * 2 - SLOT_GAP * (IC.ToolbeltSlots - 1)) / IC.ToolbeltSlots
	return math.floor(math.clamp(fit, MIN_SLOT_SIZE, SLOT_SIZE))
end

local function layout()
	local size = slotSize()
	local toolbeltWidth = size * IC.ToolbeltSlots + SLOT_GAP * (IC.ToolbeltSlots - 1)
	toolbelt.Size = UDim2.fromOffset(toolbeltWidth, size)
	backpackGrid.CellSize = UDim2.fromOffset(size, size)
	local rows = math.ceil(IC.BackpackSlots / BACKPACK_COLUMNS)
	local panelWidth = size * BACKPACK_COLUMNS + SLOT_GAP * (BACKPACK_COLUMNS - 1) + PANEL_PADDING * 2
	local panelHeight = TITLE_HEIGHT + size * rows + SLOT_GAP * (rows - 1) + PANEL_PADDING * 3
	backpack.Size = UDim2.fromOffset(panelWidth, panelHeight)
	backpack.Position = UDim2.new(0.5, 0, 1, -(BOTTOM_OFFSET + size + SLOT_GAP * 2))
end

local function makeTextButton(parent: Instance, name: string, text: string, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = TEXT_COLOR
	button.TextScaled = true
	button.BackgroundColor3 = SLOT_COLOR
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	button.Activated:Connect(onClick)
	return button
end

local function buildGui(playerGui: PlayerGui)
	gui = Instance.new("ScreenGui")
	gui.Name = "Inventory"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	toolbelt = Instance.new("Frame")
	toolbelt.Name = "Toolbelt"
	toolbelt.AnchorPoint = Vector2.new(0.5, 1)
	toolbelt.Position = UDim2.new(0.5, 0, 1, -BOTTOM_OFFSET)
	toolbelt.BackgroundTransparency = 1
	toolbelt.Parent = gui
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.Padding = UDim.new(0, SLOT_GAP)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = toolbelt

	nameLabel = makeLabel(gui, "HeldName")
	nameLabel.AnchorPoint = Vector2.new(0.5, 1)
	nameLabel.Size = UDim2.new(0, 300, 0, NAME_HEIGHT)
	nameLabel.TextSize = 18
	nameLabel.Visible = false

	backpack = Instance.new("Frame")
	backpack.Name = "Backpack"
	backpack.AnchorPoint = Vector2.new(0.5, 1)
	backpack.BackgroundColor3 = PANEL_COLOR
	backpack.BackgroundTransparency = 0.1
	backpack.Visible = false
	backpack.Parent = gui
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 8)
	panelCorner.Parent = backpack

	local title = makeLabel(backpack, "Title")
	title.Position = UDim2.fromOffset(PANEL_PADDING, PANEL_PADDING)
	title.Size = UDim2.new(1, -(PANEL_PADDING * 2 + BUTTON_WIDTH * 2 + SLOT_GAP * 2), 0, TITLE_HEIGHT)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextSize = 20
	title.Text = Localization.get("InventoryBackpack")

	local closeButton = makeTextButton(backpack, "Close", Localization.get("InventoryClose"), function()
		setBackpackOpen(false)
	end)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -PANEL_PADDING, 0, PANEL_PADDING)
	closeButton.Size = UDim2.fromOffset(BUTTON_WIDTH, TITLE_HEIGHT)
	splitButton = makeTextButton(backpack, "Split", Localization.get("InventorySplit"), function()
		pickHalf = not pickHalf
		render()
	end)
	splitButton.AnchorPoint = Vector2.new(1, 0)
	splitButton.Position = UDim2.new(1, -(PANEL_PADDING + BUTTON_WIDTH + SLOT_GAP), 0, PANEL_PADDING)
	splitButton.Size = UDim2.fromOffset(BUTTON_WIDTH, TITLE_HEIGHT)

	local gridHolder = Instance.new("Frame")
	gridHolder.Name = "Slots"
	gridHolder.BackgroundTransparency = 1
	gridHolder.Position = UDim2.fromOffset(PANEL_PADDING, PANEL_PADDING * 2 + TITLE_HEIGHT)
	gridHolder.Size = UDim2.new(1, -PANEL_PADDING * 2, 1, -(PANEL_PADDING * 3 + TITLE_HEIGHT))
	gridHolder.Parent = backpack
	backpackGrid = Instance.new("UIGridLayout")
	backpackGrid.CellPadding = UDim2.fromOffset(SLOT_GAP, SLOT_GAP)
	backpackGrid.SortOrder = Enum.SortOrder.LayoutOrder
	backpackGrid.Parent = gridHolder

	for index = 1, IC.ToolbeltSlots do
		local keyText = if index == 10 then "0" elseif index < 10 then tostring(index) else nil
		local view = makeSlot(toolbelt, index, index, keyText)
		views[index] = view
		view.button.Activated:Connect(function()
			onSlotActivated(index, false)
		end)
		view.button.MouseButton2Click:Connect(function()
			onSlotActivated(index, true)
		end)
	end
	for index = IC.ToolbeltSlots + 1, IC.ToolbeltSlots + IC.BackpackSlots do
		local view = makeSlot(gridHolder, index, index, nil)
		views[index] = view
		view.button.Activated:Connect(function()
			onSlotActivated(index, false)
		end)
		view.button.MouseButton2Click:Connect(function()
			onSlotActivated(index, true)
		end)
	end

	-- Touch: a Bag button next to the toolbelt opens the backpack.
	local bagButton = makeTextButton(gui, "Bag", Localization.get("InventoryBag"), function()
		setBackpackOpen(not backpackOpen)
	end)
	bagButton.AnchorPoint = Vector2.new(0, 1)
	bagButton.Visible = UserInputService.TouchEnabled

	local function place()
		layout()
		local size = slotSize()
		nameLabel.Position = UDim2.new(0.5, 0, 1, -(BOTTOM_OFFSET + size + SLOT_GAP))
		local toolbeltWidth = size * IC.ToolbeltSlots + SLOT_GAP * (IC.ToolbeltSlots - 1)
		bagButton.Size = UDim2.fromOffset(size, size)
		bagButton.Position = UDim2.new(0.5, toolbeltWidth / 2 + SLOT_GAP, 1, -BOTTOM_OFFSET)
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
	end
	place()
	gui.Parent = playerGui
end

-- Input Action System: slot keys, bumpers and the backpack toggle.
local function bindInput()
	local context = Instance.new("InputContext")
	context.Name = "InventoryInput"

	local function action(name: string, keys: { Enum.KeyCode }, onPressed: () -> ())
		local inputAction = Instance.new("InputAction")
		inputAction.Name = name
		inputAction.Parent = context
		for _, key in keys do
			local binding = Instance.new("InputBinding")
			binding.KeyCode = key
			binding.Parent = inputAction
		end
		inputAction.Pressed:Connect(onPressed)
	end

	for index = 1, math.min(IC.ToolbeltSlots, #SLOT_KEYS) do
		action(`Slot{index}`, { SLOT_KEYS[index] }, function()
			selectSlot(index)
		end)
	end
	action("SlotNext", { Enum.KeyCode.ButtonR1 }, function()
		selectSlot(selected % IC.ToolbeltSlots + 1)
	end)
	action("SlotPrevious", { Enum.KeyCode.ButtonL1 }, function()
		selectSlot((selected - 2) % IC.ToolbeltSlots + 1)
	end)
	-- Not Tab (7DTD's key): the Roblox player list takes it before the game sees it (tested in Play).
	action("ToggleBackpack", { Enum.KeyCode.I, Enum.KeyCode.ButtonY }, function()
		setBackpackOpen(not backpackOpen)
	end)
	context.Parent = gui
end

-- True while the backpack panel is open; gameplay input (swinging) is ignored then.
function InventoryController.isBackpackOpen(): boolean
	return backpackOpen
end

-- The stack in the active toolbelt slot as the server last sent it, or nil for an empty hand.
function InventoryController.getHeld(): Inventory.Stack?
	local slot = slots[selected]
	return if slot then slot else nil
end

function InventoryController.init()
	moveRemote = Net.event("InventoryMove")
	selectRemote = Net.event("InventorySelect")
end

function InventoryController.start()
	-- The Roblox backpack would show its own hotbar; this inventory replaces it.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	local player = Players.LocalPlayer
	buildGui(player:WaitForChild("PlayerGui") :: PlayerGui)
	bindInput()
	Net.event("InventoryUpdate").OnClientEvent:Connect(function(newSlots: { Inventory.Slot }, newSelected: number)
		slots = newSlots
		if newSelected ~= selected then
			selected = newSelected
		end
		-- A picked slot that was emptied by the server cannot be moved any more.
		if picked and not slots[picked] then
			picked = nil
		end
		render()
	end)
	render()
end

return InventoryController
