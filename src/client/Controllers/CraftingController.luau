--!strict
-- CraftingController: the crafting panel docked to the right of the backpack (7DTD's backpack crafting
-- window). Each recipe shows its ingredients against what the player carries, a count and a Craft
-- button. Cooking recipes also show the station they need nearby and the tool they need carried. The
-- queue below shows the four jobs, counts the first one down, and cancels a job when it is clicked.
-- A station's "Cook" prompt opens the panel. The server owns the queue (CraftingService); this only
-- shows its copy and sends requests.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Crafting = require(Shared.Crafting)
local ItemIcons = require(Shared.ItemIcons)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

local InventoryController = require(script.Parent.InventoryController)

local CC = Config.Crafting
local BC = Config.Build
-- How often the open panel looks for nearby stations (seconds).
local STATION_CHECK_SECONDS = 0.5

-- Layout (pixels).
local PANEL_WIDTH = 340
local PADDING = 10
local TITLE_HEIGHT = 26
local ROW_HEIGHT = 54
local ROW_GAP = 6
local SWATCH_SIZE = 32
local SMALL_BUTTON = 22
local COUNT_WIDTH = 34
local CRAFT_WIDTH = 60
local CONTROL_GAP = 4
local QUEUE_LABEL_HEIGHT = 18
local QUEUE_HEIGHT = 58
local QUEUE_GAP = 6

local PANEL_COLOR = Color3.fromRGB(18, 18, 20)
local ROW_COLOR = Color3.fromRGB(28, 28, 30)
local BUTTON_COLOR = Color3.fromRGB(44, 44, 48)
local TEXT_COLOR = Color3.new(1, 1, 1)
local MUTED_COLOR = Color3.fromRGB(170, 170, 176)
local DISABLED_TRANSPARENCY = 0.6
local HAVE_HEX = "#b4dc8c"
local MISSING_HEX = "#ff786e"
local WAITING_COLOR = Color3.fromRGB(255, 120, 100)

type Row = { ingredients: TextLabel, count: TextLabel, craft: TextButton }
type QueueView = { button: TextButton, swatch: Frame, name: TextLabel, left: TextLabel, time: TextLabel }
type JobView = {
	kind: string,
	id: string,
	left: number,
	unitSeconds: number,
	progress: number,
	waiting: boolean,
}

local CraftingController = {}

local queueRemote: RemoteEvent
local cancelRemote: RemoteEvent
-- Chosen count per recipe.
local counts: { [string]: number } = {}
local rows: { [string]: Row } = {}
local queueViews: { QueueView } = {}
local jobs: { JobView } = {}
-- Server time when `jobs` was sent.
local sentAt = 0
-- Station kinds in reach at the last check, as a sorted list joined by commas.
local nearStations = ""
local nextStationCheck = 0

local function itemName(id: string): string
	return Localization.get(`Item{id}`)
end

local function itemColor(id: string): Color3
	local item = Config.Items[id]
	local c = if item then item.Color else { 0.5, 0.5, 0.5 }
	return Color3.new(c[1], c[2], c[3])
end

local function countOf(id: string): number
	local total = 0
	for _, slot in InventoryController.getSlots() do
		if slot and slot.id == id then
			total += slot.count
		end
	end
	return total
end

local function label(parent: Instance, name: string, size: number, bold: boolean): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	text.TextSize = size
	text.TextColor3 = TEXT_COLOR
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Parent = parent
	return text
end

