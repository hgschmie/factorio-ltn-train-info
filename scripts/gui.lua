------------------------------------------------------------------------
-- LTN Train Info GUI
------------------------------------------------------------------------

local Event = require('__stdlib__/stdlib/event/event')
local Player = require('__stdlib__/stdlib/event/player')
local table = require('__stdlib__/stdlib/utils/table')
local string = require('__stdlib__/stdlib/utils/string')


local Util = require('framework.util')

local const = require('lib.constants')

---@class ModGui
local ModGui = {}

-- callback predefines
local onWindowClosed, onToggleEnable, onRadioButtonQuantity, onRadioButtonOne, onToggleNegate
local onToggleVirtual, onDivideBySlider, onDivideByText
-- forward declarations
local gui_updater

----------------------------------------------------------------------------------------------------
-- UI definition
----------------------------------------------------------------------------------------------------

--- @param lti_entity TrainInfoData
--- @return FrameworkGuiElemDef ui
local function get_ui(lti_entity)
    return {
        type = 'frame',
        name = 'gui_root',
        direction = 'vertical',
        handler = { [defines.events.on_gui_closed] = onWindowClosed },
        elem_mods = { auto_center = true },
        children = {
            { -- Title Bar
                type = 'flow',
                style = 'framework_titlebar_flow',
                drag_target = 'gui_root',
                children = {
                    {
                        type = 'label',
                        style = 'frame_title',
                        caption = { const.lti_entity_name },
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
                        sprite = 'utility/close_white',
                        hovered_sprite = 'utility/close_black',
                        clicked_sprite = 'utility/close_black',
                        mouse_button_filter = { 'left' },
                        handler = { [defines.events.on_gui_click] = onWindowClosed },
                    },
                },
            },
            {
                type = 'frame',
                style = 'inside_shallow_frame_with_padding',
                direction = 'vertical',
                children = {
                    { -- Working / ID row
                        type = 'flow',
                        style = 'framework_indicator_flow',
                        children = {
                            {
                                type = 'sprite',
                                name = 'lamp',
                                style = 'framework_indicator',
                            },
                            {
                                type = 'label',
                                style = 'label',
                                name = 'status',
                            },
                            {
                                type = 'empty-widget',
                                style = 'framework_horizontal_pusher',
                            },
                            {
                                type = 'label',
                                style = 'label',
                                caption = 'ID: ' .. lti_entity.main.unit_number,
                            },
                        },
                    },
                    {
                        type = 'frame',
                        style = 'container_invisible_frame_with_title',
                    },
                    { -- connection to train stop(s)
                        type = 'frame',
                        style = 'container_invisible_frame_with_title',
                        name = 'connection-frame',
                        children = {
                            {
                                type = 'label',
                                style = 'description_property_name_label',
                                name = 'connection-label',
                            },
                            {
                                type = 'empty-widget',
                                style = 'framework_horizontal_pusher',
                            },
                            {
                                type = 'label',
                                style = 'description_value_label',
                                name = 'connection',
                            },
                        },
                    },
                    {
                        type = 'line',
                    },
                    {
                        type = 'frame',
                        style = const:with_prefix('gui-frame'),
                        caption = { const:locale('provide') },
                        children = { -- provide settings
                            type = 'table',
                            style = const:with_prefix('delivery-settings-table'),
                            column_count = 3,
                            children = {
                                {
                                    type = 'flow',
                                    direction = 'horizontal',
                                    children = {
                                        type = 'checkbox',
                                        name = 'delivery-provide',
                                        elem_tags = { config = const.delivery_type.provide },
                                        caption = { "", { const:locale('enabled') }, ' [img=info]' },
                                        tooltip = { const:locale('enabled-description') },
                                        handler = { [defines.events.on_gui_checked_state_changed] = onToggleEnable },
                                        state = false,
                                        text_padding = 0,
                                    },
                                },
                                {
                                    type = 'flow',
                                    style = const:with_prefix('delivery-settings-radiobutton-flow'),
                                    direction = 'vertical',
                                    children = {
                                        {
                                            type = 'radiobutton',
                                            caption = { "", {  const:locale('signal-type-quantity') }, ' [img=info]' },
                                            tooltip = { const:locale('signal-type-quantity-description') },
                                            name = 'signal-type-quantity-provide',
                                            elem_tags = { config = const.delivery_type.provide },
                                            handler = { [defines.events.on_gui_checked_state_changed] = onRadioButtonQuantity },
                                            state = false,
                                        },
                                        {
                                            type = 'radiobutton',
                                            caption = { "", {  const:locale('signal-type-stacksize') }, ' [img=info]' },
                                            tooltip = { const:locale('signal-type-stacksize-description') },
                                            name = 'signal-type-stacksize-provide',
                                            elem_tags = { config = const.delivery_type.provide },
                                            handler = { [defines.events.on_gui_checked_state_changed] = onRadioButtonStackSize },
                                            state = false,
                                        },
                                        {
                                            type = 'radiobutton',
                                            caption = { const:locale('signal-type-one') },
                                            name = 'signal-type-one-provide',
                                            elem_tags = { config = const.delivery_type.provide },
                                            handler = { [defines.events.on_gui_checked_state_changed] = onRadioButtonOne },
                                            state = false,
                                        },
                                    }
                                },
                                {
                                    type = 'checkbox',
                                    name = 'negate-provide',
                                    elem_tags = { config = const.delivery_type.provide },
                                    handler = { [defines.events.on_gui_checked_state_changed] = onToggleNegate },
                                    state = false,
                                    caption = { "", {  const:locale('negate') }, ' [img=info]' },
                                    tooltip = { const:locale('negate-description') },
                                    text_padding = 0,
                                },
                            }
                        },
                    },
                    {
                        type = 'line',
                    },
                    {
                        type = 'frame',
                        style = const:with_prefix('gui-frame'),
                        caption = { const:locale('request') },
                        children = { -- request settings
                            type = 'table',
                            style = const:with_prefix('delivery-settings-table'),
                            column_count = 3,
                            children = {
                                {
                                    type = 'flow',
                                    direction = 'horizontal',
                                    children = {
                                        type = 'checkbox',
                                        name = 'delivery-request',
                                        elem_tags = { config = const.delivery_type.request },
                                        caption = { "", {  const:locale('enabled') }, ' [img=info]' },
                                        tooltip = { const:locale('enabled-description') },
                                        handler = { [defines.events.on_gui_checked_state_changed] = onToggleEnable },
                                        state = false,
                                        text_padding = 0,
                                    },
                                },
                                {
                                    type = 'flow',
                                    style = const:with_prefix('delivery-settings-radiobutton-flow'),
                                    direction = 'vertical',
                                    children = {
                                        {
                                            type = 'radiobutton',
                                            caption = { "", {  const:locale('signal-type-quantity') }, ' [img=info]' },
                                            tooltip = { const:locale('signal-type-quantity-description') },
                                            name = 'signal-type-quantity-request',
                                            elem_tags = { config = const.delivery_type.request },
                                            handler = { [defines.events.on_gui_checked_state_changed] = onRadioButtonQuantity },
                                            state = false,
                                        },
                                        {
                                            type = 'radiobutton',
                                            caption = { "", {  const:locale('signal-type-stacksize') }, ' [img=info]' },
                                            tooltip = { const:locale('signal-type-stacksize-description') },
                                            name = 'signal-type-stacksize-request',
                                            elem_tags = { config = const.delivery_type.request },
                                            handler = { [defines.events.on_gui_checked_state_changed] = onRadioButtonStackSize },
                                            state = false,
                                        },
                                        {
                                            type = 'radiobutton',
                                            caption = { const:locale('signal-type-one') },
                                            name = 'signal-type-one-request',
                                            elem_tags = { config = const.delivery_type.request },
                                            handler = { [defines.events.on_gui_checked_state_changed] = onRadioButtonOne },
                                            state = false,
                                        },
                                    },
                                },
                                {
                                    type = 'checkbox',
                                    name = 'negate-request',
                                    elem_tags = { config = const.delivery_type.request },
                                    handler = { [defines.events.on_gui_checked_state_changed] = onToggleNegate },
                                    state = false,
                                    caption = { "", {  const:locale('negate') }, ' [img=info]' },
                                    tooltip = { const:locale('negate-description') },
                                    text_padding = 0,
                                },
                            }
                        },
                    },
                    {
                        type = 'line',
                    },
                    {
                        type = 'frame',
                        style = const:with_prefix('gui-frame'),
                        caption = { const:locale('settings') },
                        children = {
                            type = 'frame',
                            style = 'invisible_frame',
                            direction = 'vertical',
                            children = {
                                { -- add virtual signals
                                    type = 'checkbox',
                                    caption = { "", {  const:locale('virtual') }, ' [img=info]' },
                                    tooltip = { const:locale('virtual-description') },
                                    name = 'virtual',
                                    handler = { [defines.events.on_gui_checked_state_changed] = onToggleVirtual },
                                    state = false,
                                },
                                { -- divider
                                    type = 'flow',
                                    style = const:with_prefix('divide-flow'),
                                    direction = 'horizontal',
                                    children = {
                                        {
                                            type = 'label',
                                            style = const:with_prefix('settings-divide-label'),
                                            caption = { "", {  const:locale('divide') }, ' [img=info]' },
                                            tooltip = { const:locale('divide-description') },
                                        },
                                        {
                                            type = 'slider',
                                            style = const:with_prefix('divide-slider'),
                                            name = 'divide_by_slider',
                                            minimum_value = 1,
                                            maximum_value = 20,
                                            handler = { [defines.events.on_gui_value_changed] = onDivideBySlider, }
                                        },
                                        {
                                            type = 'textfield',
                                            style = const:with_prefix('divide-text'),
                                            name = 'divide_by_text',
                                            numeric = true,
                                            allow_negative = false,
                                            allow_decimal = true,
                                            lose_focus_on_confirm = true,
                                            clear_and_focus_on_right_click = true,
                                            handler = { [defines.events.on_gui_confirmed] = onDivideByText, },
                                        },
                                        {
                                            type = 'empty-widget',
                                            style = 'framework_horizontal_pusher',
                                        },
                                    },
                                },
                            },
                        },
                    },
                    {
                        type = 'line',
                    },
                    {
                        type = 'frame',
                        style = const:with_prefix('gui-frame'),
                        caption = { const:locale('signals-heading') },
                        children = {
                            type = 'table',
                            name = 'signals',
                            column_count = 10,
                        },
                    }
                },
            },
        },
    }
