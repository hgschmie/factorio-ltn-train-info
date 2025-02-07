------------------------------------------------------------------------
-- Prototype for the LTN train info combinator
------------------------------------------------------------------------

local util = require('util')

local data_util = require('framework.prototypes.data-util')

local const = require('lib.constants')

local lti = data_util.copy_entity_prototype(data.raw['constant-combinator']['constant-combinator'],
    const.lti_train_info_name) --[[@as data.ConstantCombinatorPrototype ]]

-- ConstantCombinatorPrototype
---@diagnostic disable-next-line: undefined-global
lti.sprites = make_4way_animation_from_spritesheet {
    layers = {
        {
            scale = 0.5,
            filename = const:png('entity/ltn-train-info'),
            width = 114,
            height = 102,
            shift = util.by_pixel(0, 5)
        },
        {
            scale = 0.5,
            filename = '__base__/graphics/entity/combinator/constant-combinator-shadow.png',
            width = 98,
            height = 66,
            shift = util.by_pixel(8.5, 5.5),
            draw_as_shadow = true
        }
    }
}

    -- EntityPrototype
lti.icon = const:png('icon/ltn-train-info')
lti.minable = { mining_time = 0.1, result = const.lti_train_info_name }

lti.radius_visualisation_specification = {
    priority = "extra-high-no-scale",
    distance = const.lti_range + 0.5,
    offset = { 0, 0 },
    sprite = {
        filename = const:png('misc/train-info-radius-visualization'),
        height = 12,
        width = 12
    }
}

data:extend { lti }

------------------------------------------------------------------------

local lti_item = data_util.copy_prototype(data.raw.item['constant-combinator'], const.lti_train_info_name) --[[@as data.ItemPrototype]]

lti_item.icon = const:png('icon/ltn-train-info')
lti_item.icon_size = 64
lti_item.icons = nil
lti_item.order = const.order

local lti_recipe = data_util.copy_prototype(data.raw.recipe['constant-combinator'], const.lti_train_info_name) --[[@as data.RecipePrototype]]
lti_recipe.order = lti_item.order
lti_recipe.results[1].name = const.lti_train_info_name

data:extend { lti_item, lti_recipe }

table.insert(data.raw['technology']['logistic-train-network'].effects, { type = 'unlock-recipe', recipe = const.lti_train_info_name })
