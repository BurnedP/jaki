--[[--
TapRow — a reusable tappable wrapper around any visual widget.

KOReader resolves a gesture's screen region at match time via a function
range (see ui/gesturerange.lua), so we point the tap range at a closure
returning self.dimen, and set self.dimen during paintTo. This is the
idiom Button itself uses; it makes any composite row reliably tappable.
--]]

local InputContainer = require("ui/widget/container/inputcontainer")
local GestureRange = require("ui/gesturerange")
local Geom = require("ui/geometry")

local TapRow = InputContainer:extend{
    on_tap = nil,   -- function called on tap
    on_hold = nil,  -- optional function called on hold
}

function TapRow:init()
    self.ges_events = {
        Tap = {
            GestureRange:new{
                ges = "tap",
                range = function() return self.dimen end,
            },
        },
    }
    if self.on_hold then
        self.ges_events.Hold = {
            GestureRange:new{
                ges = "hold",
                range = function() return self.dimen end,
            },
        }
    end
end

function TapRow:paintTo(bb, x, y)
    local size = self[1]:getSize()
    self.dimen = Geom:new{ x = x, y = y, w = size.w, h = size.h }
    self[1]:paintTo(bb, x, y)
end

function TapRow:onTap()
    if self.on_tap then
        self.on_tap()
        return true
    end
end

function TapRow:onHold()
    if self.on_hold then
        self.on_hold()
        return true
    end
end

return TapRow
