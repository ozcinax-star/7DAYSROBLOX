--!strict
-- PickupFeedController: 7DTD's pickup feed. Items that enter the inventory show as "+N Item" lines on
-- the right edge for a few seconds; more of the same item while its line is up adds to that line.
-- Items that did not fit show as a red "No room" line.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemIcons = require(Shared.ItemIcons)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

local IC = Config.Inventory

local LINE_HEIGHT = 24
local LINE_WIDTH = 260
local SWATCH_SIZE = 16
local SCREEN_MARGIN = 16
-- Vertical position of the feed's bottom edge (share of the screen height): above the touch Hit button.
local FEED_BOTTOM = 0.55
local GAIN_COLOR = Color3.new(1, 1, 1)
local LOST_COLOR = Color3.fromRGB(255, 120, 100)

type Line = { frame: Frame, label: TextLabel, count: number, token: number }

local PickupFeedController = {}

local player = Players.LocalPlayer
local feed: Frame
local order = 0
-- Visible gain lines by item id.
local lines: { [string]: Line } = {}

local function itemName(id: string): string
	return Localization.get(`Item{id}`)
end

local function newLine(id: string, color: Color3): (Frame, TextLabel)
	order += 1
	local frame = Instance.new("Frame")
	frame.Name = id
	frame.Size = UDim2.fromOffset(LINE_WIDTH, LINE_HEIGHT)
	frame.BackgroundTransparency = 1
	frame.LayoutOrder = order
	local item = Config.Items[id]
	if item then
		local swatch = Instance.new("Frame")
		swatch.Name = "Swatch"
		swatch.AnchorPoint = Vector2.new(1, 0.5)
		swatch.Position = UDim2.new(1, 0, 0.5, 0)
		swatch.Size = UDim2.fromOffset(SWATCH_SIZE, SWATCH_SIZE)
		swatch.BackgroundColor3 = Color3.new(item.Color[1], item.Color[2], item.Color[3])
		swatch.BorderSizePixel = 0
		swatch.Parent = frame
		ItemIcons.apply(swatch, id)
	end
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, -(SWATCH_SIZE + 8), 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.5
	label.Parent = frame
	frame.Parent = feed
	-- The oldest lines go first when the feed is full.
	local children = {}
	for _, child in feed:GetChildren() do
		if child:IsA("Frame") then
			table.insert(children, child)
		end
	end
	if #children > IC.FeedLines then
		table.sort(children, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for i = 1, #children - IC.FeedLines do
			lines[children[i].Name] = nil
			children[i]:Destroy()
		end
	end
	return frame, label
end

-- Removes a line after the feed time unless it was refreshed in between.
local function expire(id: string, line: Line)
	local token = line.token
	task.delay(IC.FeedSeconds, function()
		if line.token == token then
			if lines[id] == line then
				lines[id] = nil
			end
			line.frame:Destroy()
		end
	end)
end

local function onGain(id: string, added: number, lost: number)
	if added > 0 then
		local line = lines[id]
		if line == nil or line.frame.Parent == nil then
			local frame, label = newLine(id, GAIN_COLOR)
			line = { frame = frame, label = label, count = 0, token = 0 }
			lines[id] = line
		end
		line.count += added
		line.token += 1
		line.label.Text = Localization.get("InventoryGain", { count = line.count, item = itemName(id) })
		expire(id, line)
	end
	if lost > 0 then
		local frame, label = newLine(id, LOST_COLOR)
		frame.Name = `{id}Lost`
		label.Text = Localization.get("InventoryFull", { count = lost, item = itemName(id) })
		expire(frame.Name, { frame = frame, label = label, count = lost, token = 0 })
	end
end

function PickupFeedController.init() end

function PickupFeedController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PickupFeed"
	gui.ResetOnSpawn = false
	feed = Instance.new("Frame")
	feed.Name = "Feed"
	feed.AnchorPoint = Vector2.new(1, 1)
	feed.Position = UDim2.new(1, -SCREEN_MARGIN, FEED_BOTTOM, 0)
	feed.Size = UDim2.fromOffset(LINE_WIDTH, LINE_HEIGHT * IC.FeedLines)
	feed.BackgroundTransparency = 1
	feed.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Parent = feed
	gui.Parent = player:WaitForChild("PlayerGui")
	Net.event("InventoryGain").OnClientEvent:Connect(function(id: unknown, added: unknown, lost: unknown)
		if typeof(id) == "string" and typeof(added) == "number" and typeof(lost) == "number" then
			onGain(id, added, lost)
		end
	end)
end

return PickupFeedController
