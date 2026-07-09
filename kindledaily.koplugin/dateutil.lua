--[[--
Date helpers. All date keys are local-time "YYYY-MM-DD" strings so they
sort lexicographically and survive serialization without timezone math.
--]]

local DateUtil = {}

local DAY = 86400

--- "YYYY-MM-DD" for the given timestamp (defaults to now).
function DateUtil.todayKey(t)
    return os.date("%Y-%m-%d", t or os.time())
end

--- Human header date, e.g. "Tuesday, June 9" (no leading zero on the day).
function DateUtil.headerDate(t)
    t = t or os.time()
    local wday = os.date("%A", t)
    local month = os.date("%B", t)
    local day = tostring(tonumber(os.date("%d", t)))
    return wday .. ", " .. month .. " " .. day
end

--- Time-of-day greeting.
function DateUtil.greeting(t)
    local hour = tonumber(os.date("%H", t or os.time()))
    if hour < 12 then
        return "Good morning"
    elseif hour < 18 then
        return "Good afternoon"
    else
        return "Good evening"
    end
end

--- Array of the last n days, oldest first:
--- { {key="YYYY-MM-DD", dow="Mon", ts=...}, ... }
function DateUtil.lastNDays(n)
    local days = {}
    local now = os.time()
    for i = n - 1, 0, -1 do
        local ts = now - i * DAY
        table.insert(days, {
            key = os.date("%Y-%m-%d", ts),
            dow = os.date("%a", ts),
            ts = ts,
        })
    end
    return days
end

--- Timestamp of the most recent 4am boundary — the app's "day" rollover,
--- so finished to-dos linger through the evening and clear overnight.
function DateUtil.dayStart4am(t)
    t = t or os.time()
    local y = tonumber(os.date("%Y", t))
    local mo = tonumber(os.date("%m", t))
    local d = tonumber(os.date("%d", t))
    local fouram = os.time{ year = y, month = mo, day = d, hour = 4, min = 0, sec = 0 }
    if t >= fouram then
        return fouram
    end
    return fouram - DAY
end

--- "HH:MM" formatted per the 24-hour preference (12h adds AM/PM).
function DateUtil.formatTime(t, use24)
    t = t or os.time()
    if use24 then
        return os.date("%H:%M", t)
    end
    local h = tonumber(os.date("%I", t))
    return h .. ":" .. os.date("%M", t) .. " " .. os.date("%p", t)
end

--- Forecast hour label from an ISO slot: "2026-06-21T14:00" -> "2 PM" / "14".
function DateUtil.hourLabel(iso, use24)
    local hh = tonumber((iso or ""):sub(12, 13)) or 0
    if use24 then
        return tostring(hh)
    end
    local ampm = hh < 12 and "AM" or "PM"
    local h12 = hh % 12
    if h12 == 0 then h12 = 12 end
    return h12 .. " " .. ampm
end

local MONTHS = { "January", "February", "March", "April", "May", "June",
                 "July", "August", "September", "October", "November", "December" }
function DateUtil.monthName(m) return MONTHS[m] end

--- Epoch (noon) for a "YYYY-MM-DD" key. Noon dodges the DST-midnight rollover.
function DateUtil.keyToTs(key)
    local y, mo, d = key:match("(%d+)-(%d+)-(%d+)")
    return os.time{ year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = 12 }
end

--- key +/- n days as a "YYYY-MM-DD" key, rebuilt from the noon anchor.
function DateUtil.addDaysKey(key, n)
    return os.date("%Y-%m-%d", DateUtil.keyToTs(key) + n * DAY)
end

--- Days in month, leap-correct via os.time normalization (day 0 of next month).
function DateUtil.daysInMonth(y, m)
    return tonumber(os.date("%d", os.time{ year = y, month = m + 1, day = 0, hour = 12 }))
end

--- Weekday of a key: 0=Sun .. 6=Sat (matches os.date("%w")).
function DateUtil.weekdayOfKey(key)
    return tonumber(os.date("%w", DateUtil.keyToTs(key)))
end

return DateUtil
