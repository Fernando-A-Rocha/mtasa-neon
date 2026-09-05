-- Optional test harness: spawns bundled example models for manual verification.
-- Safe to remove from meta.xml on production servers that supply their own models/ tree.

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

local function clearDemoElements()
    for _, element in ipairs(demoElements) do
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
    local faggioId = shouldWarp and exports[NEWMODELS_RESOURCE]:getModelId("demo_faggio") or false
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
