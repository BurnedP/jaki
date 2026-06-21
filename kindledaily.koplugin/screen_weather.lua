--[[--
Weather screen — current conditions plus hourly and daily strips, backed
by the cached Open-Meteo payload. A Refresh row fetches fresh data
(keyless). Offline, it shows the last cached values with a timestamp.
--]]

local VerticalGroup = require("ui/widget/verticalgroup")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local CenterContainer = require("ui/widget/container/centercontainer")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local Geom = require("ui/geometry")
local Blitbuffer = require("ffi/blitbuffer")
local _ = require("gettext")

local H = require("ui_helpers")
local Prefs = require("prefs")
local WeatherIcons = require("weather_icons")

local WeatherScreen = {}

--- "2026-06-21T14:00" -> "2 PM"
local function hourLabel(iso)
    local hh = tonumber((iso or ""):sub(12, 13)) or 0
    local ampm = hh < 12 and "AM" or "PM"
    local h12 = hh % 12
    if h12 == 0 then h12 = 12 end
    return h12 .. " " .. ampm
end

--- "2026-06-21" -> "Sat" (today shows "Today")
local function dayLabel(iso, idx)
    if idx == 1 then return "Today" end
    local y, m, d = (iso or ""):match("(%d+)-(%d+)-(%d+)")
    if not y then return "" end
    local t = os.time{ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 }
    return os.date("%a", t)
end

local function doRefresh(app)
    local ok, service = pcall(require, "weather_service")
    if not ok or not service or not service.refresh then
        UIManager:show(InfoMessage:new{ text = _("Weather unavailable."), timeout = 2 })
        return
    end
    UIManager:show(InfoMessage:new{ text = _("Fetching weather…"), timeout = 1 })
    UIManager:scheduleIn(0.1, function()
        local fetched, err = service.refresh()
        if not fetched then
            UIManager:show(InfoMessage:new{
                text = _("Couldn't fetch weather.\n") .. tostring(err or ""),
                timeout = 3,
            })
        end
        app:rerender()
    end)
end

local function cell(w, top, mid, bottom)
    local col = VerticalGroup:new{ align = "center" }
    table.insert(col, H.text(top, H.SIZE.meta, false, Blitbuffer.COLOR_DARK_GRAY))
    table.insert(col, H.vspan(H.s(4)))
    table.insert(col, H.text(mid, H.SIZE.body, true))
    if bottom then
        table.insert(col, H.vspan(H.s(2)))
        table.insert(col, H.textCapped(bottom, H.SIZE.meta, w, false, Blitbuffer.COLOR_GRAY))
    end
    return CenterContainer:new{ dimen = Geom:new{ w = w, h = H.s(70) }, col }
end

function WeatherScreen.render(app)
    local w = app.content_w
    local prefs = Prefs.get()
    local col = VerticalGroup:new{ align = "left" }

    table.insert(col, H.vspan(H.s(16)))
    table.insert(col, H.text("Weather", H.SIZE.hero, true))

    if prefs.location == "" then
        table.insert(col, H.vspan(H.s(30)))
        table.insert(col, H.text("No location set.", H.SIZE.body, true))
        table.insert(col, H.vspan(H.s(8)))
        table.insert(col, H.text("Add your location in Settings — no API key needed.",
            H.SIZE.meta, false, Blitbuffer.COLOR_DARK_GRAY))
        return col
    end

    local wc = prefs.weather_cache
    local p = wc and wc.payload
    table.insert(col, H.vspan(H.s(4)))
    table.insert(col, H.text((p and p.location) or prefs.location,
        H.SIZE.section, false, Blitbuffer.COLOR_DARK_GRAY))

    if p and p.temp then
        -- Current
        table.insert(col, H.vspan(H.s(18)))
        local cur = HorizontalGroup:new{ align = "center" }
        local ic = WeatherIcons.widget(p.code, H.s(88))
        if ic then
            table.insert(cur, ic)
            table.insert(cur, H.hspan(H.s(18)))
        end
        table.insert(cur, H.text(p.temp .. "°", H.SIZE.hero + 26, true))
        table.insert(cur, H.hspan(H.s(20)))
        local meta = VerticalGroup:new{ align = "left" }
        table.insert(meta, H.text(p.condition or "", H.SIZE.body))
        if p.high and p.low then
            table.insert(meta, H.text("H " .. p.high .. "°   L " .. p.low .. "°",
                H.SIZE.meta, false, Blitbuffer.COLOR_DARK_GRAY))
        end
        table.insert(cur, meta)
        table.insert(col, cur)

        -- Hourly strip
        if p.hourly and #p.hourly > 0 then
            table.insert(col, H.vspan(H.s(20)))
            table.insert(col, H.sectionHeader("Next hours"))
            table.insert(col, H.vspan(H.s(8)))
            local cw = math.floor(w / math.min(#p.hourly, 6))
            local strip = HorizontalGroup:new{ align = "top" }
            for _, h in ipairs(p.hourly) do
                table.insert(strip, cell(cw, hourLabel(h.time), (h.temp or "?") .. "°"))
            end
            table.insert(col, strip)
        end

        -- Daily strip
        if p.daily and #p.daily > 0 then
            table.insert(col, H.vspan(H.s(16)))
            table.insert(col, H.sectionHeader("Next days"))
            table.insert(col, H.vspan(H.s(8)))
            local cw = math.floor(w / #p.daily)
            local strip = HorizontalGroup:new{ align = "top" }
            for i, d in ipairs(p.daily) do
                table.insert(strip, cell(cw, dayLabel(d.date, i),
                    (d.hi or "?") .. "° / " .. (d.lo or "?") .. "°"))
            end
            table.insert(col, strip)
        end

        if wc.fetched_at then
            table.insert(col, H.vspan(H.s(14)))
            table.insert(col, H.text("Updated " .. os.date("%-I:%M %p", wc.fetched_at),
                H.SIZE.meta, false, Blitbuffer.COLOR_GRAY))
        end
    else
        table.insert(col, H.vspan(H.s(20)))
        table.insert(col, H.text("No data yet — tap Refresh.", H.SIZE.body))
    end

    table.insert(col, H.vspan(H.s(20)))
    table.insert(col, H.hline(w))
    table.insert(col, H.tappable(
        H.text("Refresh now", H.SIZE.body, true),
        w, H.s(56), function() doRefresh(app) end))
    table.insert(col, H.hline(w))

    return col
end

return WeatherScreen
