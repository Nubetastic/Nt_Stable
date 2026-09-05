local HorseStats = lib.load('shared.horse_stats')

local WILD_NATIVE = 0x3B005FF0538ED2A9
local SET_PED_SCALE_NATIVE = 0x25ACFC650B65C538
local HORSE_MODEL_NATIVE = 0x772A1969F649E902
local SADDLE_NATIVE = 0xFB4891BD7578CDC1
local IS_PED_MALE_NATIVE = 0x6D9F5FAA7488BA46
local INPUT_CONTEXT = 0xCEFD9220
local ATTRIBUTE_INDEX = { health = 0, stamina = 1, agility = 4, speed = 5, acceleration = 6 }
local ATTRIBUTE_STATS = { 'health', 'stamina', 'agility', 'speed', 'acceleration' }

local modelNames = {}
for model in pairs(HorseStats.GetAll()) do
    modelNames[joaat(model)] = model
end

local observedHorse = 0
local observedWild = false
local tamedHorse = 0
local registrationHorse = 0
local registrationStable
local registrationOpen = false
local registrationPromptOpen = false
local cachedPlayerHeight
local tamingHeightApplied = false
local heightRestorePending = false
local heightRestoreToken = 0

local function SetPlayerHeight(height)
    local playerPed = cache.ped
    if not playerPed or playerPed == 0 or not DoesEntityExist(playerPed) then return end
    Citizen.InvokeNative(SET_PED_SCALE_NATIVE, playerPed, height)
end

local function RestorePlayerHeight(immediately)
    if not tamingHeightApplied or not cachedPlayerHeight then return end

    if immediately then
        heightRestoreToken = heightRestoreToken + 1
        heightRestorePending = false
        SetPlayerHeight(cachedPlayerHeight)
        cachedPlayerHeight = nil
        tamingHeightApplied = false
        return
    end

    if heightRestorePending then return end

    heightRestorePending = true
    heightRestoreToken = heightRestoreToken + 1
    local restoreToken = heightRestoreToken

    CreateThread(function()
        Wait(10000)
        if restoreToken ~= heightRestoreToken or not heightRestorePending then return end

        heightRestorePending = false
        SetPlayerHeight(cachedPlayerHeight)
        cachedPlayerHeight = nil
        tamingHeightApplied = false
    end)
end

local function ApplyTamingHeight()
    if heightRestorePending then
        heightRestoreToken = heightRestoreToken + 1
        heightRestorePending = false
    end

    if tamingHeightApplied then return end

    local playerPed = cache.ped
    if not playerPed or playerPed == 0 or not DoesEntityExist(playerPed) then return end

    cachedPlayerHeight = GetPedScale(playerPed)
    SetPlayerHeight(1.0)
    tamingHeightApplied = true
end

local function IsHorse(entity)
    return entity and entity ~= 0
        and DoesEntityExist(entity)
        and IsEntityAPed(entity)
        and Citizen.InvokeNative(HORSE_MODEL_NATIVE, GetEntityModel(entity), Citizen.ResultAsInteger()) ~= 0
end

local function IsWild(horse)
    return Citizen.InvokeNative(WILD_NATIVE, horse, Citizen.ResultAsInteger()) ~= 0
end

local function HasSaddle(horse)
    return Citizen.InvokeNative(
        SADDLE_NATIVE,
        horse,
        ConfigStables.WildHorseRegistration.SaddleCategory,
        Citizen.ResultAsInteger()
    ) ~= 0
end

local function GetRegisterableHorse()
    local horse = GetMount(cache.ped)
    if horse ~= tamedHorse or horse == PlayerHorse then return 0 end
    if not IsHorse(horse) or IsWild(horse) or HasSaddle(horse) then return 0 end
    if not modelNames[GetEntityModel(horse)] then return 0 end
    return horse
end

local function GetNativeRanks(horse)
    local ranks = {}
    for stat, attribute in pairs(ATTRIBUTE_INDEX) do
        ranks[stat] = GetAttributeBaseRank(horse, attribute)
    end
    return ranks
end

