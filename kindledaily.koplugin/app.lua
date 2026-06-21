--[[--
App shell for Kindle Daily.

A full-screen InputContainer: a thin status bar on top, a screen body in
the middle, and a 5-tab bottom nav. Tabs swap the body; any data change
rebuilds the tree and asks UIManager for an e-ink refresh. Built to load
cleanly first; visual fidelity to the mockup is an explicit later pass.
--]]

local InputContainer = require("ui/widget/container/inputcontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local VerticalGroup = require("ui/widget/verticalgroup")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local LeftContainer = require("ui/widget/container/leftcontainer")
local RightContainer = require("ui/widget/container/rightcontainer")
local TopContainer = require("ui/widget/container/topcontainer")
local ScrollableContainer = require("scroll_container")  -- 3/4-page swipe scroll
local OverlapGroup = require("ui/widget/overlapgroup")
local Button = require("ui/widget/button")
local InfoMessage = require("ui/widget/infomessage")
local Geom = require("ui/geometry")
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local H = require("ui_helpers")

local Screen = Device.screen

-- All renderable screens (router). NAV controls only the bottom tab bar.
local SCREENS = {
    home     = "screen_home",
    todos    = "screen_todos",
    habits   = "screen_habits",
    weather  = "screen_weather",
    news     = "screen_news",
    settings = "screen_settings",
}

-- Bottom navigation tabs. To-Dos and Habits are reached by tapping their
-- column headers on Home, so they're intentionally not tabs here.
local NAV = {
    { key = "home",     label = "Home" },
    { key = "weather",  label = "Weather" },
    { key = "news",     label = "News" },
    { key = "settings", label = "Settings" },
}

local App = InputContainer:extend{
    screen = "home",
}

function App:init()
    self.covers_fullscreen = true
    self.screen_w = Screen:getWidth()
    self.screen_h = Screen:getHeight()
    self.pad = H.s(16)
    self.scrollbar_w = H.s(6)  -- matches ScrollableContainer.scroll_bar_width
    self.content_w = self.screen_w - 2 * self.pad - 3 * self.scrollbar_w
    self.bar_h = H.s(50)
    self.nav_h = H.s(60)

    if Device:hasKeys() then
        self.key_events = { Close = { { "Back" } } }
    end

    self:_build()

    self._clock_alive = true
    self:_scheduleClock()
end

--- Public: rebuild the whole tree and refresh the screen.
function App:rerender()
    self:_build()
    if self.dimen then
        UIManager:setDirty(self, "ui")
    end
end

--- Refresh once per minute so the status-bar clock stays current.
function App:_scheduleClock()
    local secs = 60 - (os.time() % 60)
    UIManager:scheduleIn(secs, function()
        if not self._clock_alive then return end
        self:rerender()
        self:_scheduleClock()
    end)
end

--- Switch tabs.
function App:go(key)
    self.screen = key
    self:rerender()
end

-- ── Layout ───────────────────────────────────────────────────────────

function App:_timeString()
    local h = tonumber(os.date("%I"))
    return tostring(h) .. ":" .. os.date("%M") .. " " .. os.date("%p")
end

function App:_batteryString()
    local ok, powerd = pcall(function() return Device:getPowerDevice() end)
    if ok and powerd and powerd.getCapacity then
        local cap = powerd:getCapacity()
        if cap then return tostring(cap) .. "%" end
    end
    return ""
end

function App:_statusBar()
    local right_w = H.s(170)
    local left_w = self.content_w - right_w

    -- Left: time. Tap anywhere here to pop KOReader's own menu.
    local left = H.tap(
        LeftContainer:new{
            dimen = Geom:new{ w = left_w, h = self.bar_h },
            H.text(self:_timeString(), H.SIZE.meta, true),
        },
        function() self:showKOMenu() end)

    -- Right: battery + a library icon that drops into the file manager.
    local right_group = HorizontalGroup:new{ align = "center" }
    local batt = self:_batteryString()
    if batt ~= "" then
        table.insert(right_group, H.text(batt, H.SIZE.meta, false, Blitbuffer.COLOR_DARK_GRAY))
        table.insert(right_group, H.hspan(H.s(16)))
    end
    local lib = H.icon(require("assets").icon("library.svg"), H.s(34))
    if lib then
        table.insert(right_group, H.tap(lib, function() self:openFileManager() end))
    end
    local right = RightContainer:new{
        dimen = Geom:new{ w = right_w, h = self.bar_h },
        right_group,
    }

    local bar = HorizontalGroup:new{ align = "center" }
    table.insert(bar, left)
    table.insert(bar, right)

    return FrameContainer:new{
        bordersize = 0,
        padding = 0,
        padding_left = self.pad,
        padding_right = self.pad,
        margin = 0,
        background = Blitbuffer.COLOR_WHITE,
        bar,
    }
end

function App:_navBar()
    local n = #NAV
    local item_w = math.floor(self.screen_w / n)
    local group = HorizontalGroup:new{ align = "center" }
    for _idx, item in ipairs(NAV) do
        local active = (item.key == self.screen)
        table.insert(group, Button:new{
            text = _(item.label),
            width = item_w,
            height = self.nav_h,
            text_font_size = H.SIZE.nav,
            text_font_bold = active,
            bordersize = H.s(1),
            background = active and Blitbuffer.COLOR_GRAY_E or Blitbuffer.COLOR_WHITE,
            margin = 0,
            radius = 0,
            callback = function() self:go(item.key) end,
            show_parent = self,
        })
    end
    return group
end

function App:_body()
    local mod_name = SCREENS[self.screen] or "screen_home"

    local body
    local ok, screen = pcall(require, mod_name)
    if ok and screen and screen.render then
        local render_ok, result = pcall(screen.render, self)
        if render_ok then
            body = result
        else
            body = H.text(_("Error: ") .. tostring(result), H.SIZE.body)
        end
    else
        body = H.text(_("Missing screen: ") .. mod_name, H.SIZE.body)
    end

    local body_h = self.screen_h - self.bar_h - self.nav_h - H.s(2)
    local padded = HorizontalGroup:new{ align = "top" }
    table.insert(padded, H.hspan(self.pad))
    table.insert(padded, body)

    -- Preserve scroll position across rebuilds within the same screen
    -- (toggling an item rebuilds the tree); reset when switching tabs.
    local prev_offset
    if self._scrollable and self._scroll_screen == self.screen then
        prev_offset = self._scrollable:getScrolledOffset()
    end
    if self._scrollable and self._scrollable.reset then
        pcall(function() self._scrollable:reset() end)
    end

    local scrollable = ScrollableContainer:new{
        dimen = Geom:new{ w = self.screen_w, h = body_h },
        show_parent = self,
        padded,
    }
    if prev_offset then
        scrollable:setScrolledOffset(prev_offset)
    end
    self._scrollable = scrollable
    self._scroll_screen = self.screen
    self.cropping_widget = scrollable

    return scrollable
end

function App:_assemble()
    local pok, Prefs = pcall(require, "prefs")
    if pok then H.setSerif(Prefs.get().font == "serif") end
    local main = VerticalGroup:new{ align = "left" }
    table.insert(main, self:_statusBar())
    table.insert(main, H.hline(self.screen_w))
    table.insert(main, self:_body())
    table.insert(main, self:_navBar())

    self[1] = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        margin = 0,
        background = Blitbuffer.COLOR_WHITE,
        main,
    }