end

----------------------------------------------------------------------------------------------------
-- UI Callbacks
----------------------------------------------------------------------------------------------------

---@param event EventData.on_gui_switch_state_changed|EventData.on_gui_checked_state_changed|EventData.on_gui_elem_changed|EventData.on_gui_value_changed|EventData.on_gui_text_changed|EventData.on_gui_confirmed
---@return TrainInfoData? lti_entity
local function locate_config(event)
    local _, player_data = Player.get(event.player_index)
    if not (player_data and player_data.lti_gui) then return nil end

    local lti_entity = This.lti:entity(player_data.lti_gui.entity_id)
    if not lti_entity then return nil end

    return lti_entity
end

----------------------------------------------------------------------------------------------------

--- close the UI (button or shortcut key)
---
--- @param event EventData.on_gui_click|EventData.on_gui_opened
onWindowClosed = function(event)
    local player, player_data = Player.get(event.player_index)

    local lti_gui = player_data.lti_gui

    if (lti_gui) then
        if player.opened == player_data.lti_gui.gui.root then
            player.opened = nil
        end

        Event.remove(-1, gui_updater, nil, lti_gui)
        player_data.lti_gui = nil

        if lti_gui.gui then
            Framework.gui_manager:destroy_gui(lti_gui.gui)
        end
    end
