--[[--
Settings screen — toggle which modules show on Home, set location and
name, switch units (F/C), and exit the app. All persisted via prefs.lua.
--]]

local VerticalGroup = require("ui/widget/verticalgroup")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local LeftContainer = require("ui/widget/container/leftcontainer")
local RightContainer = require("ui/widget/container/rightcontainer")
local OverlapGroup = require("ui/widget/overlapgroup")
local InputDialog = require("ui/widget/inputdialog")
local UIManager = require("ui/uimanager")
local Geom = require("ui/geometry")
local Blitbuffer = require("ffi/blitbuffer")
local _ = require("gettext")

local H = require("ui_helpers")
local Prefs = require("prefs")

local SettingsScreen = {}

local function toggleRow(app, w, label, value, on_tap)
    local left = LeftContainer:new{
        dimen = Geom:new{ w = w, h = H.s(56) },
        H.text(label, H.SIZE.body),
    }
    local right = RightContainer:new{
        dimen = Geom:new{ w = w, h = H.s(56) },
        H.text(value, H.SIZE.body, true),
    }
    local overlap = OverlapGroup:new{
        dimen = Geom:new{ w = w, h = H.s(56) },
        left, right,
    }
    return H.tappable(overlap, w, H.s(56), on_tap)
end

local function promptText(app, title, current, save_fn)
    local dialog
    dialog = InputDialog:new{
        title = title,
        input = current or "",
        input_type = "text",
        buttons = {
            {
                { text = _("Cancel"), id = "close",
                  callback = function() UIManager:close(dialog) end },
                { text = _("Save"), is_enter_default = true,
                  callback = function()
                      local text = dialog:getInputText()
                      UIManager:close(dialog)
                      save_fn(text or "")
                      app:rerender()
                  end },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function SettingsScreen.render(app)
    local w = app.content_w
    local prefs = Prefs.get()
    local col = VerticalGroup:new{ align = "left" }

    table.insert(col, H.vspan(H.s(16)))
    table.insert(col, H.text("Settings", H.SIZE.hero, true))

    -- Home modules
    table.insert(col, H.vspan(H.s(20)))
    table.insert(col, H.sectionHeader("Home Modules"))
    table.insert(col, H.hline(w))
    local mods = { { "weather", "Weather" }, { "todos", "To-Dos" },
                   { "habits", "Habits" } }
    for _, m in ipairs(mods) do
        local key, label = m[1], m[2]
        table.insert(col, toggleRow(app, w, label,
            prefs.modules[key] and "On" or "Off",
            function() Prefs.toggleModule(key); app:rerender() end))
        table.insert(col, H.hline(w))
    end

    -- Personal
    table.insert(col, H.vspan(H.s(20)))
    table.insert(col, H.sectionHeader("Personal"))
    table.insert(col, H.hline(w))
    table.insert(col, toggleRow(app, w, "Your name",
        prefs.user_name ~= "" and prefs.user_name or "Set",
        function()
            promptText(app, _("Your name"), prefs.user_name,
                function(t) Prefs.update(function(p) p.user_name = t end) end)
        end))
    table.insert(col, H.hline(w))
    table.insert(col, toggleRow(app, w, "Location",
        prefs.location ~= "" and prefs.location or "Set",
        function()
            promptText(app, _("Location (city or postal code)"), prefs.location,
                function(t) Prefs.update(function(p) p.location = t end) end)
        end))
    table.insert(col, H.hline(w))
    table.insert(col, toggleRow(app, w, "Units",
        prefs.units == "C" and "Celsius" or "Fahrenheit",
        function()
            Prefs.update(function(p)
                p.units = (p.units == "C") and "F" or "C"
                p.weather_cache = nil  -- force a refetch in the new unit
            end)
            app:rerender()
        end))
    table.insert(col, H.hline(w))

    table.insert(col, toggleRow(app, w, "Font",
        prefs.font == "serif" and "Serif" or "Sans",
        function()
            Prefs.update(function(p) p.font = (p.font == "serif") and "sans" or "serif" end)
            app:rerender()
        end))
    table.insert(col, H.hline(w))
    table.insert(col, toggleRow(app, w, "News feed",
        (prefs.news_feed ~= "" and "Custom" or "Default"),
        function()
            promptText(app, _("News feed URL (RSS/Atom)"), prefs.news_feed,
                function(t) Prefs.update(function(p) p.news_feed = t end) end)
        end))
    table.insert(col, H.hline(w))

    -- Behavior
    table.insert(col, H.vspan(H.s(20)))
    table.insert(col, H.sectionHeader("Behavior"))
    table.insert(col, H.hline(w))
    table.insert(col, toggleRow(app, w, "Start on launch",
        prefs.autostart and "On" or "Off",
        function()
            Prefs.update(function(p) p.autostart = not p.autostart end)
            app:rerender()
        end))
    table.insert(col, H.hline(w))
    table.insert(col, toggleRow(app, w, "Return after closing a book",
        prefs.autoreturn and "On" or "Off",
        function()
            Prefs.update(function(p) p.autoreturn = not p.autoreturn end)
            app:rerender()
        end))
    table.insert(col, H.hline(w))

    -- Exit to the file manager / library
    table.insert(col, H.vspan(H.s(28)))
    table.insert(col, H.tappable(
        H.text("Exit to file manager", H.SIZE.body, true),
        w, H.s(56), function() app:openFileManager() end))

    return col
end

return SettingsScreen
