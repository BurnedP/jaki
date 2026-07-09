--[[--
Local (on-device) calendar events over store.lua, mirroring model_todos.
All-day, string-date shape ("YYYY-MM-DD"). Never touches the network.
--]]

local Store = require("store")
local Events = {}
local KEY = "events"

local function all()  return Store.read(KEY, {}) end
local function save(l) Store.write(KEY, l) end
local function trim(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end

function Events.list() return all() end

function Events.add(date, title)
    title = trim(title)
    if title == "" then return nil end
    if not (date and date:match("^%d%d%d%d%-%d%d%-%d%d$")) then return nil end
    local list = all()
    local item = { id = Store.nextId(), date = date, title = title,
                   source = "local", created = os.time() }
    table.insert(list, item)
    save(list)
    return item
end

function Events.remove(id)
    local out = {}
    for _, e in ipairs(all()) do if e.id ~= id then table.insert(out, e) end end
    save(out)
end

function Events.onDate(date)
    local out = {}
    for _, e in ipairs(all()) do if e.date == date then table.insert(out, e) end end
    return out
end

return Events
