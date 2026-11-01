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
	require(Services.ProgressionService),
	require(Services.ChallengeService),
	require(Services.LootService),
	require(Services.ToolService),
	require(Services.RangedService),
	require(Services.HarvestService),
	require(Services.DigService),
	require(Services.CraftingService),
	require(Services.BuildService),
	require(Services.FarmService),
	require(Services.PowerService),
	require(Services.StationService),
	require(Services.StorageService),
	require(Services.SurvivalService),
	require(Services.DebugService),
	-- Last: its start() restores the world once every other service has set up.
	require(Services.PersistenceService),
}

for _, service in order do
	service.init()
end

for _, service in order do
	task.spawn(service.start)
end
