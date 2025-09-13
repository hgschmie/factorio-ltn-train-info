------------------------------------------------------------------------
-- Prototype for the LTN train info combinator
------------------------------------------------------------------------

local util = require('util')

local data_util = require('framework.prototypes.data-util')

local meld = require('meld')

local const = require('lib.constants')

local lti_combinator_update = {
    ---@diagnostic disable-next-line: undefined-global
    sprites = meld.overwrite(make_4way_animation_from_spritesheet {
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
        },
    }),
    icon = const:png('icon/ltn-train-info'),
    minable = { mining_time = 0.1, result = const.lti_name },
    radius_visualisation_specification = {
        priority = 'extra-high-no-scale',
        distance = const.lti_range + 0.5,
        offset = { 0, 0 },
        sprite = {
            filename = const:png('misc/train-info-radius-visualization'),
            height = 12,
            width = 12
        }
    },
}

local lti = meld(data_util.copy_entity_prototype(data.raw['constant-combinator']['constant-combinator'], const.lti_name), lti_combinator_update) --[[@as data.ConstantCombinatorPrototype ]]

data:extend { lti }

------------------------------------------------------------------------



local lti_item_update = {
    icon = const:png('icon/ltn-train-info'),
    icon_size = 64,
    icons = meld.delete(),
    order = const.order,
}

local lti_item = meld(data_util.copy_other_prototype(data.raw.item['constant-combinator'], const.lti_name), lti_item_update) --[[@as data.ItemPrototype]]

local lti_recipe_update = {
    order = lti_item.order,
    results = meld.invoke(function(result)
        result[1].name = const.lti_name
        return result
    end),
}

local lti_recipe = meld(data_util.copy_other_prototype(data.raw.recipe['constant-combinator'], const.lti_name), lti_recipe_update) --[[@as data.RecipePrototype]]

data:extend { lti_item, lti_recipe }

table.insert(data.raw['technology']['logistic-train-network'].effects, { type = 'unlock-recipe', recipe = const.lti_name })
