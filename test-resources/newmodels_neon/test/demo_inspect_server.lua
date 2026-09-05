-- Optional test harness: prints registered logical model IDs on the server.
-- Safe to remove from meta.xml on production servers.

addCommandHandler("newmodelinfo", function(player)
    local catalog = exports[NEWMODELS_RESOURCE]:getModelCatalog()
    local lines = {}
    for i = 1, #catalog do
        local entry = catalog[i]
        lines[#lines + 1] = ("%s=%d parent=%d"):format(entry.qualifiedName, entry.logicalId, entry.parent)
    end
    if #lines == 0 then
        outputChatBox("[newmodels_neon] no models registered.", player, 255, 190, 80)
        return
    end
    outputChatBox("[newmodels_neon] " .. table.concat(lines, " | "), player, 120, 220, 255)
end)
