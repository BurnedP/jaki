--[[--
A ScrollableContainer whose swipe scrolls by a fraction of the view rather
than a full page, leaving a strip of overlap so you keep visual continuity
between swipes. Keyboard PgUp/PgDown stay full-page.
--]]

local ScrollableContainer = require("ui/widget/container/scrollablecontainer")

local PagedScroll = ScrollableContainer:extend{
    scroll_fraction = 0.75,
}

function PagedScroll:onScrollableSwipe(_, ges)
    if not self._is_scrollable then
        return false
    end
    if not ges.pos:intersectWith(self.dimen) then
        return false
    end
    self._scrolling = false  -- a "pan" may have set this before the swipe
    local dy = math.floor(self._crop_h * self.scroll_fraction)
    local dx = math.floor(self._crop_w * self.scroll_fraction)
    local d = ges.direction
    if d == "north" then self:_scrollBy(0, dy, true)
    elseif d == "south" then self:_scrollBy(0, -dy, true)
    elseif d == "east" then self:_scrollBy(-dx, 0, true)
    elseif d == "west" then self:_scrollBy(dx, 0, true)
    elseif d == "northeast" then self:_scrollBy(-dx, dy, true)
    elseif d == "northwest" then self:_scrollBy(dx, dy, true)
    elseif d == "southeast" then self:_scrollBy(-dx, -dy, true)
    elseif d == "southwest" then self:_scrollBy(dx, -dy, true)
    end
    return true
end

return PagedScroll
