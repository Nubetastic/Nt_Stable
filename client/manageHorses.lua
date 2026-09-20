local HorseStats = lib.load('shared.horse_stats')
local HorseComponents = lib.load('shared.horse_components')

local managedHorses = {}
local managedWagons = {}
local stableManagerData
local previewHorse = 0
local previewWagon = 0
local previewWagonHorses = {}
local customizeCamera
local customizeStable
local cameraAngle = 0.0
local cameraVerticalAngle = 0.0
local cameraDistance = 0.0
local cameraZoom = 50
local customization
local wagonCustomization
local previewIsWagon = false
local assignmentWagonId
local SpawnPreviewWagonHorses
local auctionListings = {}
local auctionHeld = { selling = {}, receiving = {}, funds = 0 }

HorseManagerOpen = false

local function GetManagedHorse(horseId)
    for _, horse in ipairs(managedHorses) do
        if horse.id == horseId then return horse end
    end
end

local function GetManagedWagon(wagonId)
    for _, wagon in ipairs(managedWagons) do
        if wagon.id == wagonId then return wagon end
    end
end

local function IsWagonOption(options, selectedValue)
    for _, value in ipairs(options or {}) do
        if value == selectedValue then return true end
    end
    return false
end

local function BuildHorseList()
    local horseList = {}

    for _, horse in ipairs(managedHorses) do
        local stats = HorseStats.Get(horse.horse)
        horseList[#horseList + 1] = {
            id = horse.id,
            name = horse.name,
            breed = stats.breed,
            active = horse.active == 1 or horse.active == true,
            isWagonHorse = horse.isWagonHorse == true,
        }
    end

    return horseList
end

local function BuildAuctionHorse(horse)
    local base, stats, level = HorseStats.Calculate(horse)
    if not base then return end
    local modifiers = {}
    if horse.wild == 1 or horse.wild == true or horse.wild == '1' then
        local success, stored = pcall(json.decode, horse.stat_modifiers or '')
        if success and stored and stored.modifiers then modifiers = stored.modifiers end
        if modifiers.strength == nil and modifiers.carry ~= nil then modifiers.strength = modifiers.carry end
    end
    return {
        id = horse.id, name = horse.name, horse = horse.horse, gender = horse.gender,
        wild = horse.wild == 1 or horse.wild == true or horse.wild == '1',
        breed = base.breed, level = level, stats = stats,
        carryWeight = HorseStats.GetCarryWeight(stats.strength),
        pullWeight = HorseStats.GetPullWeight(stats.strength),
        wildModifiers = modifiers,
    }
end

