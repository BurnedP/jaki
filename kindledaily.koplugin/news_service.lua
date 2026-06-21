--[[--
News service — fetches an RSS or Atom feed over HTTPS and extracts
headlines. Crude tag matching (no XML lib), but robust enough for common
feeds. Results cache in prefs so the last headlines show offline.
--]]

local ltn12 = require("ltn12")
local socketutil = require("socketutil")
local logger = require("logger")

local Prefs = require("prefs")

local NewsService = {}

local DEFAULT_FEED = "https://feeds.bbci.co.uk/news/world/rss.xml"
local MAX_ITEMS = 25

local function stripTags(s)
    if not s then return "" end
    s = s:gsub("<!%[CDATA%[(.-)%]%]>", "%1")
    s = s:gsub("<[^>]->", "")
    s = s:gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">")
    s = s:gsub("&quot;", '"'):gsub("&#39;", "'"):gsub("&#x27;", "'"):gsub("&nbsp;", " ")
    s = s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

local function getRaw(url)
    local https = require("ssl.https")
    local body = {}
    socketutil:set_timeout(10, 30)
    local res, code = https.request{
        url = url,
        method = "GET",
        sink = ltn12.sink.table(body),
    }
    socketutil:reset_timeout()
    if not res or code ~= 200 then
        logger.warn("KindleDaily news: request failed", url, code)
        return nil, "Network error (" .. tostring(code) .. ")"
    end
    return table.concat(body)
end

function NewsService.feedUrl()
    local u = Prefs.get().news_feed
    if not u or u == "" then return DEFAULT_FEED end
    return u
end

--- Fetch and cache headlines. Returns the items list, or (nil, message).
function NewsService.refresh()
    local xml, err = getRaw(NewsService.feedUrl())
    if not xml then return nil, err end

    local items = {}

    -- RSS <item>
    for block in xml:gmatch("<item[%s>](.-)</item>") do
        local title = block:match("<title.->(.-)</title>")
        if title then
            table.insert(items, {
                title = stripTags(title),
                link = block:match("<link.->(.-)</link>"),
                desc = stripTags(block:match("<description.->(.-)</description>")),
            })
        end
        if #items >= MAX_ITEMS then break end
    end

    -- Atom <entry> fallback
    if #items == 0 then
        for block in xml:gmatch("<entry[%s>](.-)</entry>") do
            local title = block:match("<title.->(.-)</title>")
            if title then
                table.insert(items, {
                    title = stripTags(title),
                    link = block:match('<link.-href="(.-)"'),
                    desc = stripTags(block:match("<summary.->(.-)</summary>")
                        or block:match("<content.->(.-)</content>")),
                })
            end
            if #items >= MAX_ITEMS then break end
        end
    end

    if #items == 0 then return nil, "No headlines found" end

    Prefs.update(function(p)
        p.news_cache = { fetched_at = os.time(), items = items }
    end)
    return items
end

return NewsService
