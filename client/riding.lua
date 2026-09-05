local RSGCore = exports['rsg-core']:GetCoreObject()
local HorseStats = lib.load('shared.horse_stats')
local HorseComponents = lib.load('shared.horse_components')

PlayerHorse = 0
PlayerHorseData = nil
PlayerHorseRiding = false
PlayerHorseFleeing = false
state = {
    horse = {},
    wagon = {},
}

local horseBlip
local lanternEquipped = false
local lastDirt = -1
local horseMonitorId = 0
local horseReviveInProgress = false
local deadHorsePrompts = {}

local HORSE_MODEL_NATIVE = 0x772A1969F649E902
local RESURRECT_PED_NATIVE = 0x71BC8E838B9C6035

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

function ShowOwnedHorseInfo(horseData, returnToManager)
    local base, finalStats, level = HorseStats.Calculate(horseData)
    if not base then return end

    local modifiers = {}
    if horseData.wild == 1 or horseData.wild == true or horseData.wild == '1' then
        local success, stored = pcall(json.decode, horseData.stat_modifiers or '')
        if success and stored and stored.modifiers then modifiers = stored.modifiers end
        if modifiers.strength == nil and modifiers.carry ~= nil then modifiers.strength = modifiers.carry end
    end

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
        wild = horseData.wild == 1 or horseData.wild == true or horseData.wild == '1',
        wildModifiers = modifiers,
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

local function ClearPlayerHorseState(horse)
    if PlayerHorse ~= horse then return end

    RemoveHorseTarget()
    if horseBlip then
        RemoveBlip(horseBlip)
        horseBlip = nil
    end

    PlayerHorse = 0
    PlayerHorseData = nil
    PlayerHorseRiding = false
    PlayerHorseFleeing = false
    lanternEquipped = false
    lastDirt = -1
end

local function DeletePlayerHorse()
    if PlayerHorse == 0 then return end

    local horse = PlayerHorse
    local horseState = PlayerHorseData and state.horse[PlayerHorseData.id]
    if horseState and horseState.entity == horse then
        if DoesEntityExist(horse) then horseState.dead = IsEntityDead(horse) end
        horseState.isSpawned = false
        if horseState.dead and not horseState.deathPending then
            horseState.deathPending = true
            TriggerServerEvent('nt_stables:server:beginHorseDeath', PlayerHorseData.id)
        end
        if horseState.deathPending then
            TriggerServerEvent(
                horseState.dead and 'nt_stables:server:finishHorseDeath' or 'nt_stables:server:cancelHorseDeath',
                PlayerHorseData.id
            )
        end
        state.horse[PlayerHorseData.id] = nil
    end
    horseMonitorId = horseMonitorId + 1
    ClearPlayerHorseState(horse)

    if DoesEntityExist(horse) then
        local timeout = GetGameTimer() + 2000
        NetworkRequestControlOfEntity(horse)
        while not NetworkHasControlOfEntity(horse) and GetGameTimer() < timeout do
            Wait(0)
            NetworkRequestControlOfEntity(horse)
        end

        SetEntityAsNoLongerNeeded(horse)
        SetEntityAsMissionEntity(horse, true, true)
        DeletePed(horse)
        if DoesEntityExist(horse) then DeleteEntity(horse) end
    end
end

local function SetupHorseTarget()
    local targets = {
        {
            name = 'nt_player_horse_info',
            icon = 'fa-solid fa-horse-head',
            label = 'View Horse Info',
            distance = 2.5,
            canInteract = function(entity)
                return not IsEntityDead(entity)
            end,
            onSelect = OpenOwnedHorseInfo,
        },
        {
            name = 'nt_player_horse_lantern',
            icon = 'fa-solid fa-lightbulb',
            label = 'Horse Lantern',
            distance = 2.5,
            canInteract = function(entity)
                return not IsEntityDead(entity)
            end,
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
    }
    targets[#targets + 1] = {
            name = 'nt_player_horse_saddlebag',
            icon = 'fa-solid fa-box-open',
            label = 'Saddlebag',
            distance = 2.5,
            canInteract = function(entity)
                return not IsEntityDead(entity)
            end,
            onSelect = function()
                TriggerServerEvent('nt_stables:server:openSaddleBag', PlayerHorseData.horseid)
            end,
    }
    exports.ox_target:addLocalEntity(PlayerHorse, targets)
end

local function CreateHorseBlip(horse, horseData)
    horseBlip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, -1230993421, horse)
    Citizen.InvokeNative(0x9CB1A1623062F402, horseBlip, horseData.name)
