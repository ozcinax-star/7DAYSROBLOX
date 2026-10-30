--!strict
-- TreeFallController: animates felled trees. The server stops a felled tree colliding and removes it
-- after Config.Harvest.FallSeconds + FadeSeconds; meanwhile this client tips the tree's own parts over
-- around the trunk base, away from the player who felled it, then fades them out. The changes stay
-- local, so every client animates its own copy.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local HC = Config.Harvest
-- The trunk ends just short of lying flat, so it rests on the slope instead of sinking into it.
local FALL_ANGLE = math.rad(84)

type Fall = {
	startedAt: number,
	start: CFrame,
	base: Vector3,
	axis: Vector3,
	parts: { [BasePart]: number },
}

local TreeFallController = {}

local falls: { [Model]: Fall } = {}

local function onFelled(model: unknown, base: unknown, direction: unknown)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		-- The tree is not streamed in on this client.
		return
	end
	if typeof(base) ~= "Vector3" or typeof(direction) ~= "Vector3" or direction.Magnitude < 0.5 then
		return
	end
	local parts: { [BasePart]: number } = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			parts[part] = part.Transparency
		end
	end
	falls[model] = {
		startedAt = os.clock(),
		start = model:GetPivot(),
		base = base,
		-- Turning about (up cross direction) tips the top toward `direction`.
		axis = Vector3.yAxis:Cross(direction.Unit),
		parts = parts,
	}
end

local function onRender()
	local now = os.clock()
	for model, fall in falls do
		if model.Parent == nil then
			falls[model] = nil
			continue
		end
		local elapsed = now - fall.startedAt
		-- Falls like a toppling trunk: slow at first, fastest when it hits the ground.
		local progress = math.min(1, elapsed / HC.FallSeconds)
		local angle = FALL_ANGLE * progress * progress
		local turn = CFrame.new(fall.base) * CFrame.fromAxisAngle(fall.axis, angle) * CFrame.new(-fall.base)
		model:PivotTo(turn * fall.start)
		if elapsed > HC.FallSeconds then
			local fade = math.min(1, (elapsed - HC.FallSeconds) / HC.FadeSeconds)
			for part, transparency in fall.parts do
				part.Transparency = transparency + (1 - transparency) * fade
			end
			if fade >= 1 then
				falls[model] = nil
			end
		end
	end
end

function TreeFallController.init() end

function TreeFallController.start()
	Net.event("TreeFelled").OnClientEvent:Connect(onFelled)
	RunService.PreRender:Connect(onRender)
end

return TreeFallController
