-- Optional test harness: prints logical/runtime mappings and client load state.
-- Safe to remove from meta.xml on production servers.

addCommandHandler("newmodelclient", function()
    local catalog = getElementData(resourceRoot, "newmodels_neon.catalog")
    if type(catalog) ~= "table" or #catalog == 0 then
        outputChatBox("[newmodels_neon] no catalog entries.", 255, 190, 80)
        return
    end

    for _, entry in ipairs(catalog) do
        local runtimeId = engineGetModelRuntimeID(entry.logicalId)
        local reverseId = runtimeId and engineGetModelServerID(runtimeId) or false
        local loadState = exports[NEWMODELS_RESOURCE]:isModelLoaded(entry.logicalId)
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
