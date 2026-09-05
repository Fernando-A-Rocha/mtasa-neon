NEWMODELS_RESOURCE = "newmodels_neon"
MODELS_ROOT = "models"
VALID_MODEL_TYPES = { "vehicle", "object", "ped" }

DEFAULT_SETTINGS = {
    lodDistance = false,
    enableDFFAlphaTransparency = false,
    disableTXDTextureFiltering = false,
}

function newmodelsLog(message, level)
    outputDebugString("[" .. NEWMODELS_RESOURCE .. "] " .. message, level or 3)
end

function newmodelsQualifyName(resourceName, name)
    if not name or name == "" then
        return false
    end
    if name:find(":", 1, true) then
        return name
    end
    return resourceName .. ":" .. name
end

function newmodelsJoinPath(base, relative)
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
            settings[key] = newmodelsJoinPath(folderPath, assetPath)
        end
        return true
    end

    return true
end

function newmodelsParseSettings(filePath, folderPath)
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

function newmodelsNormalizeAssets(folderPath, folderName, assets, settings)
    local normalized = {
        dff = assets.dff,
        txd = assets.txd or settings.txd,
        col = assets.col or settings.col,
    }

    if settings.dff then
        normalized.dff = settings.dff
    end

    for assetType, path in pairs(normalized) do
        if path and not path:find("^models/") then
            normalized[assetType] = newmodelsJoinPath(folderPath, path)
        end
    end

    if not normalized.dff then
        normalized.dff = folderPath .. "/model.dff"
        if not fileExists(normalized.dff) then
            normalized.dff = folderPath .. "/" .. folderName .. ".dff"
        end
    end

    if not normalized.txd then
        local localTxd = folderPath .. "/model.txd"
        if fileExists(localTxd) then
            normalized.txd = localTxd
        end
    end

    if not normalized.col then
        local localCol = folderPath .. "/model.col"
        if fileExists(localCol) then
            normalized.col = localCol
        elseif fileExists(folderPath .. "/" .. folderName .. ".col") then
            normalized.col = folderPath .. "/" .. folderName .. ".col"
        end
    end

    return normalized
end
