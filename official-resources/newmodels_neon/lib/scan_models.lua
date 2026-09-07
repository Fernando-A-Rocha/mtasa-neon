local VALID_MODEL_TYPE_LOOKUP = { vehicle = true, object = true, ped = true }

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
                local parsedSettings, reason = newmodelsParseSettings(entryPath, folderPath)
                if not parsedSettings then
                    return false, reason
                end
                settings = parsedSettings
            end
        end
    end

    local normalizedAssets = newmodelsNormalizeAssets(folderPath, folderName, assets, settings)
    if newmodelsCountAssets(normalizedAssets) == 0 then
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

function newmodelsScanFolder(resourceName)
    local discovered = {}
    local countByParent = {}

    if not pathIsDirectory(MODELS_ROOT) then
        return discovered, 0
    end

    for i = 1, #VALID_MODEL_TYPES do
        local modelType = VALID_MODEL_TYPES[i]
        local typePath = MODELS_ROOT .. "/" .. modelType
        if not pathIsDirectory(typePath) then
            -- continue
        else
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

                                countByParent[parent] = (countByParent[parent] or 0) + 1
                                definition.qualifiedName = newmodelsQualifyName(resourceName, definition.name)
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

function newmodelsNormalizeExternalDefinition(resourceName, definition)
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
    if newmodelsCountAssets(assets) == 0 then
        return false, "at least one of dff, txd, or col is required"
    end

    return {
        type = definition.type,
        parent = definition.parent,
        name = definition.name,
        qualifiedName = newmodelsQualifyName(resourceName, definition.name),
        assets = assets,
        settings = type(definition.settings) == "table" and definition.settings or {},
        sourceResource = resourceName,
    }
end
