------------------------------------------------------------------------
-- LTN Train Info GUI
------------------------------------------------------------------------
assert(script)

local Event = require('stdlib.event.event')
local Player = require('stdlib.event.player')
local table = require('stdlib.utils.table')
local string = require('stdlib.utils.string')

local Matchers = require('framework.matchers')
local tools = require('framework.tools')

local signal_converter = require('framework.signal_converter')

local const = require('lib.constants')

---@class lti.Gui
---@field NAME string
local Gui = {
    NAME = 'combinator-gui',
}

----------------------------------------------------------------------------------------------------
-- UI definition
----------------------------------------------------------------------------------------------------

--- Provides all the events used by the GUI and their mappings to functions. This must be outside the
--- GUI definition as it can not be serialized into storage.
---@return framework.gui_manager.event_definition
local function get_gui_event_definition()
    return {
        events = {
            onWindowClosed = Gui.onWindowClosed,
            onSwitchEnabled = Gui.onSwitchEnabled,
            onToggleSignalEnabled = Gui.onToggleSignalEnabled,
            onRadioButtonQuantity = Gui.onRadioButtonQuantity,
            onRadioButtonStackSize = Gui.onRadioButtonStackSize,
            onRadioButtonOne = Gui.onRadioButtonOne,
            onToggleNegate = Gui.onToggleNegate,
            onToggleVirtual = Gui.onToggleVirtual,
            onDivideBySlider = Gui.onDivideBySlider,
            onDivideByText = Gui.onDivideByText,
        },
        callback = Gui.guiUpdater,
    }
end