local function BuildAuctionOwnedHorses()
    local horses = {}
    for _, horse in ipairs(managedHorses) do
        local built = BuildAuctionHorse(horse)
        if built then horses[#horses + 1] = built end
    end
    return horses
end

local function BuildWagonList()
    local wagonList = {}

    for _, wagon in ipairs(managedWagons) do
        local wagonConfig = ConfigWagon.Wagons[wagon.model]
        if wagonConfig then
            wagonList[#wagonList + 1] = {
                id = wagon.id,
                name = wagon.name,
                model = wagon.model,
                label = wagonConfig.label,
                active = wagon.active == 1 or wagon.active == true,
                ready = wagon.ready == true,
                needsRepair = wagon.needs_repair == 1 or wagon.needs_repair == true,
                repairPrice = wagon.repairPrice,
                horseCount = wagonConfig.horseCount,
                horses = wagon.horses or {},
            }
        end
    end

    return wagonList
end

local function SendStableManagerData(action, selectedHorseId, selectedWagonId)
    SendNUIMessage({
        action = action,
        horses = BuildHorseList(),
        wagons = BuildWagonList(),
        horseSlots = stableManagerData.horseSlots,
        wagonSlots = stableManagerData.wagonSlots,
        debt = stableManagerData.debt,
        selectedHorseId = selectedHorseId or 0,
        selectedWagonId = selectedWagonId or 0,
        cameraZoom = cameraZoom,
    })
end

local function UpdateCustomizeCamera()
    if not customizeCamera then return end

    local horseCoords = ConfigStables.Locations[customizeStable].CustomizeCoords
    local targetZ = horseCoords.z + (previewIsWagon and 1.2 or 0.5)
    local horizontalDistance = math.cos(cameraVerticalAngle) * cameraDistance
    local cameraX = horseCoords.x + math.cos(cameraAngle) * horizontalDistance
    local cameraY = horseCoords.y + math.sin(cameraAngle) * horizontalDistance
    local cameraZ = targetZ + math.sin(cameraVerticalAngle) * cameraDistance

    SetCamCoord(customizeCamera, cameraX, cameraY, cameraZ)
    SetCamFov(customizeCamera, 40.0)
    PointCamAtCoord(customizeCamera, horseCoords.x, horseCoords.y, targetZ)
end

local function DeletePreviewWagon()
    if previewWagon ~= 0 and DoesEntityExist(previewWagon) then
        Citizen.InvokeNative(0xB32A5813C7F87B09, previewWagon)
    end

    for horse in pairs(previewWagonHorses) do
        if DoesEntityExist(horse) then
            SetEntityAsMissionEntity(horse, true, true)
            DeleteEntity(horse)
        end
    end

    if previewWagon ~= 0 and DoesEntityExist(previewWagon) then
        SetEntityAsMissionEntity(previewWagon, true, true)
        DeleteVehicle(previewWagon)
        if DoesEntityExist(previewWagon) then DeleteEntity(previewWagon) end
    end

    previewWagon = 0
    previewWagonHorses = {}
end

local function DeletePreviewHorse()
    if previewHorse ~= 0 and DoesEntityExist(previewHorse) then
        SetEntityAsMissionEntity(previewHorse, true, true)
        DeletePed(previewHorse)
        DeleteEntity(previewHorse)
    end

    previewHorse = 0
end

local function ApplyWagonPreviewCustomization(wagon, selectedCustomization, spawnDraftHorses)
    if wagon == 0 or not DoesEntityExist(wagon) then return end

    Citizen.InvokeNative(0x8268B098F6FCA4E2, wagon, selectedCustomization.tint)
    if selectedCustomization.livery >= 0 then
        Citizen.InvokeNative(0xF89D82A0582E46ED, wagon, selectedCustomization.livery)
    end

    for extra = 0, 10 do
        if DoesExtraExist(wagon, extra) then
            Citizen.InvokeNative(0xBB6F89150BC9D16B, wagon, extra, true)
        end
    end
    local enabledExtras = selectedCustomization.extras
    if type(enabledExtras) == 'string' then
        local success, storedExtras = pcall(json.decode, enabledExtras)
        enabledExtras = success and storedExtras or {}
    end
    if type(enabledExtras) ~= 'table' then
        enabledExtras = {}
        if tonumber(selectedCustomization.extra) and tonumber(selectedCustomization.extra) > 0 then
            enabledExtras[1] = tonumber(selectedCustomization.extra)
        end
    end
    local previewExtra = tonumber(selectedCustomization.extra) or 0
    if previewExtra > 0 and DoesExtraExist(wagon, previewExtra) then
        Citizen.InvokeNative(0xBB6F89150BC9D16B, wagon, previewExtra, false)
    else
        for _, extra in ipairs(enabledExtras) do
            if DoesExtraExist(wagon, extra) then
                Citizen.InvokeNative(0xBB6F89150BC9D16B, wagon, extra, false)
            end
        end
    end

    Citizen.InvokeNative(0xE31C0CB1C3186D40, wagon)
    if selectedCustomization.lantern ~= 0 then
        AddLightPropSetToVehicle(wagon, joaat(selectedCustomization.lantern))
    end

    if spawnDraftHorses then
        SpawnPreviewWagonHorses(wagon, selectedCustomization)
    end
end

local function SpawnPreviewWagon(wagon, spawnDraftHorses)
    spawnDraftHorses = spawnDraftHorses ~= false
    DeletePreviewHorse()
    DeletePreviewWagon()
    previewIsWagon = true
    cameraDistance = 5.0 + (cameraZoom * 0.05)
    UpdateCustomizeCamera()

    local modelHash = joaat(wagon.model)
    local timeout = GetGameTimer() + 10000
    RequestModel(modelHash, false)
    while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do Wait(0) end

    if not HasModelLoaded(modelHash) then
        lib.notify({ title = 'Failed to load wagon preview.', type = 'error', duration = 10000 })
        return
    end

    local wagonCoords = ConfigStables.Locations[customizeStable].CustomizeCoords
    previewWagon = CreateVehicle(modelHash, wagonCoords.x, wagonCoords.y, wagonCoords.z, wagonCoords.w, false, false, false, false)
    SetModelAsNoLongerNeeded(modelHash)

    if previewWagon == 0 or not DoesEntityExist(previewWagon) then
        previewWagon = 0
        lib.notify({ title = 'Failed to spawn wagon preview.', type = 'error', duration = 10000 })
        return
    end

    SetEntityAsMissionEntity(previewWagon, true, true)
    SetDraftVehicleAllowDraftAnimalAutoCreation(previewWagon, spawnDraftHorses)
    if spawnDraftHorses then
        SetDraftVehicleAnimalsCanDetach(previewWagon, false)
        Citizen.InvokeNative(0x7263332501E07F52, previewWagon, true)
    end
    SetEntityInvincible(previewWagon, true)
    FreezeEntityPosition(previewWagon, true)
    ApplyWagonPreviewCustomization(previewWagon, wagon, spawnDraftHorses)
    SetVehicleDirtLevel(previewWagon, 0.0)
    if spawnDraftHorses then
        local spawnedWagon = previewWagon
        SetTimeout(250, function()
            if previewWagon == spawnedWagon and DoesEntityExist(spawnedWagon) then
                SpawnPreviewWagonHorses(spawnedWagon, wagon)
            end
        end)
    end

    if wagon.needs_repair == 1 or wagon.needs_repair == true then
        local damagedPreview = previewWagon
        SetTimeout(300, function()
            if previewWagon == damagedPreview and DoesEntityExist(damagedPreview) then
                BreakOffVehicleWheel(damagedPreview, 0, true, false, 0, false)
                BreakOffVehicleWheel(damagedPreview, 1, true, false, 0, false)
                FreezeEntityPosition(previewWagon, false)
            end
        end)
    end

end

local function GetHorseComponents(horse)
    if type(horse.components) == 'table' then return json.decode(json.encode(horse.components)) end
    if type(horse.components) ~= 'string' or horse.components == '' then return {} end

    local success, components = pcall(json.decode, horse.components)
    if success and type(components) == 'table' then return components end
    return {}
end

local function GetComponentIndex(horse, categoryHash)
    local componentCount = Citizen.InvokeNative(0x90403E8107B60E81, horse, Citizen.ResultAsInteger())
    for index = 0, componentCount - 1 do
        local category = Citizen.InvokeNative(0x9B90842304C938A7, horse, index, 0, Citizen.ResultAsInteger())
        if category == categoryHash or category == categoryHash - 0x100000000 then return index end
    end
end

local function WaitForHorseRender(horse)
    local timeout = GetGameTimer() + 5000

    while DoesEntityExist(horse) and not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, horse) and GetGameTimer() < timeout do
        Wait(0)
    end

    return DoesEntityExist(horse) and Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, horse)
end

local function GetComponentTints(horse, categoryHash)
    local componentIndex = GetComponentIndex(horse, categoryHash)
    if not componentIndex then return end

    local palette, tint0, tint1, tint2 = Citizen.InvokeNative(
        0xE7998FEC53A33BBE,
        horse,
        componentIndex,
        Citizen.PointerValueInt(),
        Citizen.PointerValueInt(),
        Citizen.PointerValueInt(),
        Citizen.PointerValueInt()
    )

    return { palette = palette, tint0 = tint0, tint1 = tint1, tint2 = tint2 }
end

local function ApplyComponentTints(horse, category, tints)
    if not tints or not WaitForHorseRender(horse) then return end

    Citizen.InvokeNative(0x4EFC1F8FF1AD94DE, horse, category.categoryHash, joaat(category.tintPalette), tints.tint0, tints.tint1, tints.tint2)
    Citizen.InvokeNative(0xAAB86462966168CE, horse, true)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, horse, false, true, true, true, false)
end

local function ApplyHorseComponents(horse, components)
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
        ApplyComponentTints(horse, category, components[category.tintKey])
    end
end

SpawnPreviewWagonHorses = function(wagonEntity, wagon)
    local wagonConfig = ConfigWagon.Wagons[wagon.model]
    if not wagonConfig then return end

    for slot = 1, wagonConfig.horseCount do
        local harnessIndex = slot - 1
        local attachedHorse = Citizen.InvokeNative(0xA8BA0BAE0173457B, wagonEntity, harnessIndex, Citizen.ResultAsInteger())
        local timeout = GetGameTimer() + 3000
        while (attachedHorse == 0 or not DoesEntityExist(attachedHorse)) and GetGameTimer() < timeout do
            Wait(50)
            attachedHorse = Citizen.InvokeNative(0xA8BA0BAE0173457B, wagonEntity, harnessIndex, Citizen.ResultAsInteger())
        end

        local horseData
        for _, assignedHorse in ipairs(wagon.horses or {}) do
            if tonumber(assignedHorse.slot) == slot then
                horseData = assignedHorse
                break
            end
        end

        if attachedHorse ~= 0 and DoesEntityExist(attachedHorse) then
            previewWagonHorses[attachedHorse] = previewWagonHorses[attachedHorse] or 0
            SetEntityAsMissionEntity(attachedHorse, true, true)
            SetBlockingOfNonTemporaryEvents(attachedHorse, true)

            if not horseData then
                SetEntityAlpha(attachedHorse, 0, false)
                previewWagonHorses[attachedHorse] = 0
            elseif tonumber(previewWagonHorses[attachedHorse]) ~= tonumber(horseData.id) then
                Citizen.InvokeNative(0x5653AB26C82938CF, attachedHorse, 41611, horseData.gender == 'male' and 0.0 or 1.0)
                if NtHorseAppearance.Apply(attachedHorse, horseData.appearance, false, 100) then
                    SetPedPromptName(attachedHorse, horseData.name)
                    Citizen.InvokeNative(0x5DA12E025D47D4E5, attachedHorse, 16, 0)
                    SetEntityVisible(attachedHorse, true)
                    ResetEntityAlpha(attachedHorse)
                    previewWagonHorses[attachedHorse] = horseData.id
                else
                    SetEntityAlpha(attachedHorse, 0, false)
                    previewWagonHorses[attachedHorse] = 0
                end
            else
                SetEntityVisible(attachedHorse, true)
                ResetEntityAlpha(attachedHorse)
            end
        end
    end
