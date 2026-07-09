--[[--
Calendar service — fetch a read-only ICS/iCal feed over HTTPS and parse
VEVENTs (RFC 5545: line unfolding, DATE vs DATE-TIME, TEXT unescaping,
DTEND-exclusive), cache compact events, and expand RRULE lazily inside a
bounded window at render time.

Timezone stance (v1): UTC ("Z") times convert exactly via timegm; TZID /
floating times render as the device's local wall clock (correct on a
single-timezone device). Recurrence supports DAILY/WEEKLY(+BYDAY)/MONTHLY/
YEARLY on a fixed day; MONTHLY/YEARLY with BYDAY/BYSETPOS/etc fall back to
the base instance rather than emitting wrong dates.
--]]

local ltn12 = require("ltn12")
local socketutil = require("socketutil")
local logger = require("logger")
local Prefs = require("prefs")

local CalendarService = {}
local DAY = 86400
local MAX_EVENTS = 500
local KEEP_BACK = 31 * DAY
local KEEP_FWD = 400 * DAY

local function timegm(t)
    local epoch = os.time(t)
    local delta = os.difftime(os.time(os.date("!*t", epoch)), epoch)
    return epoch - delta
end

local function unfold(raw)
    raw = raw:gsub("\r\n", "\n"):gsub("\r", "\n")
    return (raw:gsub("\n[ \t]", ""))
end

local function unescapeText(s)
    if not s then return nil end
    return (s:gsub("\\(.)", function(c)
        if c == "n" or c == "N" then return "\n"
        elseif c == "\\" or c == ";" or c == "," then return c
        else return "\\" .. c end
    end))
end