end

local function StartHorseMonitor(horse, horseData)
    horseMonitorId = horseMonitorId + 1
    local monitorId = horseMonitorId
    local horseState = {
        entity = horse,
        isSpawned = true,
        dead = false,
        deathPending = false,
    }
    state.horse[horseData.id] = horseState

    CreateThread(function()
        while horseMonitorId == monitorId and PlayerHorse == horse and horseState.isSpawned and DoesEntityExist(horse) do
            Wait(500)
            if horseMonitorId ~= monitorId or PlayerHorse ~= horse or state.horse[horseData.id] ~= horseState then return end
            if not horseState.isSpawned or not DoesEntityExist(horse) then break end
            horseState.dead = IsEntityDead(horse)

            if horseState.dead then
                local deathCoords = GetEntityCoords(horse)
                local reviveDeadline = GetGameTimer() + ConfigStables.Settings.HorseReviveTime
                local tenSecondWarning = false
                horseState.deathPending = true
                TriggerServerEvent('nt_stables:server:beginHorseDeath', horseData.id)
                RemoveHorseTarget()
                lib.notify({
                    title = horseData.name .. ' has died.',
                    description = 'Use a horse reviver within 3 minutes.',
                    type = 'error',
                    duration = 10000,
                })
                if horseBlip then
                    RemoveBlip(horseBlip)
                    horseBlip = nil
                end
                PlayerHorseRiding = false
                if NetworkGetEntityIsNetworked(horse) then
                    SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(horse), false)
                end
                SetEntityAsNoLongerNeeded(horse)

                while horseMonitorId == monitorId and PlayerHorse == horse and horseState.isSpawned and DoesEntityExist(horse)
                    and IsEntityDead(horse) and GetGameTimer() < reviveDeadline
                    and #(GetEntityCoords(cache.ped) - deathCoords) <= ConfigStables.Settings.SpawnDistance do
                    if not tenSecondWarning and reviveDeadline - GetGameTimer() <= 10000 then
                        tenSecondWarning = true
                        lib.notify({
                            title = '10 seconds remain to revive ' .. horseData.name .. '.',
                            type = 'warning',
                            duration = 10000,
                        })
                    end
                    Wait(250)
                end

                if horseMonitorId ~= monitorId or PlayerHorse ~= horse or state.horse[horseData.id] ~= horseState then return end

                if horseState.isSpawned and DoesEntityExist(horse) and not IsEntityDead(horse) then
                    horseState.dead = false
                    horseState.deathPending = false
                    SetEntityAsMissionEntity(horse, true, true)
                    if NetworkGetEntityIsNetworked(horse) then
                        SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(horse), true)
                    end
                    SetEntityHealth(horse, GetEntityMaxHealth(horse))
                    SetBlockingOfNonTemporaryEvents(horse, false)
                    TriggerServerEvent('nt_stables:server:cancelHorseDeath', horseData.id)
                    SetupHorseTarget()
                    CreateHorseBlip(horse, horseData)
                else
                    horseState.isSpawned = false
                    if horseState.dead and horseState.deathPending then
                        TriggerServerEvent('nt_stables:server:finishHorseDeath', horseData.id)
                    end
                    if state.horse[horseData.id] == horseState then state.horse[horseData.id] = nil end
                    ClearPlayerHorseState(horse)
                    return
                end
            elseif #(GetEntityCoords(cache.ped) - GetEntityCoords(horse)) > ConfigStables.Settings.SpawnDistance then
                DeletePlayerHorse()
                return
            else
                PlayerHorseRiding = GetMount(cache.ped) == horse
            end
        end

        if state.horse[horseData.id] == horseState then
            horseState.isSpawned = false
            if horseState.deathPending then
                TriggerServerEvent(
                    horseState.dead and 'nt_stables:server:finishHorseDeath' or 'nt_stables:server:cancelHorseDeath',
                    horseData.id
                )
            end
            state.horse[horseData.id] = nil
            if horseMonitorId == monitorId and PlayerHorse == horse then ClearPlayerHorseState(horse) end
        end
    end)
end