local function button(parent: Instance, name: string, text: string, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.TextColor3 = TEXT_COLOR
	b.BackgroundColor3 = BUTTON_COLOR
	b.AutoButtonColor = true
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = b
	b.Activated:Connect(onClick)
	return b
end

local function formatSeconds(seconds: number): string
	local shown = if seconds < 10 then string.format("%.1f", seconds) else tostring(math.ceil(seconds))
	return Localization.get("CraftingSeconds", { seconds = shown })
end

-- Whether a placed station of `kind` is within reach of the character (the server checks again).
local function stationNear(kind: string): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character.PrimaryPart
	local structures = Workspace:FindFirstChild(BC.FolderName)
	if root == nil or structures == nil then
		return false
	end
	for _, part in structures:GetChildren() do
		if
			part:IsA("BasePart")
			and part:GetAttribute("Kind") == kind
			and (part.Position - root.Position).Magnitude <= CC.StationReach
		then
			return true
		end
	end
	return false
end

local function stationsInReach(): string
	local kinds = {}
	for kind, def in BC.Blocks do
		if def.Station and stationNear(kind) then
			table.insert(kinds, kind)
		end
	end
	table.sort(kinds)
	return table.concat(kinds, ",")
end

-- Ingredients as "have/need item" pairs, green when there is enough for the chosen count; then the
-- station and tool a cooking recipe needs, green when at hand.
local function refreshRows()
	for _, id in CC.Order do
		local recipe = Config.Recipes[id]
		local row = rows[id]
		local most = Crafting.maxCount(recipe, countOf)
		local count = math.clamp(counts[id] or 1, 1, math.max(1, most))
		counts[id] = count
		local parts = {}
		for _, ingredient in recipe.Ingredients do
			local have = countOf(ingredient.Id)
			local need = ingredient.Count * count
			local hex = if have >= need then HAVE_HEX else MISSING_HEX
			table.insert(parts, `<font color="{hex}">{have}/{need}</font> {itemName(ingredient.Id)}`)
		end
		if recipe.Station then
			local hex = if stationNear(recipe.Station) then HAVE_HEX else MISSING_HEX
			local text = Localization.get("CraftingStation", { station = itemName(recipe.Station) })
			table.insert(parts, `<font color="{hex}">{text}</font>`)
		end
		if recipe.Tool then
			local hex = if countOf(recipe.Tool) >= 1 then HAVE_HEX else MISSING_HEX
			local text = Localization.get("CraftingTool", { tool = itemName(recipe.Tool) })
			table.insert(parts, `<font color="{hex}">{text}</font>`)
		end
		row.ingredients.Text = table.concat(parts, "   ")
		row.count.Text = Localization.get("CraftingCount", { count = count })
		local usable = most >= count and Crafting.canUse(recipe, countOf, stationNear)
		row.craft.TextTransparency = if usable then 0 else DISABLED_TRANSPARENCY
	end
end

-- Seconds until the job at `index` is done, counting the first job down from its snapshot.
local function timeLeft(index: number): number
	local job = jobs[index]
	if index > 1 then
		return job.left * job.unitSeconds
	end
	local elapsed = if job.waiting then 0 else Workspace:GetServerTimeNow() - sentAt
	local current = math.max(0, job.unitSeconds - job.progress - elapsed)
	return current + (job.left - 1) * job.unitSeconds
end

local function refreshQueue()
	for index, view in queueViews do
		local job = jobs[index]
		if job == nil then
			view.button.Visible = false
			continue
		end
		view.button.Visible = true
		local outputId = if job.kind == "Craft" then Config.Recipes[job.id].Output else job.id
		view.swatch.BackgroundColor3 = itemColor(outputId)
		view.name.Text = if job.kind == "Craft"
			then itemName(outputId)
			else Localization.get("CraftingRepairJob", { item = itemName(job.id) })
		view.left.Text = Localization.get("CraftingCount", { count = job.left })
		if job.waiting then
			view.time.Text = Localization.get("CraftingWaiting")
			view.time.TextColor3 = WAITING_COLOR
		else
			view.time.Text = formatSeconds(timeLeft(index))
			view.time.TextColor3 = TEXT_COLOR
		end
	end
end

local function buildRow(parent: Instance, id: string, order: number)
	local recipe = Config.Recipes[id]
	local frame = Instance.new("Frame")
	frame.Name = id
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	frame.BackgroundColor3 = ROW_COLOR
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame
	-- The backpack's info panel describes what the recipe makes while the mouse is on it.
	frame.MouseEnter:Connect(function()
		InventoryController.hoverItem(recipe.Output)
	end)
	frame.MouseLeave:Connect(function()
		InventoryController.hoverItem(nil)
	end)

	local swatch = Instance.new("Frame")
	swatch.Name = "Swatch"
	swatch.Position = UDim2.fromOffset(6, (ROW_HEIGHT - SWATCH_SIZE) / 2)
	swatch.Size = UDim2.fromOffset(SWATCH_SIZE, SWATCH_SIZE)
	swatch.BackgroundColor3 = itemColor(recipe.Output)
	swatch.Parent = frame
	ItemIcons.apply(swatch, recipe.Output)

	local textLeft = SWATCH_SIZE + 12
	local controls = SMALL_BUTTON * 2 + COUNT_WIDTH + CRAFT_WIDTH + CONTROL_GAP * 4
	local name = label(frame, "Name", 15, true)
	name.Position = UDim2.fromOffset(textLeft, 6)
	name.Size = UDim2.new(1, -(textLeft + controls), 0, 20)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Text = itemName(recipe.Output)

	local ingredients = label(frame, "Ingredients", 12, false)
	ingredients.Position = UDim2.fromOffset(textLeft, 28)
	ingredients.Size = UDim2.new(1, -(textLeft + 6), 0, ROW_HEIGHT - 30)
	ingredients.TextColor3 = MUTED_COLOR
	ingredients.TextWrapped = true
	ingredients.TextYAlignment = Enum.TextYAlignment.Top
	ingredients.RichText = true

	local x = -CONTROL_GAP
	local function place(control: GuiObject, width: number)
		control.AnchorPoint = Vector2.new(1, 0)
		control.Position = UDim2.new(1, x, 0, 5)
		control.Size = UDim2.fromOffset(width, SMALL_BUTTON + 2)
		x -= width + CONTROL_GAP
	end
	local craft = button(frame, "Craft", Localization.get("CraftingCraft"), function()
		local count = counts[id] or 1
		local usable = Crafting.maxCount(recipe, countOf) >= count and Crafting.canUse(recipe, countOf, stationNear)
		if usable and #jobs < CC.QueueSlots then
			queueRemote:FireServer(id, count)
		end
	end)
	place(craft, CRAFT_WIDTH)
	local plus = button(frame, "More", "+", function()
		counts[id] = (counts[id] or 1) + 1
		refreshRows()
	end)
	place(plus, SMALL_BUTTON)
	-- Clicking the count jumps to the most the player can make.
	local count = button(frame, "Count", "", function()
		counts[id] = math.max(1, Crafting.maxCount(recipe, countOf))
		refreshRows()
	end)
	count.BackgroundTransparency = 1
	place(count, COUNT_WIDTH)
	local minus = button(frame, "Less", "-", function()
		counts[id] = math.max(1, (counts[id] or 1) - 1)
		refreshRows()
	end)
	place(minus, SMALL_BUTTON)

	rows[id] = { ingredients = ingredients, count = count, craft = craft }
end

local function buildQueueSlot(parent: Instance, index: number): QueueView
	local slot = button(parent, `Job{index}`, "", function()
		if jobs[index] then
			cancelRemote:FireServer(index)
		end
	end)
	slot.LayoutOrder = index
	slot.Size = UDim2.new(1 / CC.QueueSlots, -QUEUE_GAP * (CC.QueueSlots - 1) / CC.QueueSlots, 1, 0)
	slot.BackgroundColor3 = ROW_COLOR
	slot.Visible = false
	local swatch = Instance.new("Frame")
	swatch.Name = "Swatch"
	swatch.Position = UDim2.fromOffset(4, 4)
	swatch.Size = UDim2.fromOffset(10, QUEUE_HEIGHT - 8)
	swatch.BorderSizePixel = 0
	swatch.Parent = slot
	local name = label(slot, "Name", 11, true)
	name.Position = UDim2.fromOffset(18, 3)
	name.Size = UDim2.new(1, -20, 0, 26)
	name.TextWrapped = true
	name.TextYAlignment = Enum.TextYAlignment.Top
	local left = label(slot, "Left", 11, false)
	left.Position = UDim2.new(0, 18, 1, -18)
	left.Size = UDim2.new(0.4, 0, 0, 14)
	local time = label(slot, "Time", 12, true)
	time.AnchorPoint = Vector2.new(1, 0)
	time.Position = UDim2.new(1, -4, 1, -18)
	time.Size = UDim2.new(0.6, -24, 0, 14)
	time.TextXAlignment = Enum.TextXAlignment.Right
	return { button = slot, swatch = swatch, name = name, left = left, time = time }
end

local function buildPanel(): Frame
	local panel = Instance.new("Frame")
	panel.Name = "Crafting"
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local title = label(panel, "Title", 20, true)
	title.Position = UDim2.fromOffset(PADDING, PADDING)
	title.Size = UDim2.new(1, -PADDING * 2, 0, TITLE_HEIGHT)
	title.Text = Localization.get("CraftingTitle")

	local queueTop = QUEUE_LABEL_HEIGHT + QUEUE_HEIGHT + PADDING
	local list = Instance.new("ScrollingFrame")
	list.Name = "Recipes"
	list.Position = UDim2.fromOffset(PADDING, PADDING * 2 + TITLE_HEIGHT)
	list.Size = UDim2.new(1, -PADDING * 2, 1, -(PADDING * 3 + TITLE_HEIGHT + queueTop))
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, ROW_GAP)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list
	for order, id in CC.Order do
		buildRow(list, id, order)
	end

	local queueLabel = label(panel, "QueueTitle", 12, false)
	queueLabel.AnchorPoint = Vector2.new(0, 1)
	queueLabel.Position = UDim2.new(0, PADDING, 1, -(PADDING + QUEUE_HEIGHT + 2))
	queueLabel.Size = UDim2.new(1, -PADDING * 2, 0, QUEUE_LABEL_HEIGHT)
	queueLabel.TextColor3 = MUTED_COLOR
	queueLabel.Text = Localization.get("CraftingQueue")

	local queue = Instance.new("Frame")
	queue.Name = "Queue"
	queue.AnchorPoint = Vector2.new(0, 1)
	queue.Position = UDim2.new(0, PADDING, 1, -PADDING)
	queue.Size = UDim2.new(1, -PADDING * 2, 0, QUEUE_HEIGHT)
	queue.BackgroundTransparency = 1
	queue.Parent = panel
	-- A list, not a grid: a grid wraps the last job to a second row when the cell widths round up.
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.Padding = UDim.new(0, QUEUE_GAP)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = queue
	for index = 1, CC.QueueSlots do
		queueViews[index] = buildQueueSlot(queue, index)
	end
	return panel
end

function CraftingController.init()
	queueRemote = Net.event("CraftQueue")
	cancelRemote = Net.event("CraftCancel")
end

function CraftingController.start()
	InventoryController.attachSidePanel(buildPanel(), PANEL_WIDTH)
	refreshRows()
	refreshQueue()
	InventoryController.onSlotsChanged(refreshRows)
	Net.event("CraftUpdate").OnClientEvent:Connect(function(newJobs: { JobView }, serverTime: number)
		jobs = newJobs
		sentAt = serverTime
		refreshQueue()
		refreshRows()
	end)
	RunService.Heartbeat:Connect(function()
		if not InventoryController.isBackpackOpen() then
			return
		end
		if #jobs > 0 then
			refreshQueue()
		end
		local now = os.clock()
		if now >= nextStationCheck then
			nextStationCheck = now + STATION_CHECK_SECONDS
			local near = stationsInReach()
			if near ~= nearStations then
				nearStations = near
				refreshRows()
			end
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local kind = prompt.Parent and prompt.Parent:GetAttribute("Kind")
		local def = if typeof(kind) == "string" then BC.Blocks[kind] else nil
		if def and def.Station then
			InventoryController.setBackpackOpen(true)
		end
	end)
end

return CraftingController
