--!strict
-- ChallengeController: shows the tracked 7DTD challenge (ChallengeService) on the right under the
-- graphics button: its group and place in it, title, objectives with counts, and a hint. A finished
-- challenge flashes "Challenge complete" before the next one; the panel hides when all are done.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Challenges = require(Shared.Challenges)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

-- Layout (pixels): right-aligned under the clock and the graphics button (GraphicsController).
local MARGIN = 12
local TOP = 100
local WIDTH = 300
local PADDING = 8
local HEADER_HEIGHT = 16
local TITLE_HEIGHT = 22
local ROW_HEIGHT = 18
local HINT_HEIGHT = 34
local COMPLETE_SECONDS = 2

local PANEL_COLOR = Color3.fromRGB(18, 18, 20)
local TEXT_COLOR = Color3.fromRGB(225, 225, 230)
local MUTED_COLOR = Color3.fromRGB(165, 165, 172)
local DONE_COLOR = Color3.fromRGB(120, 210, 110)
local TITLE_COLOR = Color3.fromRGB(235, 220, 160)

local ChallengeController = {}

local panel: Frame
local header: TextLabel
local title: TextLabel
local rows: Frame
local hint: TextLabel
local flashToken = 0

local function label(parent: Instance, name: string, height: number, color: Color3): TextLabel
	local item = Instance.new("TextLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.Size = UDim2.new(1, 0, 0, height)
	item.Font = Enum.Font.GothamMedium
	item.TextSize = 14
	item.TextColor3 = color
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextYAlignment = Enum.TextYAlignment.Top
	item.TextWrapped = true
	item.Parent = parent
	return item
end

local function build(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Challenge"
	gui.ResetOnSpawn = false

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -MARGIN, 0, TOP)
	panel.Size = UDim2.fromOffset(WIDTH, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.35
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, PADDING)
	padding.PaddingRight = UDim.new(0, PADDING)
	padding.PaddingTop = UDim.new(0, PADDING)
	padding.PaddingBottom = UDim.new(0, PADDING)
	padding.Parent = panel
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel

	header = label(panel, "Header", HEADER_HEIGHT, MUTED_COLOR)
	header.LayoutOrder = 1
	header.TextSize = 12
	title = label(panel, "Title", TITLE_HEIGHT, TITLE_COLOR)
	title.LayoutOrder = 2
	title.Font = Enum.Font.GothamBold
	title.TextSize = 17
	rows = Instance.new("Frame")
	rows.Name = "Objectives"
	rows.LayoutOrder = 3
	rows.BackgroundTransparency = 1
	rows.Size = UDim2.new(1, 0, 0, 0)
	rows.AutomaticSize = Enum.AutomaticSize.Y
	rows.Parent = panel
	local rowList = Instance.new("UIListLayout")
	rowList.SortOrder = Enum.SortOrder.LayoutOrder
	rowList.Parent = rows
	hint = label(panel, "Hint", HINT_HEIGHT, MUTED_COLOR)
	hint.LayoutOrder = 4
	hint.TextSize = 13
	hint.AutomaticSize = Enum.AutomaticSize.Y
	hint.Size = UDim2.new(1, 0, 0, 0)

	gui.Parent = playerGui
end

local function itemName(id: string?): string
	return if id then Localization.get(`Item{id}`) else ""
end

local function objectiveText(objective: Challenges.ObjectiveView): string
	return Localization.get(
		`ChallengeObjective{objective.kind}`,
		{ item = itemName(objective.item), held = itemName(objective.held) }
	)
end

local function show(view: Challenges.View)
	header.Text = Localization.get("ChallengeHeader", {
		group = Localization.get(`ChallengeGroup{view.group}`),
		index = view.index,
		total = view.total,
	})
	title.Text = Localization.get(`Challenge{view.id}`)
	title.TextColor3 = TITLE_COLOR
	hint.Text = Localization.get(`Challenge{view.id}Hint`)
	for _, child in rows:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for index, objective in view.objectives do
		local done = objective.have >= objective.need
		local row = Instance.new("Frame")
		row.Name = `Objective{index}`
		row.LayoutOrder = index
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		row.Parent = rows
		local name = label(row, "Name", ROW_HEIGHT, if done then DONE_COLOR else TEXT_COLOR)
		name.Size = UDim2.new(1, -60, 1, 0)
		name.Text = objectiveText(objective)
		local count = label(row, "Count", ROW_HEIGHT, if done then DONE_COLOR else TEXT_COLOR)
		count.AnchorPoint = Vector2.new(1, 0)
		count.Position = UDim2.fromScale(1, 0)
		count.Size = UDim2.new(0, 60, 1, 0)
		count.TextXAlignment = Enum.TextXAlignment.Right
		count.Text = Localization.get("ChallengeProgress", { have = objective.have, need = objective.need })
	end
	panel.Visible = true
end

-- Shows "Challenge complete" over the finished challenge's title for a moment, then `after`.
local function flashComplete(completed: string, after: () -> ())
	flashToken += 1
	local token = flashToken
	header.Text = Localization.get("ChallengeComplete")
	title.Text = Localization.get(`Challenge{completed}`)
	title.TextColor3 = DONE_COLOR
	panel.Visible = true
	task.delay(COMPLETE_SECONDS, function()
		if token == flashToken then
			after()
		end
	end)
end

local function onUpdate(view: Challenges.View | false, completed: string?)
	local done = if view then view.completed else completed
	local function apply()
		if view then
			show(view)
		else
			panel.Visible = false
		end
	end
	if done then
		flashComplete(done, apply)
	else
		flashToken += 1
		apply()
	end
end

function ChallengeController.init() end

function ChallengeController.start()
	build(Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui)
	Net.event("ChallengeUpdate").OnClientEvent:Connect(onUpdate)
end

return ChallengeController
