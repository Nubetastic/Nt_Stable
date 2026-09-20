local RSGCore = exports['rsg-core']:GetCoreObject()
local HorseComponents = lib.load('shared.horse_components')

local HORSE_APPEARANCE_CATEGORIES = {
    `horse_heads`,
    `horse_bodies`,
    `horse_manes`,
    `horse_tails`,
    0xEEDC3C76,
}

local EQUIPMENT_DRAWABLES = {}
local EQUIPMENT_CATEGORIES = {}
for category in pairs(ConfigStables.RidingHorseComponents) do
    for _, component in ipairs(HorseComponents[category] or {}) do
        EQUIPMENT_DRAWABLES[component.hash] = true
        if component.hash > 0x7FFFFFFF then
            EQUIPMENT_DRAWABLES[component.hash - 0x100000000] = true
        end
    end
end
for _, category in ipairs(ConfigStables.Customization) do
    if ConfigStables.RidingHorseComponents[category.key] then
        EQUIPMENT_CATEGORIES[#EQUIPMENT_CATEGORIES + 1] = category.categoryHash
    end
end

NtHorseAppearance = {}

local backfillRunning = false

local function WaitForHorseRender(horse)
    local timeout = GetGameTimer() + 5000
    while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, horse) and GetGameTimer() < timeout do
        Wait(0)
    end
    return Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, horse)
end

local function DecodeTable(value)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return end

    local success, decoded = pcall(json.decode, value)
    if success and type(decoded) == 'table' then return decoded end
end

