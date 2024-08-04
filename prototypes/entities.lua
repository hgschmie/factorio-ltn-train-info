------------------------------------------------------------------------
-- Prototype for the LTN train info combinator
------------------------------------------------------------------------

local const = require('lib.constants')

local lti = table.deepcopy(data.raw['constant-combinator']['constant-combinator'])
lti.name = const.lti_train_info

lti.minable = { mining_time = 0.1, result = const.lti_train_info }
lti.activity_led_light.intensity = 1.0

local tint = { r = 0, g = 0.8, b = 0.4, a = 1 }
for _, directions in pairs { 'north', 'south', 'east', 'west' } do
    lti.sprites[directions].layers[1].tint = tint
    lti.sprites[directions].layers[1].hr_version.tint = tint
end

lti.radius_visualisation_specification = {
    priority = "extra-high-no-scale",
    distance = const.lti_range + 0.5,
    offset = { 0, 0 },
    sprite = {
        filename = const:png('train-info-radius-visualization'),
        height = 12,
        width = 12
    }
}

data:extend { lti }

------------------------------------------------------------------------

local lti_item = table.deepcopy(data.raw.item['constant-combinator']) --[[@as data.ItemPrototype]]
lti_item.name = const.lti_train_info
lti_item.place_result = const.lti_train_info
lti_item.icon = nil
lti_item.icons = {
    {
        icon = '__base__/graphics/icons/constant-combinator.png',
        icon_size = 64,
        tint = tint,
        icon_mipmaps = 4,
    }
}

lti_item.flags = { 'mod-openable' }
lti_item.order = 'c[combinators]-b[ltn-train-info]'

local lti_recipe = table.deepcopy(data.raw.recipe['constant-combinator']) --[[@as data.RecipePrototype]]
lti_recipe.name = const.lti_train_info
lti_recipe.result = const.lti_train_info
lti_recipe.order = lti_item.order

data:extend { lti_item, lti_recipe }

table.insert(data.raw['technology']['logistic-train-network'].effects, { type = 'unlock-recipe', recipe = const.lti_train_info })
