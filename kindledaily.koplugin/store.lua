--[[--
Persistent local store for Kindle Daily.

Thin wrapper over KOReader's LuaSettings — a single file under the
settings dir holds all app data (todos, habits, prefs) as namespaced
keys. Everything is on-device; nothing here touches the network.
--]]

local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")

local Store = {}

local _instance

local function db()
    if not _instance then
        local path = DataStorage:getSettingsDir() .. "/kindledaily.lua"
        _instance = LuaSettings:open(path)
    end
    return _instance
end

--- Read a top-level key, returning `default` when unset.
function Store.read(key, default)
    local v = db():readSetting(key)
    if v == nil then
        return default
    end
    return v
end

--- Write a top-level key and flush to disk immediately.
function Store.write(key, value)
    local s = db()
    s:saveSetting(key, value)
    s:flush()
end

--- Monotonic id generator, persisted across restarts.
function Store.nextId()
    local s = db()
    local id = (s:readSetting("next_id") or 0) + 1
    s:saveSetting("next_id", id)
    s:flush()
    return id
end

return Store
