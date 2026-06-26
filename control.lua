------------------------------------------------------------------------
-- runtime code
------------------------------------------------------------------------

This, Framework = require('lib.init')()

-- setup events
require('scripts.event-setup')

---@diagnostic disable-next-line: undefined-field
Framework.post_runtime_stage()
