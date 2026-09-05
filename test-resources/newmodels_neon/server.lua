local catalogByName = {}
local catalogByLogicalId = {}
local demoElements = {}

local DEMO_MODELS = {
    { name = "demo_crate", create = function(logicalId, x, y, z)
        return createObject(logicalId, x, y, z)
    end },
    { name = "small_box", create = function(logicalId, x, y, z)
        return createObject(logicalId, x, y, z)
    end },
    { name = "demo_gangster", create = function(logicalId, x, y, z)
        return createPed(logicalId, x, y, z, 180)
    end },
    { name = "demo_faggio", create = function(logicalId, x, y, z)
        return createVehicle(logicalId, x, y, z)
    end },
    { name = "demo_hydra", create = function(logicalId, x, y, z)
        return createVehicle(logicalId, x, y, z + 1)
    end },
}

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

local function publishCatalog()
    local clientCatalog = buildClientCatalog()
    setElementData(resourceRoot, "newmodels_neon.catalog", clientCatalog, false)
    triggerClientEvent(root, "newmodels_neon:catalog", resourceRoot, clientCatalog)
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

    for _, definition in ipairs(discovered) do
        local logicalId, reason = registerDefinition(definition, resource)
        if not logicalId then
            return false, reason
        end
    end

    return true, countOrReason
end

local function sendCatalogToPlayer(player)
    triggerClientEvent(player, "newmodels_neon:catalog", resourceRoot, buildClientCatalog())
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

function registerModels(modelList)
    local ownerResource = sourceResource or resource
    local ownerName = getResourceName(ownerResource)
    if type(modelList) ~= "table" then
        return false, "expected a table of model definitions"
    end

    local registered = {}
    for index, definition in ipairs(modelList) do
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

    publishCatalog()
    return true, registered
end

addEventHandler("onResourceStart", resourceRoot, function()
    local ok, details = loadScannedModels()
    if not ok then
        outputDebugString("[" .. NEWMODELS_RESOURCE .. "] failed to load models: " .. tostring(details), 1)
        cancelEvent(true)
        return
    end

    publishCatalog()
    outputServerLog(("[%s] ready with %d model(s), %d logical slot(s) remaining"):format(
        NEWMODELS_RESOURCE,
        details,
        engineGetModelAvailableCount()
    ))
end)

addEventHandler("onPlayerResourceStart", root, function(startedResource)
    if startedResource == resource then
        sendCatalogToPlayer(source)
    end
end)

local function clearDemoElements()
    for _, element in ipairs(demoElements) do
        if isElement(element) then
            destroyElement(element)
        end
    end
    demoElements = {}
end

local function spawnDemoModel(player, demo)
    local logicalId = getModelId(demo.name)
    if not logicalId then
        return false, demo.name .. " is not registered"
    end

    local x, y, z = getElementPosition(player)
    local offset = (#demoElements + 1) * 3
    local element = demo.create(logicalId, x + offset, y, z)
    if not element then
        return false, ("failed to create %s (logical %d)"):format(demo.name, logicalId)
    end

    demoElements[#demoElements + 1] = element
    return true, ("%s logical=%d parent=%d"):format(
        demo.name,
        logicalId,
        engineGetModelParent(logicalId)
    )
end

addEventHandler("onResourceStop", resourceRoot, function()
    clearDemoElements()
end)

addCommandHandler("newmodelspawn", function(player, modelName)
    if not isElement(player) then
        return
    end

    clearDemoElements()

    local targets = DEMO_MODELS
    if modelName and modelName ~= "" and modelName ~= "all" then
        targets = {}
        for _, demo in ipairs(DEMO_MODELS) do
            if demo.name == modelName then
                targets[#targets + 1] = demo
            end
        end
        if #targets == 0 then
            outputChatBox("[newmodels_neon] unknown demo model: " .. modelName, player, 255, 120, 80)
            return
        end
    end

    local results = {}
    for _, demo in ipairs(targets) do
        local ok, details = spawnDemoModel(player, demo)
        if not ok then
            outputChatBox("[newmodels_neon] " .. details, player, 255, 80, 80)
            return
        end
        results[#results + 1] = details
    end

    local shouldWarp = not modelName or modelName == "" or modelName == "all" or modelName == "demo_faggio"
    local faggioId = shouldWarp and getModelId("demo_faggio") or false
    if faggioId then
        for _, element in ipairs(demoElements) do
            if isElement(element) and getElementType(element) == "vehicle" and getElementModel(element) == faggioId then
                warpPedIntoVehicle(player, element)
                break
            end
        end
    end

    outputChatBox("[newmodels_neon] spawned: " .. table.concat(results, " | "), player, 120, 220, 255)
end)

addCommandHandler("newmodelinfo", function(player)
    local lines = {}
    for _, entry in ipairs(buildClientCatalog()) do
        lines[#lines + 1] = ("%s=%d parent=%d"):format(entry.qualifiedName, entry.logicalId, entry.parent)
    end
    if #lines == 0 then
        outputChatBox("[newmodels_neon] no models registered.", player, 255, 190, 80)
        return
    end
    outputChatBox("[newmodels_neon] " .. table.concat(lines, " | "), player, 120, 220, 255)
end)
