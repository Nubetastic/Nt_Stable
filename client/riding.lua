local RSGCore = exports['rsg-core']:GetCoreObject()
local HorseStats = lib.load('shared.horse_stats')
local HorseComponents = lib.load('shared.horse_components')

PlayerHorse = 0
PlayerHorseData = nil
PlayerHorseRiding = false

local horseBlip
local lanternEquipped = false
local lastDirt = -1
local playerHorseStats

local statAttributes = {
    health = 0,
    stamina = 1,
    agility = 4,
    speed = 5,
    acceleration = 6,
}

local statPoints = {
    [0] = 0,
    [1] = 50,
    [2] = 100,
    [3] = 200,
    [4] = 350,
    [5] = 550,
    [6] = 800,
    [7] = 1100,
    [8] = 1400,
    [9] = 1700,
}

local function ApplyComponentTints(horse, componentCategory, tints)
    if not tints then return end

    local componentCount = Citizen.InvokeNative(0x90403E8107B60E81, horse, Citizen.ResultAsInteger())
    local componentIndex
    for index = 0, componentCount - 1 do
        local categoryHash = Citizen.InvokeNative(0x9B90842304C938A7, horse, index, 0, Citizen.ResultAsInteger())
        if categoryHash == componentCategory.categoryHash or categoryHash == componentCategory.categoryHash - 0x100000000 then
            componentIndex = index
            break
        end
    end
    if not componentIndex then return end

    Citizen.InvokeNative(0x4EFC1F8FF1AD94DE, horse, componentCategory.categoryHash, joaat(componentCategory.tintPalette), tints.tint0, tints.tint1, tints.tint2)
    Citizen.InvokeNative(0xAAB86462966168CE, horse, true)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, horse, false, true, true, true, false)
end

local function ApplyHorseComponents(horse, storedComponents)
    if type(storedComponents) ~= 'string' or storedComponents == '' then return end

    local success, components = pcall(json.decode, storedComponents)
    if not success or type(components) ~= 'table' then return end

    for _, category in ipairs(ConfigStables.Customization) do
        local value = tonumber(components[category.key]) or 0
        local component = value > 0 and HorseComponents[category.key][value]
        if component then
            Citizen.InvokeNative(0xD3A7B003ED343FD9, horse, component.hash, true, true, false)
        end
    end

    for _, category in ipairs(ConfigStables.Customization) do
        ApplyComponentTints(horse, category, components[category.tintKey])
    end
    Citizen.InvokeNative(0xCC8CA3E88256E58F, horse, false, true, true, true, false)
end

local function ApplyPlayerHorseSpeed(inventoryWeight)
    if PlayerHorse == 0 or not DoesEntityExist(PlayerHorse) or not playerHorseStats then return end

    local carryCapacity = HorseStats.GetCarryWeight(playerHorseStats.strength)
    local loadRatio = (inventoryWeight / 1000) / carryCapacity
    local speedFactor = Config.SpeedWeight.BaseSpeedFactor
        + (Config.SpeedWeight.RatingFactor * (playerHorseStats.speed / Config.SpeedWeight.MaxStatRank))
    local loadFactor = 1 / (1 + (Config.SpeedWeight.LoadPenalty * loadRatio * loadRatio))
    local finalSpeed = Config.SpeedWeight.HorseMaxSpeed * speedFactor * loadFactor

    Citizen.InvokeNative(0x0E46A3FCBDE2A1B1, PlayerHorse, finalSpeed)
end

function ShowOwnedHorseInfo(horseData, returnToManager)
    local base, finalStats, level = HorseStats.Calculate(horseData)
    if not base then return end

    ShowHorseInfo({
        name = horseData.name,
        model = horseData.horse,
        breed = base.breed,
        tameLevel = level,
        price = base.price,
        health = finalStats.health,
        stamina = finalStats.stamina,
        agility = finalStats.agility,
        speed = finalStats.speed,
        acceleration = finalStats.acceleration,
        strength = finalStats.strength,
        carryWeight = HorseStats.GetCarryWeight(finalStats.strength),
        pullWeight = HorseStats.GetPullWeight(finalStats.strength),
        returnToManager = returnToManager,
    }, false)
end

local function OpenOwnedHorseInfo()
    ShowOwnedHorseInfo(PlayerHorseData, false)
end

local function RemoveHorseTarget()
    if PlayerHorse == 0 then return end

    exports.ox_target:removeLocalEntity(PlayerHorse, {
        'nt_player_horse_info',
        'nt_player_horse_lantern',
        'nt_player_horse_saddlebag',
    })
end