local function SplitComponents(components)
    local horseComponents = {}
    local equipmentComponents = {}

    for _, component in ipairs(components or {}) do
        local target = EQUIPMENT_DRAWABLES[component.drawable] and equipmentComponents or horseComponents
        target[#target + 1] = component
    end

    return horseComponents, equipmentComponents
end

local function DecodeAppearance(value)
    local appearance = DecodeTable(value)
    if not appearance then return end
    if tonumber(appearance.version) and tonumber(appearance.version) >= 2 and type(appearance.horse) == 'table'
        and type(appearance.horse.components) == 'table'
        and type(appearance.equipment) == 'table'
        and type(appearance.equipment.components) == 'table' then
        return appearance
    end
    if type(appearance.components) ~= 'table' then return end

    local horseComponents, equipmentComponents = SplitComponents(appearance.components)
    return {
        version = 2,
        horse = {
            scale = appearance.scale,
            categories = appearance.categories or {},
            components = horseComponents,
        },
        equipment = {
            components = equipmentComponents,
        },
    }
end

local function ApplyTag(horse, component)
    Citizen.InvokeNative(
        0xBC6DF00D7A4A6819,
        horse,
        component.drawable,
        component.albedo,
        component.normal,
        component.material,
        component.palette,
        component.tint0,
        component.tint1,
        component.tint2
    )
end

local function ApplyStoredComponents(horse, storedComponents)
    local components = DecodeTable(storedComponents) or {}

    for _, category in ipairs(ConfigStables.Customization) do
        local storedValue = components[category.key]
        if storedValue ~= nil then
            local value = tonumber(storedValue) or 0
            local keepNaturalStyle = (category.key == 'Manes' or category.key == 'Tails') and value == 0
            if not keepNaturalStyle then
                Citizen.InvokeNative(0xD710A5007C2AC539, horse, category.categoryHash, 0)

                local component = value > 0 and HorseComponents[category.key][value]
                if component then
                    Citizen.InvokeNative(0xD3A7B003ED343FD9, horse, component.hash, true, true, false)
                end
            end
        end
    end

    Citizen.InvokeNative(0xCC8CA3E88256E58F, horse, false, true, true, true, false)
    for _, category in ipairs(ConfigStables.Customization) do
        local tints = components[category.tintKey]
        if tints then
            Citizen.InvokeNative(
                0x4EFC1F8FF1AD94DE,
                horse,
                category.categoryHash,
                joaat(category.tintPalette),
                tints.tint0,
                tints.tint1,
                tints.tint2
            )
        end
    end
end

local function CaptureCurrentAppearance(horse)
    if horse == 0 or not DoesEntityExist(horse) or not WaitForHorseRender(horse) then return end

    local appearance = {
        scale = math.floor(GetPedScale(horse) * 100) / 100,
        categories = {},
        components = {},
    }
    local categoryCount = Citizen.InvokeNative(0xA622E66EEE92A08D, horse, Citizen.ResultAsInteger())
    local componentCount = Citizen.InvokeNative(0x90403E8107B60E81, horse, Citizen.ResultAsInteger())

    for index = 0, categoryCount - 1 do
        appearance.categories[#appearance.categories + 1] = Citizen.InvokeNative(
            0xCCB97B51893C662F,
            horse,
            index,
            Citizen.ResultAsInteger()
        )
    end

    for index = 0, componentCount - 1 do
        local foundAsset, drawable, albedo, normal, material = Citizen.InvokeNative(
            0xA9C28516A6DC9D56,
            horse,
            index,
            Citizen.PointerValueInt(),
            Citizen.PointerValueInt(),
            Citizen.PointerValueInt(),
            Citizen.PointerValueInt(),
            Citizen.ReturnResultAnyway()
        )
        local foundTint, palette, tint0, tint1, tint2 = Citizen.InvokeNative(
            0xE7998FEC53A33BBE,
            horse,
            index,
            Citizen.PointerValueInt(),
            Citizen.PointerValueInt(),
            Citizen.PointerValueInt(),
            Citizen.PointerValueInt(),
            Citizen.ReturnResultAnyway()
        )
        if not foundAsset or not foundTint then return end

        appearance.components[#appearance.components + 1] = {
            drawable = drawable,
            albedo = albedo,
            normal = normal,
            material = material,
            palette = palette,
            tint0 = tint0,
            tint1 = tint1,
            tint2 = tint2,
        }
    end

    return appearance
end

local function ComponentKey(component)
    return table.concat({
        component.drawable,
        component.albedo,
        component.normal,
        component.material,
        component.palette,
        component.tint0,
        component.tint1,
        component.tint2,
    }, ':')
end

function NtHorseAppearance.Capture(horse, transitionWait)
    transitionWait = transitionWait or 500
    local completeAppearance = CaptureCurrentAppearance(horse)
    if not completeAppearance then return end

    for _, category in ipairs(EQUIPMENT_CATEGORIES) do
        Citizen.InvokeNative(0xD710A5007C2AC539, horse, category, 0)
    end
    Citizen.InvokeNative(0xAAB86462966168CE, horse, true)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, horse, false, true, true, true, false)
    Wait(transitionWait)

    local horseAppearance = CaptureCurrentAppearance(horse)

    for _, component in ipairs(completeAppearance.components) do
        ApplyTag(horse, component)
    end
    Citizen.InvokeNative(0xAAB86462966168CE, horse, true)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, horse, false, true, true, true, false)
    Wait(transitionWait)
    Citizen.InvokeNative(0x25ACFC650B65C538, horse, completeAppearance.scale)
    Wait(transitionWait)

    if not horseAppearance then return end

    local horseComponentCounts = {}
    for _, component in ipairs(horseAppearance.components) do
        local key = ComponentKey(component)
        horseComponentCounts[key] = (horseComponentCounts[key] or 0) + 1
    end

    local equipmentComponents = {}
    for _, component in ipairs(completeAppearance.components) do
        local key = ComponentKey(component)
        if horseComponentCounts[key] and horseComponentCounts[key] > 0 then
            horseComponentCounts[key] = horseComponentCounts[key] - 1
        else
            equipmentComponents[#equipmentComponents + 1] = component
        end
    end

    return {
        version = 3,
        horse = {
            scale = completeAppearance.scale,
            categories = horseAppearance.categories,
            components = horseAppearance.components,
        },
        equipment = {
            components = equipmentComponents,
        },
    }
end

function NtHorseAppearance.Save(horseId, horse)
    local appearance = NtHorseAppearance.Capture(horse)
    if not appearance then return false end

    return lib.callback.await('nt_stables:server:saveHorseAppearance', false, horseId, appearance) == true
end

function NtHorseAppearance.Apply(horse, storedAppearance, includeEquipment, transitionWait)
    transitionWait = transitionWait or 500
    local appearance = DecodeAppearance(storedAppearance)
    local scale = appearance and appearance.horse and tonumber(appearance.horse.scale)
    if not scale or type(appearance.horse.components) ~= 'table' or #appearance.horse.components == 0 then return false end

    local currentAppearance = NtHorseAppearance.Capture(horse, transitionWait)
    if not currentAppearance then return false end

    for _, category in ipairs(HORSE_APPEARANCE_CATEGORIES) do
        Citizen.InvokeNative(0xD710A5007C2AC539, horse, category, 0)
    end
    if includeEquipment ~= false then
        for _, category in ipairs(EQUIPMENT_CATEGORIES) do
            Citizen.InvokeNative(0xD710A5007C2AC539, horse, category, 0)
        end
    end
    for _, component in ipairs(appearance.horse.components) do
        ApplyTag(horse, component)
    end
    if includeEquipment ~= false then
        for _, component in ipairs(appearance.equipment.components) do
            ApplyTag(horse, component)
        end
    end

    Citizen.InvokeNative(0xAAB86462966168CE, horse, true)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, horse, false, true, true, true, false)
    Wait(transitionWait)
    Citizen.InvokeNative(0x25ACFC650B65C538, horse, scale)
    Wait(transitionWait)
    return true
