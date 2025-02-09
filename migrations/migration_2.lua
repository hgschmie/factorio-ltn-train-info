------------------------------------------------------------------------
-- data migration
------------------------------------------------------------------------

if not storage.lti_data then
    This.Lti:init()
end

if storage.last_stop then
    storage.last_stop = nil
    storage.lti_data.train_to_last_stop = {}
end

if storage.lti_data.stops then
    storage.lti_data.stops = nil
    storage.lti_data.stop_to_ltis = {}
end

for _, lti_data in pairs(This.Lti:allLtiData()) do
    lti_data.connected_stops = lti_data.connected_stops or {}
end