local function GetStartingStats(model, nativeRanks)
    local stats = HorseStats.Get(model)
    local differences = {}
    local modifiers = {}

    for _, stat in ipairs(ATTRIBUTE_STATS) do
        local rank = math.floor((tonumber(nativeRanks[stat]) or stats[stat]) + 0.5)
        rank = math.max(HorseStats.MinimumRank[stat], math.min(HorseStats.MaximumStartingRank, rank))
        differences[#differences + 1] = { stat = stat, modifier = rank - stats[stat] }
    end

    table.sort(differences, function(left, right)
        return math.abs(left.modifier) > math.abs(right.modifier)
    end)

    for index = 1, 3 do
        stats[differences[index].stat] = stats[differences[index].stat] + differences[index].modifier
        modifiers[differences[index].stat] = differences[index].modifier
    end

    return stats, modifiers
end

local function GetHorseGender(horse)
    local isMale = Citizen.InvokeNative(IS_PED_MALE_NATIVE, horse, Citizen.ResultAsInteger()) ~= 0
    return isMale and 'male' or 'female'
end

local function CloseRegistration()
    registrationOpen = false
    registrationHorse = 0
    registrationStable = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeWildHorseRegistration' })
end

local function DeleteRegisteredHorse(horse)
    TaskDismountAnimal(cache.ped, 0, 0, 0, 0, 0)
    Wait(1500)

    NetworkRequestControlOfEntity(horse)
    local timeout = GetGameTimer() + 2000
    while DoesEntityExist(horse) and not NetworkHasControlOfEntity(horse) and GetGameTimer() < timeout do
        Wait(0)
        NetworkRequestControlOfEntity(horse)
    end

    if DoesEntityExist(horse) and NetworkHasControlOfEntity(horse) then
        SetEntityAsMissionEntity(horse, true, true)
        DeleteEntity(horse)
    end
end

local function OpenRegistration(stableName, horse)
    local quote = lib.callback.await('nt_stables:server:getWildHorseRegistrationQuote', false, stableName)
    if not quote or not quote.success then
        lib.notify({ title = quote and quote.message or 'Unable to prepare registration.', type = 'error', duration = 10000 })
        return
    end

    local model = modelNames[GetEntityModel(horse)]
    local nativeRanks = GetNativeRanks(horse)
    local stats, modifiers = GetStartingStats(model, nativeRanks)

    registrationHorse = horse
    registrationStable = stableName
    registrationOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openWildHorseRegistration',
        horse = {
            breed = stats.breed,
            gender = GetHorseGender(horse),
            health = stats.health,
            stamina = stats.stamina,
            agility = stats.agility,
            speed = stats.speed,
            acceleration = stats.acceleration,
            strength = stats.strength,
            carryWeight = HorseStats.GetCarryWeight(stats.strength),
            pullWeight = HorseStats.GetPullWeight(stats.strength),
            wild = true,
            wildModifiers = modifiers,
        },
        quote = quote,
    })
end

CreateThread(function()
    while true do
        Wait(ConfigStables.WildHorseRegistration.TamingPollInterval)
        local horse = GetMount(cache.ped)

        if IsHorse(horse) and not HasSaddle(horse) then
            local wild = IsWild(horse)
            if wild then
                ApplyTamingHeight()
            else
                RestorePlayerHeight()
            end

            if horse ~= observedHorse then
                observedHorse = horse
                observedWild = wild
            elseif observedWild and not wild then
                observedWild = false
                tamedHorse = horse
                lib.notify({
                    title = 'Wild Horse Tamed',
                    description = 'Bring this horse to a stable and register it before it can gain training levels.',
                    type = 'success',
                    duration = 10000,
                })
            end
        else
            RestorePlayerHeight()
            observedHorse = 0
            observedWild = false
        end

        if tamedHorse ~= 0 and not DoesEntityExist(tamedHorse) then
            tamedHorse = 0
        end
    end
end)

CreateThread(function()
    while true do
        local wait = 500
        local horse = not registrationOpen and GetRegisterableHorse() or 0
        local nearbyStable

        if horse ~= 0 then
            local playerCoords = GetEntityCoords(cache.ped)
            for stableName, stable in pairs(ConfigStables.Locations) do
                if #(playerCoords - stable.npcCoords) <= ConfigStables.WildHorseRegistration.StableDistance then
                    nearbyStable = stableName
                    break
                end
            end
        end

        if nearbyStable then
            wait = 0
            if not registrationPromptOpen then
                lib.showTextUI('[E] Register Wild Horse')
                registrationPromptOpen = true
            end

            if IsControlJustReleased(0, INPUT_CONTEXT) then
                lib.hideTextUI()
                registrationPromptOpen = false
                OpenRegistration(nearbyStable, horse)
                Wait(500)
            end
        elseif registrationPromptOpen then
            lib.hideTextUI()
            registrationPromptOpen = false
        end

        Wait(wait)
    end
end)

RegisterNUICallback('closeWildHorseRegistration', function(_, cb)
    CloseRegistration()
    cb(1)
end)

RegisterNUICallback('registerWildHorse', function(data, cb)
    local horse = registrationHorse
    if not registrationOpen or horse == 0 or horse ~= GetRegisterableHorse() then
        lib.notify({ title = 'The wild horse is no longer available.', type = 'error', duration = 10000 })
        return cb({ success = false })
    end

    local name = tostring(data.name or ''):match('^%s*(.-)%s*$')
    if name == '' or #name > 32 then
        lib.notify({ title = 'Horse names must contain 1 to 32 characters.', type = 'error', duration = 10000 })
        return cb({ success = false })
    end

    local networkId = NetworkGetNetworkIdFromEntity(horse)
    local result = lib.callback.await('nt_stables:server:registerWildHorse', false, {
        stable = registrationStable,
        networkId = networkId,
        model = modelNames[GetEntityModel(horse)],
        name = name,
        gender = GetHorseGender(horse),
        nativeRanks = GetNativeRanks(horse),
    })

    if not result or not result.success then
        lib.notify({ title = result and result.message or 'Unable to register this horse.', type = 'error', duration = 10000 })
        return cb({ success = false })
    end

    tamedHorse = 0
    CloseRegistration()
    DeleteRegisteredHorse(horse)
    lib.notify({ title = name .. ' is now registered in your stable.', type = 'success', duration = 10000 })
    cb({ success = true })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    if registrationPromptOpen then lib.hideTextUI() end
    if registrationOpen then CloseRegistration() end
    RestorePlayerHeight(true)
end)
