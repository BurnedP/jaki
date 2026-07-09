--[[--
App preferences: which home modules show, location, units, font, and
the cached weather payload. Defaults are filled in on every read so new
keys added in future versions appear without a migration step.
--]]

local Store = require("store")

local Prefs = {}

local KEY = "prefs"

local DEFAULTS = {
    user_name = "",
    location = "",          -- free text or "lat,lon" passed to the weather API
    units = "F",            -- "F" | "C"
    font = "sans",          -- "serif" | "sans"
    weather_api_key = "",
    weather_cache = nil,    -- { fetched_at, payload } set by weather_service
    autostart = true,       -- show the dashboard once at launch
    autoreturn = true,      -- bring it back when a book is closed
    news_feed = "",         -- RSS/Atom URL; empty uses the service default
    news_cache = nil,       -- { fetched_at, items } set by news_service
    clock24 = false,        -- 24-hour time when true, else 12-hour + AM/PM
    refresh_interval = 3600, -- seconds between auto weather/news/calendar refresh; 0 = off
    calendar_ics_url = "",   -- read-only ICS/iCal URL (Google/Apple/Outlook); empty = off
    calendar_cache = nil,    -- { fetched_at, events } set by calendar_service.refresh()
    week_start = "sun",      -- "sun" | "mon" first column of the month grid
}

local DEFAULT_MODULES = {
    weather = true,
    calendar = true,
    todos = true,
    habits = true,
    news = false,
}

local function load()
    local p = Store.read(KEY, nil) or {}
    for k, v in pairs(DEFAULTS) do
        if p[k] == nil then
            p[k] = v
        end
    end
    p.modules = p.modules or {}
    for k, v in pairs(DEFAULT_MODULES) do
        if p.modules[k] == nil then
            p.modules[k] = v
        end
    end
    return p
end

--- Read the full prefs table (with defaults applied).
function Prefs.get()
    return load()
end

--- Replace the full prefs table.
function Prefs.set(p)
    Store.write(KEY, p)
end

--- Mutate prefs via a callback, then persist. Returns the updated table.
function Prefs.update(fn)
    local p = load()
    fn(p)
    Store.write(KEY, p)
    return p
end

--- Is a home module enabled?
function Prefs.moduleEnabled(name)
    return load().modules[name] == true
end

--- Toggle a home module on/off. Returns the updated prefs.
function Prefs.toggleModule(name)
    return Prefs.update(function(p)
        p.modules[name] = not p.modules[name]
    end)
end

return Prefs