end

--- Build the tree, never letting a runtime error hard-crash KOReader:
--- on failure we render the error in-place so it's diagnosable on-device.
function App:_build()
    local ok, err = pcall(function() self:_assemble() end)
    if not ok then
        self[1] = FrameContainer:new{
            bordersize = 0,
            padding = self.pad,
            margin = 0,
            background = Blitbuffer.COLOR_WHITE,
            VerticalGroup:new{
                align = "left",
                H.text("Kindle Daily hit an error:", H.SIZE.body, true),
                H.vspan(H.s(8)),
                H.textCapped(tostring(err), H.SIZE.meta, self.content_w),
            },
        }
    end
end

-- ── Lifecycle ────────────────────────────────────────────────────────

function App:paintTo(bb, x, y)
    InputContainer.paintTo(self, bb, x, y)
    self.dimen = Geom:new{ x = x, y = y, w = self.screen_w, h = self.screen_h }
end

function App:onShow()
    UIManager:setDirty(self, "full")
    return true
end

function App:onClose()
    UIManager:close(self)
    return true
end

--- Close the dashboard and open a book in the reader.
function App:openBook(path)
    UIManager:close(self)
    local ok, err = pcall(function()
        local ReaderUI = require("apps/reader/readerui")
        ReaderUI:showReader(path)
    end)
    if not ok then
        UIManager:show(InfoMessage:new{
            text = _("Couldn't open book.\n") .. tostring(err),
            timeout = 4,
        })
    end
end

--- Pop KOReader's own file-manager menu (wifi, settings, etc.) over the app.
function App:showKOMenu()
    local FM = package.loaded["apps/filemanager/filemanager"]
    if FM and FM.instance and FM.instance.menu and FM.instance.menu.onShowMenu then
        FM.instance.menu:onShowMenu()
    end
    return true
end

--- Close the dashboard, revealing (or opening) the file manager / library.
function App:openFileManager()
    UIManager:close(self)
    local FM = package.loaded["apps/filemanager/filemanager"]
    if not (FM and FM.instance) then
        pcall(function()
            require("apps/filemanager/filemanager"):showFiles()
        end)
    end
    return true
end

--- Clear the shared "open" flag whenever the app is dismissed (any path).
function App:onCloseWidget()
    self._clock_alive = false
    local ok, AppState = pcall(require, "appstate")
    if ok then AppState.open = false end
end

return App
