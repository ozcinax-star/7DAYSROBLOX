--!strict
-- Graphics: picks the client graphics preset for a device (Config.Graphics). Plain values only, so
-- the Lune tests can run it.

local Config = require("./Config")

local Graphics = {}

-- The preset Auto chooses: `touch` and `keyboard` from UserInputService, `quality` Roblox's saved
-- graphics quality (1-10), nil when it is set to Automatic.
function Graphics.autoPreset(touch: boolean, keyboard: boolean, quality: number?): string
	local GC = Config.Graphics
	if touch and not keyboard then
		return "Low"
	end
	if quality == nil then
		return "Medium"
	end
	if quality <= GC.AutoLowQuality then
		return "Low"
	end
	return if quality <= GC.AutoMediumQuality then "Medium" else "High"
end

return Graphics
