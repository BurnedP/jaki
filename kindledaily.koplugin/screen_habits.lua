--[[--
Habits screen — each habit shows its name, current streak, a 7-day grid,
and a tap-to-complete circle for today. Tap a row to toggle today; hold to
delete. Add via InputDialog.
--]]

local VerticalGroup = require("ui/widget/verticalgroup")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local LeftContainer = require("ui/widget/container/leftcontainer")
local Button = require("ui/widget/button")
local InputDialog = require("ui/widget/inputdialog")
local ConfirmBox = require("ui/widget/confirmbox")
local UIManager = require("ui/uimanager")
local Geom = require("ui/geometry")
local Blitbuffer = require("ffi/blitbuffer")
local _ = require("gettext")

local H = require("ui_helpers")
local Habits = require("model_habits")
local DateUtil = require("dateutil")

local HabitsScreen = {}

local function promptAdd(app)
    local dialog
    dialog = InputDialog:new{
        title = _("New habit"),
        input_hint = _("e.g. Meditate, Read, Stretch"),
        input_type = "text",
        buttons = {
            {
                { text = _("Cancel"), id = "close",
                  callback = function() UIManager:close(dialog) end },
                { text = _("Add"), is_enter_default = true,
                  callback = function()
                      local text = dialog:getInputText()
                      UIManager:close(dialog)
                      if text and text:match("%S") then
                          Habits.add(text)
                          app:rerender()
                      end
                  end },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

local function confirmDelete(app, habit)
    UIManager:show(ConfirmBox:new{
        text = _("Delete this habit?\n\n") .. habit.name,
        ok_text = _("Delete"),
        ok_callback = function()
            Habits.remove(habit.id)
            app:rerender()
        end,
    })
end

local function row(app, habit, w)
    local left = VerticalGroup:new{ align = "left" }
    table.insert(left, H.textCapped(habit.name, H.SIZE.body, w * 0.42, true))
    local streak = Habits.streak(habit)
    table.insert(left, H.text(streak .. " day streak", H.SIZE.meta, false, Blitbuffer.COLOR_DARK_GRAY))
    local left_box = LeftContainer:new{
        dimen = Geom:new{ w = math.floor(w * 0.42), h = H.s(72) },
        left,
    }

    -- 7-day grid with weekday letters
    local grid_col = VerticalGroup:new{ align = "center" }
    local cells = Habits.cells(habit, 7)
    local days = DateUtil.lastNDays(7)
    local labels = HorizontalGroup:new{ align = "center" }
    for _, d in ipairs(days) do
        local lbl = LeftContainer:new{
            dimen = Geom:new{ w = H.s(26), h = H.s(16) },
            H.text(d.dow:sub(1, 1), H.SIZE.meta, false, Blitbuffer.COLOR_GRAY),
        }
        table.insert(labels, lbl)
    end
    local grid = HorizontalGroup:new{ align = "center" }
    for _, cell in ipairs(cells) do
        local g = HorizontalGroup:new{ align = "center" }
        table.insert(g, H.box(H.s(20), cell.on))
        table.insert(g, H.hspan(H.s(6)))
        table.insert(grid, g)
    end
    table.insert(grid_col, labels)
    table.insert(grid_col, H.vspan(H.s(4)))
    table.insert(grid_col, grid)

    local hg = HorizontalGroup:new{ align = "center" }
    table.insert(hg, left_box)
    table.insert(hg, grid_col)
    table.insert(hg, H.hspan(H.s(20)))
    table.insert(hg, H.box(H.s(44), Habits.doneToday(habit)))

    return H.tappable(hg, w, H.s(86),
        function() Habits.toggleToday(habit.id); app:rerender() end,
        function() confirmDelete(app, habit) end)
end

function HabitsScreen.render(app)
    local w = app.content_w
    local habits = Habits.list()
    local col = VerticalGroup:new{ align = "left" }

    table.insert(col, H.vspan(H.s(16)))
    local header = HorizontalGroup:new{ align = "center" }
    table.insert(header, H.text("Habits", H.SIZE.hero, true))
    table.insert(header, H.hspan(H.s(24)))
    table.insert(header, Button:new{
        text = _("+ Add"),
        text_font_size = 16,
        bordersize = H.s(1),
        radius = H.s(6),
        padding = H.s(8),
        margin = 0,
        callback = function() promptAdd(app) end,
        show_parent = app,
    })
    table.insert(col, header)

    if #habits == 0 then
        table.insert(col, H.vspan(H.s(40)))
        table.insert(col, H.text("No habits yet.", H.SIZE.body, true))
        table.insert(col, H.vspan(H.s(8)))
        table.insert(col, H.text("Tap + Add to start tracking one.",
            H.SIZE.meta, false, Blitbuffer.COLOR_DARK_GRAY))
        return col
    end

    table.insert(col, H.vspan(H.s(12)))
    table.insert(col, H.hline(w))
    for _, habit in ipairs(habits) do
        table.insert(col, row(app, habit, w))
        table.insert(col, H.hline(w))
    end
    table.insert(col, H.vspan(H.s(10)))
    table.insert(col, H.text("Tap to mark today · hold to delete",
        H.SIZE.meta, false, Blitbuffer.COLOR_DARK_GRAY))

    return col
end

return HabitsScreen
