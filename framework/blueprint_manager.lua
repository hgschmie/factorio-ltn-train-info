---@meta
------------------------------------------------------------------------
-- Manage blueprint related state
------------------------------------------------------------------------
assert(script)

local Event = require('stdlib.event.event')
local Is = require('stdlib.utils.is')
local Player = require('stdlib.event.player')
local table = require('stdlib.utils.table')

local tools = require('framework.tools')

---@alias framework.blueprint.PrepareCallback fun(blueprint: LuaItemStack): BlueprintEntity[]?
---@alias framework.blueprint.MapCallback fun(entity: LuaEntity, idx: integer, context: table<string, any>)
---@alias framework.blueprint.Callback fun(entity: LuaEntity, context: table<string, any>): table<string, any>?
---@alias framework.blueprint.Context table<string, any?>
---@alias framework.blueprint.EntityMap table<string, LuaEntity>

---@class framework.blueprint.Manager
---@field map_callbacks table<string, framework.blueprint.MapCallback>
---@field callbacks table<string, framework.blueprint.Callback>
---@field prepare_blueprint_callback framework.blueprint.PrepareCallback?
local FrameworkBlueprintManager = {
    map_callbacks = {},
    callbacks = {},
    prepare_blueprint_callback = nil,
}

------------------------------------------------------------------------
-- Blueprint management
------------------------------------------------------------------------

---@param player LuaPlayer
---@return boolean
local function can_access_blueprint(player)
    if not Is.Valid(player) then return false end
    if not player.cursor_stack then return false end

    return (player.cursor_stack.valid_for_read and player.cursor_stack.name == 'blueprint')
end

---@param blueprint LuaItemStack
---@param surface_index number
---@param entity_map framework.blueprint.EntityMap
---@param context framework.blueprint.Context
function FrameworkBlueprintManager:augmentBlueprint(blueprint, surface_index, entity_map, context)
    if not entity_map or (table_size(entity_map) < 1) then return end
    if not (blueprint and blueprint.is_blueprint_setup()) then return end

    local blueprint_entities = self.prepare_blueprint_callback and self.prepare_blueprint_callback(blueprint) or blueprint.get_blueprint_entities()
    if not blueprint_entities then return end

    -- at this point, the entity_map contains all entities that were captured in the
    -- initial blueprint but the final list (which is part of the blueprint itself) may
    -- have changed as the player can manipulate the blueprint.

    for idx, entity in pairs(blueprint_entities) do
        local key = tools:createEntityKeyFromBlueprintEntity(entity, surface_index)
        if entity_map[key] then
            local callback = self.callbacks[entity.name]
            if callback then
                local tags = callback(entity_map[key], context)
                if tags then
                    for k, v in pairs(tags) do
                        blueprint.set_blueprint_entity_tag(idx, k, v)
                    end
                end
            end
        end
    end
end

---@param entity_mapping table<integer, LuaEntity>
---@param context framework.blueprint.Context
---@return framework.blueprint.EntityMap entity_map
function FrameworkBlueprintManager:createEntityMap(entity_mapping, context)
    local entity_map = {}
    if entity_mapping then
        for idx, mapped_entity in pairs(entity_mapping) do
            if self.callbacks[mapped_entity.name] then -- there is a callback for this entity
                local map_callback = self.map_callbacks[mapped_entity.name]
                if map_callback then
                    map_callback(mapped_entity, idx, context)
                end

                local key = tools:createEntityKeyFromEntity(mapped_entity)
                assert(key)
                
                if entity_map[key] then
                    Framework.logger:logf('Duplicate entity found at (%d/%d): %s', mapped_entity.position.x, mapped_entity.position.y, mapped_entity.name)
                else
                    entity_map[key] = mapped_entity
                end
            end
        end
    end

    return entity_map
end

------------------------------------------------------------------------
-- Event code
------------------------------------------------------------------------

---@param event EventData.on_player_setup_blueprint
local function on_player_setup_blueprint(event)
    local player, player_data = Player.get(event.player_index)
    if not (player or player_data) then return end

    local self = Framework.blueprint
    assert(self)

    local blueprinted_entities = event.mapping.get()
    -- for large blueprints, the event mapping might come up empty
    -- which seems to be a limitation of the game. Fall back to an
    -- area scan
    if table_size(blueprinted_entities) < 1 then
        if not event.area then return end
        blueprinted_entities = player.surface.find_entities_filtered {
            area = event.area,
            force = player.force,
            name = table.keys(self.callbacks)
        }
    end

    local context = {}
    local entity_map = self:createEntityMap(blueprinted_entities, context)

    if can_access_blueprint(player) then
        self:augmentBlueprint(player.cursor_stack, player.surface_index, entity_map, context)
    else
        -- Player is editing the blueprint, no access for us yet.
        -- onPlayerConfiguredBlueprint picks this up and stores it.
        player_data.current_blueprint =  {
            entity_map = entity_map,
            context = context,
        }
    end
end

---@param event EventData.on_player_configured_blueprint
local function on_player_configured_blueprint(event)
    local player, player_data = Player.get(event.player_index)
    if not (player or player_data) then return end

    local self = Framework.blueprint
    assert(self)

    local current_blueprint = player_data.current_blueprint

    if current_blueprint and can_access_blueprint(player) then
        self:augmentBlueprint(player.cursor_stack, player.surface_index, current_blueprint.entity_map, current_blueprint.context)
    end

    player_data.current_blueprint = nil
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

---@param names string|string[]
---@param callback framework.blueprint.Callback
---@param map_callback framework.blueprint.MapCallback?
function FrameworkBlueprintManager:registerCallback(names, callback, map_callback)
    assert(names)
    if type(names) ~= 'table' then names = { names } end

    for _, name in pairs(names) do
        self.callbacks[name] = callback
        if map_callback then self.map_callbacks[name] = map_callback end
    end
end

---@param callback framework.blueprint.PrepareCallback
function FrameworkBlueprintManager:registerPreprocessor(callback)
    self.prepare_blueprint_callback = callback
end

--------------------------------------------------------------------------------
-- event registration
--------------------------------------------------------------------------------

local function register_events()
    -- Blueprint management
    Event.register(defines.events.on_player_setup_blueprint, on_player_setup_blueprint)
    Event.register(defines.events.on_player_configured_blueprint, on_player_configured_blueprint)
end

Event.on_init(register_events)
Event.on_load(register_events)

return FrameworkBlueprintManager
