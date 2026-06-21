--[[--
Weather service — Open-Meteo (open-meteo.com). No API key, no signup.

Two HTTPS calls: geocode a city name to coordinates (cached), then fetch
current + hourly + daily forecast. Results are cached in prefs so the UI
shows the last known weather offline. Best-effort: any failure returns
(nil, message) and leaves the cache untouched.
--]]

local ltn12 = require("ltn12")
local socketutil = require("socketutil")
local logger = require("logger")

local Prefs = require("prefs")

local ok_json, JSON = pcall(require, "rapidjson")
if not ok_json then JSON = require("json") end

local WeatherService = {}

-- WMO weather codes -> short text (open-meteo uses these).
local WMO = {
    [0] = "Clear", [1] = "Mainly clear", [2] = "Partly cloudy", [3] = "Overcast",
    [45] = "Fog", [48] = "Rime fog",
    [51] = "Light drizzle", [53] = "Drizzle", [55] = "Heavy drizzle",
    [56] = "Freezing drizzle", [57] = "Freezing drizzle",
    [61] = "Light rain", [63] = "Rain", [65] = "Heavy rain",
    [66] = "Freezing rain", [67] = "Freezing rain",
    [71] = "Light snow", [73] = "Snow", [75] = "Heavy snow", [77] = "Snow grains",
    [80] = "Light showers", [81] = "Showers", [82] = "Heavy showers",
    [85] = "Snow showers", [86] = "Snow showers",
    [95] = "Thunderstorm", [96] = "Thunderstorm w/ hail", [99] = "Thunderstorm w/ hail",
}

local function condText(code)
    return WMO[code] or "—"
end

local function round(x)
    if x == nil then return nil end
    return math.floor(x + 0.5)
end

local function urlencode(s)
    return (tostring(s):gsub("[^%w%-_%.~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

--- HTTPS GET returning decoded JSON, or (nil, err).
local function getJSON(url)
    local https = require("ssl.https")
    local body = {}
    socketutil:set_timeout(10, 30)
    local res, code = https.request{
        url = url,
        method = "GET",
        sink = ltn12.sink.table(body),
    }
    socketutil:reset_timeout()
    if not res or code ~= 200 then
        logger.warn("KindleDaily weather: request failed", url, code)
        return nil, "Network error (" .. tostring(code) .. ")"
    end
    local decoded_ok, data = pcall(JSON.decode, table.concat(body))
    if not decoded_ok then
        return nil, "Bad response"
    end
    return data
end

--- City name -> { lat, lon, name, query }, or (nil, err).
local function geocode(name)
    local url = "https://geocoding-api.open-meteo.com/v1/search?name="
        .. urlencode(name) .. "&count=1&language=en&format=json"
    local data, err = getJSON(url)
    if not data then return nil, err end
    local r = data.results and data.results[1]
    if not r then return nil, "Location not found" end
    local label = r.name
    if r.admin1 and r.admin1 ~= "" then label = label .. ", " .. r.admin1 end
    return { lat = r.latitude, lon = r.longitude, name = label, query = name }
end

--- Fetch and cache weather for the configured location.
--- @return true on success, or (nil, message).
function WeatherService.refresh()
    local prefs = Prefs.get()
    if not prefs.location or prefs.location == "" then
        return nil, "No location set"
    end

    -- Resolve coordinates (cached unless the query changed).
    local geo = prefs.weather_geo
    if not geo or geo.query ~= prefs.location then
        local g, gerr = geocode(prefs.location)
        if not g then return nil, gerr end
        geo = g
        Prefs.update(function(p) p.weather_geo = geo end)
    end

    local unit = (prefs.units == "C") and "celsius" or "fahrenheit"
    local url = string.format(
        "https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s"
        .. "&current=temperature_2m,weather_code"
        .. "&hourly=temperature_2m,weather_code"
        .. "&daily=weather_code,temperature_2m_max,temperature_2m_min"
        .. "&forecast_days=3&timezone=auto&temperature_unit=%s",
        tostring(geo.lat), tostring(geo.lon), unit)

    local data, err = getJSON(url)
    if not data then return nil, err end

    local payload = { location = geo.name, unit = (unit == "celsius") and "C" or "F" }

    if data.current then
        payload.temp = round(data.current.temperature_2m)
        payload.code = data.current.weather_code
        payload.condition = condText(data.current.weather_code)
    end

    if data.daily and data.daily.time then
        payload.daily = {}
        for i = 1, #data.daily.time do
            table.insert(payload.daily, {
                date = data.daily.time[i],
                hi = round(data.daily.temperature_2m_max[i]),
                lo = round(data.daily.temperature_2m_min[i]),
                code = data.daily.weather_code[i],
                cond = condText(data.daily.weather_code[i]),
            })
        end
        if payload.daily[1] then
            payload.high = payload.daily[1].hi
            payload.low = payload.daily[1].lo
        end
    end

    if data.hourly and data.hourly.time then
        payload.hourly = {}
        local nowkey = os.date("%Y-%m-%dT%H:00")
        local start = 1
        for i = 1, #data.hourly.time do
            if data.hourly.time[i] >= nowkey then start = i break end
        end
        for i = start, math.min(start + 5, #data.hourly.time) do
            table.insert(payload.hourly, {
                time = data.hourly.time[i],
                temp = round(data.hourly.temperature_2m[i]),
                code = data.hourly.weather_code[i],
                cond = condText(data.hourly.weather_code[i]),
            })
        end
    end

    Prefs.update(function(p)
        p.weather_cache = { fetched_at = os.time(), payload = payload }
    end)
    return true
end

return WeatherService
