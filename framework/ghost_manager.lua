------------------------------------------------------------------------
-- Manage all ghost state for robot building
------------------------------------------------------------------------
assert(script)
assert(Framework)

-- Factorio Framework 2 (ff2)

local Event = require('stdlib.event.event')
local Is = require('stdlib.utils.is')
local Position = require('stdlib.area.position')

local Matchers = require('framework.matchers')
local tools = require('framework.tools')

local TICK_INTERVAL = 61 -- run all 61 ticks
local ATTACHED_GHOST_LINGER_TIME = 600

---@alias ff2.ghost_manager.RefreshCallback fun(entity: ff2.ghost_manager.AttachedEntity, all_entities: ff2.ghost_manager.AttachedEntity[]): ff2.ghost_manager.AttachedEntity[]
---@alias ff2.ghost_manager.GhostCallback fun(entity: ff2.ghost_manager.AttachedEntity)

---@class ff2.ghost_manager
---@field refresh_callbacks table<string, ff2.ghost_manager.RefreshCallback>
---@field ghost_callbacks table<string, ff2.ghost_manager.GhostCallback>
local FrameworkGhostManager = {
    refresh_callbacks = {},
    ghost_callbacks = {},
}

---@param force boolean? If true, force reinit
---@return ff2.ghost_manager.State state Manages ghost state
function FrameworkGhostManager:state(force)
    local state = Framework.runtime:storage()

    ---@type ff2.ghost_manager.State
    state.ghost_manager = (state.ghost_manager and not force) and state.ghost_manager or {
        ghost_entities = {},
        pre_build = {},
    }

    return state.ghost_manager
end

---@param event EventData.on_pre_build
local function on_pre_build(event)

    local state = FrameworkGhostManager:state()

    state.pre_build[event.player_index] = {
        tick = game.tick,
        direction = event.direction,
        flip_horizontal = event.flip_horizontal,
        flip_vertical = event.flip_vertical,
    }
end

---@param player_index integer
---@return ff2.ghost_manager.PreBuild? pre_build
function FrameworkGhostManager:getPreBuild(player_index)
    local state = self:state()
    local pre_build = state.pre_build[player_index]
    if not pre_build or pre_build.tick ~= game.tick then return nil end

    return pre_build
end

---@param entity LuaEntity
---@param player_index integer?
function FrameworkGhostManager:registerGhost(entity, player_index)
    -- if an entity ghost was placed, register information to configure
    -- an entity if it is placed over the ghost

    local state = self:state()

    local attached_entity = {
        entity = entity,
        key = tools:createEntityKeyFromEntity(entity),
        tags = entity.tags,
        player_index = player_index,
        -- allow 10 seconds of lingering time until a refresh must have happened
        tick = game.tick + ATTACHED_GHOST_LINGER_TIME,
        pre_build = util.copy(self:getPreBuild(player_index)),
    }

    if self.ghost_callbacks[entity.ghost_name] then
        self.ghost_callbacks[entity.ghost_name](attached_entity)
    end

    state.ghost_entities[entity.unit_number] = attached_entity
end

---@param unit_number integer
function FrameworkGhostManager:deleteGhost(unit_number)
    local state = self:state()

    local ghost_entity = state.ghost_entities[unit_number]
    if not ghost_entity then return end

    if ghost_entity.entity and ghost_entity.entity.valid then
        ghost_entity.entity.destroy()
    end

    state.ghost_entities[unit_number] = nil
end

---@param key framework.tools.EntityKey?
---@return ff2.ghost_manager.AttachedEntity? ghost
function FrameworkGhostManager:findGhostForKey(key)
    if not key then return end

    local state = self:state()

    -- find a ghost that matches the entity
    for _, ghost in pairs(state.ghost_entities) do
        -- it provides the tags and player_index for robot builds
        if ghost.key == key then return ghost end
    end

    return nil
end

---@param entity LuaEntity
---@return ff2.ghost_manager.AttachedEntity? ghost_entities
function FrameworkGhostManager:findGhostForEntity(entity)
    return self:findGhostForKey(tools:createEntityKeyFromEntity(entity))
end

---@param blueprint_entity BlueprintEntity
---@param surface_index number
---@return ff2.ghost_manager.AttachedEntity? ghost_entities
function FrameworkGhostManager:findGhostForBlueprintEntity(blueprint_entity, surface_index)
    return self:findGhostForKey(tools:createEntityKeyFromBlueprintEntity(blueprint_entity, surface_index))
end

--- Find all ghosts within a given area. If a ghost is found, pass
--- it to the callback. If the callback returns a key, move the ghost
--- into the ghost_entities return array under the given key and remove
--- it from storage.
---
---@param area BoundingBox
---@param callback fun(ghost: ff2.ghost_manager.AttachedEntity) : any?
---@return table<any, ff2.ghost_manager.AttachedEntity> ghost_entities
function FrameworkGhostManager:findGhostsInArea(area, callback)
    local state = self:state()

    local ghosts = {}
    for idx, ghost in pairs(state.ghost_entities) do
        if ghost.entity and ghost.entity.valid then
            local pos = Position.new(ghost.entity.position)
            if pos:inside(area) then
                local key = callback(ghost)
                if key and not ghosts[key] then
                    ghosts[key] = ghost
                    state.ghost_entities[idx] = nil
                end
            end
        end
    end

    return ghosts
