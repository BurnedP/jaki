--[[--
To-do model. A to-do is:
  { id, text, done, bucket = "today"|"later", created, done_at }

Storage is a flat list. Done items linger (crossed out) until the 4am
rollover, then they're purged so the next day starts clean.
--]]

local Store = require("store")
local DateUtil = require("dateutil")

local Todos = {}

local KEY = "todos"

local function all()
    return Store.read(KEY, {})
end

local function save(list)
    Store.write(KEY, list)
end

local function trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

--- Full flat list.
function Todos.list()
    return all()
end

--- Add a to-do. bucket defaults to "today". Returns the item, or nil if empty.
function Todos.add(text, bucket)
    text = trim(text)
    if text == "" then
        return nil
    end
    local list = all()
    local item = {
        id = Store.nextId(),
        text = text,
        done = false,
        bucket = bucket or "today",
        created = os.time(),
    }
    table.insert(list, item)
    save(list)
    return item
end

--- Flip done/undone.
function Todos.toggle(id)
    local list = all()
    for _, t in ipairs(list) do
        if t.id == id then
            t.done = not t.done
            t.done_at = t.done and os.time() or nil
            break
        end
    end
    save(list)
end

--- Delete a to-do.
function Todos.remove(id)
    local list = all()
    local out = {}
    for _, t in ipairs(list) do
        if t.id ~= id then
            table.insert(out, t)
        end
    end
    save(out)
end

--- Remove done to-dos completed before the most recent 4am boundary.
function Todos.purgeOldDone()
    local cutoff = DateUtil.dayStart4am()
    local list = all()
    local out, changed = {}, false
    for _, t in ipairs(list) do
        if t.done and (t.done_at or 0) < cutoff then
            changed = true
        else
            table.insert(out, t)
        end
    end
    if changed then
        save(out)
    end
end

--- Active items, then today's done items (purges stale done first).
--- @treturn table active  not-done to-dos, in insertion order
--- @treturn table done    done-today to-dos, in insertion order
function Todos.today()
    Todos.purgeOldDone()
    local active, done = {}, {}
    for _, t in ipairs(all()) do
        if t.done then
            table.insert(done, t)
        else
            table.insert(active, t)
        end
    end
    return active, done
end

--- Count of not-done items.
function Todos.activeCount()
    local n = 0
    for _, t in ipairs(all()) do
        if not t.done then
            n = n + 1
        end
    end
    return n
end

return Todos
