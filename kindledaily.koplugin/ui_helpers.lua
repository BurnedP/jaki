--[[--
Shared UI primitives for Kindle Daily. Keeps the screens declarative:
fonts, a filled/empty box (checkboxes + habit cells), section headers,
divider lines, spacers, fixed-size rows, and the TapRow wrapper.

Sizes are logical (scaled by Screen:scaleBySize) so they hold up across
densities. Values are tuned by eye on-device; treat them as a starting
point, not gospel.
--]]

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalSpan = require("ui/widget/horizontalspan")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local TextWidget = require("ui/widget/textwidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local ImageWidget = require("ui/widget/imagewidget")
local VerticalSpan = require("ui/widget/verticalspan")
local Widget = require("ui/widget/widget")
local TapRow = require("taprow")

local Screen = Device.screen

local H = {}

--- Scale a logical px value to the device.
function H.s(n)
    return Screen:scaleBySize(n)
end

--- Logical font sizes (pre-scaling; Font scales internally).
H.SIZE = {
    hero = 30,
    title = 24,
    section = 17,
    body = 20,
    meta = 15,
    nav = 15,
}

--- Font face. bold=true uses the title face, else the content face.
function H.face(size, bold)
    return Font:getFace(bold and "tfont" or "cfont", size)
end

--- A sz×sz square: filled (black) or empty (white with black border).
function H.box(sz, filled)
    local blank = Widget:new{ dimen = Geom:new{ w = sz, h = sz } }
    return FrameContainer:new{
        bordersize = H.s(2),
        background = filled and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_WHITE,
        color = Blitbuffer.COLOR_BLACK,
        margin = 0,
        padding = 0,
        blank,
    }
end

--- Plain text widget.
function H.text(str, size, bold, color)
    return TextWidget:new{
        text = str or "",
        face = H.face(size or H.SIZE.body, bold),
        fgcolor = color or Blitbuffer.COLOR_BLACK,
    }
end

--- Truncating text widget capped to max_width.
function H.textCapped(str, size, max_width, bold, color)
    return TextWidget:new{
        text = str or "",
        face = H.face(size or H.SIZE.body, bold),
        max_width = max_width,
        fgcolor = color or Blitbuffer.COLOR_BLACK,
    }
end

--- Uppercase section header.
function H.sectionHeader(label)
    return TextWidget:new{
        text = (label or ""):upper(),
        face = H.face(H.SIZE.section, true),
        fgcolor = Blitbuffer.COLOR_BLACK,
    }
end

--- Horizontal divider of the given width.
function H.hline(w)
    return LineWidget:new{
        dimen = Geom:new{ w = w, h = H.s(2) },
        background = Blitbuffer.COLOR_GRAY,
    }
end

--- Vertical spacer.
function H.vspan(h)
    return VerticalSpan:new{ width = h }
end

--- Horizontal spacer.
function H.hspan(w)
    return HorizontalSpan:new{ width = w }
end

--- Text wrapped to `width`, capped at `maxlines` (default 2) with ellipsis.
function H.wrap(str, width, maxlines, size, bold, color)
    local sz = size or H.SIZE.body
    local face = H.face(sz, bold)
    local lh = 0.3
    local line_px = math.floor((1 + lh) * (face.size or sz) + 0.5)
    return TextBoxWidget:new{
        text = str or "",
        face = face,
        width = width,
        height = (maxlines or 2) * line_px,
        line_height = lh,
        alignment = "left",
        fgcolor = color or Blitbuffer.COLOR_BLACK,
        height_overflow_show_ellipsis = true,
    }
end

--- Square icon image from an absolute file path, or nil if missing.
function H.icon(file, size)
    if not file then return nil end
    local f = io.open(file, "r")
    if not f then return nil end
    f:close()
    return ImageWidget:new{
        file = file,
        width = size,
        height = size,
        alpha = false,    -- flatten transparency onto white at cache time
        is_icon = true,   -- critical: renders SVG as black-on-white, not a black box
    }
end

--- ImageWidget for an existing blitbuffer (e.g. a book cover), scaled to
--- fit within w×h keeping aspect ratio. Returns nil if bb is nil.
function H.image(bb, w, h)
    if not bb then return nil end
    return ImageWidget:new{
        image = bb,
        width = w,
        height = h,
        scale_factor = 0,  -- fit proportionally
    }
end

--- Wrap content in a fixed w×h box, left-aligned (defines a full-width row).
function H.fixedRow(content, w, h)
    return LeftContainer:new{
        dimen = Geom:new{ w = w, h = h },
        content,
    }
end

--- Make a fixed-size row tappable.
function H.tappable(content, w, h, on_tap, on_hold)
    return TapRow:new{
        H.fixedRow(content, w, h),
        on_tap = on_tap,
        on_hold = on_hold,
    }
end

--- Make any widget tappable at its natural size (no fixed dimensions).
function H.tap(content, on_tap, on_hold)
    return TapRow:new{
        content,
        on_tap = on_tap,
        on_hold = on_hold,
    }
end

H.Blitbuffer = Blitbuffer

return H