-- split at first UNQUOTED colon; params on UNQUOTED semicolons (quoted TZID/URL survive)
local function splitLine(line)
    local inq, colon = false, nil
    for i = 1, #line do
        local c = line:sub(i, i)
        if c == '"' then inq = not inq elseif c == ":" and not inq then colon = i; break end
    end
    if not colon then return nil end
    local head, value = line:sub(1, colon - 1), line:sub(colon + 1)
    local parts, buf, q = {}, {}, false
    for i = 1, #head do
        local c = head:sub(i, i)
        if c == '"' then q = not q; buf[#buf + 1] = c
        elseif c == ";" and not q then parts[#parts + 1] = table.concat(buf); buf = {}
        else buf[#buf + 1] = c end
    end
    parts[#parts + 1] = table.concat(buf)
    local name = parts[1]:upper()
    local params = {}
    for i = 2, #parts do
        local k, v = parts[i]:match("^([^=]+)=(.*)$")
        if k then params[k:upper()] = (v:gsub('^"(.*)"$', "%1")) end
    end
    return name, params, value
end

local function parseDateValue(value, params)
    if not value then return nil end
    value = value:gsub("%s", "")
    local is_date = (params and (params.VALUE or ""):upper() == "DATE") or (not value:find("T"))
    local y, mo, d = value:match("^(%d%d%d%d)(%d%d)(%d%d)")
    if not y then return nil end
    y, mo, d = tonumber(y), tonumber(mo), tonumber(d)
    if is_date then
        return { all_day = true, ts = os.time({ year = y, month = mo, day = d, hour = 0, min = 0, sec = 0 }) }
    end
    local hh, mi, ss = value:match("T(%d%d)(%d%d)(%d%d)")
    hh, mi, ss = tonumber(hh) or 0, tonumber(mi) or 0, tonumber(ss) or 0
    local f = { year = y, month = mo, day = d, hour = hh, min = mi, sec = ss }
    local ts
    if value:sub(-1) == "Z" then ts = timegm(f) else ts = os.time(f) end
    return { all_day = false, ts = ts }
end

local function parseVevent(block)
    local ev = {}
    local dtstart, dtend
    for line in block:gmatch("[^\n]+") do
        local name, params, value = splitLine(line)
        if name == "SUMMARY" then ev.summary = unescapeText(value)
        elseif name == "LOCATION" then ev.location = unescapeText(value)
        elseif name == "UID" then ev.uid = value
        elseif name == "DTSTART" then dtstart = parseDateValue(value, params)
        elseif name == "DTEND" then dtend = parseDateValue(value, params)
        elseif name == "RRULE" then ev.rrule = value
        elseif name == "RECURRENCE-ID" then ev._override = true
        elseif name == "EXDATE" then
            ev.exdates = ev.exdates or {}
            for v in value:gmatch("[^,]+") do
                local dv = parseDateValue(v, params)
                if dv then ev.exdates[os.date("%Y-%m-%d", dv.ts)] = true end
            end
        end
    end
    if ev._override then return nil end
    if not dtstart then return nil end
    ev.all_day = dtstart.all_day and true or false
    ev.start_ts = dtstart.ts
    if dtend then ev.end_ts = dtend.ts
    elseif dtstart.all_day then ev.end_ts = dtstart.ts + DAY
    else ev.end_ts = dtstart.ts end
    return ev
end

function CalendarService.parse(text)
    local body = unfold(text)
    local events = {}
    for block in body:gmatch("BEGIN:VEVENT(.-)END:VEVENT") do
        local ev = parseVevent(block)
        if ev then events[#events + 1] = ev end
    end
    return events
end

local WD = { SU = 0, MO = 1, TU = 2, WE = 3, TH = 4, FR = 5, SA = 6 }
local function parseRRule(s)
    local r = {}
    for p in s:gmatch("[^;]+") do
        local k, v = p:match("^([^=]+)=(.*)$")
        if k then r[k:upper()] = v end
    end
    return r
end

function CalendarService.expand(ev, winStart, winEnd, out)
    out = out or {}
    if not ev.start_ts then return out end
    local dur = (ev.end_ts or ev.start_ts) - ev.start_ts
    if dur < 0 then dur = 0 end
    local function excluded(ts) return ev.exdates and ev.exdates[os.date("%Y-%m-%d", ts)] end
    local function push(ts)
        if excluded(ts) then return end
        out[#out + 1] = { uid = ev.uid, summary = ev.summary, location = ev.location,
            all_day = ev.all_day, start_ts = ts, end_ts = ts + dur, day_key = os.date("%Y-%m-%d", ts) }
    end
    if not ev.rrule then
        local overlaps = (ev.end_ts > winStart)
            or (ev.start_ts == ev.end_ts and ev.start_ts >= winStart)
        if overlaps and ev.start_ts <= winEnd then push(ev.start_ts) end
        return out
    end
    local r = parseRRule(ev.rrule)
    local freq = (r.FREQ or ""):upper()
    local interval = math.max(1, tonumber(r.INTERVAL) or 1)
    local count = tonumber(r.COUNT)
    local until_ts
    if r.UNTIL then local u = parseDateValue(r.UNTIL, nil); until_ts = u and u.ts end
    -- Set-expansion we do not implement -> base instance only.
    if (freq == "MONTHLY" or freq == "YEARLY")
        and (r.BYDAY or r.BYMONTHDAY or r.BYSETPOS or r.BYMONTH) then
        if ev.end_ts > winStart and ev.start_ts <= winEnd then push(ev.start_ts) end
        return out
    end
    local st = os.date("*t", ev.start_ts)
    local sy, sm, sd = st.year, st.month, st.day
    local hh, mi, ss = st.hour, st.min, st.sec
    local function mk(y, m, d) return os.time({ year = y, month = m, day = d, hour = hh, min = mi, sec = ss }) end
    local emitted = 0
    local function consider(ts)
        if ts < ev.start_ts then return true end
        if until_ts and ts > until_ts then return false end
        emitted = emitted + 1
        if ts >= winStart and ts <= winEnd then push(ts) end
        if count and emitted >= count then return false end
        if ts > winEnd then return false end
        return true
    end
    if freq == "DAILY" then
        local k = 0
        if not count and ev.start_ts < winStart then
            k = math.floor((winStart - ev.start_ts) / (DAY * interval)) - 1
            if k < 0 then k = 0 end
        end
        local g = 0
        while g < 4000 do
            if not consider(mk(sy, sm, sd + k * interval)) then break end
            k = k + 1; g = g + 1
        end
    elseif freq == "WEEKLY" then
        local byday = {}
        if r.BYDAY then
            for d in r.BYDAY:gmatch("[^,]+") do
                local wd = WD[d:sub(-2):upper()]
                if wd then byday[#byday + 1] = wd end
            end
        end
        if #byday == 0 then byday = { tonumber(os.date("%w", ev.start_ts)) } end
        local offs = {}
        for _, wd in ipairs(byday) do offs[#offs + 1] = (wd + 6) % 7 end
        table.sort(offs)
        local monOff = (tonumber(os.date("%w", ev.start_ts)) + 6) % 7
        local wk = 0
        if not count and ev.start_ts < winStart then
            wk = math.floor((winStart - ev.start_ts) / (interval * 7 * DAY)) - 1
            if wk < 0 then wk = 0 end
        end
        local g = 0
        while g < 800 do
            local weekStart = sd - monOff + wk * interval * 7
            local stop = false
            for _, off in ipairs(offs) do
                if not consider(mk(sy, sm, weekStart + off)) then stop = true; break end
            end
            if stop then break end
            wk = wk + 1; g = g + 1
        end
    elseif freq == "MONTHLY" then
        local k = 0
        while k < 1200 do
            local total = (sy * 12 + (sm - 1)) + k * interval
            local yy, mm = math.floor(total / 12), (total % 12) + 1
            local ts = mk(yy, mm, sd)
            if tonumber(os.date("%d", ts)) == sd then
                if not consider(ts) then break end
            elseif ts > winEnd and not count then break end
            k = k + 1
        end
    elseif freq == "YEARLY" then
        local k = 0
        while k < 200 do
            local ts = mk(sy + k * interval, sm, sd)
            if tonumber(os.date("%d", ts)) == sd and tonumber(os.date("%m", ts)) == sm then
                if not consider(ts) then break end
            elseif ts > winEnd and not count then break end
            k = k + 1
        end
    else
        if ev.end_ts > winStart and ev.start_ts <= winEnd then push(ev.start_ts) end
    end
    return out
end

local function requestOnce(url, sink)
    local https = require("ssl.https")
    return https.request{ url = url, method = "GET",
        headers = { ["User-Agent"] = "KindleDaily/1.0" }, sink = sink }
end

local function getRaw(url)
    url = url:gsub("^webcal://", "https://"):gsub("^webcals://", "https://")
    socketutil:set_timeout(10, 60)
    local body = {}
    local res, code, headers = requestOnce(url, ltn12.sink.table(body))
    if res and (code == 301 or code == 302 or code == 303 or code == 307 or code == 308) then
        local loc = headers and (headers.location or headers.Location)
        if loc and loc ~= "" then
            body = {}
            res, code, headers = requestOnce(loc, ltn12.sink.table(body))
        end
    end
    socketutil:reset_timeout()
    if not res or code ~= 200 then
        logger.warn("KindleDaily calendar: request failed", url, code)
        return nil, "Network error (" .. tostring(code) .. ")"
    end
    return table.concat(body)
end

function CalendarService.feedUrl()
    local u = Prefs.get().calendar_ics_url
    if not u or u == "" then return nil end
    return u
end

function CalendarService.refresh()
    local url = CalendarService.feedUrl()
    if not url then return nil, "No calendar URL set" end
    local text, err = getRaw(url)
    if not text then return nil, err end
    if not text:find("BEGIN:VCALENDAR") then return nil, "Not an iCalendar feed" end
    local ok, events = pcall(CalendarService.parse, text)
    if not ok then
        logger.warn("KindleDaily calendar: parse error", events)
        return nil, "Could not read calendar"
    end
    -- Bound cache size but never drop recurring events by DTSTART (an old series still occurs today).
    local now = os.time()
    local floor_ts = now - KEEP_BACK
    local ceil_ts = now + KEEP_FWD
    local kept = {}
    for _, ev in ipairs(events) do
        local keep = ev.rrule and true or ((ev.end_ts > floor_ts) and (ev.start_ts < ceil_ts))
        if keep then
            kept[#kept + 1] = ev
            if #kept >= MAX_EVENTS then break end
        end
    end
    Prefs.update(function(p) p.calendar_cache = { fetched_at = os.time(), events = kept } end)
    return kept
end

-- Expand all cached ICS events into occurrences in [winStart,winEnd]; each expand pcall-guarded.
function CalendarService.occurrencesForRange(winStart, winEnd)
    local p = Prefs.get()
    local out = {}
    local cache = p.calendar_cache
    if cache and cache.events then
        for _, ev in ipairs(cache.events) do
            local ok, e = pcall(CalendarService.expand, ev, winStart, winEnd)
            if ok and e then
                for _, occ in ipairs(e) do out[#out + 1] = occ end
            elseif not ok then
                logger.warn("KindleDaily calendar: expand failed", e)
            end
        end
    end
    return out
end

return CalendarService
