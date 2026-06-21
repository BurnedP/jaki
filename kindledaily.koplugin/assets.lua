--[[--
Resolves the plugin's own directory at runtime so bundled assets (icons)
load by absolute path without hardcoding /mnt/us. Falls back to the known
install path if the runtime source path can't be determined.
--]]

local Assets = {}

local src = debug.getinfo(1, "S").source or ""
local dir = src:gsub("^@", ""):gsub("[^/]+$", "")
if dir == nil or dir == "" then
    dir = "plugins/kindledaily.koplugin/"
end
-- Anchor a relative source path to KOReader's data dir so absolute paths
-- reach the icons regardless of the process working directory.
if dir:sub(1, 1) ~= "/" then
    local ok, DataStorage = pcall(require, "datastorage")
    if ok and DataStorage and DataStorage.getDataDir then
        dir = DataStorage:getDataDir() .. "/" .. dir
    else
        dir = "/mnt/us/koreader/" .. dir
    end
end
Assets.dir = dir

--- Absolute path to a file inside the plugin dir.
function Assets.path(rel)
    return Assets.dir .. rel
end

--- Absolute path to a bundled icon.
function Assets.icon(name)
    return Assets.dir .. "icons/" .. name
end

--- True if a file exists and is readable.
function Assets.exists(p)
    local f = io.open(p, "r")
    if f then
        f:close()
        return true
    end
    return false
end

return Assets
