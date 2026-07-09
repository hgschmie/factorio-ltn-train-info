--------------------------------------------------------------------------------
-- Picker Dollies (https://mods.factorio.com/mod/PickerDollies) support
--------------------------------------------------------------------------------

local Event = require('stdlib.event.event')

local const = require('lib.constants')

---@class epd.Event: EventData
---@field player_index uint                 Player index
---@field moved_entity LuaEntity            The entity that was moved. See 'transporter mode' note below
---@field start_pos MapPosition             The start position from which the entity was moved
---@field start_direction defines.direction The start direction of the entity (since 2.5.0)
---@field start_unit_number integer?        The original unit number of the entity (since 2.5.0)


---@param event epd.Event
local function picker_dollies_moved(event)
    local moved_entity = event.moved_entity
    if not (moved_entity and moved_entity.valid) then return end

    if moved_entity.name ~= const.lti_name then return end
    This.Lti:move(moved_entity)
end

local function picker_dollies_init()
    if remote.interfaces['PickerDollies']['dolly_moved_entity_id'] then
        Event.on_event(remote.call('PickerDollies', 'dolly_moved_entity_id'), picker_dollies_moved)
    end
end

local PickerDollies = {
    on_init = picker_dollies_init,
    on_load = picker_dollies_init,
}

return PickerDollies
