---@meta
------------------------------------------------------------------------
-- Manage all ghost state for robot building
------------------------------------------------------------------------

local Event = require('__stdlib__/stdlib/event/event')
local Is = require('__stdlib__/stdlib/utils/is')

---@class FrameworkGhostManager
local FrameworkGhostManager = {}

---@class FrameworkAttachedEntity
---@field entity LuaEntity
---@field name string?
---@field position MapPosition?
---@field orientation float?
---@field tags Tags?
---@field player_index integer
---@field tick integer

--- @return FrameworkGhostManagerState state Manages ghost state
function FrameworkGhostManager:state()
    local storage = Framework.runtime:storage()

    if not storage.ghost_manager then
        ---@class FrameworkGhostManagerState
        ---@field count integer running count of all known UIs
        ---@field guis table<number, FrameworkGui> All registered and known guis for this manager.
        storage.ghost_manager = {
            ---@type FrameworkAttachedEntity[]
            ghost_entities = {},
        }
    end

    return storage.ghost_manager
end

---@param entity LuaEntity
---@param player_index integer
function FrameworkGhostManager:registerGhost(entity, player_index)
    -- if an entity ghost was placed, register information to configure
    -- an entity if it is placed over the ghost

    local state = self:state()

    state.ghost_entities[entity.unit_number] = {
        -- maintain entity reference for attached entity ghosts
        entity = entity,
        -- but for matching ghost replacement, all the values
        -- must be kept because the entity is invalid when it
        -- replaces the ghost
        name = entity.ghost_name,
        position = entity.position,
        orientation = entity.orientation,
        tags = entity.tags,
        player_index = player_index,
        -- allow 10 seconds of dwelling time until a refresh must have happened
        tick = game.tick + 600,
    }
end

function FrameworkGhostManager:deleteGhost(unit_number)
    local state = self:state()

    if state.ghost_entities[unit_number] then
        state.ghost_entities[unit_number].entity.destroy()
        state.ghost_entities[unit_number] = nil
    end
end

---@param entity LuaEntity
---@return FrameworkAttachedEntity? attached_entity
function FrameworkGhostManager:findMatchingGhost(entity)
    local state = self:state()

    -- find a ghost that matches the entity
    for idx, ghost in pairs(state.ghost_entities) do
        -- it provides the tags and player_index for robot builds
        if entity.name == ghost.name
            and entity.position.x == ghost.position.x
            and entity.position.y == ghost.position.y
            and entity.orientation == ghost.orientation then
            state.ghost_entities[idx] = nil
            return ghost
        end
    end
    return nil
end

--- @param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_revive | EventData.script_raised_built
function FrameworkGhostManager.onGhostEntityCreated(event)
    local entity = event and (event.created_entity or event.entity)
    if not Is.Valid(entity) then return end

    script.register_on_entity_destroyed(entity)

    Framework.ghost_manager:registerGhost(entity, event.player_index)
end

---@param event EventData.on_entity_destroyed
function FrameworkGhostManager.onEntityDestroyed(event)
    Framework.ghost_manager:deleteGhost(event.unit_number)
end

Event.register(defines.events.on_entity_destroyed, FrameworkGhostManager.onEntityDestroyed)

return FrameworkGhostManager
