--[[--
Home screen — the glanceable hero.

  • Date + greeting
  • Weather section: icon, big temp, condition, H/L on the left, and the
    last-read book to the right (tap it to open). Hourly strip below.
  • To-Dos and Habits side by side in two columns (when both enabled)

Honors the home-module toggles in prefs. The app shell makes the body
scrollable, so columns can grow past the screen.
--]]

local VerticalGroup = require("ui/widget/verticalgroup")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local LeftContainer = require("ui/widget/container/leftcontainer")
local RightContainer = require("ui/widget/container/rightcontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Geom = require("ui/geometry")
local Blitbuffer = require("ffi/blitbuffer")

local H = require("ui_helpers")
local DateUtil = require("dateutil")
local Todos = require("model_todos")
local Habits = require("model_habits")
local Prefs = require("prefs")
local WeatherIcons = require("weather_icons")

local Home = {}

local MAX_ITEMS = 5
local GRAY = Blitbuffer.COLOR_DARK_GRAY

local function hourLabel(iso)
    local hh = tonumber((iso or ""):sub(12, 13)) or 0
    local ampm = hh < 12 and "AM" or "PM"
    local h12 = hh % 12
    if h12 == 0 then h12 = 12 end
    return h12 .. " " .. ampm
end

-- ── Last-read book ───────────────────────────────────────────────────

--- Cheap cover lookup: a cached cover blitbuffer or nil (never extracts).
local function coverFor(path)
    local ok, BIM = pcall(require, "bookinfomanager")
    if not ok or not BIM then return nil end
    local got, info = pcall(function() return BIM:getBookInfo(path, true) end)
    if got and info and info.cover_bb then return info.cover_bb end
    return nil
end

--- Tappable widget for the most recently read book, or nil if none.
local function lastBook(app, maxW)
    local ok, ReadHistory = pcall(require, "readhistory")
    if not ok or not ReadHistory or not ReadHistory.hist then return nil end
    local e
    for _, h in ipairs(ReadHistory.hist) do
        if h.file and h.text and not h.dim then e = h break end
    end
    if not e then return nil end

    local Assets = require("assets")
    local cluster = HorizontalGroup:new{ align = "center" }
    local cover = coverFor(e.file)
    local art = cover and H.image(cover, H.s(60), H.s(84))
        or H.icon(Assets.icon("book.svg"), H.s(44))
    if art then
        table.insert(cluster, art)
        table.insert(cluster, H.hspan(H.s(12)))
    end
    local title = (e.text or "Book"):gsub("%.%w+$", "")
    table.insert(cluster, H.wrap(title, maxW - H.s(76), 3, H.SIZE.meta))

    local path = e.file
    return H.tap(cluster, function() app:openBook(path) end)
end

-- ── Weather ──────────────────────────────────────────────────────────

local function weatherSection(app, w, prefs)
    local wc = prefs.weather_cache
    local p = wc and wc.payload

    if not (p and p.temp) then
        local msg = (prefs.location == "")
            and "Add your location in Settings"
            or ("Tap to load weather for " .. prefs.location)
        return H.tappable(H.text(msg, H.SIZE.body, false, GRAY),
            w, H.s(56), function() app:go("weather") end)
    end

    local rowH = H.s(100)
    local book = lastBook(app, math.floor(w * 0.42))
    local leftW = book and math.floor(w * 0.56) or w
    local rightW = w - leftW

    -- Weather cluster (left): icon + temp + condition + H/L
    local leftHG = HorizontalGroup:new{ align = "center" }
    local ic = WeatherIcons.widget(p.code, H.s(80))
    if ic then
        table.insert(leftHG, ic)
        table.insert(leftHG, H.hspan(H.s(14)))
    end
    local tempCol = VerticalGroup:new{ align = "left" }
    table.insert(tempCol, H.text(p.temp .. "°", H.SIZE.hero + 24, true))
    table.insert(tempCol, H.text(p.condition or "", H.SIZE.body, false, GRAY))
    if p.high and p.low then
        table.insert(tempCol, H.text("H " .. p.high .. "°   L " .. p.low .. "°",
            H.SIZE.meta, false, GRAY))
    end
    table.insert(leftHG, tempCol)

    local topRow = HorizontalGroup:new{ align = "center" }
    table.insert(topRow, H.tap(
        LeftContainer:new{ dimen = Geom:new{ w = leftW, h = rowH }, leftHG },
        function() app:go("weather") end))
    if book then
        table.insert(topRow, RightContainer:new{
            dimen = Geom:new{ w = rightW, h = rowH }, book })
    end

    local block = VerticalGroup:new{ align = "left" }
    table.insert(block, topRow)

    -- Hourly strip
    if p.hourly and #p.hourly > 0 then
        local n = math.min(#p.hourly, 6)
        local cw = math.floor(w / n)
        local strip = HorizontalGroup:new{ align = "top" }
        for i = 1, n do
            local hh = p.hourly[i]
            local cell = VerticalGroup:new{ align = "center" }
            table.insert(cell, H.text(hourLabel(hh.time), H.SIZE.meta, false, GRAY))
            local hic = WeatherIcons.widget(hh.code, H.s(32))
            if hic then
                table.insert(cell, H.vspan(H.s(4)))
                table.insert(cell, hic)
            end
            table.insert(cell, H.vspan(H.s(4)))
            table.insert(cell, H.text((hh.temp or "?") .. "°", H.SIZE.body, true))
            table.insert(strip, CenterContainer:new{
                dimen = Geom:new{ w = cw, h = H.s(100) }, cell })
        end
        table.insert(block, H.vspan(H.s(8)))
        table.insert(block, H.tap(strip, function() app:go("weather") end))
    end

    return block
end

-- ── Columns ──────────────────────────────────────────────────────────

local function todoColumn(app, colW)
    local g = Todos.grouped()
    local col = VerticalGroup:new{ align = "left" }
    table.insert(col, H.sectionHeader("To-Dos"))
    table.insert(col, H.vspan(H.s(8)))
    table.insert(col, H.hline(colW))
    if #g.today == 0 then
        table.insert(col, H.vspan(H.s(10)))
        table.insert(col, H.text("All clear", H.SIZE.meta, false, GRAY))
        return col
    end
    for i = 1, math.min(MAX_ITEMS, #g.today) do
        local todo = g.today[i]
        local row = HorizontalGroup:new{ align = "top" }
        table.insert(row, H.box(H.s(24), todo.done))
        table.insert(row, H.hspan(H.s(12)))
        table.insert(row, H.wrap(todo.text, colW - H.s(42), 2, H.SIZE.body))
        table.insert(col, H.vspan(H.s(12)))
        table.insert(col, H.tap(row, function() Todos.toggle(todo.id); app:rerender() end))
    end
    return col
end

local function habitColumn(app, colW)
    local habits = Habits.list()
    local col = VerticalGroup:new{ align = "left" }
    table.insert(col, H.sectionHeader("Habits"))
    table.insert(col, H.vspan(H.s(8)))
    table.insert(col, H.hline(colW))
    if #habits == 0 then
        table.insert(col, H.vspan(H.s(10)))
        table.insert(col, H.text("None yet", H.SIZE.meta, false, GRAY))
        return col
    end
    for i = 1, math.min(MAX_ITEMS, #habits) do
        local habit = habits[i]
        local done = Habits.doneToday(habit)
        local nameBlock = VerticalGroup:new{ align = "left" }
        table.insert(nameBlock, H.strikeText(habit.name, H.SIZE.body, colW, false, done,
            done and GRAY or nil))
        table.insert(nameBlock, H.text(Habits.streak(habit) .. "d streak",
            H.SIZE.meta, false, GRAY))
        table.insert(col, H.vspan(H.s(12)))
        table.insert(col, H.tap(
            LeftContainer:new{ dimen = Geom:new{ w = colW, h = H.s(56) }, nameBlock },
            function() Habits.toggleToday(habit.id); app:rerender() end))
    end
    return col
end

local function columns(app, w, prefs)
    local showT, showH = prefs.modules.todos, prefs.modules.habits
    if showT and showH then
        local gutter = H.s(28)
        local colW = math.floor((w - gutter) / 2)
        local band = HorizontalGroup:new{ align = "top" }
        table.insert(band, todoColumn(app, colW))
        table.insert(band, H.hspan(gutter))
        table.insert(band, habitColumn(app, colW))
        return band
    elseif showT then
        return todoColumn(app, w)
    elseif showH then
        return habitColumn(app, w)
    end
    return nil
end

-- ── Compose ──────────────────────────────────────────────────────────

function Home.render(app)
    local w = app.content_w
    local prefs = Prefs.get()
    local col = VerticalGroup:new{ align = "left" }

    table.insert(col, H.vspan(H.s(16)))
    table.insert(col, H.text(DateUtil.headerDate(), H.SIZE.section, false, GRAY))
    table.insert(col, H.vspan(H.s(4)))
    local greeting = DateUtil.greeting()
    if prefs.user_name and prefs.user_name ~= "" then
        greeting = greeting .. ", " .. prefs.user_name
    end
    table.insert(col, H.text(greeting, H.SIZE.hero, true))

    if prefs.modules.weather then
        table.insert(col, H.vspan(H.s(18)))
        table.insert(col, weatherSection(app, w, prefs))
    end

    local cols = columns(app, w, prefs)
    if cols then
        table.insert(col, H.vspan(H.s(22)))
        table.insert(col, cols)
    end

    return col
end

return Home