end

--- @param event  EventData.on_gui_checked_state_changed
onToggleEnable = function(event)
    local lti_entity = locate_config(event)
    if not lti_entity then return end

    local config = lti_entity.config[event.element.tags['config']]

    config.enabled = event.element.state
    config.modified = true
end

--- @param event  EventData.on_gui_checked_state_changed
onRadioButtonQuantity = function(event)
    local lti_entity = locate_config(event)
    if not lti_entity then return end

    local config = lti_entity.config[event.element.tags['config']]

    config.signal_type = const.signal_type.quantity
    config.modified = true
end

--- @param event  EventData.on_gui_checked_state_changed
onRadioButtonStackSize = function(event)
    local lti_entity = locate_config(event)
    if not lti_entity then return end

    local config = lti_entity.config[event.element.tags['config']]

    config.signal_type = const.signal_type.stack_size
    config.modified = true
end

--- @param event  EventData.on_gui_checked_state_changed
onRadioButtonOne = function(event)
    local lti_entity = locate_config(event)
    if not lti_entity then return end

    local config = lti_entity.config[event.element.tags['config']]

    config.signal_type = const.signal_type.one
    config.modified = true
end

--- @param event  EventData.on_gui_checked_state_changed
onToggleNegate = function(event)
    local lti_entity = locate_config(event)
    if not lti_entity then return end

    local config = lti_entity.config[event.element.tags['config']]

    config.negate = event.element.state
    config.modified = true
