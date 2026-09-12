-- Client asset loader only. Defaults live here so the client never downloads
-- server folder-scan / settings-parsing helpers it cannot use.

local DEFAULT_SETTINGS = {
    lodDistance = false,
    enableDFFAlphaTransparency = false,
    disableTXDTextureFiltering = false,
    -- nil/false means do not call setVehicleModelWheelSize; GTA keeps the
    -- parent automobile default (usually around 0.7).
    wheelSizeFront = false,
    wheelSizeRear = false,
}

local catalog = {}
local loaded = {}
local pollTimer = false

local function logMessage(message, level)
    outputDebugString("[newmodels_neon] " .. message, level or 3)
end

local function getSetting(settings, key)
    if settings and settings[key] ~= nil then
        return settings[key]
    end
    return DEFAULT_SETTINGS[key]
end

-- set/getVehicleModelWheelSize raise on invalid model or size instead of returning false.
local function callModelWheelSize(fn, runtimeId, ...)
    local ok, result = pcall(fn, runtimeId, ...)
    if not ok then
        return false, result
    end
    return true, result
end

local function captureWheelSizes(runtimeId)
    local ok, sizes = callModelWheelSize(getVehicleModelWheelSize, runtimeId, "all_wheels")
    if ok and type(sizes) == "table" then
        return sizes
    end
    return nil
end

local function restoreWheelSizes(runtimeId, original)
    if not original then
        return
    end
    local front = original.front_axle
    local rear = original.rear_axle
    if type(front) == "number" and front > 0 then
        callModelWheelSize(setVehicleModelWheelSize, runtimeId, "front_axle", front)
    end
    if type(rear) == "number" and rear > 0 then
        callModelWheelSize(setVehicleModelWheelSize, runtimeId, "rear_axle", rear)
    end
end

-- Wheel size can only be set clientside, and the native wants this client's
-- vehicle model ID (the runtime slot), not the server logical ID.
local function applyVehicleWheelSize(runtimeId, settings)
    local front = getSetting(settings, "wheelSizeFront")
    local rear = getSetting(settings, "wheelSizeRear")
    local setFront = type(front) == "number" and front > 0
    local setRear = type(rear) == "number" and rear > 0
    if not setFront and not setRear then
        return nil
    end

    local original = captureWheelSizes(runtimeId)

    local function setGroup(wheelGroup, wheelSize)
        local ok, result = callModelWheelSize(setVehicleModelWheelSize, runtimeId, wheelGroup, wheelSize)
        if not ok then
            logMessage(
                "setVehicleModelWheelSize(" ..
                wheelGroup .. ") failed for runtime model " .. runtimeId .. ": " .. tostring(result),
                1
            )
        end
    end

    if setFront and setRear and front == rear then
        setGroup("all_wheels", front)
    else
        if setFront then
            setGroup("front_axle", front)
        end
        if setRear then
            setGroup("rear_axle", rear)
        end
    end

    return original
end

local function unloadModel(logicalId)
    local state = loaded[logicalId]
    if not state then
        return
    end

    local runtimeId = engineGetModelRuntimeID(logicalId)
    if runtimeId then
        restoreWheelSizes(runtimeId, state.originalWheelSize)
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
    if not assets.dff and not assets.txd and not assets.col then
        logMessage("catalog entry has no replaceable assets: " .. entry.qualifiedName, 1)
        return false
    end

    local colElement, txdElement, dffElement

    if assets.col then
        colElement = engineLoadCOL(assets.col)
        if not colElement then
            logMessage("engineLoadCOL failed for logical model " .. logicalId .. " (" .. assets.col .. ")", 1)
            return false
        end
        if not engineReplaceCOL(colElement, runtimeId) then
            destroyElement(colElement)
            logMessage("engineReplaceCOL failed for logical model " .. logicalId, 1)
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
            logMessage("engineLoadTXD failed for logical model " .. logicalId .. " (" .. assets.txd .. ")", 1)
            return false
        end
        if not engineImportTXD(txdElement, runtimeId) then
            destroyElement(txdElement)
            if colElement then
                engineRestoreCOL(runtimeId)
                destroyElement(colElement)
            end
            logMessage("engineImportTXD failed for logical model " .. logicalId, 1)
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
            logMessage("engineLoadDFF failed for logical model " .. logicalId .. " (" .. assets.dff .. ")", 1)
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
            logMessage("engineReplaceModel failed for logical model " .. logicalId, 1)
            return false
        end
    end

    local lodDistance = getSetting(settings, "lodDistance")
    if type(lodDistance) == "number" then
        engineSetModelLODDistance(runtimeId, lodDistance)
    end

    local originalWheelSize
    if entry.type == "vehicle" then
        originalWheelSize = applyVehicleWheelSize(runtimeId, settings)
    end

    loaded[logicalId] = {
        runtimeId = runtimeId,
        colElement = colElement,
        txdElement = txdElement,
        dffElement = dffElement,
        qualifiedName = entry.qualifiedName,
        originalWheelSize = originalWheelSize,
    }

    return true
end

local function unloadMissingModels()
    local active = {}
    for i = 1, #catalog do
        active[catalog[i].logicalId] = true
    end

    for logicalId in pairs(loaded) do
        if not active[logicalId] then
            unloadModel(logicalId)
        end
    end
end

local function tryLoadAll()
    local pending = 0
    for i = 1, #catalog do
        if not applyModel(catalog[i]) then
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

-- Runtime ID mapping is engineGetModelRuntimeID / engineGetModelServerID.
-- These exports only expose this resource's load/catalog state.

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
