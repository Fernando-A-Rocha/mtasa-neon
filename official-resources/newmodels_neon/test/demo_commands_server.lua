-- Optional test harness: /newmodelspawn and /newmodelinfo.
-- Safe to remove from meta.xml on production servers that supply their own models/ tree.

local function describeVanillaModel(modelId, modelType)
    if modelType == "vehicle" then
        local vehicleName = getVehicleNameFromModel(modelId)
        if vehicleName and vehicleName ~= "" then
            return vehicleName .. " (" .. modelId .. ")"
        end
    end
    return tostring(modelId)
end

local function resolveCustomModel(identifier)
    local logicalId = engineGetModelIDFromName(identifier)
    if not logicalId and not identifier:find(":", 1, true) then
        logicalId = engineGetModelIDFromName(getResourceName(resource) .. ":" .. identifier)
    end
    if not logicalId then
        return false
    end

    local name = engineGetModelName(logicalId) or identifier
    local modelType = engineGetModelType(logicalId) or "object"
    return {
        model = logicalId,
        type = modelType,
        label = getResourceName(resource) .. ":" .. name,
        source = "custom",
    }
end

local function resolveSpawnModel(identifier)
    if not identifier or identifier == "" then
        return false, "usage: /newmodelspawn <custom-name|model-id|vehicle-name>"
    end

    local custom = resolveCustomModel(identifier)
    if custom then
        return custom
    end

    local numericId = tonumber(identifier)
    if numericId then
        local vehicleName = getVehicleNameFromModel(numericId)
        if vehicleName and vehicleName ~= "" then
            return {
                model = numericId,
                type = "vehicle",
                label = vehicleName .. " (" .. numericId .. ")",
                source = "vanilla",
            }
        end
        if numericId >= 400 and numericId <= 611 then
            return {
                model = numericId,
                type = "vehicle",
                label = tostring(numericId),
                source = "vanilla",
            }
        end
        if numericId >= 0 and numericId <= 312 then
            return {
                model = numericId,
                type = "ped",
                label = tostring(numericId),
                source = "vanilla",
            }
        end
        return {
            model = numericId,
            type = "object",
            label = tostring(numericId),
            source = "vanilla",
        }
    end

    local vehicleId = getVehicleModelFromName(identifier)
    if vehicleId then
        return {
            model = vehicleId,
            type = "vehicle",
            label = getVehicleNameFromModel(vehicleId) .. " (" .. vehicleId .. ")",
            source = "vanilla",
        }
    end

    return false, "unknown model '" .. identifier .. "'; try /newmodelinfo for custom models"
end

local function spawnResolvedModel(player, resolved)
    local x, y, z = getElementPosition(player)
    local spawnX = x + 2
    local element

    if resolved.type == "vehicle" then
        element = createVehicle(resolved.model, spawnX, y, z)
    elseif resolved.type == "ped" then
        element = createPed(resolved.model, spawnX, y, z, 0)
    else
        element = createObject(resolved.model, spawnX, y, z)
    end

    if not element then
        return false, ("failed to create %s as %s"):format(resolved.label, resolved.type)
    end

    if resolved.source == "custom" then
        return true, ("%s logical=%d parent=%d"):format(
            resolved.label,
            resolved.model,
            engineGetModelParent(resolved.model)
        )
    end

    return true, ("%s %s=%s"):format(
        resolved.type,
        resolved.type == "vehicle" and describeVanillaModel(resolved.model, "vehicle") or resolved.label,
        tostring(getElementModel(element))
    )
end

addCommandHandler("newmodelspawn", function(player, _, modelName)
    if not isElement(player) then
        return
    end

    local resolved, reason = resolveSpawnModel(modelName)
    if not resolved then
        outputChatBox("[newmodels_neon] " .. reason, player, 255, 120, 80)
        return
    end

    local ok, details = spawnResolvedModel(player, resolved)
    if not ok then
        outputChatBox("[newmodels_neon] " .. details, player, 255, 80, 80)
        return
    end

    outputChatBox("[newmodels_neon] spawned " .. details, player, 120, 220, 255)
end)

addCommandHandler("newmodelinfo", function(player)
    local catalog = exports.newmodels_neon:getModelCatalog()
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
