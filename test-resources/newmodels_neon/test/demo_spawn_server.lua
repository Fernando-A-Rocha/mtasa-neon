-- Optional test harness: spawns bundled example models for manual verification.
-- Safe to remove from meta.xml on production servers that supply their own models/ tree.

local demoElements = {}
local WARP_VEHICLE = "schafter"
local WARP_FALLBACK = "demo_faggio"

local DEMO_MODELS = {
    { name = "demo_crate", create = function(logicalId, x, y, z)
        return createObject(logicalId, x, y, z)
    end },
    { name = "small_box", create = function(logicalId, x, y, z)
        return createObject(logicalId, x, y, z)
    end },
    { name = "engine_hoist", create = function(logicalId, x, y, z)
        return createObject(logicalId, x, y, z)
    end },
    { name = "wrecked_car_1", create = function(logicalId, x, y, z)
        return createObject(logicalId, x, y, z)
    end },
    { name = "wrecked_car_2", create = function(logicalId, x, y, z)
        return createObject(logicalId, x, y, z)
    end },
    { name = "demo_gangster", create = function(logicalId, x, y, z)
        return createPed(logicalId, x, y, z, 180)
    end },
    { name = "mafioso_1", create = function(logicalId, x, y, z)
        return createPed(logicalId, x, y, z, 180)
    end },
    { name = "mafioso_2", create = function(logicalId, x, y, z)
        return createPed(logicalId, x, y, z, 180)
    end },
    { name = "mafioso_3", create = function(logicalId, x, y, z)
        return createPed(logicalId, x, y, z, 180)
    end },
    { name = "demo_faggio", create = function(logicalId, x, y, z)
        return createVehicle(logicalId, x, y, z)
    end },
    { name = "demo_hydra", create = function(logicalId, x, y, z)
        return createVehicle(logicalId, x, y, z + 1)
    end },
    { name = "schafter", create = function(logicalId, x, y, z)
        return createVehicle(logicalId, x, y, z)
    end },
    { name = "landstalker_02", create = function(logicalId, x, y, z)
        return createVehicle(logicalId, x, y, z)
    end },
    { name = "landstalker_86", create = function(logicalId, x, y, z)
        return createVehicle(logicalId, x, y, z)
    end },
    { name = "landstalker_98", create = function(logicalId, x, y, z)
        return createVehicle(logicalId, x, y, z)
    end },
    { name = "sanchez_test", create = function(logicalId, x, y, z)
        return createVehicle(logicalId, x, y, z)
    end },
}

local function clearDemoElements()
    for i = 1, #demoElements do
        local element = demoElements[i]
        if isElement(element) then
            destroyElement(element)
        end
    end
    demoElements = {}
end

local function spawnDemoModel(player, demo)
    local logicalId = exports[NEWMODELS_RESOURCE]:getModelId(demo.name)
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

local function warpIntoDemoVehicle(player, vehicleName)
    local logicalId = exports[NEWMODELS_RESOURCE]:getModelId(vehicleName)
    if not logicalId then
        return false
    end

    for i = 1, #demoElements do
        local element = demoElements[i]
        if isElement(element) and getElementType(element) == "vehicle" and getElementModel(element) == logicalId then
            warpPedIntoVehicle(player, element)
            return true
        end
    end
    return false
end

addEventHandler("onResourceStop", resourceRoot, function()
    clearDemoElements()
end)

addCommandHandler("newmodelspawn", function(player, _, modelName)
    if not isElement(player) then
        return
    end

    clearDemoElements()

    local targets = DEMO_MODELS
    if modelName and modelName ~= "" and modelName ~= "all" then
        targets = {}
        for i = 1, #DEMO_MODELS do
            local demo = DEMO_MODELS[i]
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
    for i = 1, #targets do
        local ok, details = spawnDemoModel(player, targets[i])
        if not ok then
            outputChatBox("[newmodels_neon] " .. details, player, 255, 80, 80)
            return
        end
        results[#results + 1] = details
    end

    local shouldWarp = not modelName or modelName == "" or modelName == "all"
        or modelName == WARP_VEHICLE or modelName == WARP_FALLBACK
    if shouldWarp then
        if not warpIntoDemoVehicle(player, WARP_VEHICLE) then
            warpIntoDemoVehicle(player, WARP_FALLBACK)
        end
    end

    outputChatBox("[newmodels_neon] spawned: " .. table.concat(results, " | "), player, 120, 220, 255)
end)
