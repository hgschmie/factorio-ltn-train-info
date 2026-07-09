----------------------------------------------------------------------------------------------------
-- Support for Remote APIs.
--
-- Must be defined in This.RemoteApis. If an API is present, finds scripts.remote-apis.<api-name> and calls
-- - runtime() in runtime phase
--
----------------------------------------------------------------------------------------------------

assert(Framework)

-- Factorio Framework 2 (ff2)

---@class ff2.RemoteApisManager
local RemoteApis = {
    runtime = function()
        assert(script)
        if not (This and This.remote_apis) then return end

        local Event = require('stdlib.event.event')

        for api_name, alias in pairs(This.remote_apis) do
            local api_support = require('lib.remote-apis.' .. alias)

            for _, event in pairs { 'on_load', 'on_init', 'on_configuration_changed' } do
                if api_support[event] then
                    Event[event](function()
                        if not remote.interfaces[api_name] then return end
                        api_support[event](api_name)
                    end, nil, nil, { framework = true })
                end
            end
        end
    end
}

local RemoteApis_mt = {
    __index = function(_, stage)
        return function() end
    end
}

setmetatable(RemoteApis, RemoteApis_mt)

return RemoteApis
