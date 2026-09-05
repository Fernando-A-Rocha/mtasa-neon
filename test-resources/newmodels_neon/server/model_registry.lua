local catalogByName = {}
local catalogByLogicalId = {}
local syncedPlayers = {}

local function buildClientCatalog()
    local clientCatalog = {}
    for logicalId, entry in pairs(catalogByLogicalId) do
        clientCatalog[#clientCatalog + 1] = {
            logicalId = logicalId,
            type = entry.type,
            parent = entry.parent,
            name = entry.name,
            qualifiedName = entry.qualifiedName,
            assets = entry.clientAssets,
            settings = entry.settings,
        }
    end
    table.sort(clientCatalog, function(a, b)
        return a.logicalId < b.logicalId
    end)
    return clientCatalog
end

local function markPlayerSynced(player)
    syncedPlayers[player] = true
end

local function unmarkPlayerSynced(player)
    syncedPlayers[player] = nil
end

local function sendCatalogToPlayer(player)
    if not isElement(player) then
        return
    end
    triggerClientEvent(player, "newmodels_neon:catalog", resourceRoot, buildClientCatalog())
end

local function syncCatalogToReadyPlayers()
    for player in pairs(syncedPlayers) do
        if isElement(player) then
            sendCatalogToPlayer(player)
        else
            syncedPlayers[player] = nil
        end
    end
end

local function registerDefinition(definition, ownerResource)
    local qualifiedName = definition.qualifiedName
    if catalogByName[qualifiedName] then
        return false, "duplicate model name: " .. qualifiedName
    end

    local logicalId = engineRequestModel(definition.type, definition.parent, definition.name)
    if not logicalId then
        return false, "engineRequestModel failed for " .. qualifiedName
    end

    local clientAssets = {}
    for assetType, path in pairs(definition.assets) do
        if path then
            if definition.sourceResource and definition.sourceResource ~= getResourceName(resource) then
                clientAssets[assetType] = ":" .. definition.sourceResource .. "/" .. path
            else
                clientAssets[assetType] = path
            end
        end
    end

    local entry = {
        logicalId = logicalId,
        type = definition.type,
        parent = definition.parent,
        name = definition.name,
        qualifiedName = qualifiedName,
        ownerResource = ownerResource,
        assets = definition.assets,
        clientAssets = clientAssets,
        settings = definition.settings or {},
    }

    catalogByName[qualifiedName] = entry
    catalogByName[definition.name] = entry
    catalogByLogicalId[logicalId] = entry

    outputServerLog(("[%s] allocated %s (%s parent=%d) as logical model %d"):format(
        NEWMODELS_RESOURCE,
        qualifiedName,
        definition.type,
        definition.parent,
        logicalId
    ))

    return logicalId
end

local function loadScannedModels()
    local resourceName = getResourceName(resource)
    local discovered, countOrReason = newmodelsScanFolder(resourceName)
    if discovered == false then
        return false, countOrReason
    end

    for i = 1, #discovered do
        local definition = discovered[i]
        local logicalId, reason = registerDefinition(definition, resource)
        if not logicalId then
            return false, reason
        end
    end

    return true, countOrReason
end

function getModelId(name)
    local entry = catalogByName[name]
    return entry and entry.logicalId or false
end

function getModelDefinition(name)
    local entry = catalogByName[name]
    if not entry then
        return false
    end
    return {
        logicalId = entry.logicalId,
        type = entry.type,
        parent = entry.parent,
        name = entry.name,
        qualifiedName = entry.qualifiedName,
    }
end

function getModels(modelType)
    local results = {}
    for logicalId, entry in pairs(catalogByLogicalId) do
        if not modelType or entry.type == modelType then
            results[#results + 1] = logicalId
        end
    end
    table.sort(results)
    return results
end

function getModelCatalog()
    return buildClientCatalog()
end

function registerModels(modelList)
    local ownerResource = sourceResource or resource
    local ownerName = getResourceName(ownerResource)
    if type(modelList) ~= "table" then
        return false, "expected a table of model definitions"
    end

    local registered = {}
    for index = 1, #modelList do
        local definition = modelList[index]
        local normalized, reason = newmodelsNormalizeExternalDefinition(ownerName, definition)
        if not normalized then
            return false, ("entry %d: %s"):format(index, reason)
        end
        local logicalId, registerReason = registerDefinition(normalized, ownerResource)
        if not logicalId then
            return false, ("entry %d: %s"):format(index, registerReason)
        end
        registered[#registered + 1] = logicalId
    end

    syncCatalogToReadyPlayers()
    return true, registered
end

addEventHandler("onResourceStart", resourceRoot, function()
    local ok, details = loadScannedModels()
    if not ok then
        outputDebugString("[" .. NEWMODELS_RESOURCE .. "] failed to load models: " .. tostring(details), 1)
        cancelEvent(true)
        return
    end

    outputServerLog(("[%s] ready with %d model(s), %d logical slot(s) remaining"):format(
        NEWMODELS_RESOURCE,
        details,
        engineGetModelAvailableCount()
    ))
end)

addEventHandler("onPlayerResourceStart", root, function(startedResource)
    if startedResource ~= resource then
        return
    end

    -- Deliver the catalog only after this player's client has started the resource.
    markPlayerSynced(source)
    sendCatalogToPlayer(source)
end)

addEventHandler("onPlayerResourceStop", root, function(stoppedResource)
    if stoppedResource == resource then
        unmarkPlayerSynced(source)
    end
end)

addEventHandler("onPlayerQuit", root, function()
    unmarkPlayerSynced(source)
end)
