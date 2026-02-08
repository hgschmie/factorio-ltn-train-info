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
                width = 128,
                height = 128,
                shift = util.by_pixel(7, -2)
            },
            {
                scale = 0.5,
                filename = const:png('entity/ltn-train-info-shadow'),
                width = 128,
                height = 128,
                shift = util.by_pixel(7, -2),
                draw_as_shadow = true
            }
        },
    }),
    circuit_wire_connection_points = {
        {
            shadow = {
                red = util.by_pixel(-1, 0),
                green = util.by_pixel(9, 0.5),
            },
            wire = {
                red = util.by_pixel(-11, -9),
                green = util.by_pixel(2, -7.5),
            }
        },
        {
            shadow = {
                red = util.by_pixel(34, 15.5),
                green = util.by_pixel(34, 6.5),
            },
            wire = {
                red = util.by_pixel(9, -7),
                green = util.by_pixel(9.75, -17),
            }
        },
        {
            shadow = {
                red = util.by_pixel(35, 0.5),
                green = util.by_pixel(5.0, -15),
            },
            wire = {
                red = util.by_pixel(10.5, -21.5),
                green = util.by_pixel(-3.5, -23),
            }
        },
        {
            shadow = {
                red = util.by_pixel(0, -15.25),
                green = util.by_pixel(-4, -5.5),
            },
            wire = {
                red = util.by_pixel(-9.5, -23),
                green = util.by_pixel(-12, -12.5),
            }
        }
    },
    activity_led_sprites = {
        north = util.draw_as_glow {
            scale = 0.5,
            filename = const:png('misc/red-activity-led'),
            width = 14,
            height = 16,
            shift = util.by_pixel(9.5, -14)
        },
        east = util.draw_as_glow {
            scale = 0.5,
            filename = const:png('misc/red-activity-led'),
            width = 14,
            height = 16,
            shift = util.by_pixel(-10, -14.5)
        },
        south = util.draw_as_glow {
            scale = 0.5,
            filename = const:png('misc/red-activity-led'),
            width = 14,
            height = 16,
            shift = util.by_pixel(-10.5, -1)
        },
        west = util.draw_as_glow {
            scale = 0.5,
            filename = const:png('misc/red-activity-led'),
            width = 14,
            height = 16,
            shift = util.by_pixel(8.5, -0.5)
        }
    },
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
