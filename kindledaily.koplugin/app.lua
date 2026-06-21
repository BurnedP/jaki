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

-- Screen modules: each exposes render(app) -> widget (the body content).
local NAV = {
    { key = "home",     label = "Home",    module = "screen_home" },
    { key = "todos",    label = "To-Dos",  module = "screen_todos" },
    { key = "habits",   label = "Habits",  module = "screen_habits" },
    { key = "weather",  label = "Weather", module = "screen_weather" },
    { key = "settings", label = "Settings", module = "screen_settings" },
}

local App = InputContainer:extend{
    screen = "home",
}

function App:init()
    self.covers_fullscreen = true
    self.screen_w = Screen:getWidth()
    self.screen_h = Screen:getHeight()
    self.pad = H.s(16)
    self.content_w = self.screen_w - 2 * self.pad
    self.bar_h = H.s(50)
    self.nav_h = H.s(60)

    if Device:hasKeys() then
        self.key_events = { Close = { { "Back" } } }
    end

    self:_build()
end

--- Public: rebuild the whole tree and refresh the screen.
function App:rerender()
    self:_build()
    if self.dimen then
        UIManager:setDirty(self, "ui")
    end
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
    local left = LeftContainer:new{
        dimen = Geom:new{ w = self.content_w, h = self.bar_h },
        H.text(self:_timeString(), H.SIZE.meta, true),
    }

    local right_group = HorizontalGroup:new{ align = "center" }
    local batt = self:_batteryString()
    if batt ~= "" then
        table.insert(right_group, H.text(batt, H.SIZE.meta, false, Blitbuffer.COLOR_DARK_GRAY))
        table.insert(right_group, H.hspan(H.s(14)))
    end
    table.insert(right_group, Button:new{
        text = _("Exit"),
        text_font_size = 14,
        bordersize = H.s(1),
        radius = H.s(4),
        padding = H.s(5),
        margin = 0,
        callback = function() self:onClose() end,
        show_parent = self,
    })
    local right = RightContainer:new{
        dimen = Geom:new{ w = self.content_w, h = self.bar_h },
        right_group,
    }

    local overlap = OverlapGroup:new{
        dimen = Geom:new{ w = self.content_w, h = self.bar_h },
        left,
        right,
    }

    return FrameContainer:new{
        bordersize = 0,
        padding = 0,
        padding_left = self.pad,
        padding_right = self.pad,
        margin = 0,
        background = Blitbuffer.COLOR_WHITE,
        overlap,
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
    local mod_name
    for _, item in ipairs(NAV) do
        if item.key == self.screen then mod_name = item.module end
    end
    mod_name = mod_name or "screen_home"

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

    return TopContainer:new{
        dimen = Geom:new{ w = self.screen_w, h = body_h },
        padded,
    }
end

function App:_assemble()
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

return App
