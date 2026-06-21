--[[--
Maps WMO weather codes (from Open-Meteo) to bundled SVG glyphs and builds
ImageWidgets for them. Returns nil when an icon file is missing so callers
can fall back to text gracefully.
--]]

local ImageWidget = require("ui/widget/imagewidget")
local Assets = require("assets")

local WeatherIcons = {}

local MAP = {
    [0] = "clear",
    [1] = "partly", [2] = "partly",
    [3] = "cloudy",
    [45] = "fog", [48] = "fog",
    [51] = "rain", [53] = "rain", [55] = "rain",
    [56] = "rain", [57] = "rain",
    [61] = "rain", [63] = "rain", [65] = "rain",
    [66] = "rain", [67] = "rain",
    [71] = "snow", [73] = "snow", [75] = "snow", [77] = "snow",
    [80] = "rain", [81] = "rain", [82] = "rain",
    [85] = "snow", [86] = "snow",
    [95] = "storm", [96] = "storm", [99] = "storm",
}

function WeatherIcons.fileForCode(code)
    return (MAP[code] or "cloudy") .. ".svg"
end

--- ImageWidget for a weather code at the given size, or nil if missing.
function WeatherIcons.widget(code, size)
    if code == nil then return nil end
    local file = Assets.icon(WeatherIcons.fileForCode(code))
    if not Assets.exists(file) then return nil end
    return ImageWidget:new{
        file = file,
        width = size,
        height = size,
        alpha = false,    -- flatten transparency onto white at cache time
        is_icon = true,   -- critical: renders SVG as black-on-white, not a black box
    }
end

return WeatherIcons
