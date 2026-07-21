local icon_map = require("icon_map")
local override = require("icon_override")

local M = {
	clock = "\u{F017}",
	calendar = "\u{F073}",
	weather = "\u{F185}",
	cpu = "\u{F2DB}",
	mem = "\u{F035B}",
	speed = "\u{F1EB}",
	bat_full = "\u{F240}",
	bat_75 = "\u{F241}",
	bat_50 = "\u{F242}",
	bat_25 = "\u{F243}",
	bat_empty = "\u{F244}",
	bolt = "\u{F0E7}",
	net = "\u{F132}",
	service = "\u{F013}",
	default = "\u{F069}",
}

function M.app(name)
	return override[name] or icon_map[name] or ":default:"
end

return M
