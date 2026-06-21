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

return DateUtil
