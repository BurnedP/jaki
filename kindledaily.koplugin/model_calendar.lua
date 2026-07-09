--[[--
Calendar aggregator — merges expanded ICS occurrences (calendar_service)
with local events (model_events) into a per-day index keyed by the shared
"YYYY-MM-DD" local keyspace. Multi-day all-day events spread across every
covered day (honoring DTEND-exclusive). Ordering is pure string compare.
--]]

local Events = require("model_events")
local DateUtil = require("dateutil")
local CalendarService = require("calendar_service")

local Calendar = {}
local DAY = 86400

local function dayStartTs(key)
    local y, mo, d = key:match("(%d+)-(%d+)-(%d+)")
    return os.time{ year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = 0, min = 0, sec = 0 }
end
local function dayEndTs(key)
    local y, mo, d = key:match("(%d+)-(%d+)-(%d+)")
    return os.time{ year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = 23, min = 59, sec = 59 }
end

local function dayLess(a, b)
    local aw = a.all_day and 0 or 1
    local bw = b.all_day and 0 or 1
    if aw ~= bw then return aw < bw end
    if aw == 1 and (a.start_ts or 0) ~= (b.start_ts or 0) then
        return (a.start_ts or 0) < (b.start_ts or 0)
    end
    return (a.title or "") < (b.title or "")
end

-- covered day keys, honoring DTEND-exclusive for all-day (inclusive last = end_ts-1)
local function coveredKeys(occ)
    local keys = {}
    if occ.all_day then
        local last = (occ.end_ts and occ.end_ts > occ.start_ts) and (occ.end_ts - 1) or occ.start_ts
        local cur = occ.start_ts
        local g = 0
        while cur <= last and g < 400 do
            keys[#keys + 1] = os.date("%Y-%m-%d", cur)
            cur = cur + DAY; g = g + 1
        end
    else
        keys[#keys + 1] = os.date("%Y-%m-%d", occ.start_ts)
    end
    return keys
end

function Calendar.forRange(fromKey, toKey)
    local index = {}
    local function add(dateKey, ev)
        if dateKey >= fromKey and dateKey <= toKey then
            index[dateKey] = index[dateKey] or {}
            table.insert(index[dateKey], ev)
        end
    end
    for _, e in ipairs(Events.list()) do
        add(e.date, { id = e.id, date = e.date, title = e.title,
                      all_day = true, start_ts = nil, source = "local" })
    end
    local occs = CalendarService.occurrencesForRange(dayStartTs(fromKey), dayEndTs(toKey))
    for _, occ in ipairs(occs) do
        local title = occ.summary or "(busy)"
        for _, dateKey in ipairs(coveredKeys(occ)) do
            add(dateKey, { uid = occ.uid, date = dateKey, title = title,
                           all_day = occ.all_day and true or false,
                           start_ts = occ.start_ts, source = "ics" })
        end
    end
    for _, list in pairs(index) do table.sort(list, dayLess) end
    return index
end

function Calendar.forMonth(y, m)
    local from = string.format("%04d-%02d-01", y, m)
    local to = string.format("%04d-%02d-%02d", y, m, DateUtil.daysInMonth(y, m))
    return Calendar.forRange(from, to)
end

function Calendar.onDay(key) return Calendar.forRange(key, key)[key] or {} end
function Calendar.today() return Calendar.onDay(DateUtil.todayKey()) end

function Calendar.upcoming(n, fromKey)
    fromKey = fromKey or DateUtil.todayKey()
    local toKey = DateUtil.addDaysKey(fromKey, 60)
    local index = Calendar.forRange(fromKey, toKey)
    local keys = {}
    for k in pairs(index) do keys[#keys + 1] = k end
    table.sort(keys)
    local flat = {}
    for _, k in ipairs(keys) do
        for _, ev in ipairs(index[k]) do flat[#flat + 1] = ev end
    end
    if n and #flat > n then
        local t = {}
        for i = 1, n do t[i] = flat[i] end
        return t
    end
    return flat
end

return Calendar