end

local function OpenWagonHorseAssignment(wagon)
    assignmentWagonId = wagon.id
    SpawnPreviewWagon(wagon, true)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openWagonHorseAssignment',
        wagonId = wagon.id,
        wagonName = wagon.name,
        horseCount = ConfigWagon.Wagons[wagon.model].horseCount,
        assignments = wagon.horses or {},
        horses = BuildHorseList(),
    })
end

local function SpawnPreviewHorse(horse)
    DeletePreviewWagon()
    DeletePreviewHorse()
    previewIsWagon = false
    cameraDistance = 2.25 + (cameraZoom * 0.045)
    UpdateCustomizeCamera()

    local modelHash = joaat(horse.horse)
    local timeout = GetGameTimer() + 10000

    RequestModel(modelHash, false)
    while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
        Wait(0)
    end

    if not HasModelLoaded(modelHash) then
        lib.notify({ title = 'Failed to load horse preview.', type = 'error', duration = 10000 })
        return
    end

    local horseCoords = ConfigStables.Locations[customizeStable].CustomizeCoords
    previewHorse = CreatePed(modelHash, horseCoords.x, horseCoords.y, horseCoords.z - 1.0, horseCoords.w, false, false, 0, 0)
    SetModelAsNoLongerNeeded(modelHash)

    if previewHorse ~= 0 and DoesEntityExist(previewHorse) then
        SetEntityAsMissionEntity(previewHorse, true, true)
        SetEntityInvincible(previewHorse, true)
        FreezeEntityPosition(previewHorse, true)
        SetBlockingOfNonTemporaryEvents(previewHorse, true)
        WaitForHorseRender(previewHorse)
        SetRandomOutfitVariation(previewHorse, true)
        Wait(0)
        WaitForHorseRender(previewHorse)
        Citizen.InvokeNative(0x5653AB26C82938CF, previewHorse, 41611, horse.gender == 'male' and 0.0 or 1.0)
        if not NtHorseAppearance.Apply(previewHorse, horse.appearance, true, 100) then
            ApplyHorseComponents(previewHorse, GetHorseComponents(horse))
        end
        Citizen.InvokeNative(0x5DA12E025D47D4E5, previewHorse, 16, 0)
    end
end

local function StartCustomizeCamera(stableName)
    customizeStable = stableName

    local horseCoords = ConfigStables.Locations[stableName].CustomizeCoords
    local cameraCoords = ConfigStables.Locations[stableName].CustomizeCamera
    local offsetX = cameraCoords.x - horseCoords.x
    local offsetY = cameraCoords.y - horseCoords.y
    local horizontalDistance = math.sqrt((offsetX * offsetX) + (offsetY * offsetY))

    cameraAngle = math.atan(offsetY, offsetX)
    cameraVerticalAngle = math.atan(cameraCoords.z - (horseCoords.z + 1.0), horizontalDistance)
    cameraZoom = 50
    cameraDistance = 2.25 + (cameraZoom * 0.045)

    customizeCamera = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', cameraCoords.x, cameraCoords.y, cameraCoords.z, 0.0, 0.0, cameraCoords.w, 40.0, true, 0)
    UpdateCustomizeCamera()
    SetCamActive(customizeCamera, true)
    RenderScriptCams(true, true, 500, true, true)
end

local function OpenCustomization(horse)
    customization = {
        horse = horse,
        components = GetHorseComponents(horse),
        originalComponents = GetHorseComponents(horse),
    }

    SpawnPreviewHorse({
        horse = horse.horse,
        gender = horse.gender,
        components = customization.components,
    })

    local categories = {}
    for _, category in ipairs(ConfigStables.Customization) do
        local value = tonumber(customization.components[category.key]) or 0
        local originalValue = tonumber(customization.originalComponents[category.key]) or 0
        customization.components[category.key] = value
        customization.originalComponents[category.key] = originalValue

        local tints = customization.components[category.tintKey] or GetComponentTints(previewHorse, category.categoryHash) or {
            tint0 = 0,
            tint1 = 0,
            tint2 = 0,
        }
        customization.components[category.tintKey] = { tint0 = tints.tint0, tint1 = tints.tint1, tint2 = tints.tint2 }
        customization.originalComponents[category.tintKey] = customization.originalComponents[category.tintKey] or {
            tint0 = tints.tint0,
            tint1 = tints.tint1,
            tint2 = tints.tint2,
        }

        categories[#categories + 1] = {
            key = category.key,
            label = category.label,
            defaultLabel = category.defaultLabel or 'None',
            price = category.price,
            value = value,
            originalValue = originalValue,
            maximum = #HorseComponents[category.key],
            models = category.models,
            tints = customization.components[category.tintKey],
            originalTints = customization.originalComponents[category.tintKey],
        }
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openHorseCustomization',
        name = horse.name,
        gender = horse.gender,
        breed = HorseStats.Get(horse.horse).breed,
        categories = categories,
        cameraZoom = cameraZoom,
    })
end

local function BuildWagonCatalog()
    local catalog = {}
    for model, wagon in pairs(ConfigWagon.Wagons) do
        catalog[#catalog + 1] = {
            model = model,
            label = wagon.label,
            description = wagon.description,
            category = wagon.category,
            price = wagon.price,
            horseCount = wagon.horseCount,
            maxWeight = wagon.maxWeight,
            slots = wagon.slots,
            livery = wagon.customizations.livery,
            tint = wagon.customizations.tint,
            extras = wagon.customizations.extras,
            lanterns = wagon.customizations.lanterns or { 0 },
        }
    end
    table.sort(catalog, function(left, right) return left.label < right.label end)
    return catalog
end

