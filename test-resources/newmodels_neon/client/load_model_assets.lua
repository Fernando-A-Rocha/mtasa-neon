local catalog = {}
local loaded = {}
local pollTimer = false

local function getSetting(settings, key)
    if settings and settings[key] ~= nil then
        return settings[key]
    end
    return DEFAULT_SETTINGS[key]
end

local function unloadModel(logicalId)
    local state = loaded[logicalId]
    if not state then
        return
    end

    local runtimeId = engineGetModelRuntimeID(logicalId)
    if runtimeId then
        engineRestoreCOL(runtimeId)
        engineRestoreModel(runtimeId)
    end

    if state.colElement and isElement(state.colElement) then
        destroyElement(state.colElement)
    end
    if state.txdElement and isElement(state.txdElement) then
        destroyElement(state.txdElement)
    end
    if state.dffElement and isElement(state.dffElement) then
        destroyElement(state.dffElement)
    end

    loaded[logicalId] = nil
end

local function applyModel(entry)
    local logicalId = entry.logicalId
    if loaded[logicalId] then
        return true
    end

    local runtimeId = engineGetModelRuntimeID(logicalId)
    if not runtimeId then
        return false
    end

    local settings = entry.settings or {}
    local assets = entry.assets or {}
    local colElement, txdElement, dffElement

    if assets.col then
        colElement = engineLoadCOL(assets.col)
        if not colElement then
            newmodelsLog("engineLoadCOL failed for logical model " .. logicalId .. " (" .. assets.col .. ")", 1)
            return false
        end
        if not engineReplaceCOL(colElement, runtimeId) then
            destroyElement(colElement)
            newmodelsLog("engineReplaceCOL failed for logical model " .. logicalId, 1)
            return false
        end
    end

    if assets.txd then
        local disableFiltering = getSetting(settings, "disableTXDTextureFiltering")
        txdElement = engineLoadTXD(assets.txd, disableFiltering and false or nil)
        if not txdElement then
            if colElement then
                engineRestoreCOL(runtimeId)
                destroyElement(colElement)
            end
            newmodelsLog("engineLoadTXD failed for logical model " .. logicalId .. " (" .. assets.txd .. ")", 1)
            return false
        end
        if not engineImportTXD(txdElement, runtimeId) then
            destroyElement(txdElement)
            if colElement then
                engineRestoreCOL(runtimeId)
                destroyElement(colElement)
            end
            newmodelsLog("engineImportTXD failed for logical model " .. logicalId, 1)
            return false
        end
    end

    if assets.dff then
        dffElement = engineLoadDFF(assets.dff)
        if not dffElement then
            if colElement then
                engineRestoreCOL(runtimeId)
                destroyElement(colElement)
            end
            if txdElement then
                destroyElement(txdElement)
            end
            newmodelsLog("engineLoadDFF failed for logical model " .. logicalId .. " (" .. assets.dff .. ")", 1)
            return false
        end

        local alphaFlag = getSetting(settings, "enableDFFAlphaTransparency") or nil
        if not engineReplaceModel(dffElement, runtimeId, alphaFlag) then
            destroyElement(dffElement)
            if colElement then
                engineRestoreCOL(runtimeId)
                destroyElement(colElement)
            end
            if txdElement then
                destroyElement(txdElement)
            end
            newmodelsLog("engineReplaceModel failed for logical model " .. logicalId, 1)
            return false
        end
    end

    local lodDistance = getSetting(settings, "lodDistance")
    if type(lodDistance) == "number" then
        engineSetModelLODDistance(runtimeId, lodDistance)
    end

    loaded[logicalId] = {
        runtimeId = runtimeId,
        colElement = colElement,
        txdElement = txdElement,
        dffElement = dffElement,
        qualifiedName = entry.qualifiedName,
    }

    triggerEvent("newmodels_neon:onModelLoaded", resourceRoot, logicalId, runtimeId, entry.qualifiedName)
    newmodelsLog(("loaded %s: logical=%d runtime=%d"):format(entry.qualifiedName, logicalId, runtimeId))
    return true
end

local function unloadMissingModels()
    local active = {}
    for _, entry in ipairs(catalog) do
        active[entry.logicalId] = true
    end

    for logicalId in pairs(loaded) do
        if not active[logicalId] then
            unloadModel(logicalId)
        end
    end
end

local function tryLoadAll()
    local pending = 0
    for _, entry in ipairs(catalog) do
        if not applyModel(entry) then
            pending = pending + 1
        end
    end

    if pending == 0 and isTimer(pollTimer) then
        killTimer(pollTimer)
        pollTimer = false
    elseif pending > 0 and not isTimer(pollTimer) then
        pollTimer = setTimer(tryLoadAll, 250, 0)
    end
end

local function setCatalog(newCatalog)
    catalog = type(newCatalog) == "table" and newCatalog or {}
    unloadMissingModels()
    tryLoadAll()
end

function getModelRuntimeId(logicalId)
    return engineGetModelRuntimeID(logicalId)
end

function isModelLoaded(logicalId)
    return loaded[logicalId] ~= nil
end

function getLoadedModels()
    local results = {}
    for logicalId, state in pairs(loaded) do
        results[#results + 1] = {
            logicalId = logicalId,
            runtimeId = state.runtimeId,
            qualifiedName = state.qualifiedName,
        }
    end
    table.sort(results, function(a, b)
        return a.logicalId < b.logicalId
    end)
    return results
end

function getClientCatalog()
    return catalog
end

addEvent("newmodels_neon:catalog", true)
addEventHandler("newmodels_neon:catalog", resourceRoot, function(newCatalog)
    setCatalog(newCatalog)
end, false)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isTimer(pollTimer) then
        killTimer(pollTimer)
        pollTimer = false
    end
    for logicalId in pairs(loaded) do
        unloadModel(logicalId)
    end
end)
