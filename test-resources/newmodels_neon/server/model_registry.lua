local models = {}
local names = {}
local clientCatalog = false
local syncedPlayers = {}

local function invalidateClientCatalog()
    clientCatalog = false
end

local function ensureClientCatalog()
    if clientCatalog then
        return clientCatalog
    end

    local catalog = {}
    for logicalId, entry in pairs(models) do
        catalog[#catalog + 1] = {
            logicalId = logicalId,
            type = entry.type,
            parent = entry.parent,
            name = entry.name,
            qualifiedName = entry.qualifiedName,
            assets = entry.assets,
            settings = entry.settings,
        }
    end
    table.sort(catalog, function(a, b)
        return a.logicalId < b.logicalId
    end)

    clientCatalog = catalog
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
    triggerClientEvent(player, "newmodels_neon:catalog", resourceRoot, ensureClientCatalog())
end

local function syncCatalogToReadyPlayers()
    local catalog = ensureClientCatalog()
    for player in pairs(syncedPlayers) do
        if isElement(player) then
            triggerClientEvent(player, "newmodels_neon:catalog", resourceRoot, catalog)
        else
            syncedPlayers[player] = nil
        end
    end
end

local function registerDefinition(definition, ownerResource)
    local qualifiedName = definition.qualifiedName
    if names[qualifiedName] or names[definition.name] then
        return false, "duplicate model name: " .. qualifiedName
    end

    local logicalId = engineRequestModel(definition.type, definition.parent, definition.name)
    if not logicalId then
        return false, "engineRequestModel failed for " .. qualifiedName
    end

    local assets = {}
    for assetType, path in pairs(definition.assets) do
        if path then
            if definition.sourceResource and definition.sourceResource ~= getResourceName(resource) then
                assets[assetType] = ":" .. definition.sourceResource .. "/" .. path
            else
                assets[assetType] = path
            end
        end
    end

    models[logicalId] = {
        logicalId = logicalId,
        type = definition.type,
        parent = definition.parent,
        name = definition.name,
        qualifiedName = qualifiedName,
        assets = assets,
        settings = definition.settings or {},
        ownerResource = ownerResource,
    }
    names[qualifiedName] = logicalId
    names[definition.name] = logicalId

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
        local logicalId, reason = registerDefinition(discovered[i], resource)
        if not logicalId then
            return false, reason
        end
    end

    invalidateClientCatalog()
    return true, countOrReason
end

function getModelId(name)
    return names[name] or false
end

function getModelDefinition(name)
    local logicalId = names[name]
    if not logicalId then
        return false
    end

    local entry = models[logicalId]
    return {
        logicalId = logicalId,
        type = entry.type,
        parent = entry.parent,
        name = entry.name,
        qualifiedName = entry.qualifiedName,
    }
end

function getModels(modelType)
    local results = {}
    for logicalId, entry in pairs(models) do
        if not modelType or entry.type == modelType then
            results[#results + 1] = logicalId
        end
    end
    table.sort(results)
    return results
end

function getModelCatalog()
    return ensureClientCatalog()
end

function registerModels(modelList)
    local ownerResource = sourceResource or resource
    local ownerName = getResourceName(ownerResource)
    if type(modelList) ~= "table" then
        return false, "expected a table of model definitions"
    end

    local registered = {}
    for index = 1, #modelList do
        local normalized, reason = newmodelsNormalizeExternalDefinition(ownerName, modelList[index])
        if not normalized then
            return false, ("entry %d: %s"):format(index, reason)
        end
        local logicalId, registerReason = registerDefinition(normalized, ownerResource)
        if not logicalId then
            return false, ("entry %d: %s"):format(index, registerReason)
        end
        registered[#registered + 1] = logicalId
    end

    invalidateClientCatalog()
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
