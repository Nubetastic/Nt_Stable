local testWagon = 0
local testHorse = 0

local TestWagons = {
    [1] = { model = 'cart01', horseCount = 1 },
    [2] = { model = 'wagon02x', horseCount = 2 },
    [3] = { model = 'coach2', horseCount = 4 },
}

local function DeleteWagonTest()
    if testWagon ~= 0 and DoesEntityExist(testWagon) then
        Citizen.InvokeNative(0xB32A5813C7F87B09, testWagon)
        SetEntityAsMissionEntity(testWagon, true, true)
        DeleteVehicle(testWagon)
        if DoesEntityExist(testWagon) then DeleteEntity(testWagon) end
    end

    if testHorse ~= 0 and DoesEntityExist(testHorse) then
        SetEntityAsMissionEntity(testHorse, true, true)
        DeletePed(testHorse)
        if DoesEntityExist(testHorse) then DeleteEntity(testHorse) end
    end

    testWagon = 0
    testHorse = 0
end

RegisterCommand('WHtest', function(_, args)
    local wagonType = tonumber(args[1])
    local slotNumber = tonumber(args[2])
    local wagonTest = TestWagons[wagonType]

    if not wagonTest or not slotNumber or slotNumber % 1 ~= 0 or slotNumber < 1 or slotNumber > wagonTest.horseCount then
        lib.notify({
            title = 'Usage: /WHtest [wagon type] [horse slot]',
            description = 'Example: /WHtest 1 1',
            type = 'error',
            duration = 10000,
        })
        return
    end

    local horseData = lib.callback.await('nt_stables:server:getActiveHorse', false)
    if not horseData then
        lib.notify({ title = 'Set a riding horse before running this test.', type = 'error', duration = 10000 })
        return
    end

    DeleteWagonTest()

    local wagonHash = joaat(wagonTest.model)
    local horseHash = joaat(horseData.horse)
    local timeout = GetGameTimer() + 10000
    RequestModel(wagonHash, false)
    RequestModel(horseHash, false)
    while (not HasModelLoaded(wagonHash) or not HasModelLoaded(horseHash)) and GetGameTimer() < timeout do Wait(0) end

    if not HasModelLoaded(wagonHash) or not HasModelLoaded(horseHash) then
        lib.notify({ title = 'Failed to load the wagon or horse model.', type = 'error', duration = 10000 })
        return
    end

    local playerCoords = GetEntityCoords(cache.ped)
    local _, wagonCoords = GetClosestVehicleNode(playerCoords.x - 15.0, playerCoords.y, playerCoords.z, 0, 3.0, 0.0)
    testWagon = CreateVehicle(wagonHash, wagonCoords.x, wagonCoords.y, wagonCoords.z, GetEntityHeading(cache.ped), false, false, false, false)
    SetModelAsNoLongerNeeded(wagonHash)

    if testWagon == 0 or not DoesEntityExist(testWagon) then
        testWagon = 0
        SetModelAsNoLongerNeeded(horseHash)
        lib.notify({ title = 'Failed to spawn the test wagon.', type = 'error', duration = 10000 })
        return
    end

    SetEntityAsMissionEntity(testWagon, true, true)
    Citizen.InvokeNative(0x7263332501E07F52, testWagon, true)

    local harnessIndex = slotNumber - 1
    local defaultHorse = 0
    timeout = GetGameTimer() + 5000
    while GetGameTimer() < timeout do
        defaultHorse = Citizen.InvokeNative(0xA8BA0BAE0173457B, testWagon, harnessIndex, Citizen.ResultAsInteger())
        if defaultHorse ~= 0 and DoesEntityExist(defaultHorse) then break end
        Wait(100)
    end

    if defaultHorse == 0 or not DoesEntityExist(defaultHorse) then
        SetModelAsNoLongerNeeded(horseHash)
        lib.notify({ title = ('No horse was found in slot %d.'):format(slotNumber), type = 'error', duration = 10000 })
        return
    end

    local horseCoords = GetEntityCoords(defaultHorse)
    local horseHeading = GetEntityHeading(defaultHorse)

    Citizen.InvokeNative(0x4402960666000E62, testWagon, harnessIndex)
    SetEntityAsMissionEntity(defaultHorse, true, true)
    DeletePed(defaultHorse)
    if DoesEntityExist(defaultHorse) then DeleteEntity(defaultHorse) end

    testHorse = CreatePed(horseHash, horseCoords.x, horseCoords.y, horseCoords.z, horseHeading, false, true, true, true)
    SetModelAsNoLongerNeeded(horseHash)

    if testHorse == 0 or not DoesEntityExist(testHorse) then
        testHorse = 0
        lib.notify({ title = 'Failed to spawn the riding horse.', type = 'error', duration = 10000 })
        return
    end

    SetEntityAsMissionEntity(testHorse, true, true)
    SetRandomOutfitVariation(testHorse, true)
    SetBlockingOfNonTemporaryEvents(testHorse, true)
    SetPedPromptName(testHorse, horseData.name)

    for _, category in ipairs(ConfigStables.Customization) do
        if ConfigStables.RidingHorseComponents[category.key] then
            Citizen.InvokeNative(0xD710A5007C2AC539, testHorse, category.categoryHash, 0)
        end
    end
    Citizen.InvokeNative(0x1902C4CFCC5BE57C, testHorse, ConfigStables.WagonHorse.HarnessOutfit)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, testHorse, false, true, true, true, false)
    SetEntityVisible(testHorse, true)
    ResetEntityAlpha(testHorse)

    Citizen.InvokeNative(0x316CDB5B6E8F4110, testHorse, testWagon, harnessIndex)
    Wait(250)

    local attachedHorse = Citizen.InvokeNative(0xA8BA0BAE0173457B, testWagon, harnessIndex, Citizen.ResultAsInteger())
    if attachedHorse ~= testHorse then
        DeletePed(testHorse)
        if DoesEntityExist(testHorse) then DeleteEntity(testHorse) end
        testHorse = 0
        lib.notify({ title = ('Failed to attach the riding horse to slot %d.'):format(slotNumber), type = 'error', duration = 10000 })
        return
    end

    print(('WHtest: %s replaced slot %d with %s using harness outfit 0xC81D2897.'):format(
        wagonTest.model,
        slotNumber,
        horseData.name
    ))
    lib.notify({
        title = ('%s attached to wagon slot %d.'):format(horseData.name, slotNumber),
        description = 'Harness outfit: 0xC81D2897',
        type = 'success',
        duration = 10000,
    })
end, false)

RegisterCommand('WHtestclear', DeleteWagonTest, false)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    DeleteWagonTest()
end)
