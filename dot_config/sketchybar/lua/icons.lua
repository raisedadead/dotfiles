local icon_map = require("icon_map")
local override = require("icon_override")

local M = {
	clock = "\u{F017}",
	calendar = "\u{F073}",
	service = "\u{F013}",
	default = "\u{F069}",
}

function M.app(name)
	return override[name] or icon_map[name] or ":default:"
end

return M
