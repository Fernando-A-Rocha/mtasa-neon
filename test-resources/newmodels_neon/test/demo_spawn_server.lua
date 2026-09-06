-- Optional test harness: spawns one model by custom name, MTA model ID, or vehicle name.
-- Safe to remove from meta.xml on production servers that supply their own models/ tree.

local demoElements = {}

local function clearDemoElements()
    for i = 1, #demoElements do
        local element = demoElements[i]
        if isElement(element) then
            destroyElement(element)
        end
    end
    demoElements = {}
end

local function describeVanillaModel(modelId, modelType)
    if modelType == "vehicle" then
        local vehicleName = getVehicleNameFromModel(modelId)
        if vehicleName and vehicleName ~= "" then
            return vehicleName .. " (" .. modelId .. ")"
        end
    end
    return tostring(modelId)
end

local function resolveSpawnModel(identifier)
    if not identifier or identifier == "" then
        return false, "usage: /newmodelspawn <custom-name|model-id|vehicle-name>"
    end

    if identifier == "all" then
        return false, "spawn one model at a time; use /newmodelinfo to list custom models"
    end

    local customId = exports[NEWMODELS_RESOURCE]:getModelId(identifier)
    if customId then
        local definition = exports[NEWMODELS_RESOURCE]:getModelDefinition(identifier)
        if not definition then
            definition = exports[NEWMODELS_RESOURCE]:getModelDefinition(customId)
        end
        return {
            model = customId,
            type = definition and definition.type or "object",
            label = definition and definition.qualifiedName or identifier,
            source = "custom",
        }
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
    local offset = #demoElements * 3
    local spawnX = x + 2 + offset
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

    demoElements[#demoElements + 1] = element

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

addEventHandler("onResourceStop", resourceRoot, function()
    clearDemoElements()
end)

addCommandHandler("newmodelspawn", function(player, _, modelName)
    if not isElement(player) then
        return
    end

    local resolved, reason = resolveSpawnModel(modelName)
    if not resolved then
        outputChatBox("[newmodels_neon] " .. reason, player, 255, 120, 80)
        return
    end

    clearDemoElements()

    local ok, details = spawnResolvedModel(player, resolved)
    if not ok then
        outputChatBox("[newmodels_neon] " .. details, player, 255, 80, 80)
        return
    end

    outputChatBox("[newmodels_neon] spawned " .. details, player, 120, 220, 255)
end)
