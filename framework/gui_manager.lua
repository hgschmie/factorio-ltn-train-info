---@meta
------------------------------------------------------------------------
-- Manage GUIs and GUI state -- loosely inspired by flib
------------------------------------------------------------------------

-- only works in runtime mode
if not script then return end

local Event = require('__stdlib__/stdlib/event/event')
local Is = require('__stdlib__/stdlib/utils/is')

local FrameworkGui = require('framework.gui')

---@class FrameworkGuiManager
---@field GUI_PREFIX string The prefix for all registered handlers and other global information.
local FrameworkGuiManager = {
    GUI_PREFIX = Framework.PREFIX .. 'gui-',
}

------------------------------------------------------------------------
--
------------------------------------------------------------------------

---@return FrameworkGuiManagerState state Manages GUI state
function FrameworkGuiManager:state()
    local storage = Framework.runtime:storage()

    if not storage.gui_manager then
        ---@type FrameworkGuiManagerState
        storage.gui_manager = {
            count = 0,
            guis = {},
        }
    end

    return storage.gui_manager
end

------------------------------------------------------------------------

--- Creates a new id for the guis.
---@return number A unique gui id.
function FrameworkGuiManager:create_id()
    local state = self:state()

    state.count = state.count + 1
    return state.count
end

------------------------------------------------------------------------

--- Dispatch an event to a registered gui.
---@param ev FrameworkGuiEventData
---@return boolean handled True if an event handler was called, False otherwise.
function FrameworkGuiManager:dispatch(ev)
    if not ev then return false end

    ---@type LuaGuiElement
    local elem = ev.element
    if not Is.Valid(elem) then return false end

    -- see if this has the right tags
    local tags = elem.tags --[[@as Tags]]
    local gui_id = tags[self.GUI_PREFIX .. 'id']

    local state = self:state()

    if not (gui_id and state.guis[gui_id]) then return false end

    -- dispatch to the UI instance
    return state.guis[gui_id]:dispatch(ev)
end

------------------------------------------------------------------------

--- Finds a gui.
---@param gui_id number?
---@return FrameworkGui? framework_gui
function FrameworkGuiManager:find_gui(gui_id)
    if not gui_id then return nil end
    local state = self:state()

    return state.guis[gui_id]
end

------------------------------------------------------------------------

--- Creates a new GUI instance.
---@param parent LuaGuiElement
---@param ui_tree FrameworkGuiElemDef|FrameworkGuiElemDef[] The element definition, or an array of element definitions.
---@param existing_elements table<string, LuaGuiElement>? Optional set of existing GUI elements.
---@return FrameworkGui framework_gui A framework gui instance
function FrameworkGuiManager:create_gui(parent, ui_tree, existing_elements)
    assert(Is.Table(ui_tree) and #ui_tree == 0, 'The UI tree must have a single root!')
    local gui_id = self:create_id()
    local gui = FrameworkGui.create(gui_id, self.GUI_PREFIX)
    local state = self:state()

    state.guis[gui_id] = gui

    local root = gui:add_child_elements(parent, ui_tree, existing_elements)
    gui.root = root

    return gui
end

------------------------------------------------------------------------

--- Destroys a GUI instance.
---@param gui (FrameworkGui|number)? The gui to destroy
function FrameworkGuiManager:destroy_gui(gui)
    if Is.Number(gui) then
        gui = self:find_gui(gui --[[@as number?]])
    end

    if not gui then return end

    local state = self:state()

    local gui_id = gui.id
    state.guis[gui_id] = nil
    if gui.root then gui.root.destroy() end
end

------------------------------------------------------------------------

-- register all gui events with the framework
for name, id in pairs(defines.events) do
    if name:sub(1, 7) == 'on_gui_' then
        Event.on_event(id, function(ev)
            Framework.gui_manager:dispatch(ev)
        end)
    end
end

------------------------------------------------------------------------

return FrameworkGuiManager