local function CallPlayerHorse()
    if PlayerHorse ~= 0 then
        if DoesEntityExist(PlayerHorse) then
            if IsEntityDead(PlayerHorse) then
                lib.notify({ title = 'Your horse must be revived.', type = 'error', duration = 5000 })
                return
            end
            PlayerHorseFleeing = false
            Citizen.InvokeNative(0x6A071245EB0D1882, PlayerHorse, cache.ped, -1, 3.0, 2.0, 0, 0)
            return
        end

        DeletePlayerHorse()
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

    local roadSpawn = FindStableRoadSpawn(
        GetEntityCoords(cache.ped),
        GetEntityHeading(cache.ped),
        ConfigStables.Settings.HorseCallSpawnDistance
    )
    if not roadSpawn then
        SetModelAsNoLongerNeeded(modelHash)
        lib.notify({ title = 'No suitable road was found for your horse.', type = 'error', duration = 10000 })
        return
    end

    PlayerHorse = CreatePed(modelHash, roadSpawn.coords.x, roadSpawn.coords.y, roadSpawn.coords.z, roadSpawn.heading, false, true, 0, 0)
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
    for stat, attribute in pairs(statAttributes) do
        SetAttributePoints(PlayerHorse, attribute, statPoints[finalStats[stat]])
    end

    CreateHorseBlip(PlayerHorse, data)

    SetupHorseTarget()
    Citizen.InvokeNative(0x6A071245EB0D1882, PlayerHorse, cache.ped, -1, 3.0, 2.0, 0, 0)

    NetworkRegisterEntityAsNetworked(PlayerHorse)
    local networkId = NetworkGetNetworkIdFromEntity(PlayerHorse)
    --SetNetworkIdCanMigrate(networkId, true) -- false native do not use.
    SetNetworkIdExistsOnAllMachines(networkId, true)
    StartHorseMonitor(PlayerHorse, data)
end

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
                local eventData = string.rep('\0', 80)
                local hasData = Citizen.InvokeNative(0x57EC5FA4D4D6AFCA, 0, eventIndex, eventData, 10)
                if hasData and PlayerHorse == string.unpack('<i4', eventData, 17) then
                    local promptType = string.unpack('<i4', eventData)

                    if promptType == 33 and not PlayerHorseFleeing then
                        local fleeingHorse = PlayerHorse
                        PlayerHorseFleeing = true
                        ClearPedTasks(fleeingHorse)
                        TaskAnimalFlee(fleeingHorse, cache.ped, -1)

                        CreateThread(function()
                            Wait(5000)
                            if PlayerHorseFleeing and PlayerHorse == fleeingHorse then
                                DeletePlayerHorse()
                            end
                        end)
                    end
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(5000)

        if PlayerHorse ~= 0 and DoesEntityExist(PlayerHorse) then
            local dirt = Citizen.InvokeNative(0x147149F2E909323C, PlayerHorse, 16, Citizen.ResultAsInteger())
            if dirt ~= lastDirt then
                lastDirt = dirt
                TriggerServerEvent('nt_stables:server:setHorseDirt', dirt)
            end
        end
    end
end)

local function FaceDeadHorse(horse)
    if not DoesEntityExist(horse) or not IsEntityDead(horse) then return false end
    if #(GetEntityCoords(cache.ped) - GetEntityCoords(horse)) > 1.5 then
        lib.notify({ title = 'You must be closer to a dead horse.', type = 'error', duration = 5000 })
        return false
    end

    ClearPedTasks(cache.ped)
    Citizen.InvokeNative(0x5AD23D40115353AC, cache.ped, horse, 500, -1.0, -1.0, -1.0)
    Wait(500)
    return DoesEntityExist(horse) and IsEntityDead(horse)
end

