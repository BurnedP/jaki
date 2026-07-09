--[[--
News screen — a scrollable list of headlines from the configured feed.
Tap a headline to read its summary; Refresh pulls the latest. Cached so
the last headlines show offline.
--]]

local VerticalGroup = require("ui/widget/verticalgroup")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local LeftContainer = require("ui/widget/container/leftcontainer")
local Geom = require("ui/geometry")
local Button = require("ui/widget/button")
local TextViewer = require("ui/widget/textviewer")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local Font = require("ui/font")
local Blitbuffer = require("ffi/blitbuffer")
local _ = require("gettext")

local H = require("ui_helpers")
local Prefs = require("prefs")
local DateUtil = require("dateutil")

local NewsScreen = {}

local function doRefresh(app)
    local ok, service = pcall(require, "news_service")
    if not ok or not service then
        UIManager:show(InfoMessage:new{ text = _("News unavailable."), timeout = 2 })
        return
    end
    UIManager:show(InfoMessage:new{ text = _("Fetching news…"), timeout = 1 })
    UIManager:scheduleIn(0.1, function()
        local items, err = service.refresh()
        if not items then
            UIManager:show(InfoMessage:new{
                text = _("Couldn't fetch news.\n") .. tostring(err or ""),
                timeout = 3,
            })
        end
        app:rerender()
    end)
end

local function showArticle(item)
    local text = item.title or ""
    if item.desc and item.desc ~= "" then
        text = text .. "\n\n" .. item.desc
    end
    UIManager:show(TextViewer:new{
        title = _("Article"),
        text = text,
        text_face = Font:getFace("cfont", 20),
    })
end

function NewsScreen.render(app)
    local w = app.content_w
    local prefs = Prefs.get()
    local col = VerticalGroup:new{ align = "left" }

    table.insert(col, H.vspan(H.s(16)))
    local header = HorizontalGroup:new{ align = "center" }
    table.insert(header, H.text("News", H.SIZE.hero, true))
    table.insert(header, H.hspan(H.s(24)))
    table.insert(header, Button:new{
        text = _("Refresh"),
        text_font_size = 16,
        bordersize = H.s(1), radius = H.s(6), padding = H.s(8), margin = 0,
        callback = function() doRefresh(app) end,
        show_parent = app,
    })
    table.insert(col, header)

    local cache = prefs.news_cache
    if not (cache and cache.items and #cache.items > 0) then
        table.insert(col, H.vspan(H.s(30)))
        table.insert(col, H.text("No headlines yet.", H.SIZE.body, true))
        table.insert(col, H.vspan(H.s(8)))
        table.insert(col, H.text("Tap Refresh to load the latest.",
            H.SIZE.meta, false, Blitbuffer.COLOR_DARK_GRAY))
        return col
    end

    table.insert(col, H.vspan(H.s(6)))
    if cache.fetched_at then
        table.insert(col, H.text("Updated " .. DateUtil.formatTime(cache.fetched_at, prefs.clock24),
            H.SIZE.meta, false, Blitbuffer.COLOR_GRAY))
    end
    table.insert(col, H.vspan(H.s(8)))
    table.insert(col, H.hline(w))
    local tagW = H.s(96)
    local gap = H.s(14)
    local textW = w - tagW - gap
    for _, item in ipairs(cache.items) do
        local it = item
        local tagText = (item.tag and item.tag ~= "") and item.tag:upper() or "NEWS"
        local rowG = HorizontalGroup:new{ align = "top" }
        table.insert(rowG, H.wrap(tagText, tagW, 2, H.SIZE.meta, false, Blitbuffer.COLOR_GRAY))
        table.insert(rowG, H.hspan(gap))
        table.insert(rowG, H.wrap(item.title, textW, 3, H.SIZE.body))
        table.insert(col, H.vspan(H.s(12)))
        table.insert(col, H.tap(rowG, function() showArticle(it) end))
        table.insert(col, H.vspan(H.s(12)))
        table.insert(col, H.hline(w))
    end
    return col
end

return NewsScreen
