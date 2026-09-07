-- Server-only model registry: folder scan, allocation, catalog sync, and exports.
-- Kept off the client so path/settings helpers and scan logic are never downloaded.

local RESOURCE_NAME = "newmodels_neon"
local MODELS_ROOT = "models"
local VALID_MODEL_TYPES = { "vehicle", "object", "ped" }
local VALID_MODEL_TYPE_LOOKUP = { vehicle = true, object = true, ped = true }

local models = {}
local names = {}
local clientCatalog = {}

local function qualifyName(resourceName, name)
    if not name or name == "" then
        return false
    end
    if name:find(":", 1, true) then
        return name
    end
    return resourceName .. ":" .. name
end

local function joinPath(base, relative)
    local combined = (base or "") .. "/" .. (relative or "")
    local parts = {}
    for part in combined:gmatch("[^/]+") do
        if part == ".." then
            table.remove(parts)
        elseif part ~= "." and part ~= "" then
            parts[#parts + 1] = part
        end
    end
    return table.concat(parts, "/")
end

local function parseSettingLine(line, settings, folderPath)
    line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if line == "" or line:sub(1, 1) == "#" then
        return true
    end

    if line == "enableDFFAlphaTransparency" then
        settings.enableDFFAlphaTransparency = true
        return true
    end
    if line == "disableTXDTextureFiltering" then
        settings.disableTXDTextureFiltering = true
        return true
    end

    local key, value = line:match("^(%w+)=(.+)$")
    if not key then
        return true
    end

    if key == "lodDistance" then
        settings.lodDistance = tonumber(value)
        return settings.lodDistance ~= nil
    end

    if key == "txd" or key == "dff" or key == "col" then
        local assetPath = value:gsub("\\", "/")
        if assetPath:find("^models/") then
            settings[key] = assetPath
        else
            settings[key] = joinPath(folderPath, assetPath)
        end
        return true
    end

    return true
end

local function parseSettings(filePath, folderPath)
    local file = fileOpen(filePath, true)
    if not file then
        return false, "cannot open settings file: " .. filePath
    end

    local contents = fileRead(file, fileGetSize(file))
    fileClose(file)
    if not contents then
        return false, "cannot read settings file: " .. filePath
    end

    local settings = {}
    for line in contents:gmatch("[^\n]+") do
        if not parseSettingLine(line, settings, folderPath) then
            return false, "invalid settings line in " .. filePath .. ": " .. line
        end
    end

    return settings
end

local function countAssets(assets)
    local count = 0
    if assets and assets.dff then
        count = count + 1
    end
    if assets and assets.txd then
        count = count + 1
    end
    if assets and assets.col then
        count = count + 1
    end
    return count
end

local function normalizeAssets(folderPath, folderName, assets, settings)
    local normalized = {
        dff = settings.dff or assets.dff,
        txd = settings.txd or assets.txd,
        col = settings.col or assets.col,
    }

    if not normalized.dff then
        local modelPath = folderPath .. "/model.dff"
        if fileExists(modelPath) then
            normalized.dff = modelPath
        elseif fileExists(folderPath .. "/" .. folderName .. ".dff") then
            normalized.dff = folderPath .. "/" .. folderName .. ".dff"
        end
    end

    if not normalized.txd then
        local modelPath = folderPath .. "/model.txd"
        if fileExists(modelPath) then
            normalized.txd = modelPath
        elseif fileExists(folderPath .. "/" .. folderName .. ".txd") then
            normalized.txd = folderPath .. "/" .. folderName .. ".txd"
        end
    end

    if not normalized.col then
        local modelPath = folderPath .. "/model.col"
        if fileExists(modelPath) then
            normalized.col = modelPath
        elseif fileExists(folderPath .. "/" .. folderName .. ".col") then
            normalized.col = folderPath .. "/" .. folderName .. ".col"
        end
    end

    for assetType, path in pairs(normalized) do
        if path and not path:find("^models/") then
            normalized[assetType] = joinPath(folderPath, path)
        end
    end

    if normalized.dff and not fileExists(normalized.dff) then
        normalized.dff = nil
    end
    if normalized.txd and not fileExists(normalized.txd) then
        normalized.txd = nil
    end
    if normalized.col and not fileExists(normalized.col) then
        normalized.col = nil
    end

    return normalized
end

local function isValidParent(modelType, parent)
    if modelType == "vehicle" then
        return parent >= 400 and parent <= 611
    end
    if modelType == "ped" then
        return parent >= 0 and parent <= 312
    end
    return parent >= 0 and parent <= 20000
end

local function collectModelFolder(modelType, parent, folderName, folderPath)
    local assets = {}
    local settings = {}

    local entries = pathListDir(folderPath) or {}
    for i = 1, #entries do
        local entry = entries[i]
        local entryPath = folderPath .. "/" .. entry
        if pathIsFile(entryPath) then
            local extension = entry:match("%.([^.]+)$")
            if extension == "dff" or extension == "txd" or extension == "col" then
                if entry == "model." .. extension or entry == folderName .. "." .. extension then
                    assets[extension] = entryPath
                end
            elseif extension == "txt" and entry == "settings.txt" then
                local parsedSettings, reason = parseSettings(entryPath, folderPath)
                if not parsedSettings then
                    return false, reason
                end
                settings = parsedSettings
            end
        end
    end

    local normalizedAssets = normalizeAssets(folderPath, folderName, assets, settings)
    if countAssets(normalizedAssets) == 0 then
        return false, "model folder must provide at least one DFF, TXD, or COL: " .. folderPath
    end
    if normalizedAssets.dff and not fileExists(normalizedAssets.dff) then
        return false, "DFF file not found for model folder: " .. folderPath
    end
    if normalizedAssets.txd and not fileExists(normalizedAssets.txd) then
        return false, "TXD file not found for model folder: " .. folderPath
    end
    if normalizedAssets.col and not fileExists(normalizedAssets.col) then
        return false, "COL file not found for model folder: " .. folderPath
    end

    return {
        type = modelType,
        parent = parent,
        name = folderName,
        assets = normalizedAssets,
        settings = settings,
    }
end

local function scanFolder(resourceName)
    local discovered = {}

    if not pathIsDirectory(MODELS_ROOT) then
        return discovered, 0
    end

    for i = 1, #VALID_MODEL_TYPES do
        local modelType = VALID_MODEL_TYPES[i]
        local typePath = MODELS_ROOT .. "/" .. modelType
        if pathIsDirectory(typePath) then
            local parentNames = pathListDir(typePath) or {}
            for j = 1, #parentNames do
                local parentName = parentNames[j]
                local parent = tonumber(parentName)
                if parent and isValidParent(modelType, parent) then
                    local parentPath = typePath .. "/" .. parentName
                    if pathIsDirectory(parentPath) then
                        local folderNames = pathListDir(parentPath) or {}
                        for k = 1, #folderNames do
                            local folderName = folderNames[k]
                            local folderPath = parentPath .. "/" .. folderName
                            if pathIsDirectory(folderPath) then
                                local definition, reason = collectModelFolder(modelType, parent, folderName, folderPath)
                                if not definition then
                                    return false, reason
                                end

                                definition.qualifiedName = qualifyName(resourceName, definition.name)
                                discovered[#discovered + 1] = definition
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(discovered, function(a, b)
        if a.type == b.type then
            if a.parent == b.parent then
                return a.name < b.name
            end
            return a.parent < b.parent
        end
        return a.type < b.type
    end)

    return discovered, #discovered
end

local function normalizeExternalDefinition(resourceName, definition)
    if type(definition) ~= "table" then
        return false, "model definition must be a table"
    end
    if not VALID_MODEL_TYPE_LOOKUP[definition.type or ""] then
        return false, "invalid model type: " .. tostring(definition.type)
    end
    if type(definition.parent) ~= "number" or not isValidParent(definition.type, definition.parent) then
        return false, "invalid parent model for type " .. tostring(definition.type)
    end
    if type(definition.name) ~= "string" or definition.name == "" then
        return false, "model name is required"
    end

    local function normalizePath(path)
        if not path then
            return nil
        end
        return path:gsub("\\", "/"):gsub("^/", "")
    end

    local assets = {
        dff = normalizePath(definition.dff),
        txd = normalizePath(definition.txd),
        col = normalizePath(definition.col),
    }
    if countAssets(assets) == 0 then
        return false, "at least one of dff, txd, or col is required"
    end

    return {
        type = definition.type,
        parent = definition.parent,
        name = definition.name,
        qualifiedName = qualifyName(resourceName, definition.name),
        assets = assets,
        settings = type(definition.settings) == "table" and definition.settings or {},
        sourceResource = resourceName,
    }
end

-- Catalog is rebuilt only when the registry changes (startup scan or registerModels).
-- getModelCatalog / player sync just read the cached table.
local function rebuildClientCatalog()
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
end

local function sendCatalogToPlayer(player)
    if not isElement(player) then
        return
    end
    triggerClientEvent(player, "newmodels_neon:catalog", resourceRoot, clientCatalog)
end

local function syncCatalogToPlayers()
    local players = getElementsByType("player")
    for i = 1, #players do
        sendCatalogToPlayer(players[i])
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

    return logicalId
end

local function loadScannedModels()
    local resourceName = getResourceName(resource)
    local discovered, countOrReason = scanFolder(resourceName)
    if discovered == false then
        return false, countOrReason
    end

    for i = 1, #discovered do
        local logicalId, reason = registerDefinition(discovered[i], resource)
        if not logicalId then
            return false, reason
        end
    end

    rebuildClientCatalog()
    return true, countOrReason
end

-- Name/id/type/parent listing use engine natives (engineGetModelIDFromName,
-- engineGetModelName, engineGetModelType, engineGetModelParent, engineGetModels).
-- This resource only exports asset-bearing catalog sync and registerModels.

function getModelCatalog()
    return clientCatalog
end

function registerModels(modelList)
    local ownerResource = sourceResource or resource
    local ownerName = getResourceName(ownerResource)
    if type(modelList) ~= "table" then
        return false, "expected a table of model definitions"
    end

    local registered = {}
    for index = 1, #modelList do
        local normalized, reason = normalizeExternalDefinition(ownerName, modelList[index])
        if not normalized then
            return false, ("entry %d: %s"):format(index, reason)
        end
        local logicalId, registerReason = registerDefinition(normalized, ownerResource)
        if not logicalId then
            return false, ("entry %d: %s"):format(index, registerReason)
        end
        registered[#registered + 1] = logicalId
    end

    rebuildClientCatalog()
    syncCatalogToPlayers()
    return true, registered
end

addEventHandler("onResourceStart", resourceRoot, function()
    local ok, details = loadScannedModels()
    if not ok then
        outputDebugString("[" .. RESOURCE_NAME .. "] failed to load models: " .. tostring(details), 1)
        cancelEvent(true)
        return
    end

    outputServerLog(("[%s] ready with %d model(s), %d logical slot(s) remaining"):format(
        RESOURCE_NAME,
        details,
        engineGetModelAvailableCount()
    ))
end)

-- First catalog push once this resource is running on the player's client.
-- Later registerModels updates broadcast to currently connected players; clients
-- that have not started the resource yet get the full catalog on join instead.
addEventHandler("onPlayerResourceStart", root, function(startedResource)
    if startedResource ~= resource then
        return
    end
    sendCatalogToPlayer(source)
end)