local function OpenWagonCustomization(wagon)
    local model
    if wagon then
        model = wagon.model
    else
        local catalog = BuildWagonCatalog()
        model = catalog[1] and catalog[1].model
    end
    local wagonConfig = model and ConfigWagon.Wagons[model]
    if not wagonConfig then return end

    local enabledExtras = {}
    if wagon and wagon.extras then
        local success, storedExtras = pcall(json.decode, wagon.extras)
        if success and type(storedExtras) == 'table' then enabledExtras = storedExtras end
    elseif wagon and tonumber(wagon.extra) and tonumber(wagon.extra) > 0 then
        enabledExtras[1] = tonumber(wagon.extra)
    end

    wagonCustomization = {
        mode = wagon and 'customize' or 'buy',
        wagon = wagon,
        model = model,
        name = wagon and wagon.name or wagonConfig.label,
        livery = wagon and tonumber(wagon.livery) or wagonConfig.customizations.livery[1],
        tint = wagon and tonumber(wagon.tint) or wagonConfig.customizations.tint[1],
        extra = wagon and tonumber(wagon.extra) or wagonConfig.customizations.extras[1],
        extras = enabledExtras,
        lantern = wagon and wagon.lantern ~= '0' and wagon.lantern or 0,
        horses = wagon and wagon.horses or {},
    }
    if not IsWagonOption(wagonConfig.customizations.livery, wagonCustomization.livery) then
        wagonCustomization.livery = wagonConfig.customizations.livery[1]
    end
    if not IsWagonOption(wagonConfig.customizations.tint, wagonCustomization.tint) then
        wagonCustomization.tint = wagonConfig.customizations.tint[1]
    end
    if not IsWagonOption(wagonConfig.customizations.extras, wagonCustomization.extra) then
        wagonCustomization.extra = wagonConfig.customizations.extras[1]
    end
    if not IsWagonOption(wagonConfig.customizations.lanterns or { 0 }, wagonCustomization.lantern) then
        wagonCustomization.lantern = 0
    end

    SpawnPreviewWagon(wagonCustomization, wagonCustomization.mode ~= 'buy')
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openWagonCustomization',
        mode = wagonCustomization.mode,
        wagons = BuildWagonCatalog(),
        selected = {
            model = wagonCustomization.model,
            name = wagonCustomization.name,
            livery = wagonCustomization.livery,
            tint = wagonCustomization.tint,
            extra = wagonCustomization.extra,
            extras = wagonCustomization.extras,
            lantern = wagonCustomization.lantern,
        },
        prices = ConfigWagon.Prices,
        ownedHorseCount = #managedHorses,
        cameraZoom = cameraZoom,
    })
end

function CloseHorseManager()
    HorseManagerOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeHorseManager' })
    DeletePreviewHorse()
    DeletePreviewWagon()

    if customizeCamera then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(customizeCamera, false)
        customizeCamera = nil
    end

    managedHorses = {}
    managedWagons = {}
    stableManagerData = nil
    customizeStable = nil
    customization = nil
    wagonCustomization = nil
    assignmentWagonId = nil
    previewIsWagon = false
end

function OpenHorseManager(stableName)
    NtHorseAppearance.BackfillMissing()
    local managerData = lib.callback.await('nt_stables:server:getStableManagerData', false)
    if not managerData then return end

    managedHorses = managerData.horses
    managedWagons = managerData.wagons
    stableManagerData = managerData
    HorseManagerOpen = true
    customization = nil
    wagonCustomization = nil

    local selectedHorse = managedHorses[1]
    local selectedWagon = not selectedHorse and managedWagons[1]

    StartCustomizeCamera(stableName)

    if selectedHorse then
        SpawnPreviewHorse(selectedHorse)
    elseif selectedWagon then
        SpawnPreviewWagon(selectedWagon)
    end
    SetNuiFocus(true, true)
    SendStableManagerData('openHorseManager', selectedHorse and selectedHorse.id, selectedWagon and selectedWagon.id)
end

RegisterNetEvent('nt_stables:client:manageHorses', function(stableName)
    OpenHorseManager(stableName)
end)

RegisterNUICallback('customizeComponentTint', function(data, cb)
    if not customization or previewHorse == 0 then return cb({ success = false }) end

    local selectedCategory
    for _, category in ipairs(ConfigStables.Customization) do
        if category.key == data.category then
            selectedCategory = category
            break
        end
    end
    if not selectedCategory then return cb({ success = false }) end

    local tint0 = tonumber(data.tint0)
    local tint1 = tonumber(data.tint1)
    local tint2 = tonumber(data.tint2)
    if not tint0 or not tint1 or not tint2 then return cb({ success = false }) end

    tint0 = math.floor(math.max(0, math.min(255, tint0)))
    tint1 = math.floor(math.max(0, math.min(255, tint1)))
    tint2 = math.floor(math.max(0, math.min(255, tint2)))
    customization.components[selectedCategory.tintKey] = { tint0 = tint0, tint1 = tint1, tint2 = tint2 }
    ApplyComponentTints(previewHorse, selectedCategory, customization.components[selectedCategory.tintKey])
    cb({ success = true })
end)

RegisterNUICallback('selectManagedHorse', function(data, cb)
    local selectedId = tonumber(data.horseId)
    local horse = GetManagedHorse(selectedId)
    if horse then SpawnPreviewHorse(horse) end

    cb(1)
end)

RegisterNUICallback('selectManagedWagon', function(data, cb)
    local wagon = GetManagedWagon(tonumber(data.wagonId))
    if wagon then SpawnPreviewWagon(wagon) end
    cb(1)
end)

RegisterNUICallback('managedHorseAction', function(data, cb)
    local horse = GetManagedHorse(tonumber(data.horseId))
    if not horse then return cb({ success = false }) end

    if data.action == 'setRiding' then
        local result = lib.callback.await('nt_stables:server:setRidingHorse', false, horse.id)
        if result and result.success then
            local managerData = lib.callback.await('nt_stables:server:getStableManagerData', false)
            managedHorses = managerData.horses
            managedWagons = managerData.wagons
            stableManagerData = managerData
            for _, ownedHorse in ipairs(managedHorses) do
                ownedHorse.active = ownedHorse.id == horse.id and 1 or 0
            end

            TriggerEvent('nt_stables:client:ridingHorseChanged')
            if result.clearedWagon then TriggerEvent('nt_stables:client:ridingWagonChanged') end
            SendStableManagerData('refreshManagedHorses', horse.id)
            lib.notify({ title = horse.name .. ' is now your riding horse.', type = 'success', duration = 10000 })
        end

        return cb({ success = result and result.success == true })
    end

    if data.action == 'customize' then
        OpenCustomization(horse)
        return cb({ success = true })
    end

    if data.action == 'stats' then
        ShowOwnedHorseInfo(horse, true)
        return cb({ success = true })
    end

    cb({ success = false })
end)

