--[[--
Calendar tab — "< Month Year >" header, month grid (delegated to
cal_grid), the selected day's events (local events deletable on hold, ICS
read-only), an Add-event flow (date picker -> title dialog), and an
Upcoming agenda. Month/selection state lives on app._cal across rerenders.
--]]

local VerticalGroup = require("ui/widget/verticalgroup")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local Button = require("ui/widget/button")
local InputDialog = require("ui/widget/inputdialog")
local ConfirmBox = require("ui/widget/confirmbox")
local UIManager = require("ui/uimanager")
local Blitbuffer = require("ffi/blitbuffer")
local _ = require("gettext")

local H = require("ui_helpers")
local Prefs = require("prefs")
local DateUtil = require("dateutil")
local Calendar = require("model_calendar")
local Events = require("model_events")

local GRAY = Blitbuffer.COLOR_DARK_GRAY
local CalScreen = {}

local function state(app)
    if not app._cal then
        local k = DateUtil.todayKey()
        app._cal = { y = tonumber(k:sub(1, 4)), m = tonumber(k:sub(6, 7)), sel = k }
    end
    return app._cal
end

local function shiftMonth(app, delta)
    local s = state(app)
    local m, yy = s.m + delta, s.y
    if m < 1 then m, yy = 12, yy - 1 elseif m > 12 then m, yy = 1, yy + 1 end
    s.m, s.y = m, yy
    app:rerender()
end

local function promptTitle(app, dateKey)
    local dialog
    dialog = InputDialog:new{
        title = _("New event ") .. dateKey, input = "",
        input_hint = _("Event title"), input_type = "text",
        buttons = {{
            { text = _("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
            { text = _("Add"), is_enter_default = true, callback = function()
                local t = dialog:getInputText()
                UIManager:close(dialog)
                Events.add(dateKey, t or "")
                app:rerender()
            end },
        }},
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

local function addEvent(app, dateKey)
    local DateTimeWidget = require("ui/widget/datetimewidget")
    local y, m, d = dateKey:match("(%d+)-(%d+)-(%d+)")
    UIManager:show(DateTimeWidget:new{
        year = tonumber(y), month = tonumber(m), day = tonumber(d),  -- date-only: omit hour/min
        title_text = _("Event date"), ok_text = _("Next"),
        callback = function(cw)
            promptTitle(app, string.format("%04d-%02d-%02d", cw.year, cw.month, cw.day))
        end,
    })
end

local function confirmDelete(app, ev)
    UIManager:show(ConfirmBox:new{
        text = _("Delete this event?\n\n") .. (ev.title or ""),
        ok_text = _("Delete"),
        ok_callback = function() Events.remove(ev.id); app:rerender() end,
    })
end

function CalScreen.render(app)
    local w = app.content_w
    local prefs = Prefs.get()
    local s = state(app)
    local index = Calendar.forMonth(s.y, s.m)
    local col = VerticalGroup:new{ align = "left" }

    table.insert(col, H.vspan(H.s(16)))
    local hdr = HorizontalGroup:new{ align = "center" }
    table.insert(hdr, Button:new{ text = "<", text_font_size = 20, bordersize = H.s(1),
        radius = H.s(6), padding = H.s(8), margin = 0,
        callback = function() shiftMonth(app, -1) end, show_parent = app })
    table.insert(hdr, H.hspan(H.s(16)))
    table.insert(hdr, H.text(DateUtil.monthName(s.m) .. " " .. s.y, H.SIZE.title, true))
    table.insert(hdr, H.hspan(H.s(16)))
    table.insert(hdr, Button:new{ text = ">", text_font_size = 20, bordersize = H.s(1),
        radius = H.s(6), padding = H.s(8), margin = 0,
        callback = function() shiftMonth(app, 1) end, show_parent = app })
    table.insert(col, hdr)
    table.insert(col, H.vspan(H.s(12)))

    local gok, CalGrid = pcall(require, "cal_grid")
    if gok and CalGrid and CalGrid.render then
        table.insert(col, CalGrid.render(app, { width = w, year = s.y, month = s.m, index = index,
            selected = s.sel, week_start = prefs.week_start,
            on_pick = function(key) s.sel = key; app:rerender() end }))
    else
        table.insert(col, H.text("Calendar grid unavailable", H.SIZE.meta, false, GRAY))
    end

    table.insert(col, H.vspan(H.s(18)))
    table.insert(col, H.sectionHeader(DateUtil.headerDate(DateUtil.keyToTs(s.sel))))
    table.insert(col, H.hline(w))
    local dayList = Calendar.onDay(s.sel)
    if #dayList == 0 then
        table.insert(col, H.vspan(H.s(10)))
        table.insert(col, H.text("No events", H.SIZE.meta, false, GRAY))
    else
        for _, ev in ipairs(dayList) do
            local e = ev
            local label = ev.title
            if not ev.all_day and ev.start_ts then
                label = DateUtil.formatTime(ev.start_ts, prefs.clock24) .. "  " .. ev.title
            end
            table.insert(col, H.vspan(H.s(12)))
            table.insert(col, H.tappable(H.wrap(label, w, 2, H.SIZE.body), w, H.s(48), nil,
                e.source == "local" and function() confirmDelete(app, e) end or nil))
        end
    end

    table.insert(col, H.vspan(H.s(14)))
    table.insert(col, H.tappable(H.text("+ Add event", H.SIZE.body, true), w, H.s(52),
        function() addEvent(app, s.sel) end))

    table.insert(col, H.vspan(H.s(24)))
    table.insert(col, H.sectionHeader("Upcoming"))
    table.insert(col, H.hline(w))
    local up = Calendar.upcoming(8)
    if #up == 0 then
        table.insert(col, H.vspan(H.s(10)))
        table.insert(col, H.text("Nothing upcoming", H.SIZE.meta, false, GRAY))
    else
        local whenW = H.s(120)
        for _, ev in ipairs(up) do
            local when = DateUtil.headerDate(DateUtil.keyToTs(ev.date))
            if not ev.all_day and ev.start_ts then
                when = when .. " " .. DateUtil.formatTime(ev.start_ts, prefs.clock24)
            end
            local rowG = HorizontalGroup:new{ align = "top" }
            table.insert(rowG, H.wrap(when, whenW, 2, H.SIZE.meta, false, GRAY))
            table.insert(rowG, H.hspan(H.s(12)))
            table.insert(rowG, H.wrap(ev.title, w - whenW - H.s(12), 2, H.SIZE.body))
            table.insert(col, H.vspan(H.s(12)))
            table.insert(col, rowG)
            table.insert(col, H.vspan(H.s(12)))
            table.insert(col, H.hline(w))
        end
    end

    return col
end

return CalScreen
