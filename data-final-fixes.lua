------------------------------------------------------------------------
-- data phase 3
------------------------------------------------------------------------

require('lib.init')
local const = require('lib.constants')

-- 20 is a fudge factor to account for some modules adding items in their final-fixes stage
local count = 20;

-- There are modules that add items late in the init stage (data-updates).
-- Create the final count of all items at the very latest state of the data initialization.
for _, info in pairs(data.raw) do
    for _, item in pairs(info) do
        if (item.stack_size or item.type == 'fluid') then
            count = count + 1
        end
    end
end

-- round up
count = 10 * math.ceil(count / 10)

data.raw['constant-combinator'][const.lti_train_info].item_slot_count = count

--------------------------------------------------------------------------------

require('framework.other-mods').data_final_fixes()
