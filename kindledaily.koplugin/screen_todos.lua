--[[--
To-Dos screen — tap to cross out; done items sink to the bottom and clear
at the 4am rollover so the day's wins stay visible. Hold a row to delete.
Add via InputDialog.
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
local Todos = require("model_todos")

local TodosScreen = {}
local GRAY = Blitbuffer.COLOR_DARK_GRAY

local function promptAdd(app)
    local dialog
    dialog = InputDialog:new{
        title = _("New to-do"),
        input_hint = _("What needs doing?"),
        input_type = "text",
        buttons = {{
            { text = _("Cancel"), id = "close",
              callback = function() UIManager:close(dialog) end },
            { text = _("Add"), is_enter_default = true, callback = function()
                local text = dialog:getInputText()
                UIManager:close(dialog)
                if text and text:match("%S") then
                    Todos.add(text, "today")
                    app:rerender()
                end
            end },
        }},
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

local function confirmDelete(app, todo)
    UIManager:show(ConfirmBox:new{
        text = _("Delete this to-do?\n\n") .. todo.text,
        ok_text = _("Delete"),
        ok_callback = function() Todos.remove(todo.id); app:rerender() end,
    })
end

local function activeRow(app, todo, w)
    return H.tap(H.wrap(todo.text, w, 2, H.SIZE.body),
        function() Todos.toggle(todo.id); app:rerender() end,
        function() confirmDelete(app, todo) end)
end

local function doneRow(app, todo, w)
    return H.tap(
        LeftContainer:new{ dimen = Geom:new{ w = w, h = H.s(40) },
            H.strikeText(todo.text, H.SIZE.body, w, false, true, GRAY) },
        function() Todos.toggle(todo.id); app:rerender() end,
        function() confirmDelete(app, todo) end)
end

function TodosScreen.render(app)
    local w = app.content_w
    local active, done = Todos.today()
    local col = VerticalGroup:new{ align = "left" }

    table.insert(col, H.vspan(H.s(16)))
    local header = HorizontalGroup:new{ align = "center" }
    table.insert(header, H.text("To-Dos", H.SIZE.hero, true))
    table.insert(header, H.hspan(H.s(24)))
    table.insert(header, Button:new{
        text = _("+ Add"),
        text_font_size = 16, bordersize = H.s(1), radius = H.s(6),
        padding = H.s(8), margin = 0,
        callback = function() promptAdd(app) end, show_parent = app,
    })
    table.insert(col, header)

    if #active == 0 and #done == 0 then
        table.insert(col, H.vspan(H.s(40)))
        table.insert(col, H.text("Nothing to do.", H.SIZE.body, true))
        table.insert(col, H.vspan(H.s(8)))
        table.insert(col, H.text("Tap + Add to capture the first one.",
            H.SIZE.meta, false, GRAY))
        return col
    end

    table.insert(col, H.vspan(H.s(12)))
    table.insert(col, H.hline(w))
    for _, todo in ipairs(active) do
        table.insert(col, H.vspan(H.s(14)))
        table.insert(col, activeRow(app, todo, w))
        table.insert(col, H.vspan(H.s(4)))
        table.insert(col, H.hline(w))
    end

    if #done > 0 then
        table.insert(col, H.vspan(H.s(18)))
        table.insert(col, H.text("DONE TODAY", H.SIZE.section, true, GRAY))
        table.insert(col, H.vspan(H.s(6)))
        table.insert(col, H.hline(w))
        for _, todo in ipairs(done) do
            table.insert(col, H.vspan(H.s(12)))
            table.insert(col, doneRow(app, todo, w))
            table.insert(col, H.vspan(H.s(8)))
            table.insert(col, H.hline(w))
        end
    end

    table.insert(col, H.vspan(H.s(10)))
    table.insert(col, H.text("Tap to cross out · hold to delete",
        H.SIZE.meta, false, GRAY))
    return col
end

return TodosScreen