end


--- @param event  EventData.on_gui_checked_state_changed
onToggleVirtual = function(event)
    local lti_entity = locate_config(event)
    if not lti_entity then return end

    lti_entity.config.virtual = event.element.state
    lti_entity.config.modified = true
end

--- @param event  EventData.on_gui_value_changed
onDivideBySlider = function(event)
    local lti_entity = locate_config(event)
    if not lti_entity then return end

    local value = event.element.slider_value

    value = math.min(const.divide_by_max, math.max(const.divide_by_min, value))

    lti_entity.config.divide_by = value
    lti_entity.config.modified = true
end

--- @param event  EventData.on_gui_text_changed
onDivideByText = function(event)
    local lti_entity = locate_config(event)
    if not lti_entity then return end

    local value = tonumber(event.element.text) or 1

    value = math.min(const.divide_by_max, math.max(const.divide_by_min, value))

    lti_entity.config.divide_by = value
    lti_entity.config.modified = true
end

----------------------------------------------------------------------------------------------------
-- GUI state updater
----------------------------------------------------------------------------------------------------

---@param gui FrameworkGui
---@param type string
---@param cfg TrainInfoDeliveryConfig
local function update_gui_delivery(gui, type, cfg)
    local delivery = gui:find_element('delivery-' .. type)
    delivery.state = cfg.enabled

    local quantity = gui:find_element('signal-type-quantity-' .. type)
    local stacksize = gui:find_element('signal-type-stacksize-' .. type)
    local one = gui:find_element('signal-type-one-' .. type)

    quantity.state = cfg.signal_type == const.signal_type.quantity
    stacksize.state = cfg.signal_type == const.signal_type.stack_size
    one.state = cfg.signal_type == const.signal_type.one

    local negate = gui:find_element('negate-' .. type)
    negate.state = cfg.negate
end

