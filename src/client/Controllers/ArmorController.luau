--!strict
-- ArmorController: the worn-armour panel beside the open backpack (7DTD character window): the total
-- rating, one row per slot with the piece and its durability, and a click on a row asks the server to
-- take that piece off. Putting a piece on is "use" while holding it (ToolService on the server).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Armor = require(Shared.Armor)
local Config = require(Shared.Config)
local ItemIcons = require(Shared.ItemIcons)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

local InventoryController = require(script.Parent.InventoryController)
local SoundController = require(script.Parent.SoundController)

local AC = Config.Armor
local BACK = Color3.fromRGB(20, 24, 23)
local ROW = Color3.fromRGB(38, 42, 40)
local MUTED = Color3.fromRGB(150, 150, 140)
local BROKEN = Color3.fromRGB(196, 92, 72)
local WIDTH = 280
local ROW_HEIGHT = 44
local PADDING = 10
local TITLE_HEIGHT = 26
local HINT_HEIGHT = 30

type Row = { button: TextButton, icon: Frame, name: TextLabel, wear: TextLabel }

local ArmorController = {}

local panel: Frame
local title: TextLabel
local rows: { [string]: Row } = {}
local worn: Armor.Worn = Armor.empty()

local function label(parent: Instance, size: UDim2, pos: UDim2, textSize: number): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size, t.Position = size, pos
	t.Font, t.TextSize, t.TextColor3 = Enum.Font.GothamBold, textSize, Color3.new(1, 1, 1)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextTruncate = Enum.TextTruncate.AtEnd
	t.Parent = parent
	return t
end

local function render()
	title.Text = Localization.get("ArmorTitle", { rating = Armor.rating(worn) })
	for slot, row in rows do
		local stack = worn[slot]
		if stack then
			local name = Localization.get(`Item{stack.id}`)
			local max = Config.Items[stack.id].Durability
			local broken = stack.durability == 0
			row.name.Text = if broken then Localization.get("ArmorBroken", { name = name }) else name
			row.name.TextColor3 = if broken then BROKEN else Color3.new(1, 1, 1)
			row.wear.Text = if max and stack.durability then `{stack.durability} / {max}` else ""
			local color = Config.Items[stack.id].Color
			row.icon.BackgroundColor3 = Color3.new(color[1], color[2], color[3])
			row.icon.BackgroundTransparency = 0
			ItemIcons.apply(row.icon, stack.id)
		else
			row.name.Text = Localization.get("ArmorEmpty")
			row.name.TextColor3 = MUTED
			row.wear.Text = ""
			row.icon.BackgroundTransparency = 1
			ItemIcons.apply(row.icon, "")
		end
	end
end

local function build(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Armor"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local height = PADDING * 2 + TITLE_HEIGHT + #AC.Slots * (ROW_HEIGHT + 4) + HINT_HEIGHT
	panel = Instance.new("Frame")
	panel.Name = "ArmorPanel"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -16, 0.5, 0)
	panel.Size = UDim2.fromOffset(WIDTH, height)
	panel.BackgroundColor3 = BACK
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	title = label(panel, UDim2.new(1, -PADDING * 2, 0, TITLE_HEIGHT), UDim2.fromOffset(PADDING, PADDING), 18)

	for index, slot in AC.Slots do
		local top = PADDING + TITLE_HEIGHT + (index - 1) * (ROW_HEIGHT + 4)
		local button = Instance.new("TextButton")
		button.Name = slot
		button.Text = ""
		button.AutoButtonColor = true
		button.BackgroundColor3 = ROW
		button.Size = UDim2.new(1, -PADDING * 2, 0, ROW_HEIGHT)
		button.Position = UDim2.fromOffset(PADDING, top)
		button.Parent = panel
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 6)
		rowCorner.Parent = button
		local icon = Instance.new("Frame")
		icon.Name = "Icon"
		icon.Size = UDim2.fromOffset(ROW_HEIGHT - 8, ROW_HEIGHT - 8)
		icon.Position = UDim2.fromOffset(4, 4)
		icon.BackgroundTransparency = 1
		icon.Parent = button
		local slotName = label(button, UDim2.new(1, -ROW_HEIGHT - 8, 0, 14), UDim2.fromOffset(ROW_HEIGHT + 2, 3), 11)
		slotName.TextColor3 = MUTED
		slotName.Text = Localization.get(`ArmorSlot{slot}`)
		local name = label(button, UDim2.new(1, -ROW_HEIGHT - 64, 0, 20), UDim2.fromOffset(ROW_HEIGHT + 2, 18), 14)
		local wear = label(button, UDim2.fromOffset(58, 20), UDim2.new(1, -62, 0, 18), 12)
		wear.TextXAlignment = Enum.TextXAlignment.Right
		wear.TextColor3 = MUTED
		button.Activated:Connect(function()
			if worn[slot] then
				Net.event("ArmorTakeOff"):FireServer(slot)
				SoundController.play("UIClick")
			end
		end)
		rows[slot] = { button = button, icon = icon, name = name, wear = wear }
	end

	local hint = label(panel, UDim2.new(1, -PADDING * 2, 0, HINT_HEIGHT), UDim2.new(0, PADDING, 1, -HINT_HEIGHT - 4), 11)
	hint.TextColor3 = MUTED
	hint.TextWrapped = true
	hint.TextTruncate = Enum.TextTruncate.None
	hint.Text = Localization.get("ArmorHint")
	render()
end

function ArmorController.init() end

function ArmorController.start()
	local player = Players.LocalPlayer
	build(player:WaitForChild("PlayerGui") :: PlayerGui)
	Net.event("ArmorUpdate").OnClientEvent:Connect(function(data: unknown)
		if typeof(data) ~= "table" then
			return
		end
		local fresh = Armor.empty()
		for _, slot in AC.Slots do
			local row = (data :: any)[slot]
			if typeof(row) == "table" and typeof(row.id) == "string" and Config.Items[row.id] then
				local durability = if typeof(row.durability) == "number" then row.durability else nil
				fresh[slot] = { id = row.id, count = 1, source = "Loot", durability = durability }
			end
		end
		worn = fresh
		render()
	end)
	panel.Visible = InventoryController.isBackpackOpen()
	InventoryController.onBackpackChanged(function(open)
		panel.Visible = open
	end)
end

return ArmorController