RegisterNUICallback('managedWagonAction', function(data, cb)
    local wagon = GetManagedWagon(tonumber(data.wagonId))
    if not wagon then return cb({ success = false }) end

    if data.action == 'setRiding' then
        local result = lib.callback.await('nt_stables:server:setRidingWagon', false, wagon.id)
        if result and result.success then
            for _, ownedWagon in ipairs(managedWagons) do
                ownedWagon.active = ownedWagon.id == wagon.id
            end
            TriggerEvent('nt_stables:client:ridingWagonChanged')
            SendStableManagerData('refreshManagedHorses', nil, wagon.id)
            lib.notify({ title = wagon.name .. ' is now your active wagon.', type = 'success', duration = 10000 })
        elseif result and result.message then
            lib.notify({ title = result.message, type = 'error', duration = 10000 })
        end
        return cb({ success = result and result.success == true })
    end

    if data.action == 'repair' then
        local result = lib.callback.await('nt_stables:server:repairWagon', false, wagon.id)
        if result and result.success then
            local managerData = lib.callback.await('nt_stables:server:getStableManagerData', false)
            managedHorses = managerData.horses
            managedWagons = managerData.wagons
            stableManagerData = managerData
            local repairedWagon = GetManagedWagon(wagon.id)
            if repairedWagon then SpawnPreviewWagon(repairedWagon) end
            SendStableManagerData('refreshManagedHorses', nil, wagon.id)
            lib.notify({ title = ('%s repaired for $%.2f.'):format(wagon.name, result.price), type = 'success', duration = 10000 })
        elseif result and result.message then
            lib.notify({ title = result.message, type = 'error', duration = 10000 })
        end
        return cb({ success = result and result.success == true })
    end

    if data.action == 'assignHorses' then
        OpenWagonHorseAssignment(wagon)
        return cb({ success = true })
    end

    if data.action == 'customize' then
        OpenWagonCustomization(wagon)
        return cb({ success = true })
    end

    if data.action == 'stats' then
        local wagonConfig = ConfigWagon.Wagons[wagon.model]
        local currentWeight = 0
        for _, horse in ipairs(wagon.horses or {}) do
            local _, stats = HorseStats.Calculate(horse)
            if stats then currentWeight = currentWeight + (HorseStats.GetPullWeight(stats.strength) * 1000) end
        end

        SendNUIMessage({
            action = 'openWagonStats',
            name = wagon.name,
            label = wagonConfig.label,
            description = wagonConfig.description,
            horseCount = wagonConfig.horseCount,
            slots = wagonConfig.slots,
            currentWeight = math.min(currentWeight, wagonConfig.maxWeight),
            maxWeight = wagonConfig.maxWeight,
            price = wagonConfig.price,
        })
        return cb({ success = true })
    end

    cb({ success = false })
end)

RegisterNUICallback('setWagonHorse', function(data, cb)
    local wagonId = tonumber(data.wagonId)
    if wagonId ~= tonumber(assignmentWagonId) then return cb({ success = false }) end

    local result = lib.callback.await(
        'nt_stables:server:setWagonHorse',
        false,
        wagonId,
        tonumber(data.slot),
        tonumber(data.horseId)
    )
    if not result or not result.success then
        lib.notify({ title = result and result.message or 'Unable to update wagon horse.', type = 'error', duration = 10000 })
        return cb({ success = false })
    end

    local managerData = lib.callback.await('nt_stables:server:getStableManagerData', false)
    managedHorses = managerData.horses
    managedWagons = managerData.wagons
    stableManagerData = managerData
    local wagon = GetManagedWagon(wagonId)
    if wagon and previewWagon ~= 0 and DoesEntityExist(previewWagon) then
        SpawnPreviewWagonHorses(previewWagon, wagon)
    elseif wagon then
        SpawnPreviewWagon(wagon, true)
    end

    if result.wasRiding then
        TriggerEvent('nt_stables:client:ridingHorseChanged')
        lib.notify({ title = 'The assigned horse is no longer your riding horse.', type = 'inform', duration = 10000 })
    end
    if result.clearedWagon or result.activeWagonChanged then
        TriggerEvent('nt_stables:client:ridingWagonChanged')
    end

    SendNUIMessage({
        action = 'refreshWagonHorseAssignment',
        assignments = wagon and wagon.horses or {},
        horses = BuildHorseList(),
    })
    cb({ success = true })
end)

RegisterNUICallback('closeWagonHorseAssignment', function(_, cb)
    local wagon = GetManagedWagon(tonumber(assignmentWagonId))
    assignmentWagonId = nil
    if wagon then SpawnPreviewWagon(wagon) end
    SendNUIMessage({ action = 'closeWagonHorseAssignment' })
    SendStableManagerData('refreshManagedHorses', nil, wagon and wagon.id)
    cb(1)
end)

RegisterNUICallback('openWagonPurchase', function(_, cb)
    OpenWagonCustomization()
    cb({ success = true })
end)

RegisterNUICallback('selectWagonModel', function(data, cb)
    if not wagonCustomization or wagonCustomization.mode ~= 'buy' then return cb({ success = false }) end

    local model = tostring(data.model or ''):lower()
    local wagonConfig = ConfigWagon.Wagons[model]
    if not wagonConfig then return cb({ success = false }) end

    wagonCustomization.model = model
    wagonCustomization.livery = wagonConfig.customizations.livery[1]
    wagonCustomization.tint = wagonConfig.customizations.tint[1]
    wagonCustomization.extra = wagonConfig.customizations.extras[1]
    wagonCustomization.extras = {}
    wagonCustomization.lantern = 0
    SpawnPreviewWagon(wagonCustomization, false)

    cb({
        success = true,
        livery = wagonCustomization.livery,
        tint = wagonCustomization.tint,
        extra = wagonCustomization.extra,
        extras = wagonCustomization.extras,
        lantern = wagonCustomization.lantern,
    })
end)

RegisterNUICallback('previewWagonCustomization', function(data, cb)
    if not wagonCustomization or previewWagon == 0 then return cb({ success = false }) end

    local wagonConfig = ConfigWagon.Wagons[wagonCustomization.model]
    local livery = tonumber(data.livery)
    local tint = tonumber(data.tint)
    local extra = tonumber(data.extra)
    local extras = data.extras
    local lantern = data.lantern == 0 and 0 or tostring(data.lantern or '')
    if not wagonConfig or not IsWagonOption(wagonConfig.customizations.livery, livery)
        or not IsWagonOption(wagonConfig.customizations.tint, tint)
        or not IsWagonOption(wagonConfig.customizations.extras, extra)
        or type(extras) ~= 'table'
        or not IsWagonOption(wagonConfig.customizations.lanterns or { 0 }, lantern) then
        return cb({ success = false })
    end
    for _, enabledExtra in ipairs(extras) do
        if tonumber(enabledExtra) == 0 or not IsWagonOption(wagonConfig.customizations.extras, tonumber(enabledExtra)) then
            return cb({ success = false })
        end
    end

    local resetLivery = livery == -1 and wagonCustomization.livery ~= -1
    wagonCustomization.livery = livery
    wagonCustomization.tint = tint
    wagonCustomization.extra = extra
    wagonCustomization.extras = extras
    wagonCustomization.lantern = lantern
    if resetLivery then
        SpawnPreviewWagon(wagonCustomization, wagonCustomization.mode ~= 'buy')
    else
        ApplyWagonPreviewCustomization(previewWagon, wagonCustomization, wagonCustomization.mode ~= 'buy')
    end
    cb({ success = true })
end)

