-- Optional test harness: prints logical/runtime mappings and client load state.
-- Safe to remove from meta.xml on production servers.

addCommandHandler("newmodelclient", function()
    local catalog = exports.newmodels_neon:getClientCatalog()
    if type(catalog) ~= "table" or #catalog == 0 then
        outputChatBox("[newmodels_neon] no catalog entries.", 255, 190, 80)
        return
    end

    for i = 1, #catalog do
        local entry = catalog[i]
        local runtimeId = engineGetModelRuntimeID(entry.logicalId)
        local reverseId = runtimeId and engineGetModelServerID(runtimeId) or false
        local loadState = exports.newmodels_neon:isModelLoaded(entry.logicalId)
        outputChatBox((
            "%s: logical=%s runtime=%s reverse=%s loaded=%s"
        ):format(
            entry.qualifiedName,
            tostring(entry.logicalId),
            tostring(runtimeId),
            tostring(reverseId),
            tostring(loadState and runtimeId or false)
        ), 120, 220, 255)
    end
end)