---@param gui FrameworkGui
---@param lti_entity TrainInfoData?
update_gui_state = function(gui, lti_entity, signals)
    if not lti_entity then return end

    local lti_config = lti_entity.config

    local entity_status = lti_config.enabled and defines.entity_status.working
        or defines.entity_status.disabled

    local lamp = gui:find_element('lamp')
    lamp.sprite = Util.STATUS_SPRITES[entity_status]

    local status = gui:find_element('status')
    status.caption = { Util.STATUS_NAMES[entity_status] }

    local connection_frame = gui:find_element('connection-frame')
    connection_frame.visible = lti_config.enabled

    local connection_label = gui:find_element('connection-label')
    local connection_name = #lti_entity.stop_ids > 1 and 'connection-info-p' or 'connection-info-s'
    connection_label.caption = { const:locale(connection_name) }

    local connection = gui:find_element('connection')
    connection.caption = string.join(', ', lti_entity.stop_ids)

    -- deal with provide and request
    update_gui_delivery(gui, 'provide', lti_config.provide)
    update_gui_delivery(gui, 'request', lti_config.request)

    local virtual = gui:find_element('virtual')
    virtual.state = lti_config.virtual

    local divide_by_slider = gui:find_element('divide_by_slider')
    divide_by_slider.slider_value = lti_config.divide_by
    local divide_by_text = gui:find_element('divide_by_text')
    divide_by_text.text = tostring(lti_config.divide_by)

    local signal_table = gui:find_element('signals')
    signal_table.clear()

    for idx, s in pairs(signals) do
        local sprite_type = s.signal.type == 'virtual' and 'virtual-signal' or s.signal.type

        signal_table.add {
            type = 'sprite-button',
            sprite = sprite_type .. '/' .. s.signal['name'],
            number = s.count,
        }
    end

    lti_config.modified = false
end

----------------------------------------------------------------------------------------------------
-- Event ticker
----------------------------------------------------------------------------------------------------

---@param lti_gui LtiGui
gui_updater = function(ev, lti_gui)
    local lti_entity = This.lti:entity(lti_gui.entity_id)
    if not lti_entity then
        Event.remove(-1, gui_updater, nil, lti_gui)
        return
    end

    if not (lti_gui.last_config and table.compare(lti_gui.last_config, lti_entity.config)) then
        local signals = This.lti:update_delivery(lti_entity)
        update_gui_state(lti_gui.gui, lti_entity, signals)
        lti_gui.last_config = table.deepcopy(lti_entity.config)
    end
end

----------------------------------------------------------------------------------------------------
-- open gui handler
----------------------------------------------------------------------------------------------------

--- @param event EventData.on_gui_opened
local function onGuiOpened(event)
    local player, player_data = Player.get(event.player_index)
    if player.opened and player_data.lti_gui and player.opened == player_data.lti_gui.gui.root then
        player.opened = nil
    end

    -- close an eventually open gui
    onWindowClosed(event)

    local entity = event and event.entity --[[@as LuaEntity]]
    local entity_id = entity.unit_number
    local lti_entity = This.lti:entity(entity_id)

    if not lti_entity then
        log('Data missing for ' ..
            event.entity.name .. ' on ' .. event.entity.surface.name .. ' at ' .. serpent.line(event.entity.position) .. ' refusing to display UI')
        player.opened = nil
        return
    end

    local gui = Framework.gui_manager:create_gui(player.gui.screen, get_ui(lti_entity))

    ---@class LtiGui
    ---@field gui FrameworkGui
    ---@field entity_id integer
    ---@field last_config TrainInfoConfig?
    player_data.lti_gui = {
        gui = gui,
        entity_id = entity_id,
        last_config = nil,
    }

    lti_entity.config.modified = false
    Event.register(-1, gui_updater, nil, player_data.lti_gui)

    player.opened = gui.root
end

----------------------------------------------------------------------------------------------------
-- Event registration
----------------------------------------------------------------------------------------------------

local lti_entity_filter = Util.create_event_entity_matcher('name', const.lti_train_info)

Event.on_event(defines.events.on_gui_opened, onGuiOpened, lti_entity_filter)

return ModGui
