PlayerWagon = 0
PlayerWagonData = nil
PlayerWagonHorses = {}

local wagonBlip
local HorseComponents = lib.load('shared.horse_components')
local HorseStats = lib.load('shared.horse_stats')
local wagonTeamStats

local function ApplyPlayerWagonSpeed(inventoryWeight)
    if PlayerWagon == 0 or not DoesEntityExist(PlayerWagon) or not wagonTeamStats then return end

    local loadRatio = (inventoryWeight / 1000) / wagonTeamStats.pullCapacity
    local loadFactor = 1 / (1 + (Config.SpeedWeight.LoadPenalty * loadRatio * loadRatio))
    local finalSpeed = Config.SpeedWeight.WagonMaxSpeed * wagonTeamStats.driveFactor * loadFactor

    Citizen.InvokeNative(0x0E46A3FCBDE2A1B1, PlayerWagon, finalSpeed)
    for horse in pairs(PlayerWagonHorses) do
        if DoesEntityExist(horse) then
            Citizen.InvokeNative(0x0E46A3FCBDE2A1B1, horse, finalSpeed)
        end
    end
end

local function SetWagonTeamStats(wagonData)
    local totalSpeed = 0
    local totalStrength = 0

    for _, horseData in ipairs(wagonData.horses or {}) do
        local _, stats = HorseStats.Calculate(horseData)
        if not stats then
            print(('Nt_Stables: missing stats for wagon horse model %s.'):format(tostring(horseData.horse)))
            wagonTeamStats = nil
            return
        end

        totalSpeed = totalSpeed + stats.speed
        totalStrength = totalStrength + stats.strength
    end

    local horseCount = #(wagonData.horses or {})
    if horseCount == 0 then
        wagonTeamStats = nil
        return
    end

    local averageSpeed = totalSpeed / horseCount
    local averageStrength = totalStrength / horseCount
    local speedRating = averageSpeed / Config.SpeedWeight.MaxStatRank
    local strengthRating = averageStrength / Config.SpeedWeight.MaxStatRank
    local horseRating = (speedRating * Config.SpeedWeight.SpeedStatWeight)
        + (strengthRating * Config.SpeedWeight.StrengthStatWeight)

    wagonTeamStats = {
        driveFactor = Config.SpeedWeight.BaseSpeedFactor + (horseRating * Config.SpeedWeight.RatingFactor),
        pullCapacity = totalStrength * HorseStats.PullWeightPerStrength,
    }
end

local function ApplyComponentTints(horse, componentCategory, tints)
    if not tints then return end

    Citizen.InvokeNative(0x4EFC1F8FF1AD94DE, horse, componentCategory.categoryHash, joaat(componentCategory.tintPalette), tints.tint0, tints.tint1, tints.tint2)
    Citizen.InvokeNative(0xAAB86462966168CE, horse, true)
end

local function ApplyWagonHorseComponents(horse, storedComponents)
    local components = {}
    if type(storedComponents) == 'string' and storedComponents ~= '' then
        local success, decoded = pcall(json.decode, storedComponents)
        if success and type(decoded) == 'table' then components = decoded end
    end

    for _, category in ipairs(ConfigStables.Customization) do
        if ConfigStables.RidingHorseComponents[category.key] then
            Citizen.InvokeNative(0xD710A5007C2AC539, horse, category.categoryHash, 0)
        else
            local value = tonumber(components[category.key]) or 0
            local component = value > 0 and HorseComponents[category.key][value]
            if component then Citizen.InvokeNative(0xD3A7B003ED343FD9, horse, component.hash, true, true, false) end
        end
    end

    Citizen.InvokeNative(0x1902C4CFCC5BE57C, horse, ConfigStables.WagonHorse.HarnessOutfit)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, horse, false, true, true, true, false)

    for _, category in ipairs(ConfigStables.Customization) do
        if not ConfigStables.RidingHorseComponents[category.key] then
            ApplyComponentTints(horse, category, components[category.tintKey])
        end
    end
end