RegisterNUICallback('saveWagonCustomization', function(data, cb)
    if not wagonCustomization then return cb({ success = false }) end

    local result
    if wagonCustomization.mode == 'buy' then
        result = lib.callback.await(
            'nt_stables:server:buyWagon',
            false,
            wagonCustomization.model,
            data.name,
            wagonCustomization.livery,
            wagonCustomization.tint,
            wagonCustomization.extras,
            wagonCustomization.lantern
        )
    else
        result = lib.callback.await(
            'nt_stables:server:saveWagonCustomization',
            false,
            wagonCustomization.wagon.id,
            wagonCustomization.livery,
            wagonCustomization.tint,
            wagonCustomization.extras,
            wagonCustomization.lantern
        )
    end

    if not result or not result.success then
        lib.notify({ title = result and result.message or 'Unable to save wagon.', type = 'error', duration = 10000 })
        return cb({ success = false })
    end

    local selectedWagonId = result.wagonId or wagonCustomization.wagon.id
    local wasPurchase = wagonCustomization.mode == 'buy'
    wagonCustomization = nil

    local managerData = lib.callback.await('nt_stables:server:getStableManagerData', false)
    managedHorses = managerData.horses
    managedWagons = managerData.wagons
    stableManagerData = managerData

    local selectedWagon = GetManagedWagon(selectedWagonId)
    if selectedWagon then SpawnPreviewWagon(selectedWagon) end
    TriggerEvent('nt_stables:client:ridingWagonChanged')
    SendNUIMessage({ action = 'closeWagonCustomization' })
    SendStableManagerData('refreshManagedHorses', nil, selectedWagonId)
    lib.notify({ title = wasPurchase and 'Wagon purchased.' or 'Wagon customization saved.', type = 'success', duration = 10000 })
    cb({ success = true })
end)

RegisterNUICallback('cancelWagonCustomization', function(data, cb)
    local selectedWagon = wagonCustomization and wagonCustomization.wagon
    wagonCustomization = nil

    if selectedWagon then
        SpawnPreviewWagon(selectedWagon)
    elseif GetManagedHorse(tonumber(data.horseId)) then
        SpawnPreviewHorse(GetManagedHorse(tonumber(data.horseId)))
    elseif GetManagedWagon(tonumber(data.wagonId)) then
        SpawnPreviewWagon(GetManagedWagon(tonumber(data.wagonId)))
    elseif managedHorses[1] then
        SpawnPreviewHorse(managedHorses[1])
    elseif managedWagons[1] then
        SpawnPreviewWagon(managedWagons[1])
    else
        DeletePreviewWagon()
    end

    SendNUIMessage({ action = 'closeWagonCustomization' })
    cb(1)
end)

RegisterNUICallback('changeStableSlots', function(data, cb)
    local result = lib.callback.await('nt_stables:server:changeStableSlots', false, data.slotType, data.action)
    if not result or not result.success then
        lib.notify({ title = result and result.message or 'Unable to change stable slots.', type = 'error', duration = 10000 })
        return cb({ success = false })
    end

    managedHorses = result.horses
    managedWagons = result.wagons
    stableManagerData = result

    local action = data.action == 'buy' and 'purchased' or 'sold'
    local slotName = data.slotType == 'horse' and 'Horse' or 'Wagon'
    lib.notify({ title = ('%s slot %s.'):format(slotName, action), type = 'success', duration = 10000 })
    result.horses = BuildHorseList()
    result.wagons = BuildWagonList()
    result.selectedHorseId = tonumber(data.selectedHorseId)
    result.selectedWagonId = tonumber(data.selectedWagonId)
    cb(result)
end)

RegisterNUICallback('customizeHorseComponent', function(data, cb)
    if not customization or previewHorse == 0 then return cb({ success = false }) end

    local selectedCategory
    for _, category in ipairs(ConfigStables.Customization) do
        if category.key == data.category then
            selectedCategory = category
            break
        end
    end

    local value = tonumber(data.value)
    if not selectedCategory or not value or value % 1 ~= 0 or value < 0 or value > #HorseComponents[selectedCategory.key] then
        return cb({ success = false })
    end

    customization.components[selectedCategory.key] = value
    if not WaitForHorseRender(previewHorse) then return cb({ success = false }) end

    local keepNaturalStyle = (selectedCategory.key == 'Manes' or selectedCategory.key == 'Tails') and value == 0
    if keepNaturalStyle then
        SpawnPreviewHorse({
            horse = customization.horse.horse,
            gender = customization.horse.gender,
            components = customization.components,
        })
    else
        Citizen.InvokeNative(0xD710A5007C2AC539, previewHorse, selectedCategory.categoryHash, 0)

        if value > 0 then
            Citizen.InvokeNative(0xD3A7B003ED343FD9, previewHorse, HorseComponents[selectedCategory.key][value].hash, true, true, false)
        end

        Citizen.InvokeNative(0xAAB86462966168CE, previewHorse, true)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, previewHorse, false, true, true, true, false)
    end
    if not WaitForHorseRender(previewHorse) then return cb({ success = false }) end

    local componentTints = GetComponentTints(previewHorse, selectedCategory.categoryHash)
    if componentTints then
        customization.components[selectedCategory.tintKey] = {
            tint0 = componentTints.tint0,
            tint1 = componentTints.tint1,
            tint2 = componentTints.tint2,
        }
    end

    cb({ success = true, tints = customization.components[selectedCategory.tintKey] })
end)

RegisterNUICallback('saveHorseCustomization', function(_, cb)
    if not customization then return cb({ success = false }) end

    local horse = customization.horse
    local appearance = NtHorseAppearance.Capture(previewHorse)
    if not appearance then
        lib.notify({ title = 'The horse appearance could not be captured.', type = 'error', duration = 10000 })
        return cb({ success = false })
    end

    local result = lib.callback.await('nt_stables:server:saveHorseComponents', false, horse.id, customization.components, appearance)
    if result and result.success then
        horse.components = json.encode(customization.components)
        horse.appearance = json.encode(appearance)
        if horse.active == 1 or horse.active == true then TriggerEvent('nt_stables:client:ridingHorseChanged') end
        customization = nil
        SendNUIMessage({ action = 'closeHorseCustomization' })
        lib.notify({ title = ('%s customized for $%s.'):format(horse.name, result.price), type = 'success', duration = 10000 })
    else
        lib.notify({ title = result and result.message or 'Unable to save horse customization.', type = 'error', duration = 10000 })
    end

    cb({ success = result and result.success or false })
end)

RegisterNUICallback('cancelHorseCustomization', function(_, cb)
    if not customization then return cb(1) end

    local horse = customization.horse
    customization = nil
    SpawnPreviewHorse(horse)
    SendNUIMessage({ action = 'closeHorseCustomization' })

    cb(1)
end)