local function DeletePlayerHorse()
    if PlayerHorse == 0 then return end

    RemoveHorseTarget()

    if horseBlip then
        RemoveBlip(horseBlip)
        horseBlip = nil
    end

    if DoesEntityExist(PlayerHorse) then
        SetEntityAsMissionEntity(PlayerHorse, true, true)
        DeletePed(PlayerHorse)
        DeleteEntity(PlayerHorse)
    end

    PlayerHorse = 0
    PlayerHorseData = nil
    PlayerHorseRiding = false
    lanternEquipped = false
    lastDirt = -1
    playerHorseStats = nil
end

local function SetupHorseTarget()
    exports.ox_target:addLocalEntity(PlayerHorse, {
        {
            name = 'nt_player_horse_info',
            icon = 'fa-solid fa-horse-head',
            label = 'View Horse Info',
            distance = 2.5,
            onSelect = OpenOwnedHorseInfo,
        },
        {
            name = 'nt_player_horse_lantern',
            icon = 'fa-solid fa-lightbulb',
            label = 'Horse Lantern',
            distance = 2.5,
            onSelect = function()
                if not RSGCore.Functions.HasItem('horse_lantern', 1) then
                    lib.notify({ title = 'You do not have a horse lantern.', type = 'error', duration = 10000 })
                    return
                end

                if lanternEquipped then
                    Citizen.InvokeNative(0xD710A5007C2AC539, PlayerHorse, 0x1530BE1C, 0)
                    Citizen.InvokeNative(0xCC8CA3E88256E58F, PlayerHorse, 0, 1, 1, 1, 0)
                    lanternEquipped = false
                else
                    Citizen.InvokeNative(0xD3A7B003ED343FD9, PlayerHorse, 0x635E387C, true, true, true)
                    lanternEquipped = true
                end
            end,
        },
        {
            name = 'nt_player_horse_saddlebag',
            icon = 'fa-solid fa-box-open',
            label = 'Saddlebag',
            distance = 2.5,
            onSelect = function()
                TriggerServerEvent('nt_stables:server:openSaddleBag', PlayerHorseData.horseid)
            end,
        },
    })
end

local function CallPlayerHorse()
    if PlayerHorse ~= 0 and DoesEntityExist(PlayerHorse) then
        Citizen.InvokeNative(0x6A071245EB0D1882, PlayerHorse, cache.ped, -1, 7.2, 2.0, 0, 0)
        return
    end

    local data = lib.callback.await('nt_stables:server:getActiveHorse', false)
    if not data then
        lib.notify({ title = 'You do not have an active horse.', type = 'error', duration = 10000 })
        return
    end

    local modelHash = joaat(data.horse)
    local timeout = GetGameTimer() + 10000

    RequestModel(modelHash, false)
    while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
        Wait(0)
    end

    if not HasModelLoaded(modelHash) then
        lib.notify({ title = 'Failed to load your horse.', type = 'error', duration = 10000 })
        return
    end

    local playerCoords = GetEntityCoords(cache.ped)
    local _, spawnCoords = GetClosestVehicleNode(playerCoords.x - 15.0, playerCoords.y, playerCoords.z, 0, 3.0, 0.0)

    PlayerHorse = CreatePed(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, 300.0, true, true, 0, 0)
    SetModelAsNoLongerNeeded(modelHash)

    if PlayerHorse == 0 or not DoesEntityExist(PlayerHorse) then
        PlayerHorse = 0
        lib.notify({ title = 'Failed to spawn your horse.', type = 'error', duration = 10000 })
        return
    end

    PlayerHorseData = data
    SetEntityAsMissionEntity(PlayerHorse, true, true)
    SetRandomOutfitVariation(PlayerHorse, true)
    SetBlockingOfNonTemporaryEvents(PlayerHorse, true)
    SetPedPromptName(PlayerHorse, data.name)
    SetEntityCanBeDamaged(PlayerHorse, true)

    local horseFlags = {
        [6] = true,
        [113] = false,
        [136] = false,
        [208] = true,
        [209] = true,
        [211] = true,
        [277] = true,
        [297] = true,
        [300] = false,
        [301] = false,
        [312] = false,
        [319] = true,
        [400] = true,
        [412] = false,
        [419] = false,
        [438] = false,
        [439] = false,
        [440] = false,
        [561] = true,
    }

    for flag, value in pairs(horseFlags) do
        Citizen.InvokeNative(0x1913FE4CBF41C463, PlayerHorse, flag, value)
    end

    Citizen.InvokeNative(0xFE26E4609B1C3772, PlayerHorse, 'HorseCompanion', true)
    Citizen.InvokeNative(0x931B241409216C1F, cache.ped, PlayerHorse, false)
    Citizen.InvokeNative(0xB8B6430EAD2D2437, PlayerHorse, joaat('PLAYER_HORSE'))
    Citizen.InvokeNative(0xDF93973251FB2CA5, PlayerId(), true)
    Citizen.InvokeNative(0xE6D4E435B56D5BD0, PlayerId(), PlayerHorse)
    Citizen.InvokeNative(0xAEB97D84CDF3C00B, PlayerHorse, false)
    Citizen.InvokeNative(0x024EC9B649111915, PlayerHorse, true)
    Citizen.InvokeNative(0xCC97B29285B1DC3B, PlayerHorse, 1)
    Citizen.InvokeNative(0x5DA12E025D47D4E5, PlayerHorse, 16, tonumber(data.dirt) or 0)

    local faceFeature = data.gender == 'male' and 0.0 or 1.0
    Citizen.InvokeNative(0x5653AB26C82938CF, PlayerHorse, 41611, faceFeature)
    ApplyHorseComponents(PlayerHorse, data.components)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, PlayerHorse, false, true, true, true, false)

    Citizen.InvokeNative(0xA3DB37EDF9A74635, PlayerId(), PlayerHorse, 28, 1, true)
    Citizen.InvokeNative(0xA3DB37EDF9A74635, PlayerId(), PlayerHorse, 35, 1, true)
    Citizen.InvokeNative(0xA3DB37EDF9A74635, PlayerId(), PlayerHorse, 45, 1, true)

    local _, finalStats = HorseStats.Calculate(data)
    playerHorseStats = finalStats
    for stat, attribute in pairs(statAttributes) do
        SetAttributePoints(PlayerHorse, attribute, statPoints[finalStats[stat]])
    end
    ApplyPlayerHorseSpeed(0)

    horseBlip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, -1230993421, PlayerHorse)
    Citizen.InvokeNative(0x9CB1A1623062F402, horseBlip, data.name)

    SetupHorseTarget()
    Citizen.InvokeNative(0x6A071245EB0D1882, PlayerHorse, cache.ped, -1, 7.2, 2.0, 0, 0)
