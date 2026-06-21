--[[--
To-Dos screen — Today / Later / Done sections, tap a row to toggle done,
hold a row to delete, and an Add button (KOReader InputDialog for v1).
--]]

local VerticalGroup = require("ui/widget/verticalgroup")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local Button = require("ui/widget/button")
local InputDialog = require("ui/widget/inputdialog")
local ConfirmBox = require("ui/widget/confirmbox")
local UIManager = require("ui/uimanager")
local Blitbuffer = require("ffi/blitbuffer")
local _ = require("gettext")

local H = require("ui_helpers")
local Todos = require("model_todos")

local TodosScreen = {}

local function promptAdd(app)
    local dialog
    dialog = InputDialog:new{
        title = _("New to-do"),
        input_hint = _("What needs doing?"),
        input_type = "text",
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function() UIManager:close(dialog) end,
                },
                {
                    text = _("Add"),
                    is_enter_default = true,
                    callback = function()
                        local text = dialog:getInputText()
                        UIManager:close(dialog)
                        if text and text:match("%S") then
                            Todos.add(text, "today")
                            app:rerender()
                        end
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

local function confirmDelete(app, todo)
    UIManager:show(ConfirmBox:new{
        text = _("Delete this to-do?\n\n") .. todo.text,
        ok_text = _("Delete"),
        ok_callback = function()
            Todos.remove(todo.id)
            app:rerender()
        end,
    })
end

local function row(app, todo, w)
    local hg = HorizontalGroup:new{ align = "center" }
    table.insert(hg, H.box(H.s(26), todo.done))
    table.insert(hg, H.hspan(H.s(16)))
    table.insert(hg, H.textCapped(todo.text, H.SIZE.body, w - H.s(60)))
    return H.tappable(hg, w, H.s(64),
        function() Todos.toggle(todo.id); app:rerender() end,
        function() confirmDelete(app, todo) end)
end

local function section(app, col, label, items, w)
    if #items == 0 then return end
    table.insert(col, H.vspan(H.s(18)))
    table.insert(col, H.sectionHeader(label .. "  (" .. #items .. ")"))
    table.insert(col, H.vspan(H.s(8)))
    table.insert(col, H.hline(w))
    for _, todo in ipairs(items) do
        table.insert(col, row(app, todo, w))
        table.insert(col, H.hline(w))
    end
end

function TodosScreen.render(app)
    local w = app.content_w
    local g = Todos.grouped()
    local col = VerticalGroup:new{ align = "left" }

    table.insert(col, H.vspan(H.s(16)))
    local header = HorizontalGroup:new{ align = "center" }
    table.insert(header, H.text("To-Dos", H.SIZE.hero, true))
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

    if #g.today == 0 and #g.later == 0 and #g.done == 0 then
        table.insert(col, H.vspan(H.s(40)))
        table.insert(col, H.text("No to-dos yet.", H.SIZE.body, true))
        table.insert(col, H.vspan(H.s(8)))
        table.insert(col, H.text("Tap + Add to capture the first one.",
            H.SIZE.meta, false, Blitbuffer.COLOR_DARK_GRAY))
        return col
    end

    section(app, col, "Today", g.today, w)
    section(app, col, "Later", g.later, w)
    section(app, col, "Done", g.done, w)

    table.insert(col, H.vspan(H.s(10)))
    table.insert(col, H.text("Tap to toggle · hold to delete",
        H.SIZE.meta, false, Blitbuffer.COLOR_DARK_GRAY))

    return col
end

return TodosScreen