local function SpawnWagonHorses(wagon, wagonData)
    local wagonConfig = ConfigWagon.Wagons[wagonData.model]
    if not wagonConfig then return end

    for slot = 1, wagonConfig.horseCount do
        local harnessIndex = slot - 1
        local defaultHorse = 0
        local timeout = GetGameTimer() + 3000
        while GetGameTimer() < timeout do
            defaultHorse = Citizen.InvokeNative(0xA8BA0BAE0173457B, wagon, harnessIndex, Citizen.ResultAsInteger())
            if defaultHorse ~= 0 and DoesEntityExist(defaultHorse) then break end
            Wait(50)
        end

        if defaultHorse ~= 0 and DoesEntityExist(defaultHorse) then
            local horseCoords = GetEntityCoords(defaultHorse)
            local horseHeading = GetEntityHeading(defaultHorse)
            Citizen.InvokeNative(0x4402960666000E62, wagon, harnessIndex)
            SetEntityAsMissionEntity(defaultHorse, true, true)
            DeletePed(defaultHorse)
            if DoesEntityExist(defaultHorse) then DeleteEntity(defaultHorse) end

            local horseData
            for _, assignedHorse in ipairs(wagonData.horses or {}) do
                if tonumber(assignedHorse.slot) == slot then
                    horseData = assignedHorse
                    break
                end
            end

            if horseData then
                local horseHash = joaat(horseData.horse)
                timeout = GetGameTimer() + 10000
                RequestModel(horseHash, false)
                while not HasModelLoaded(horseHash) and GetGameTimer() < timeout do Wait(0) end

                if HasModelLoaded(horseHash) then
                    local horse = CreatePed(horseHash, horseCoords.x, horseCoords.y, horseCoords.z, horseHeading, true, true, true, true)
                    SetModelAsNoLongerNeeded(horseHash)
                    if horse ~= 0 and DoesEntityExist(horse) then
                        PlayerWagonHorses[horse] = true
                        SetEntityAsMissionEntity(horse, true, true)
                        SetRandomOutfitVariation(horse, true)
                        SetBlockingOfNonTemporaryEvents(horse, true)
                        SetPedPromptName(horse, horseData.name)
                        Citizen.InvokeNative(0x5653AB26C82938CF, horse, 41611, horseData.gender == 'male' and 0.0 or 1.0)
                        Citizen.InvokeNative(0x5DA12E025D47D4E5, horse, 16, tonumber(horseData.dirt) or 0)
                        ApplyWagonHorseComponents(horse, horseData.components)
                        Citizen.InvokeNative(0xCC8CA3E88256E58F, horse, false, true, true, true, false)
                        SetEntityVisible(horse, true)
                        ResetEntityAlpha(horse)
                        Citizen.InvokeNative(0x316CDB5B6E8F4110, horse, wagon, harnessIndex)
                    end
                end
            end
        end
    end
end

local function ApplyWagonCustomization(wagon, wagonData)
    Citizen.InvokeNative(0x8268B098F6FCA4E2, wagon, tonumber(wagonData.tint) or 0)

    local livery = tonumber(wagonData.livery) or -1
    if livery >= 0 then
        Citizen.InvokeNative(0xF89D82A0582E46ED, wagon, livery)
    end

    for extra = 0, 10 do
        if DoesExtraExist(wagon, extra) then
            Citizen.InvokeNative(0xBB6F89150BC9D16B, wagon, extra, true)
        end
    end

    local enabledExtras = {}
    if wagonData.extras then
        local success, storedExtras = pcall(json.decode, wagonData.extras)
        if success and type(storedExtras) == 'table' then enabledExtras = storedExtras end
    elseif tonumber(wagonData.extra) and tonumber(wagonData.extra) > 0 then
        enabledExtras[1] = tonumber(wagonData.extra)
    end
    for _, extra in ipairs(enabledExtras) do
        if DoesExtraExist(wagon, extra) then
            Citizen.InvokeNative(0xBB6F89150BC9D16B, wagon, extra, false)
        end
    end

    Citizen.InvokeNative(0xE31C0CB1C3186D40, wagon)
    if wagonData.lantern and wagonData.lantern ~= '0' then
        AddLightPropSetToVehicle(wagon, joaat(wagonData.lantern))
    end