end

RegisterCommand('callhorse', CallPlayerHorse, false)

RegisterNetEvent('nt_stables:client:callActiveStableRide', function()
    CallPlayerHorse()
end)

CreateThread(function()
    while true do
        Wait(0)

        if Citizen.InvokeNative(0x91AEF906BCA88877, 0, RSGCore.Shared.Keybinds['H']) then
            TriggerEvent('nt_stables:client:callActiveStableRide')
            Wait(1000)
        end

        local eventCount = GetNumberOfEvents(0)
        for eventIndex = 0, eventCount - 1 do
            if GetEventAtIndex(0, eventIndex) == `EVENT_PLAYER_PROMPT_TRIGGERED` then
                local eventData = DataView.ArrayBuffer(80)
                for index = 0, 9 do
                    eventData:SetInt32(8 * index, 0)
                end

                local hasData = Citizen.InvokeNative(0x57EC5FA4D4D6AFCA, 0, eventIndex, eventData:Buffer(), 10)
                if hasData and PlayerHorse == eventData:GetInt32(16) then
                    local promptType = eventData:GetInt32(0)

                    if promptType == 33 then
                        TaskAnimalFlee(PlayerHorse, cache.ped, -1)
                        Wait(10000)
                        DeletePlayerHorse()
                    end
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(500)

        if PlayerHorse ~= 0 and DoesEntityExist(PlayerHorse) then
            PlayerHorseRiding = GetMount(cache.ped) == PlayerHorse
        else
            PlayerHorseRiding = false
        end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.SpeedWeight.RefreshInterval)

        if PlayerHorse ~= 0 and DoesEntityExist(PlayerHorse) then
            local dirt = Citizen.InvokeNative(0x147149F2E909323C, PlayerHorse, 16, Citizen.ResultAsInteger())
            if dirt ~= lastDirt then
                lastDirt = dirt
                TriggerServerEvent('nt_stables:server:setHorseDirt', dirt)
            end

            local inventoryWeight = lib.callback.await('nt_stables:server:getHorseInventoryWeight', false, PlayerHorseData.horseid)
            if inventoryWeight then ApplyPlayerHorseSpeed(inventoryWeight) end
        end
    end
end)

exports('GetPlayerHorse', function()
    return PlayerHorse
end)

exports('IsRidingPlayerHorse', function()
    return PlayerHorseRiding
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    DeletePlayerHorse()
end)

RegisterNetEvent('nt_stables:client:ridingHorseChanged', function()
    DeletePlayerHorse()
end)
