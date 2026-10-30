--!strict
-- Client bootstrap: starts every controller under Controllers.

local Controllers = script.Controllers

local controllers = {}
for _, module in Controllers:GetChildren() do
	if module:IsA("ModuleScript") then
		table.insert(controllers, (require :: any)(module))
	end
end

for _, controller in controllers do
	controller.init()
end

for _, controller in controllers do
	task.spawn(controller.start)
end