--- Returns the definition of the GUI. All events must be mapped onto constants from the gui_events array.
---@param gui framework.gui
---@return framework.gui.element_definition ui
function Gui.getUi(gui)
    local gui_events = gui.gui_events

    local lti_data = This.Lti:getLtiData(gui.entity_id)
    assert(lti_data)

    return {
        type = 'frame',
        name = 'gui_root',
        direction = 'vertical',
        handler = { [defines.events.on_gui_closed] = gui_events.onWindowClosed },
        elem_mods = { auto_center = true },
        children = {
            { -- Title Bar
                type = 'flow',
                style = 'frame_header_flow',
                drag_target = 'gui_root',
                children = {
                    {
                        type = 'label',
                        style = 'frame_title',
                        caption = { 'entity-name.' .. const.lti_name },
                        drag_target = 'gui_root',
                        ignored_by_interaction = true,
                    },
                    {
                        type = 'empty-widget',
                        style = 'framework_titlebar_drag_handle',
                        ignored_by_interaction = true,
                    },
                    {
                        type = 'sprite-button',
                        style = 'frame_action_button',
                        sprite = 'utility/close',
                        hovered_sprite = 'utility/close_black',
                        clicked_sprite = 'utility/close_black',
                        mouse_button_filter = { 'left' },
                        handler = { [defines.events.on_gui_click] = gui_events.onWindowClosed },
                    },
                },
            }, -- Title Bar End
            {  -- Body
                type = 'frame',
                style = 'entity_frame',
                style_mods = { width = 424, }, -- fix width of the window to match the signal bottom
                children = {
                    {
                        type = 'flow',
                        style = 'two_module_spacing_vertical_flow',
                        direction = 'vertical',
                        children = {
                            {
                                type = 'frame',
                                direction = 'horizontal',
                                style = 'framework_subheader_frame',
                                children = {
                                    {
                                        type = 'label',
                                        style = 'subheader_label',
                                        name = 'connections',
                                    },
                                    {
                                        type = 'label',
                                        style = 'label',
                                        name = 'connection-red',
                                        visible = false,
                                    },
                                    {
                                        type = 'label',
                                        style = 'label',
                                        name = 'connection-green',
                                        visible = false,
                                    },
                                    {
                                        type = 'empty-widget',
                                        style_mods = { horizontally_stretchable = true },
                                    },
                                },
                            },
                            {
                                type = 'flow',
                                style = 'framework_indicator_flow',
                                children = {
                                    {
                                        type = 'sprite',
                                        name = 'status-lamp',
                                        style = 'framework_indicator',
                                    },
                                    {
                                        type = 'label',
                                        style = 'label',
                                        name = 'status-label',
                                    },
                                    {
                                        type = 'empty-widget',
                                        style_mods = { horizontally_stretchable = true },
                                    },
                                    {
                                        type = 'label',
                                        style = 'label',
                                        caption = { const:locale('id'), lti_data.main.unit_number, },
                                    },
                                },
                            },
                            {
                                type = 'frame',
                                style = 'deep_frame_in_shallow_frame',
                                name = 'preview_frame',
                                children = {
                                    {
                                        type = 'entity-preview',
                                        name = 'preview',
                                        style = 'wide_entity_button',
                                        elem_mods = { entity = lti_data.main },
                                    },
                                },
                            },
                            { -- connection to train stop(s)
                                type = 'flow',
                                style = 'framework_indicator_flow',
                                name = 'connection-frame',
                                children = {
                                    {
                                        type = 'label',
                                        style = 'semibold_label',
                                        name = 'connection-label',
                                        caption = { const:locale('train-stop-connection'), },
                                    },
                                    {
                                        type = 'label',
                                        style = 'label',
                                        name = 'connection',
                                    },
                                    {
                                        type = 'empty-widget',
                                        style_mods = { horizontally_stretchable = true },
                                    },
                                },
                            },
                            {
                                type = 'line',
                            },
                            {
                                type = 'label',
                                style = 'semibold_label',
                                caption = { 'gui-constant.output' },
                            },
                            {
                                type = 'switch',
                                name = 'on-off',
                                right_label_caption = { 'gui-constant.on' },
                                left_label_caption = { 'gui-constant.off' },
                                handler = { [defines.events.on_gui_switch_state_changed] = gui_events.onSwitchEnabled },
                            },
                            {
                                type = 'label',
                                style = 'semibold_label',
                                style_mods = {
                                    top_padding = 8,                   -- pad a bit to create visual space between the on-off switch and the label
                                },
                                caption = { const:locale('provide') }, -- tables can't have captions
                            },
                            {                                          -- provide settings
                                type = 'table',
                                column_count = 3,
                                style_mods = {
                                    top_margin = -8,         -- pull the table a bit closer to the label above
                                    horizontal_spacing = 24, -- space the elements in the table out
                                },
                                children = {
                                    {
                                        type = 'checkbox',
                                        caption = { '', { const:locale('enabled') }, ' [img=info]' },
                                        tooltip = { const:locale('enabled-description') },
                                        name = 'delivery-provide',
                                        elem_tags = { config = const.delivery_type.provide },
                                        handler = { [defines.events.on_gui_checked_state_changed] = gui_events.onToggleSignalEnabled },
                                        state = false,
                                    },
                                    {
                                        type = 'flow',
                                        direction = 'vertical',
                                        children = {
                                            {
                                                type = 'radiobutton',
                                                caption = { '', { const:locale('signal-type-quantity') }, ' [img=info]' },
                                                tooltip = { const:locale('signal-type-quantity-description') },
                                                name = 'signal-type-quantity-provide',
                                                elem_tags = { config = const.delivery_type.provide },
                                                handler = { [defines.events.on_gui_checked_state_changed] = gui_events.onRadioButtonQuantity },
                                                state = false,
                                            },
                                            {
                                                type = 'radiobutton',
                                                caption = { '', { const:locale('signal-type-stacksize') }, ' [img=info]' },
                                                tooltip = { const:locale('signal-type-stacksize-description') },
                                                name = 'signal-type-stacksize-provide',
                                                elem_tags = { config = const.delivery_type.provide },
                                                handler = { [defines.events.on_gui_checked_state_changed] = gui_events.onRadioButtonStackSize },
                                                state = false,
                                            },
                                            {
                                                type = 'radiobutton',
                                                caption = { const:locale('signal-type-one') },
                                                name = 'signal-type-one-provide',
                                                elem_tags = { config = const.delivery_type.provide },
                                                handler = { [defines.events.on_gui_checked_state_changed] = gui_events.onRadioButtonOne },
                                                state = false,
                                            },
                                        }
                                    },
                                    {
                                        type = 'checkbox',
                                        caption = { '', { const:locale('negate') }, ' [img=info]' },
                                        tooltip = { const:locale('negate-description') },
                                        name = 'negate-provide',
                                        elem_tags = { config = const.delivery_type.provide },
                                        handler = { [defines.events.on_gui_checked_state_changed] = gui_events.onToggleNegate },
                                        state = false,
                                    },
                                },
                            },
                            {
                                type = 'label',
                                style = 'semibold_label',
                                caption = { const:locale('request') },
                            },
                            { -- request settings
                                type = 'table',
                                column_count = 3,
                                style_mods = {
                                    top_margin = -8,         -- pull the table a bit closer to the label above
                                    horizontal_spacing = 24, -- space the elements in the table out
                                },
                                children = {
                                    {
                                        type = 'checkbox',
                                        caption = { '', { const:locale('enabled') }, ' [img=info]' },
                                        tooltip = { const:locale('enabled-description') },
                                        name = 'delivery-request',
                                        elem_tags = { config = const.delivery_type.request },
                                        handler = { [defines.events.on_gui_checked_state_changed] = gui_events.onToggleSignalEnabled },
                                        state = false,
                                    },
                                    {
                                        type = 'flow',
                                        direction = 'vertical',
                                        children = {
                                            {
                                                type = 'radiobutton',
                                                caption = { '', { const:locale('signal-type-quantity') }, ' [img=info]' },
                                                tooltip = { const:locale('signal-type-quantity-description') },
                                                name = 'signal-type-quantity-request',
                                                elem_tags = { config = const.delivery_type.request },
                                                handler = { [defines.events.on_gui_checked_state_changed] = gui_events.onRadioButtonQuantity },
                                                state = false,
                                            },
                                            {
                                                type = 'radiobutton',
                                                caption = { '', { const:locale('signal-type-stacksize') }, ' [img=info]' },
                                                tooltip = { const:locale('signal-type-stacksize-description') },
                                                name = 'signal-type-stacksize-request',
                                                elem_tags = { config = const.delivery_type.request },
                                                handler = { [defines.events.on_gui_checked_state_changed] = gui_events.onRadioButtonStackSize },
                                                state = false,
                                            },
                                            {
                                                type = 'radiobutton',
                                                caption = { const:locale('signal-type-one') },
                                                name = 'signal-type-one-request',
                                                elem_tags = { config = const.delivery_type.request },
                                                handler = { [defines.events.on_gui_checked_state_changed] = gui_events.onRadioButtonOne },
                                                state = false,
                                            },
                                        },
                                    },
                                    {
                                        type = 'checkbox',
                                        caption = { '', { const:locale('negate') }, ' [img=info]' },
                                        tooltip = { const:locale('negate-description') },
                                        name = 'negate-request',
                                        elem_tags = { config = const.delivery_type.request },
                                        handler = { [defines.events.on_gui_checked_state_changed] = gui_events.onToggleNegate },
                                        state = false,
                                    },
                                },
                            },
                            {
                                type = 'label',
                                style = 'semibold_label',
                                caption = { const:locale('settings') },
                            },
                            { -- add virtual signals
                                type = 'checkbox',
                                caption = { '', { const:locale('virtual') }, ' [img=info]' },
                                tooltip = { const:locale('virtual-description') },
                                name = 'virtual',
                                handler = { [defines.events.on_gui_checked_state_changed] = gui_events.onToggleVirtual },
                                state = false,
                            },
                            { -- divider
                                type = 'flow',
                                direction = 'horizontal',
                                style_mods = {
                                    horizontal_spacing = 16,   -- space the label, slider and text box out a bit
                                    vertical_align = 'center', -- align all subelements
                                },
                                children = {
                                    {
                                        type = 'label',
                                        style = 'label',
                                        caption = { '', { const:locale('divide') }, ' [img=info]' },
                                        tooltip = { const:locale('divide-description') },
                                    },
                                    {
                                        type = 'slider',
                                        name = 'divide_by_slider',
                                        style = 'slider',
                                        style_mods = {
                                            maximal_width = 100, -- limit slider width to match look of the UI
                                        },
                                        minimum_value = const.divide_by_min,
                                        maximum_value = const.divide_by_max,
                                        handler = { [defines.events.on_gui_value_changed] = gui_events.onDivideBySlider, }
                                    },
                                    {
                                        type = 'textfield',
                                        name = 'divide_by_text',
                                        style = 'slider_value_textfield',
                                        style_mods = {
                                            maximal_width = 40, -- match the very_short_number_textfield
                                        },
                                        numeric = true,
                                        allow_negative = false,
                                        allow_decimal = true,
                                        lose_focus_on_confirm = true,
                                        clear_and_focus_on_right_click = true,
                                        handler = { [defines.events.on_gui_confirmed] = gui_events.onDivideByText, },
                                    },
                                    {
                                        type = 'empty-widget',
                                        style_mods = { horizontally_stretchable = true },
                                    },
                                },
                            },
                            {
                                type = 'label',
                                style = 'semibold_label',
                                caption = { const:locale('signals-heading') },
                            },
                            {
                                type = 'scroll-pane',
                                style = 'deep_slots_scroll_pane',
                                direction = 'vertical',
                                name = 'signal-view-pane',
                                vertical_scroll_policy = 'auto-and-reserve-space',
                                horizontal_scroll_policy = 'never',
                                style_mods = {
                                    width = 400,
                                },
                                children = {
                                    {
                                        type = 'table',
                                        style = 'filter_slot_table',
                                        name = 'signal-view',
                                        column_count = 10,
                                        style_mods = {
                                            vertical_spacing = 4,
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    }
end

----------------------------------------------------------------------------------------------------
-- UI Callbacks
----------------------------------------------------------------------------------------------------

--- close the UI (button or shortcut key)
---
---@param event EventData.on_gui_click|EventData.on_gui_opened
function Gui.onWindowClosed(event)
    Framework.gui_manager:destroy_gui(event.player_index)
end

local on_off_values = {
    left = false,
    right = true,
}

local values_on_off = table.invert(on_off_values)

--- Enable / Disable switch
---
---@param event EventData.on_gui_switch_state_changed
---@param gui framework.gui
function Gui.onSwitchEnabled(event, gui)
    local lti_data = This.Lti:getLtiData(gui.entity_id)
    if not lti_data then return end

    lti_data.config.enabled = on_off_values[event.element.switch_state]
end

---@param event  EventData.on_gui_checked_state_changed
---@param gui framework.gui
function Gui.onToggleSignalEnabled(event, gui)
    local lti_data = This.Lti:getLtiData(gui.entity_id)
    if not lti_data then return end

    local config = lti_data.config[event.element.tags['config']]
    assert(config)

    config.enabled = event.element.state
end

---@param event  EventData.on_gui_checked_state_changed
---@param gui framework.gui
function Gui.onRadioButtonQuantity(event, gui)
    local lti_data = This.Lti:getLtiData(gui.entity_id)
    if not lti_data then return end

    local config = lti_data.config[event.element.tags['config']]
    assert(config)

    config.signal_type = const.signal_type.quantity
end

---@param event  EventData.on_gui_checked_state_changed
---@param gui framework.gui
function Gui.onRadioButtonStackSize(event, gui)
    local lti_data = This.Lti:getLtiData(gui.entity_id)
    if not lti_data then return end

    local config = lti_data.config[event.element.tags['config']]
    assert(config)

    config.signal_type = const.signal_type.stack_size
end

---@param event  EventData.on_gui_checked_state_changed
---@param gui framework.gui
function Gui.onRadioButtonOne(event, gui)
    local lti_data = This.Lti:getLtiData(gui.entity_id)
    if not lti_data then return end

    local config = lti_data.config[event.element.tags['config']]
    assert(config)

    config.signal_type = const.signal_type.one
end

---@param event  EventData.on_gui_checked_state_changed
---@param gui framework.gui
function Gui.onToggleNegate(event, gui)
    local lti_data = This.Lti:getLtiData(gui.entity_id)
    if not lti_data then return end

    local config = lti_data.config[event.element.tags['config']]
    assert(config)

    config.negate = event.element.state
end

---@param event  EventData.on_gui_checked_state_changed
---@param gui framework.gui
function Gui.onToggleVirtual(event, gui)
    local lti_data = This.Lti:getLtiData(gui.entity_id)
    if not lti_data then return end

    lti_data.config.virtual = event.element.state
end

---@param event  EventData.on_gui_value_changed
---@param gui framework.gui
function Gui.onDivideBySlider(event, gui)
    local lti_data = This.Lti:getLtiData(gui.entity_id)
    if not lti_data then return end

    local value = event.element.slider_value

    value = math.min(const.divide_by_max, math.max(const.divide_by_min, value))

    lti_data.config.divide_by = value
end

---@param event  EventData.on_gui_text_changed
---@param gui framework.gui
function Gui.onDivideByText(event, gui)
    local lti_data = This.Lti:getLtiData(gui.entity_id)
    if not lti_data then return end

    local value = tonumber(event.element.text) or 1

    value = math.min(const.divide_by_max, math.max(const.divide_by_min, value))

    lti_data.config.divide_by = value
end

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------

---@param gui_element LuaGuiElement?
---@param lti_data lti.Data?
local function render_output_signals(gui_element, lti_data)
    if not lti_data then return end

    assert(gui_element)
    gui_element.clear()

    local output = lti_data.main.get_control_behavior() --[[@as LuaConstantCombinatorControlBehavior ]]
    assert(output)

    assert(output.sections_count == 1)
    local section = output.sections[1]
    assert(section.type == defines.logistic_section_type.manual)

    local filters = section.filters

    if not (filters) then return end

    for _, filter in pairs(filters) do
        if filter.value.name then
            local button = gui_element.add {
                type = 'sprite-button',
                style = 'compact_slot',
                number = filter.min,
                quality = filter.value.quality,
                sprite = signal_converter:logistic_filter_to_sprite_name(filter),
                tooltip = signal_converter:logistic_filter_to_prototype(filter).localised_name,
                elem_tooltip = signal_converter:logistic_filter_to_elem_id(filter),
                enabled = true,
            }
        end
    end
end

---@param gui framework.gui
---@param type string
---@param cfg lti.DeliveryConfig
local function update_gui_delivery(gui, type, cfg)
    local delivery = gui:find_element('delivery-' .. type)
    delivery.state = cfg.enabled

    local quantity = gui:find_element('signal-type-quantity-' .. type)
    quantity.state = cfg.signal_type == const.signal_type.quantity
    quantity.enabled = cfg.enabled

    local stacksize = gui:find_element('signal-type-stacksize-' .. type)
    stacksize.state = cfg.signal_type == const.signal_type.stack_size
    stacksize.enabled = cfg.enabled

    local one = gui:find_element('signal-type-one-' .. type)
    one.state = cfg.signal_type == const.signal_type.one
    one.enabled = cfg.enabled

    local negate = gui:find_element('negate-' .. type)
    negate.state = cfg.negate
    negate.enabled = cfg.enabled
end


----------------------------------------------------------------------------------------------------
-- GUI state updater
----------------------------------------------------------------------------------------------------

---@param gui framework.gui
---@param lti_data lti.Data
local function update_gui(gui, lti_data)
    local config = lti_data.config

    local enabled = lti_data.config.enabled
    local on_off = gui:find_element('on-off')
    on_off.switch_state = values_on_off[enabled]

    -- deal with provide and request
    update_gui_delivery(gui, 'provide', config.provide)
    update_gui_delivery(gui, 'request', config.request)

    local virtual = gui:find_element('virtual')
    virtual.state = config.virtual

    local divide_enabled = config.provide.enabled or config.request.enabled

    local divide_by_slider = gui:find_element('divide_by_slider')
    divide_by_slider.slider_value = config.divide_by
    divide_by_slider.enabled = divide_enabled

    local divide_by_text = gui:find_element('divide_by_text')
    divide_by_text.text = tostring(config.divide_by)
    divide_by_text.enabled = divide_enabled
end

---@param gui framework.gui
---@param lti_data lti.Data
---@return table<defines.wire_connector_id, boolean> connection_state
local function refresh_gui(gui, lti_data)
    local lti_config = lti_data.config

    ---@type defines.entity_status?
    local entity_status

    -- status LED
    if lti_config.enabled then
        if lti_data.main.status ~= defines.entity_status.working then
            entity_status = lti_data.main.status or defines.entity_status.broken
        elseif table_size(lti_data.connected_stops) > 0 then
            entity_status = defines.entity_status.working
        end
    else
        entity_status = defines.entity_status.disabled
    end

    local lamp = gui:find_element('status-lamp')
    lamp.sprite = tools.STATUS_SPRITES[entity_status] or tools.STATUS_LEDS.RED

    local status = gui:find_element('status-label')
    status.caption = entity_status and { tools.STATUS_NAMES[entity_status] } or { const:locale('not-connected') }

    -- train stop connections
    local connection_caption = table_size(lti_data.connected_stops) > 0 and string.join(', ', table.keys(lti_data.connected_stops, true)) or { 'gui-control-behavior.not-connected' }
    local connection = gui:find_element('connection')
    connection.caption = connection_caption

    -- render output signals
    local output_signals = gui:find_element('signal-view')
    render_output_signals(output_signals, lti_data)

    -- wire connections
    local connections = gui:find_element('connections')
    connections.caption = { 'gui-control-behavior.not-connected' }

    local connection_state = {}
    for _, color in pairs { 'red', 'green' } do
        local connector_id = defines.wire_connector_id['circuit_' .. color]
        local wire_connector = lti_data.main.get_wire_connector(connector_id, false)

        local wire_connection = gui:find_element('connection-' .. color)
        if wire_connector and wire_connector.connection_count > 0 then
            connection_state[connector_id] = true
            connections.caption = { 'gui-control-behavior.connected-to-network' }
            wire_connection.visible = true
            wire_connection.caption = { 'gui-control-behavior.' .. color .. '-network-id', wire_connector.network_id }
        else
            wire_connection.visible = false
            wire_connection.caption = nil
        end
    end

    return connection_state
end

----------------------------------------------------------------------------------------------------
-- open gui handler
----------------------------------------------------------------------------------------------------

---@param event EventData.on_gui_opened
function Gui.onGuiOpened(event)
    local player = Player.get(event.player_index)
    if not player then return end

    -- close an eventually open gui
    Framework.gui_manager:destroy_gui(event.player_index)

    local entity = event and event.entity --[[@as LuaEntity]]
    if not entity then
        player.opened = nil
        return
    end

    assert(entity.unit_number)
    local lti_data = This.Lti:getLtiData(entity.unit_number)

    if not lti_data then
        Framework.logger:logf('Data missing for %s on %s at %s, refusing to display UI',
            event.entity.name, event.entity.surface.name, serpent.line(event.entity.position))
        player.opened = nil
        return
    end

    ---@class lti.GuiContext
    ---@field last_config lti.Config?
    ---@field last_connection_state table<defines.wire_connector_id, boolean>?
    local gui_state = {
        last_config = nil,
        last_connection_state = nil,
    }

    local gui = Framework.gui_manager:create_gui {
        type = Gui.NAME,
        player_index = event.player_index,
        parent = player.gui.screen,
        ui_tree_provider = Gui.getUi,
        context = gui_state,
        entity_id = entity.unit_number
    }

    player.opened = gui.root
end

function Gui.onGhostGuiOpened(event)
    local player = Player.get(event.player_index)
    if not player then return end

    player.opened = nil
end

----------------------------------------------------------------------------------------------------
-- Event ticker
----------------------------------------------------------------------------------------------------

---@param gui framework.gui
---@return boolean
function Gui.guiUpdater(gui)
    local lti_data = This.Lti:getLtiData(gui.entity_id)
    if not lti_data then return false end

    ---@type lti.GuiContext
    local context = gui.context

    -- always update wire state and preview
    local connection_state = refresh_gui(gui, lti_data)

    local refresh_config = not (context.last_config and table.compare(context.last_config, lti_data.config))
    local refresh_state = not (context.last_connection_state and table.compare(context.last_connection_state, connection_state))

    if refresh_config or refresh_state then
        update_gui(gui, lti_data)
        This.Lti:updateLtiState(lti_data, lti_data.current_delivery)
    end

    if refresh_config then
        context.last_config = tools.copy(lti_data.config)
    end

    if refresh_state then
        context.last_connection_state = connection_state
    end

    return true
end

----------------------------------------------------------------------------------------------------
-- Event registration
----------------------------------------------------------------------------------------------------

local function init_gui()
    Framework.gui_manager:register_gui_type(Gui.NAME, get_gui_event_definition())

    local match_main_entity = Matchers:matchEventEntityName(const.lti_name)
    local match_ghost_main_entity = Matchers:matchEventEntityGhostName(const.lti_name)

    -- Gui updates / sync inserters
    Event.on_event(defines.events.on_gui_opened, Gui.onGuiOpened, match_main_entity)
    Event.on_event(defines.events.on_gui_opened, Gui.onGhostGuiOpened, match_ghost_main_entity)
end

Event.on_init(init_gui)
Event.on_load(init_gui)

return Gui