RegisterNUICallback('renameManagedHorse', function(data, cb)
    local horse = GetManagedHorse(tonumber(data.horseId))
    if not horse then return cb({ success = false }) end

    local horseName = tostring(data.name or ''):match('^%s*(.-)%s*$')
    local success = lib.callback.await('nt_stables:server:renameHorse', false, horse.id, horseName)

    if success then
        horse.name = horseName
        if PlayerHorseData and PlayerHorseData.id == horse.id then
            PlayerHorseData.name = horseName
            if PlayerHorse ~= 0 and DoesEntityExist(PlayerHorse) then SetPedPromptName(PlayerHorse, horseName) end
        end

        SendStableManagerData('refreshManagedHorses', horse.id)
        lib.notify({ title = 'Horse renamed to ' .. horseName .. '.', type = 'success', duration = 10000 })
    else
        lib.notify({ title = 'Horse names must contain 1 to 32 characters.', type = 'error', duration = 10000 })
    end

    cb({ success = success })
end)

RegisterNUICallback('getManagedHorseSellPrice', function(data, cb)
    local horse = GetManagedHorse(tonumber(data.horseId))
    if not horse then return cb({ success = false }) end

    local sellPrice = lib.callback.await('nt_stables:server:getHorseSellPrice', false, horse.id)
    cb({ success = sellPrice ~= nil, price = sellPrice, name = horse.name })
end)

RegisterNUICallback('sellManagedHorse', function(data, cb)
    local horse = GetManagedHorse(tonumber(data.horseId))
    if not horse then return cb({ success = false }) end

    local result = lib.callback.await('nt_stables:server:sellHorse', false, horse.id)
    if not result or result.success == false then
        lib.notify({ title = result and result.message or 'Unable to sell this horse.', type = 'error', duration = 10000 })
        return cb({ success = false })
    end

    if result.wasActive then TriggerEvent('nt_stables:client:ridingHorseChanged') end
    if result.clearedWagon then TriggerEvent('nt_stables:client:ridingWagonChanged') end

    for index, ownedHorse in ipairs(managedHorses) do
        if ownedHorse.id == horse.id then
            table.remove(managedHorses, index)
            break
        end
    end

    lib.notify({ title = ('%s sold for $%s.'):format(horse.name, result.price), type = 'success', duration = 10000 })

    local managerData = lib.callback.await('nt_stables:server:getStableManagerData', false)
    managedHorses = managerData.horses
    managedWagons = managerData.wagons
    stableManagerData = managerData

    if #managedHorses > 0 then
        SpawnPreviewHorse(managedHorses[1])
        SendStableManagerData('refreshManagedHorses', managedHorses[1].id)
    elseif #managedWagons > 0 then
        SpawnPreviewWagon(managedWagons[1])
        SendStableManagerData('refreshManagedHorses', nil, managedWagons[1].id)
    else
        DeletePreviewHorse()
        SendStableManagerData('refreshManagedHorses')
    end

    cb({ success = true })
end)

RegisterNUICallback('renameManagedWagon', function(data, cb)
    local wagon = GetManagedWagon(tonumber(data.wagonId))
    if not wagon then return cb({ success = false }) end

    local wagonName = tostring(data.name or ''):match('^%s*(.-)%s*$')
    local success = lib.callback.await('nt_stables:server:renameWagon', false, wagon.id, wagonName)
    if success then
        wagon.name = wagonName
        SendStableManagerData('refreshManagedHorses', nil, wagon.id)
        lib.notify({ title = 'Wagon renamed to ' .. wagonName .. '.', type = 'success', duration = 10000 })
    else
        lib.notify({ title = 'Wagon names must contain 1 to 100 valid characters.', type = 'error', duration = 10000 })
    end

    cb({ success = success })
end)

RegisterNUICallback('getManagedWagonSellPrice', function(data, cb)
    local wagon = GetManagedWagon(tonumber(data.wagonId))
    if not wagon then return cb({ success = false }) end

    local sellPrice = lib.callback.await('nt_stables:server:getWagonSellPrice', false, wagon.id)
    cb({ success = sellPrice ~= nil, price = sellPrice, name = wagon.name })
end)

RegisterNUICallback('sellManagedWagon', function(data, cb)
    local wagon = GetManagedWagon(tonumber(data.wagonId))
    if not wagon then return cb({ success = false }) end

    local result = lib.callback.await('nt_stables:server:sellWagon', false, wagon.id)
    if not result or result.success == false then
        lib.notify({ title = result and result.message or 'Unable to sell this wagon.', type = 'error', duration = 10000 })
        return cb({ success = false })
    end

    if result.wasActive then
        TriggerEvent('nt_stables:client:ridingWagonChanged')
        TriggerEvent('nt_stables:client:ridingHorseChanged')
    end

    lib.notify({ title = ('%s sold for $%s.'):format(wagon.name, result.price), type = 'success', duration = 10000 })

    local managerData = lib.callback.await('nt_stables:server:getStableManagerData', false)
    managedHorses = managerData.horses
    managedWagons = managerData.wagons
    stableManagerData = managerData

    if managedWagons[1] then
        SpawnPreviewWagon(managedWagons[1])
        SendStableManagerData('refreshManagedHorses', nil, managedWagons[1].id)
    elseif managedHorses[1] then
        SpawnPreviewHorse(managedHorses[1])
        SendStableManagerData('refreshManagedHorses', managedHorses[1].id)
    else
        DeletePreviewWagon()
        SendStableManagerData('refreshManagedHorses')
    end

    cb({ success = true })
end)

RegisterNUICallback('openHorseAuction', function(_, cb)
    local home = lib.callback.await('nt_stables:server:getAuctionHome', false)
    if not home then return cb({ success = false }) end
    SendNUIMessage({ action = 'openHorseAuction', home = home, horses = BuildAuctionOwnedHorses() })
    cb({ success = true })
end)

RegisterNUICallback('auctionPreviewOwnedHorse', function(data, cb)
    local horse = GetManagedHorse(tonumber(data.horseId))
    if horse then SpawnPreviewHorse(horse) end
    cb({ success = horse ~= nil })
end)

RegisterNUICallback('createAuctionListing', function(data, cb)
    local horse = GetManagedHorse(tonumber(data.horseId))
    if not horse then return cb({ success = false, message = 'Horse not found.' }) end
    local result = lib.callback.await('nt_stables:server:createAuctionListing', false, horse.id, data.listingType, data.price, data.days)
    if result and result.success then
        if result.wasActive then TriggerEvent('nt_stables:client:ridingHorseChanged') end
        if result.clearedWagon then TriggerEvent('nt_stables:client:ridingWagonChanged') end
        local managerData = lib.callback.await('nt_stables:server:getStableManagerData', false)
        managedHorses, managedWagons, stableManagerData = managerData.horses, managerData.wagons, managerData
        auctionHeld = lib.callback.await('nt_stables:server:getHeldHorses', false)
        SendNUIMessage({ action = 'refreshAuctionHeld', held = auctionHeld })
        lib.notify({ title = horse.name .. ' was moved to the auction stable.', type = 'success', duration = 10000 })
    else
        lib.notify({ title = result and result.message or 'The horse could not be listed.', type = 'error', duration = 10000 })
    end
    cb(result or { success = false })
end)