local function ReviveHorse(horse)
    if not DoesEntityExist(horse) or not IsEntityDead(horse) then return end
    if not RSGCore.Functions.HasItem('horse_reviver', 1) then
        lib.notify({ title = 'You do not have a horse reviver.', type = 'error', duration = 5000 })
        return
    end
    if not FaceDeadHorse(horse) then return end

    local animDict = 'mech_revive@unapproved'
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do Wait(0) end

    local playerCoords = GetEntityCoords(cache.ped)
    local syringe = CreateObject(joaat('p_syringe01x'), playerCoords.x, playerCoords.y, playerCoords.z, true, true, false)
    SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)
    TaskPlayAnim(cache.ped, animDict, 'revive', 1.0, 1.0, -1, 0, false, false, false)
    AttachEntityToEntity(
        syringe,
        cache.ped,
        GetEntityBoneIndexByName(cache.ped, 'SKEL_R_HAND'),
        0.10, 0.0, 0.03,
        0.0, -80.0, -90.0,
        true, true, false, true, 1, true
    )
    Wait(3000)
    DeleteObject(syringe)
    ClearPedTasks(cache.ped)

    if not DoesEntityExist(horse) or not IsEntityDead(horse) then return end

    if NetworkGetEntityIsNetworked(horse) then
        local timeout = GetGameTimer() + 2000
        NetworkRequestControlOfEntity(horse)
        while not NetworkHasControlOfEntity(horse) and GetGameTimer() < timeout do
            Wait(0)
            NetworkRequestControlOfEntity(horse)
        end
        if not NetworkHasControlOfEntity(horse) then return end
    end
    if not IsEntityDead(horse) then return end

    Citizen.InvokeNative(RESURRECT_PED_NATIVE, horse)
    SetEntityHealth(horse, GetEntityMaxHealth(horse))
    Wait(0)
    if not IsEntityDead(horse) then
        TriggerServerEvent('nt_stables:server:removeHorseReviver')
    end
end

CreateThread(function()
    while true do
        Wait(500)

        for horse, prompt in pairs(deadHorsePrompts) do
            if not DoesEntityExist(horse) or not IsEntityDead(horse) then
                PromptDelete(prompt)
                deadHorsePrompts[horse] = nil
            end
        end

        for _, ped in ipairs(GetGamePool('CPed')) do
            if ped ~= cache.ped and IsEntityDead(ped) and not deadHorsePrompts[ped]
                and Citizen.InvokeNative(HORSE_MODEL_NATIVE, GetEntityModel(ped), Citizen.ResultAsInteger()) ~= 0 then
                local prompt = PromptRegisterBegin()
                PromptSetControlAction(prompt, `INPUT_INTERACT_ANIMAL`)
                PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', 'Revive Horse'))
                PromptSetEnabled(prompt, true)
                PromptSetVisible(prompt, true)
                PromptSetStandardMode(prompt, true)
                PromptSetGroup(prompt, Citizen.InvokeNative(0xB796970BD125FCE8, ped, Citizen.ResultAsLong()), 0)
                PromptRegisterEnd(prompt)
                deadHorsePrompts[ped] = prompt
            end
        end
    end
end)

CreateThread(function()
    while true do
        if next(deadHorsePrompts) then
            Wait(0)
            for horse, prompt in pairs(deadHorsePrompts) do
                if PromptHasStandardModeCompleted(prompt) and not horseReviveInProgress then
                    horseReviveInProgress = true
                    ReviveHorse(horse)
                    horseReviveInProgress = false
                    break
                end
            end
        else
            Wait(500)
        end
    end
end)

RegisterNetEvent('nt_stables:client:useHorseReviver', function()
    if horseReviveInProgress then return end

    local playerCoords = GetEntityCoords(cache.ped)
    local closestHorse
    local closestDistance = 1.5
    for _, ped in ipairs(GetGamePool('CPed')) do
        if ped ~= cache.ped and IsEntityDead(ped)
            and Citizen.InvokeNative(HORSE_MODEL_NATIVE, GetEntityModel(ped), Citizen.ResultAsInteger()) ~= 0 then
            local distance = #(playerCoords - GetEntityCoords(ped))
            if distance <= closestDistance then
                closestHorse = ped
                closestDistance = distance
            end
        end
    end

    if not closestHorse then
        lib.notify({ title = 'You must be closer to a dead horse.', type = 'error', duration = 5000 })
        return
    end

    horseReviveInProgress = true
    ReviveHorse(closestHorse)
    horseReviveInProgress = false
end)

exports('GetPlayerHorse', function()
    return PlayerHorse
end)

exports('IsRidingPlayerHorse', function()
    return PlayerHorseRiding
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, prompt in pairs(deadHorsePrompts) do PromptDelete(prompt) end
    DeletePlayerHorse()
end)

RegisterNetEvent('nt_stables:client:ridingHorseChanged', function()
    DeletePlayerHorse()
end)
