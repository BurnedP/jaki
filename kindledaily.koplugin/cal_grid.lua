--[[--
Month-grid renderer with DST-safe date math. Contract:
  CalGrid.render(app, { width, year, month, index, selected, week_start, on_pick=fn(dateKey) })
Today is a string compare recomputed each render; dots come from the
per-day index; every cell is built at noon and keyed via string.format.
--]]

local VerticalGroup = require("ui/widget/verticalgroup")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local Blitbuffer = require("ffi/blitbuffer")

local H = require("ui_helpers")
local DateUtil = require("dateutil")

local CalGrid = {}
local GRAY = Blitbuffer.COLOR_DARK_GRAY
local SUN_LABELS = { "S", "M", "T", "W", "T", "F", "S" }
local MON_LABELS = { "M", "T", "W", "T", "F", "S", "S" }

local function dayCell(o, cellW, cellH, y, m, dayNum, todayKey)
    local key = string.format("%04d-%02d-%02d", y, m, dayNum)
    local is_today = (key == todayKey)
    local is_sel = (key == o.selected)
    local list = o.index[key]
    local has_ev = list and #list > 0
    local inner = VerticalGroup:new{ align = "center" }
    table.insert(inner, H.text(tostring(dayNum), H.SIZE.body, is_today or is_sel))
    table.insert(inner, H.vspan(H.s(3)))
    if has_ev then table.insert(inner, H.box(H.s(6), true))
    else table.insert(inner, H.vspan(H.s(6))) end
    local body
    if is_sel then
        body = FrameContainer:new{ bordersize = H.s(2), color = Blitbuffer.COLOR_BLACK,
            background = Blitbuffer.COLOR_WHITE, radius = H.s(6), margin = 0, padding = H.s(2),
            CenterContainer:new{ dimen = Geom:new{ w = cellW - H.s(12), h = cellH - H.s(12) }, inner } }
    else body = inner end
    local outer = CenterContainer:new{ dimen = Geom:new{ w = cellW, h = cellH }, body }
    local kcap = key
    return H.tappable(outer, cellW, cellH, function() if o.on_pick then o.on_pick(kcap) end end)
end

function CalGrid.render(app, o)
    local w = o.width
    local y, m = o.year, o.month
    o.index = o.index or {}
    local monStart = (o.week_start == "mon")
    local todayKey = DateUtil.todayKey()
    local ndays = DateUtil.daysInMonth(y, m)
    local firstKey = string.format("%04d-%02d-01", y, m)
    local w0 = DateUtil.weekdayOfKey(firstKey)          -- 0=Sun..6=Sat
    local lead = monStart and ((w0 + 6) % 7) or w0
    local cellW = math.floor(w / 7)
    local cellH = H.s(52)
    local col = VerticalGroup:new{ align = "left" }
    local labels = monStart and MON_LABELS or SUN_LABELS
    local hrow = HorizontalGroup:new{ align = "center" }
    for i = 1, 7 do
        table.insert(hrow, CenterContainer:new{
            dimen = Geom:new{ w = cellW, h = H.s(22) }, H.text(labels[i], H.SIZE.meta, false, GRAY) })
    end
    table.insert(col, hrow)
    table.insert(col, H.vspan(H.s(4)))
    local pos = 0
    local total = lead + ndays
    local rows = math.ceil(total / 7)
    for _r = 1, rows do
        local rowG = HorizontalGroup:new{ align = "center" }
        for _c = 1, 7 do
            local dayNum = pos - lead + 1
            local content
            if dayNum >= 1 and dayNum <= ndays then
                content = dayCell(o, cellW, cellH, y, m, dayNum, todayKey)
            else
                content = CenterContainer:new{ dimen = Geom:new{ w = cellW, h = cellH }, H.text("", H.SIZE.body) }
            end
            table.insert(rowG, content)
            pos = pos + 1
        end
        table.insert(col, rowG)
    end
    return col
end

return CalGrid
