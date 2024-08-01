------------------------------------------------------------------------
-- styles
------------------------------------------------------------------------

local const = require('lib.constants')

local styles = data.raw['gui-style'].default

styles[const:with_prefix('delivery-settings')] = {
    type = 'frame_style',
    parent = 'container_invisible_frame_with_title',
    top_padding = 10,
}
