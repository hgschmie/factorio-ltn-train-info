------------------------------------------------------------------------
-- runtime code
------------------------------------------------------------------------

require('lib.init')

-- setup events
require('scripts.event-setup')

-- other mods code
require('framework.other-mods').runtime()