end

local function DeletePlayerWagon()
    if wagonBlip then
        RemoveBlip(wagonBlip)
        wagonBlip = nil
    end

    if DoesEntityExist(PlayerWagon) then
        Citizen.InvokeNative(0xB32A5813C7F87B09, PlayerWagon)
        SetEntityAsMissionEntity(PlayerWagon, true, true)
        DeleteVehicle(PlayerWagon)
        if DoesEntityExist(PlayerWagon) then DeleteEntity(PlayerWagon) end
    end

    for horse in pairs(PlayerWagonHorses) do
        if DoesEntityExist(horse) then
            SetEntityAsMissionEntity(horse, true, true)
            DeletePed(horse)
            if DoesEntityExist(horse) then DeleteEntity(horse) end
        end
    end

    PlayerWagon = 0
    PlayerWagonData = nil
    PlayerWagonHorses = {}
    wagonTeamStats = nil
end

local function CallPlayerWagon()
    if PlayerWagon ~= 0 and DoesEntityExist(PlayerWagon) then
        lib.notify({ title = PlayerWagonData.name .. ' is already out.', type = 'inform', duration = 10000 })
        return
    end

    local wagonData = lib.callback.await('nt_stables:server:getActiveWagon', false)
    if not wagonData then
        lib.notify({ title = 'You do not have an active wagon.', type = 'error', duration = 10000 })
        return
    end

    local modelHash = joaat(wagonData.model)
    local timeout = GetGameTimer() + 10000

    RequestModel(modelHash, false)
    while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
        Wait(0)
    end

    if not HasModelLoaded(modelHash) then
        lib.notify({ title = 'Failed to load your wagon.', type = 'error', duration = 10000 })
        return
    end

    local playerCoords = GetEntityCoords(cache.ped)
    local _, spawnCoords = GetClosestVehicleNode(playerCoords.x - 15.0, playerCoords.y, playerCoords.z, 0, 3.0, 0.0)
    local heading = GetEntityHeading(cache.ped)

    PlayerWagon = CreateVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, heading, true, false, false, false)
    SetModelAsNoLongerNeeded(modelHash)

    if PlayerWagon == 0 or not DoesEntityExist(PlayerWagon) then
        PlayerWagon = 0
        lib.notify({ title = 'Failed to spawn your wagon.', type = 'error', duration = 10000 })
        return
    end

    PlayerWagonData = wagonData
    SetEntityAsMissionEntity(PlayerWagon, true, true)
    Citizen.InvokeNative(0x7263332501E07F52, PlayerWagon, true)
    Citizen.InvokeNative(0xD0E02AA618020D17, PlayerId(), PlayerWagon)
    ApplyWagonCustomization(PlayerWagon, wagonData)
    SetVehicleDirtLevel(PlayerWagon, 0.0)
    SpawnWagonHorses(PlayerWagon, wagonData)
    SetWagonTeamStats(wagonData)
    ApplyPlayerWagonSpeed(0)

    wagonBlip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, -1230993421, PlayerWagon)
    SetBlipSprite(wagonBlip, joaat('blip_player_coach'), true)
    Citizen.InvokeNative(0x9CB1A1623062F402, wagonBlip, wagonData.name)
end

RegisterCommand('callwagon', CallPlayerWagon, false)
RegisterNetEvent('nt_stables:client:callWagon', CallPlayerWagon)
RegisterNetEvent('nt_stables:client:ridingWagonChanged', DeletePlayerWagon)

CreateThread(function()
    while true do
        Wait(Config.SpeedWeight.RefreshInterval)

        if PlayerWagon ~= 0 and DoesEntityExist(PlayerWagon) and PlayerWagonData then
            local inventoryWeight = lib.callback.await('nt_stables:server:getWagonInventoryWeight', false, PlayerWagonData.id)
            if inventoryWeight then ApplyPlayerWagonSpeed(inventoryWeight) end
        end
    end
end)

exports('GetPlayerWagon', function()
    return PlayerWagon
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    DeletePlayerWagon()
end)
