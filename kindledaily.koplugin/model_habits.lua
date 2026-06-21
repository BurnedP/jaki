--[[--
Habit model. A habit is:
  { id, name, created, history = { ["YYYY-MM-DD"] = true, ... } }

Completion is a set of date keys. Streaks and the 7-day grid are derived
from that set, so the stored shape stays tiny and merge-friendly.
--]]

local Store = require("store")
local DateUtil = require("dateutil")

local Habits = {}

local KEY = "habits"
local DAY = 86400

local function all()
    return Store.read(KEY, {})
end

local function save(list)
    Store.write(KEY, list)
end

local function trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

--- Full list of habits.
function Habits.list()
    return all()
end

--- Add a habit. Returns the item, or nil if the name is empty.
function Habits.add(name)
    name = trim(name)
    if name == "" then
        return nil
    end
    local list = all()
    local item = {
        id = Store.nextId(),
        name = name,
        created = os.time(),
        history = {},
    }
    table.insert(list, item)
    save(list)
    return item
end

--- Delete a habit.
function Habits.remove(id)
    local list = all()
    local out = {}
    for _, h in ipairs(list) do
        if h.id ~= id then
            table.insert(out, h)
        end
    end
    save(out)
end

--- Toggle today's completion for a habit.
function Habits.toggleToday(id)
    local key = DateUtil.todayKey()
    local list = all()
    for _, h in ipairs(list) do
        if h.id == id then
            h.history = h.history or {}
            if h.history[key] then
                h.history[key] = nil
            else
                h.history[key] = true
            end
            break
        end
    end
    save(list)
end

--- Is the habit marked done for today?
function Habits.doneToday(h)
    return h.history ~= nil and h.history[DateUtil.todayKey()] == true
end

--- Consecutive-day streak ending today (today counts only if done).
function Habits.streak(h)
    local hist = h.history or {}
    local n = 0
    local ts = os.time()
    while true do
        local key = os.date("%Y-%m-%d", ts)
        if hist[key] then
            n = n + 1
            ts = ts - DAY
        else
            break
        end
    end
    return n
end

--- Last n days as cells (oldest first): { {on=bool, today=bool}, ... }
function Habits.cells(h, n)
    n = n or 7
    local hist = h.history or {}
    local todayKey = DateUtil.todayKey()
    local cells = {}
    for _, d in ipairs(DateUtil.lastNDays(n)) do
        table.insert(cells, {
            on = hist[d.key] == true,
            today = d.key == todayKey,
        })
    end
    return cells
end

return Habits
