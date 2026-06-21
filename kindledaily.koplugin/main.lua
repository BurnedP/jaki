--[[--
Kindle Daily — KOReader plugin entry point.

Registers the dashboard in the menu, registers a gesture-bindable action
to open it, auto-starts it once at launch, and brings it back when a book
is closed. The app shell is required lazily so a UI load error surfaces as
a readable message instead of breaking the plugin.
--]]

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local Dispatcher = require("dispatcher")
local logger = require("logger")
local _ = require("gettext")

local AppState = require("appstate")

-- Module-level guards: persist for the KOReader session across the separate
-- plugin instances created for the file manager and for the reader.
local _registered = false
local _did_autostart = false

local KindleDaily = WidgetContainer:extend{
    name = "kindledaily",
    is_doc_only = false,  -- active in both file manager and reader contexts
}

function KindleDaily:init()
    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
    self:_registerGesture()
    self:_maybeAutostart()
end

function KindleDaily:addToMainMenu(menu_items)
    menu_items.kindle_daily = {
        text = _("Kindle Daily"),
        sorting_hint = "more_tools",
        callback = function() self:open() end,
    }
end

--- Register a gesture-bindable action ("Open Kindle Daily"), once per session.
function KindleDaily:_registerGesture()
    if _registered then return end
    _registered = true
    pcall(function()
        Dispatcher:registerAction("kindledaily_open", {
            category = "none",
            event = "KindleDailyOpen",
            title = _("Open Kindle Daily"),
            general = true,
        })
    end)
end

--- Gesture handler (matches event = "KindleDailyOpen").
function KindleDaily:onKindleDailyOpen()
    self:open()
    return true
end

--- Show the dashboard once shortly after launch (file-manager startup).
function KindleDaily:_maybeAutostart()
    if _did_autostart then return end
    _did_autostart = true
    local ok, Prefs = pcall(require, "prefs")
    if not (ok and Prefs and Prefs.get().autostart) then return end
    UIManager:scheduleIn(0.3, function() self:open() end)
end

--- When any book closes, bring the dashboard back over the file manager.
function KindleDaily:onCloseDocument()
    local ok, Prefs = pcall(require, "prefs")
    if not (ok and Prefs and Prefs.get().autoreturn) then return end
    UIManager:scheduleIn(0.2, function() self:open() end)
end

--- Launch the dashboard (no-op if it's already showing).
function KindleDaily:open()
    if AppState.open then return end

    local ok, App = pcall(require, "app")
    if not ok then
        logger.err("KindleDaily: failed to load app:", App)
        UIManager:show(InfoMessage:new{
            text = _("Kindle Daily failed to load.\n\n") .. tostring(App),
            timeout = 6,
        })
        return
    end

    local instance_ok, err = pcall(function()
        local app = App:new{}
        UIManager:show(app)
    end)
    if instance_ok then
        AppState.open = true
    else
        logger.err("KindleDaily: failed to start app:", err)
        UIManager:show(InfoMessage:new{
            text = _("Kindle Daily crashed on launch.\n\n") .. tostring(err),
            timeout = 6,
        })
    end
end

return KindleDaily
