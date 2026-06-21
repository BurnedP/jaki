--[[--
Kindle Daily — KOReader plugin.

A local-first daily dashboard: to-dos, habits, and weather.
This entry point registers the plugin in KOReader's menu and launches
the full-screen app. The app shell is required lazily (inside the launch
callback) so that a load error in any UI module never prevents the
plugin itself from loading — it surfaces as a readable message instead.
--]]

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local logger = require("logger")
local _ = require("gettext")

local KindleDaily = WidgetContainer:extend{
    name = "kindledaily",
    is_doc_only = false,  -- available from the file manager, not just in-book
}

function KindleDaily:init()
    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
end

function KindleDaily:addToMainMenu(menu_items)
    menu_items.kindle_daily = {
        text = _("Kindle Daily"),
        sorting_hint = "more_tools",
        callback = function()
            self:open()
        end,
    }
end

--- Launch the dashboard.
function KindleDaily:open()
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
    if not instance_ok then
        logger.err("KindleDaily: failed to start app:", err)
        UIManager:show(InfoMessage:new{
            text = _("Kindle Daily crashed on launch.\n\n") .. tostring(err),
            timeout = 6,
        })
    end
end

return KindleDaily