end

function NtHorseAppearance.BackfillMissing()
    if backfillRunning then
        while backfillRunning do Wait(100) end
        return
    end
    backfillRunning = true

    local horses = lib.callback.await('nt_stables:server:getMissingHorseAppearances', false) or {}
    for _, horseData in ipairs(horses) do
        local storedAppearance = DecodeAppearance(horseData.appearance)
        local model = joaat(horseData.horse)
        RequestModel(model, false)
        local timeout = GetGameTimer() + 10000
        while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end

        if HasModelLoaded(model) then
            local coords = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 4.0, 0.0)
            local horse = CreatePed(model, coords.x, coords.y, coords.z, GetEntityHeading(cache.ped), false, false, 0, 0)
            if horse ~= 0 and DoesEntityExist(horse) then
                SetEntityAsMissionEntity(horse, true, true)
                SetEntityVisible(horse, false)
                SetEntityCollision(horse, false, false)
                FreezeEntityPosition(horse, true)
                SetBlockingOfNonTemporaryEvents(horse, true)
                SetRandomOutfitVariation(horse, true)
                WaitForHorseRender(horse)
                Citizen.InvokeNative(0x5653AB26C82938CF, horse, 41611, horseData.gender == 'male' and 0.0 or 1.0)
                if not storedAppearance or not NtHorseAppearance.Apply(horse, storedAppearance) then
                    ApplyStoredComponents(horse, horseData.components)
                    Wait(500)
                end
                if not NtHorseAppearance.Save(horseData.id, horse) then
                    print(('Nt_Stables: failed to cache the appearance for horse %s.'):format(horseData.id))
                end
                DeletePed(horse)
                if DoesEntityExist(horse) then DeleteEntity(horse) end
            end
            SetModelAsNoLongerNeeded(model)
        else
            print(('Nt_Stables: failed to load %s while caching horse appearance.'):format(horseData.horse))
        end
    end

    backfillRunning = false
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    CreateThread(function()
        Wait(2000)
        NtHorseAppearance.BackfillMissing()
    end)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    CreateThread(function()
        Wait(5000)
        local playerData = RSGCore.Functions.GetPlayerData()
        if playerData and playerData.citizenid then NtHorseAppearance.BackfillMissing() end
    end)
end)
