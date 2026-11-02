--!strict
-- InventoryController: toolbelt along the bottom of the screen and a backpack panel (Tab like 7DTD, or
-- I, gamepad Y, or the Bag button next to the toolbelt). The server owns the inventory; this
-- controller only shows the copy it receives and sends move / select requests.
--
-- Moving items works the same with mouse, touch and gamepad cursor: pick a slot, then pick the slot
-- to put it in (picking the same slot again cancels). Right-click, or the Split toggle on touch,
-- picks up half a stack. With the backpack closed, a toolbelt slot (click, tap, 1-9/0, or the
-- gamepad bumpers) becomes the active one. Repair sends the picked tool to the crafting queue. Drop
-- (or G) puts the picked stack, or with nothing picked the held one, on the ground in a bag.
--
-- Another panel (crafting) can be attached to the right of the backpack; the backpack then moves left
-- and its slots shrink so both fit on the screen. Over the open backpack an info panel describes the
-- item under the cursor, or else the picked one: its name, numbers (Shared/ItemInfo) and what it is
-- for (7DTD's item info).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Crafting = require(Shared.Crafting)
local Inventory = require(Shared.Inventory)
local ItemIcons = require(Shared.ItemIcons)
local ItemInfo = require(Shared.ItemInfo)
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
local BUTTON_WIDTH = 72
-- Header buttons scale their text down to fit but never above the title's size.
local BUTTON_TEXT_MAX = 18
local NAME_HEIGHT = 24
-- Slot item names: never smaller than this (pixels), never larger than that.
local NAME_MIN_TEXT = 10
local NAME_MAX_TEXT = 14
local DURABILITY_HEIGHT = 4
local NAME_SHOW_SECONDS = 1.6
local INFO_PADDING = 8

local SLOT_COLOR = Color3.fromRGB(28, 28, 30)
local SLOT_STROKE = Color3.fromRGB(90, 90, 96)
local SELECTED_STROKE = Color3.fromRGB(235, 220, 160)
local PICKED_STROKE = Color3.fromRGB(120, 200, 255)
local TEXT_COLOR = Color3.new(1, 1, 1)
local PANEL_COLOR = Color3.fromRGB(18, 18, 20)
local DURABILITY_GOOD = Color3.fromRGB(110, 200, 90)
local DURABILITY_BAD = Color3.fromRGB(210, 70, 60)
local DISABLED_TRANSPARENCY = 0.6
local INFO_STATS_COLOR = Color3.fromRGB(235, 220, 160)
local INFO_TEXT_COLOR = Color3.fromRGB(200, 200, 205)

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
-- The slot under the mouse, and an item another panel points at (a crafting recipe), for the info
-- panel.
local hovered: number? = nil
local hoveredItem: string? = nil
local pickHalf = false
local backpackOpen = false

local gui: ScreenGui
local toolbelt: Frame
local backpack: Frame
local backpackGrid: UIGridLayout
local nameLabel: TextLabel
local infoPanel: Frame
local infoTitle: TextLabel
local infoStats: TextLabel
local infoText: TextLabel
local splitButton: TextButton
local repairButton: TextButton
local dropButton: TextButton
local moveRemote: RemoteEvent
local selectRemote: RemoteEvent
local repairRemote: RemoteEvent
local dropRemote: RemoteEvent
local sidePanel: Frame? = nil
local sideWidth = 0
-- A panel shown in the side panel's place for a while (an open storage crate).
local overridePanel: Frame? = nil
local slotsChangedCallbacks: { () -> () } = {}
-- Rounds left in each gun's magazine as ToolController counts them (nil: full).
local backpackCallbacks: { (open: boolean) -> () } = {}
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
	-- Long names used to shrink to ~6 px; below the floor they are cut with an ellipsis instead.
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local nameSize = Instance.new("UITextSizeConstraint")
	nameSize.MinTextSize = NAME_MIN_TEXT
	nameSize.MaxTextSize = NAME_MAX_TEXT
	nameSize.Parent = name

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

-- Total count of `id` in the inventory copy.
local function countOf(id: string): number
	local total = 0
	for _, slot in slots do
		if slot and slot.id == id then
			total += slot.count
		end
	end
	return total
end

-- True when slot `index` holds a damaged tool that can be repaired with what the player carries.
local function canRepair(index: number?): boolean
	local slot = if index then slots[index] else nil
	local def = if slot then Inventory.def(slot.id) else nil
	local repair = if def then def.Repair else nil
	if not slot or def == nil or repair == nil or def.Durability == nil or slot.durability == nil then
		return false
	end
	local missing = def.Durability - slot.durability
	return missing > 0 and countOf(repair.Id) >= Crafting.repairUnits(missing, repair.Amount)
end

-- Count text of a ranged weapon's slot (7DTD shows the ammo on the toolbelt): rounds in the magazine
-- over the ammo carried for guns, the ammo carried for bows.
local function ammoText(stack: Inventory.Stack, weapon: Config.RangedDef): string
	local carried = 0
	for _, slot in slots do
		if slot and table.find(weapon.Ammo, slot.id) then
			carried += slot.count
		end
	end
	local magazine = weapon.Magazine
	if magazine == nil then
		return tostring(carried)
	end
	return Localization.get("WeaponAmmo", { loaded = stack.loadedRounds or 0, reserve = carried })
end

-- The info panel: the hovered slot's item, the item another panel points at, or else the picked
-- slot's item (none: hidden).
local function showInfo()
	local hoveredSlot = if hovered then slots[hovered] else nil
	local pickedSlot = if picked then slots[picked] else nil
	local id = hoveredItem
	if hoveredSlot then
		id = hoveredSlot.id
	elseif id == nil and pickedSlot then
		id = pickedSlot.id
	end
	if id == nil then
		infoPanel.Visible = false
		return
	end
	infoTitle.Text = itemName(id)
	local parts: { string } = {}
	for _, line in ItemInfo.lines(id) do
		local value = line.value
		if line.key == "InfoAmmo" then
			local names: { string } = {}
			for id in string.gmatch(value, "[^,]+") do
				table.insert(names, itemName(id))
			end
			value = table.concat(names, ", ")
		end
		table.insert(parts, Localization.get(line.key, { value = value }))
	end
	infoStats.Text = table.concat(parts, Localization.get("InfoSeparator"))
	infoStats.Visible = #parts > 0
	infoText.Text = Localization.get(`ItemDesc{id}`)
	infoPanel.Visible = true
end

local function render()
	for index, view in views do
		local slot = slots[index]
		if slot then
			local def = Inventory.def(slot.id)
			local c = if def then def.Color else { 0.5, 0.5, 0.5 }
			view.icon.BackgroundColor3 = Color3.new(c[1], c[2], c[3])
			view.icon.Visible = true
			ItemIcons.apply(view.icon, slot.id)
			view.name.Text = itemName(slot.id)
			-- With the backpack shut the toolbelt shows icons only; the held item's name shows above it.
			view.name.Visible = backpackOpen or index > IC.ToolbeltSlots
			local ranged = Config.Ranged.Weapons[slot.id]
			view.count.Text = if ranged
				then ammoText(slot, ranged)
				elseif slot.count > 1 then tostring(slot.count)
				else ""
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
	showInfo()
	repairButton.TextTransparency = if canRepair(picked) then 0 else DISABLED_TRANSPARENCY
	dropButton.TextTransparency = if picked then 0 else DISABLED_TRANSPARENCY
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
	local changed = open ~= backpackOpen
	backpackOpen = open
	backpack.Visible = open
	picked = nil
	render()
	if changed then
		for _, callback in backpackCallbacks do
			task.spawn(callback, open)
		end
	end
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
	for index = 1, IC.ToolbeltSlots do
		views[index].button.Size = UDim2.fromOffset(size, size)
	end
	-- With a side panel the backpack slots shrink until both panels fit side by side.
	local camera = workspace.CurrentCamera
	local screenWidth = if camera then camera.ViewportSize.X else 1024
	local side = if sideWidth > 0 then sideWidth + SLOT_GAP else 0
	local fit = (screenWidth - SCREEN_MARGIN * 2 - side - PANEL_PADDING * 2 - SLOT_GAP * (BACKPACK_COLUMNS - 1))
		/ BACKPACK_COLUMNS
	local cell = math.floor(math.clamp(fit, MIN_SLOT_SIZE, size))
	backpackGrid.CellSize = UDim2.fromOffset(cell, cell)
	local rows = math.ceil(IC.BackpackSlots / BACKPACK_COLUMNS)
	local panelWidth = cell * BACKPACK_COLUMNS + SLOT_GAP * (BACKPACK_COLUMNS - 1) + PANEL_PADDING * 2
	local panelHeight = TITLE_HEIGHT + cell * rows + SLOT_GAP * (rows - 1) + PANEL_PADDING * 3
	backpack.Size = UDim2.fromOffset(panelWidth, panelHeight)
	backpack.Position = UDim2.new(0.5, -side / 2, 1, -(BOTTOM_OFFSET + size + SLOT_GAP * 2))
	for _, panel: Frame? in { sidePanel, overridePanel } do
		if panel then
			panel.Position = UDim2.new(1, SLOT_GAP, 0, 0)
			panel.Size = UDim2.fromOffset(sideWidth, panelHeight)
		end
	end
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
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = BUTTON_TEXT_MAX
	limit.Parent = button
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	button.Activated:Connect(onClick)
	return button
end

-- Shows the info of the slot under the mouse while it is there.
local function watchHover(button: TextButton, index: number)
	button.MouseEnter:Connect(function()
		hovered = index
		showInfo()
	end)
	button.MouseLeave:Connect(function()
		if hovered == index then
			hovered = nil
			showInfo()
		end
	end)
end

-- The info panel sits over the backpack, as wide as it.
local function buildInfoPanel()
	infoPanel = Instance.new("Frame")
	infoPanel.Name = "Info"
	infoPanel.AnchorPoint = Vector2.new(0, 1)
	infoPanel.Position = UDim2.new(0, 0, 0, -SLOT_GAP)
	infoPanel.Size = UDim2.fromScale(1, 0)
	infoPanel.AutomaticSize = Enum.AutomaticSize.Y
	infoPanel.BackgroundColor3 = PANEL_COLOR
	infoPanel.BackgroundTransparency = 0.1
	infoPanel.Visible = false
	infoPanel.Parent = backpack
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = infoPanel
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, INFO_PADDING)
	padding.PaddingRight = UDim.new(0, INFO_PADDING)
	padding.PaddingTop = UDim.new(0, INFO_PADDING)
	padding.PaddingBottom = UDim.new(0, INFO_PADDING)
	padding.Parent = infoPanel
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 2)
	list.Parent = infoPanel
	local function line(name: string, order: number, size: number, color: Color3): TextLabel
		local label = makeLabel(infoPanel, name)
		label.LayoutOrder = order
		label.Size = UDim2.fromScale(1, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.TextSize = size
		label.TextColor3 = color
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		return label
	end
	infoTitle = line("Title", 1, 18, TEXT_COLOR)
	infoStats = line("Stats", 2, 14, INFO_STATS_COLOR)
	infoText = line("Text", 3, 14, INFO_TEXT_COLOR)
	infoText.Font = Enum.Font.GothamMedium
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
	buildInfoPanel()

	local title = makeLabel(backpack, "Title")
	title.Position = UDim2.fromOffset(PANEL_PADDING, PANEL_PADDING)
	title.Size = UDim2.new(1, -(PANEL_PADDING * 2 + BUTTON_WIDTH * 4 + SLOT_GAP * 4), 0, TITLE_HEIGHT)
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
	repairButton = makeTextButton(backpack, "Repair", Localization.get("CraftingRepair"), function()
		if picked and canRepair(picked) then
			repairRemote:FireServer(picked)
			picked = nil
			pickHalf = false
			render()
		end
	end)
	repairButton.AnchorPoint = Vector2.new(1, 0)
	repairButton.Position = UDim2.new(1, -(PANEL_PADDING + (BUTTON_WIDTH + SLOT_GAP) * 2), 0, PANEL_PADDING)
	repairButton.Size = UDim2.fromOffset(BUTTON_WIDTH, TITLE_HEIGHT)
	dropButton = makeTextButton(backpack, "Drop", Localization.get("InventoryDrop"), function()
		if picked then
			dropRemote:FireServer(picked)
			picked = nil
			pickHalf = false
			render()
		end
	end)
	dropButton.AnchorPoint = Vector2.new(1, 0)
	dropButton.Position = UDim2.new(1, -(PANEL_PADDING + (BUTTON_WIDTH + SLOT_GAP) * 3), 0, PANEL_PADDING)
	dropButton.Size = UDim2.fromOffset(BUTTON_WIDTH, TITLE_HEIGHT)

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
		watchHover(view.button, index)
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
		watchHover(view.button, index)
		view.button.Activated:Connect(function()
			onSlotActivated(index, false)
		end)
		view.button.MouseButton2Click:Connect(function()
			onSlotActivated(index, true)
		end)
	end

	-- A Bag button next to the toolbelt opens the backpack on every device; with a keyboard it shows
	-- the key in its corner like the toolbelt slots.
	local bagButton = makeTextButton(gui, "Bag", Localization.get("InventoryBag"), function()
		setBackpackOpen(not backpackOpen)
	end)
	bagButton.AnchorPoint = Vector2.new(0, 1)
	if UserInputService.KeyboardEnabled then
		local key = makeLabel(bagButton, "Key")
		key.Position = UDim2.new(0, 3, 0, 2)
		key.Size = UDim2.new(0.6, 0, 0.24, 0)
		key.TextScaled = true
		key.TextXAlignment = Enum.TextXAlignment.Left
		key.TextColor3 = Color3.fromRGB(200, 200, 205)
		key.Text = Localization.get("KeyTab")
	end

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
	if sidePanel then
		sidePanel.Parent = backpack
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
	-- G (7DTD): the picked stack while the backpack is open, else the held one.
	action("DropItem", { Enum.KeyCode.G }, function()
		local index = if backpackOpen then picked else selected
		if index and slots[index] then
			dropRemote:FireServer(index)
			if index == picked then
				picked = nil
				pickHalf = false
				render()
			end
		end
	end)
	-- Tab is 7DTD's key; it reaches the game only with the Roblox player list off (start). I stays: on a
	-- Turkish Q keyboard it is the dotless-I key, and the dotted one is KeyCode.Quote.
	action("ToggleBackpack", { Enum.KeyCode.Tab, Enum.KeyCode.I, Enum.KeyCode.ButtonY }, function()
		setBackpackOpen(not backpackOpen)
	end)
	context.Parent = gui
end

-- Describes item `id` in the info panel while another panel points at it (nil: stops).
function InventoryController.hoverItem(id: string?)
	hoveredItem = id
	showInfo()
end

-- True while the backpack panel is open; gameplay input (swinging) is ignored then.
function InventoryController.isBackpackOpen(): boolean
	return backpackOpen
end

-- The inventory copy the server last sent (read only).
function InventoryController.getSlots(): { Inventory.Slot }
	return slots
end

-- Calls `callback` whenever a new inventory copy arrives.
function InventoryController.onSlotsChanged(callback: () -> ())
	table.insert(slotsChangedCallbacks, callback)
end

-- Docks `panel` to the right of the backpack panel, `width` pixels wide and as tall as the backpack;
-- it shows and hides with the backpack. Before the backpack is built, it is docked when it is.
function InventoryController.attachSidePanel(panel: Frame, width: number)
	sidePanel = panel
	sideWidth = width
	panel.AnchorPoint = Vector2.new(0, 0)
	if backpack then
		panel.Parent = backpack
		layout()
	end
end

-- Shows `panel` where the side panel is (same size), hiding the side panel, until it is called with
-- nil. The backpack must be built.
function InventoryController.showSidePanel(panel: Frame?)
	local old = overridePanel
	if old and old ~= panel then
		old.Visible = false
	end
	overridePanel = panel
	if panel then
		panel.AnchorPoint = Vector2.new(0, 0)
		panel.Parent = backpack
		panel.Visible = true
	end
	if sidePanel then
		sidePanel.Visible = panel == nil
	end
	layout()
end

-- Opens or closes the backpack panel.
function InventoryController.setBackpackOpen(open: boolean)
	setBackpackOpen(open)
end

-- Calls `callback` with the new state whenever the backpack opens or closes.
function InventoryController.onBackpackChanged(callback: (open: boolean) -> ())
	table.insert(backpackCallbacks, callback)
end

-- The slot the player picked to move (nil when none), which is dropped: another panel takes it.
function InventoryController.takePicked(): number?
	local index = picked
	picked = nil
	pickHalf = false
	render()
	return index
end

-- The toolbelt frame once it is built (other HUD parts lay themselves out around it), or nil.
function InventoryController.getToolbelt(): Frame?
	return toolbelt
end

-- The stack in the active toolbelt slot as the server last sent it, or nil for an empty hand.
function InventoryController.getHeld(): Inventory.Stack?
	local slot = slots[selected]
	return if slot then slot else nil
end

function InventoryController.getSelectedSlot(): number
	return selected
end

function InventoryController.init()
	moveRemote = Net.event("InventoryMove")
	selectRemote = Net.event("InventorySelect")
	repairRemote = Net.event("CraftRepair")
	dropRemote = Net.event("InventoryDrop")
end

function InventoryController.start()
	-- The Roblox backpack would show its own hotbar; this inventory replaces it.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	-- The player list takes Tab before the game sees it (measured in Play); the Escape menu still
	-- lists the players in the server.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
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
		for _, callback in slotsChangedCallbacks do
			task.spawn(callback)
		end
	end)
	render()
end

return InventoryController
