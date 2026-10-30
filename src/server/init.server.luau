--!strict
-- Server bootstrap: requires every service, runs all init() first, then all start().
-- Services may reference each other inside start(); init() must not depend on another service.

local Services = script.Services

local order = {
	require(Services.MapService),
	require(Services.DayNightService),
	require(Services.ThreatService),
	require(Services.ZombieService),
	require(Services.InventoryService),
	require(Services.ToolService),
	require(Services.HarvestService),
	require(Services.CraftingService),
	require(Services.BuildService),
	require(Services.DebugService),
}

for _, service in order do
	service.init()
end

for _, service in order do
	task.spawn(service.start)
end