RegisterNUICallback('getAuctionListings', function(data, cb)
    auctionListings = lib.callback.await('nt_stables:server:getAuctionListings', false, data.listingType, data.filters) or {}
    cb({ success = true, listings = auctionListings })
end)

RegisterNUICallback('getTrackedAuctions', function(_, cb)
    auctionListings = lib.callback.await('nt_stables:server:getTrackedAuctions', false) or {}
    cb({ success = true, listings = auctionListings })
end)

RegisterNUICallback('trackAuction', function(data, cb)
    local result = lib.callback.await('nt_stables:server:trackAuction', false, data.listingId)
    if result and result.success then
        lib.notify({ title = 'Auction added to your tracked auctions.', type = 'success', duration = 10000 })
    else
        lib.notify({ title = result and result.message or 'The auction could not be tracked.', type = 'error', duration = 10000 })
    end
    cb(result or { success = false })
end)

RegisterNUICallback('untrackAuction', function(data, cb)
    local result = lib.callback.await('nt_stables:server:untrackAuction', false, data.listingId)
    cb(result or { success = false })
end)

RegisterNUICallback('auctionPreviewListing', function(data, cb)
    local listingId = tonumber(data.listingId)
    for _, listing in ipairs(auctionListings) do
        if tonumber(listing.id) == listingId then SpawnPreviewHorse(listing.horse) return cb({ success = true }) end
    end
    for _, listing in ipairs(auctionHeld.selling or {}) do
        if tonumber(listing.id) == listingId then SpawnPreviewHorse(listing.horse) return cb({ success = true }) end
    end
    cb({ success = false })
end)

RegisterNUICallback('buyAuctionHorse', function(data, cb)
    local result = lib.callback.await('nt_stables:server:buyAuctionHorse', false, data.listingId)
    lib.notify({ title = result and result.success and 'Horse purchased. It is waiting under Horses Held.' or (result and result.message or 'Purchase failed.'), type = result and result.success and 'success' or 'error', duration = 10000 })
    cb(result or { success = false })
end)

RegisterNUICallback('placeAuctionBid', function(data, cb)
    local result = lib.callback.await('nt_stables:server:placeAuctionBid', false, data.listingId, data.amount)
    lib.notify({ title = result and result.success and 'Bid placed.' or (result and result.message or 'Bid failed.'), type = result and result.success and 'success' or 'error', duration = 10000 })
    cb(result or { success = false })
end)

RegisterNUICallback('getHeldHorses', function(_, cb)
    auctionHeld = lib.callback.await('nt_stables:server:getHeldHorses', false) or { selling = {}, receiving = {}, funds = 0 }
    cb({ success = true, held = auctionHeld })
end)

RegisterNUICallback('auctionPreviewHeldHorse', function(data, cb)
    local heldId = tonumber(data.heldId)
    local records = data.heldType == 'selling' and auctionHeld.selling or auctionHeld.receiving
    for _, record in ipairs(records or {}) do
        if tonumber(record.id) == heldId then SpawnPreviewHorse(record.horse) return cb({ success = true }) end
    end
    cb({ success = false })
end)

RegisterNUICallback('cancelAuctionListing', function(data, cb)
    local result = lib.callback.await('nt_stables:server:cancelAuctionListing', false, data.listingId)
    if result and result.success then auctionHeld = lib.callback.await('nt_stables:server:getHeldHorses', false) end
    lib.notify({ title = result and result.success and 'Listing cancelled. The horse is waiting for your stable.' or (result and result.message or 'Cancellation failed.'), type = result and result.success and 'success' or 'error', duration = 10000 })
    cb(result and result.success and { success = true, held = auctionHeld, horses = BuildAuctionOwnedHorses() } or (result or { success = false }))
end)

RegisterNUICallback('receiveAuctionHorse', function(data, cb)
    local result = lib.callback.await('nt_stables:server:receiveAuctionHorse', false, data.receiveId)
    if result and result.success then
        local managerData = lib.callback.await('nt_stables:server:getStableManagerData', false)
        managedHorses, managedWagons, stableManagerData = managerData.horses, managerData.wagons, managerData
        auctionHeld = lib.callback.await('nt_stables:server:getHeldHorses', false)
        CreateThread(NtHorseAppearance.BackfillMissing)
    end
    lib.notify({ title = result and result.success and 'Horse added to your stable.' or (result and result.message or 'The horse could not be received.'), type = result and result.success and 'success' or 'error', duration = 10000 })
    cb(result and result.success and { success = true, held = auctionHeld, horses = BuildAuctionOwnedHorses() } or (result or { success = false }))
end)

RegisterNUICallback('collectAuctionFunds', function(_, cb)
    local result = lib.callback.await('nt_stables:server:collectAuctionFunds', false)
    if result and result.success then auctionHeld.funds = 0 end
    lib.notify({ title = result and result.success and ('$%.2f collected.'):format(result.amount) or (result and result.message or 'Funds could not be collected.'), type = result and result.success and 'success' or 'error', duration = 10000 })
    cb(result or { success = false })
end)

RegisterNUICallback('closeHorseAuction', function(_, cb)
    local managerData = lib.callback.await('nt_stables:server:getStableManagerData', false)
    managedHorses, managedWagons, stableManagerData = managerData.horses, managerData.wagons, managerData
    local horse = managedHorses[1]
    if horse then SpawnPreviewHorse(horse) else DeletePreviewHorse() end
    SendStableManagerData('returnFromHorseAuction', horse and horse.id)
    cb(1)
end)

RegisterNUICallback('horseCameraZoom', function(data, cb)
    cameraZoom = math.max(0, math.min(100, tonumber(data.zoom) or 50))
    cameraDistance = previewIsWagon and (5.0 + (cameraZoom * 0.05)) or (2.25 + (cameraZoom * 0.045))
    UpdateCustomizeCamera()
    cb(1)
end)

RegisterNUICallback('rotateHorseCamera', function(data, cb)
    cameraAngle = cameraAngle - ((tonumber(data.movementX) or 0) * 0.005)
    cameraVerticalAngle = math.max(-0.35, math.min(1.15, cameraVerticalAngle + ((tonumber(data.movementY) or 0) * 0.005)))
    UpdateCustomizeCamera()
    cb(1)
end)

RegisterNUICallback('closeHorseManager', function(_, cb)
    CloseHorseManager()
    cb(1)
end)

exports('OpenHorseManager', OpenHorseManager)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CloseHorseManager()
end)