end

--------------------------------------------------------------------------------
-- event callbacks
--------------------------------------------------------------------------------

---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.on_space_platform_built_entity | EventData.script_raised_revive | EventData.script_raised_built
local function on_ghost_entity_created(event)
    local entity = event and event.entity
    if not Is.Valid(entity) then return end

    script.register_on_object_destroyed(entity)

    FrameworkGhostManager:registerGhost(entity, event.player_index)
end

---@param event EventData.on_post_entity_died
local function on_post_entity_died(event)
    local entity = event and event.ghost
    if not Is.Valid(entity) then return end

    script.register_on_object_destroyed(entity)

    FrameworkGhostManager:registerGhost(entity)
end

---@param event EventData.on_object_destroyed
local function on_object_destroyed(event)
    FrameworkGhostManager:deleteGhost(event.useful_id)
end

--------------------------------------------------------------------------------
-- ticker
--------------------------------------------------------------------------------

local function tick()
    local state = FrameworkGhostManager:state()

    if table_size(state.ghost_entities) == 0 then return end

    for id, ghost_entity in pairs(state.ghost_entities) do
        if ghost_entity.entity and ghost_entity.entity.valid then
            local callback = FrameworkGhostManager.refresh_callbacks[ghost_entity.entity.ghost_name]
            if callback then
                local entities = callback(ghost_entity, state.ghost_entities)
                for _, entity in pairs(entities) do
                    entity.tick = game.tick + ATTACHED_GHOST_LINGER_TIME -- refresh
                end
            end
        else
            FrameworkGhostManager:deleteGhost(id)
        end
    end

    -- remove stale ghost entities
    for id, ghost_entity in pairs(state.ghost_entities) do
        if ghost_entity.tick < game.tick then
            FrameworkGhostManager:deleteGhost(id)
        end
    end
end

--------------------------------------------------------------------------------
-- public API
--------------------------------------------------------------------------------

---@class ff2.ghost_manager.registerForNameAttrs
---@field names string|string[] One or more names to match to the ghost_name field.
---@field refresh_callback ff2.ghost_manager.RefreshCallback? Optional callback to refresh entities
---@field ghost_callback ff2.ghost_manager.GhostCallback?

--- Registers a name as a managed ghost. Those are available e.g. for construction to
--- retrieve tags. This also supports undo/redo passing tags to ghosts.
---
--- Normal entities (main entities) should register without a callback as they are managed
--- by the game and the manager only takes care of tag data and player_index.
---
--- When adding a callback, the callback will be called periodically to "refresh" the ghost
--- list. Any ghost that was registered *without* a callback will be removed when the linger
--- period expires and it had not been refreshed.
---
--- When creating a multi-ghost entity (e.g. for connection pins), register the main entity
--- with a callback and all other entities without. When the all the entities are placed down,
--- the callback will be called for the main entity which in turn must find its associated
--- entity ghosts and refresh them as well (return on the refresh list). If the main ghost is
--- replaced but the others are not, they will be removed when the linger period expires.
---
---@param attrs ff2.ghost_manager.registerForNameAttrs
function FrameworkGhostManager:registerForName(attrs)
    assert(attrs.names)
    local event_matcher = Matchers:matchEventEntityGhostName(attrs.names)
    Event.register(Matchers.CREATION_EVENTS, on_ghost_entity_created, event_matcher)
    Event.register(defines.events.on_post_entity_died, on_post_entity_died)

    local names = (type(attrs.names) ~= 'table') and { attrs.names } or attrs.names

    -- if a callback was provided, register callback and turn on the ticker
    if attrs.refresh_callback then
        Event.register_if(table_size(self.refresh_callbacks) == 0, -TICK_INTERVAL, tick)

        for _, name in pairs(names) do
            assert(not self.refresh_callbacks[name])
            self.refresh_callbacks[name] = attrs.refresh_callback
        end
    end

    if attrs.ghost_callback then
        for _, name in pairs(names) do
            assert(not self.ghost_callbacks[name])
            self.ghost_callbacks[name] = attrs.ghost_callback
        end
    end
end

---@param attribute string The entity attribute to match.
---@param values string|string[] One or more values to match.
function FrameworkGhostManager:registerForAttribute(attribute, values)
    local event_matcher = Matchers:matchEventEntityAsGhost(attribute, values)
    Event.register(Matchers.CREATION_EVENTS, on_ghost_entity_created, event_matcher)
    Event.register(defines.events.on_post_entity_died, on_post_entity_died)
end

--- Can be called by the tombstone manager. Will pass in all the information necessary to find
--- a ghost that matches a blueprint entity to build and apply a possible tombstone as tags to the
--- ghost.
---@param data Tags?
---@param position MapPosition
---@param surface_index number
---@param name string
function FrameworkGhostManager.mapTombstoneToGhostTags(data, position, surface_index, name)
    local ghost = FrameworkGhostManager:findGhostForKey(tools:createEntityKey(position, surface_index, name))
    if ghost then ghost.tags = data end
end

--------------------------------------------------------------------------------
-- event registration
--------------------------------------------------------------------------------

local function register_events()
    Event.register(defines.events.on_pre_build, on_pre_build)
    Event.register(defines.events.on_object_destroyed, on_object_destroyed)
end

Event.on_init(register_events)
Event.on_load(register_events)

return FrameworkGhostManager
