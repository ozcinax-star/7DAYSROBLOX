--!strict
-- Every UI string lives here. Code refers to keys only; English is the source language and other
-- languages are added as extra columns (later exported to a Roblox LocalizationTable).

export type Key = string

local Strings: { [string]: { [string]: string } } = {
	en = {
		-- Threat tiers (PLAN: Quiet, Noticed, Hunted, Besieged, Targeted)
		ThreatTier1 = "Quiet",
		ThreatTier2 = "Noticed",
		ThreatTier3 = "Hunted",
		ThreatTier4 = "Besieged",
		ThreatTier5 = "Targeted",

		-- Day / night
		PhaseDay = "Day {day}",
		PhaseNight = "Night {day}",
		HordeNight = "Horde night",

		-- Camera
		CameraShoulder = "Shoulder",
		CameraFirstPerson = "First person",

		-- Debug overlay
		DebugFps = "FPS: {value}",
		DebugServerTick = "Server tick avg/max: {value} ms",
		DebugZombieCount = "Zombies: {value}",
		DebugRendered = "Rendered: {value}",
		DebugSpawn = "Spawn {value}",
		DebugNoise = "Make noise",
		DebugGodMode = "God mode on/off",
		DebugClear = "Clear",

		-- Shop signs
		SignMarket = "MARKET",
		SignDiner = "DINER",
		SignClinic = "CLINIC",
		SignHardware = "HARDWARE",
		SignGasStation = "GAS",
		SignTownHall = "TOWN HALL",
		SignWarehouse = "STORAGE",
	},
}

local Localization = {}

local currentLocale = "en"
local FALLBACK_LOCALE = "en"

function Localization.setLocale(locale: string)
	if Strings[locale] then
		currentLocale = locale
	end
end

-- Returns the localized string for `key`, replacing {name} placeholders from `args`.
function Localization.get(key: Key, args: { [string]: any }?): string
	local text = Strings[currentLocale][key] or Strings[FALLBACK_LOCALE][key]
	if text == nil then
		warn(`[Localization] missing key: {key}`)
		return key
	end
	if args then
		text = string.gsub(text, "{(%w+)}", function(name: string): string?
			local value = args[name]
			return if value ~= nil then tostring(value) else nil
		end)
	end
	return text
end

return Localization
