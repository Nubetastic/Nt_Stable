PlayerWagon = 0
PlayerWagonData = nil
PlayerWagonHorses = {}

local wagonBlip
local wagonDriveId = 0
local wagonMonitorId = 0
local activeWagonContext
local HitchWagonHorses

local function DriveWagonToPlayer()
    wagonDriveId = wagonDriveId + 1
    local currentDriveId = wagonDriveId
    local wagon = PlayerWagon

    CreateThread(function()
        Wait(1000)
        if wagonDriveId ~= currentDriveId or PlayerWagon ~= wagon or not DoesEntityExist(wagon) then return end

        local playerCoords = GetEntityCoords(cache.ped)
        local destinationCoords = playerCoords
        local foundRoadCoords, roadCoords = GetClosestVehicleNodeWithHeading(
            playerCoords.x,
            playerCoords.y,
            playerCoords.z,
            0,
            3.0,
            0
        )
        if foundRoadCoords and roadCoords then destinationCoords = roadCoords end

        Citizen.InvokeNative(
            0x391073B9D3CCE2BA,
            wagon,
            destinationCoords.x,
            destinationCoords.y,
            destinationCoords.z,
            ConfigStables.WagonApproach.Speed,
            ConfigStables.WagonApproach.DrivingFlags,
            0,
            ConfigStables.WagonApproach.StopDistance,
            1.0
        )

        while wagonDriveId == currentDriveId and PlayerWagon == wagon and DoesEntityExist(wagon) do
            Wait(250)

            local wagonCoords = GetEntityCoords(wagon)
            local playerDistance = #(GetEntityCoords(cache.ped) - wagonCoords)
            local destinationDistance = #(destinationCoords - wagonCoords)
            if playerDistance <= ConfigStables.WagonApproach.StopDistance
                or destinationDistance <= ConfigStables.WagonApproach.StopDistance
            then
                Citizen.InvokeNative(
                    0x391073B9D3CCE2BA,
                    wagon,
                    wagonCoords.x,
                    wagonCoords.y,
                    wagonCoords.z,
                    0.0,
                    ConfigStables.WagonApproach.DrivingFlags,
                    0,
                    0.0,
                    1.0
                )
                return
            end
        end
    end)
end

local function SpawnWagonHorses(wagon, wagonData)
    local wagonConfig = ConfigWagon.Wagons[wagonData.model]
    if not wagonConfig then return 0 end
    local attachedCount = 0

    SetDraftVehicleAnimalsCanDetach(wagon, false)
    SetDraftVehicleAllowDraftAnimalAutoCreation(wagon, true)
    Wait(3000)

    for slot = 1, wagonConfig.horseCount do
        local harnessIndex = slot - 1
        local horseData
        for _, assignedHorse in ipairs(wagonData.horses or {}) do
            if tonumber(assignedHorse.slot) == slot then
                horseData = assignedHorse
                break
            end
        end

        if horseData then
            local timeout = GetGameTimer() + 10000
            local horse = Citizen.InvokeNative(0xA8BA0BAE0173457B, wagon, harnessIndex, Citizen.ResultAsInteger())
            while (horse == 0 or not DoesEntityExist(horse)) and GetGameTimer() < timeout do
                Wait(100)
                horse = Citizen.InvokeNative(0xA8BA0BAE0173457B, wagon, harnessIndex, Citizen.ResultAsInteger())
            end

            if horse ~= 0 and DoesEntityExist(horse) then
                SetEntityAsMissionEntity(horse, true, true)
                SetBlockingOfNonTemporaryEvents(horse, true)
                SetPedPromptName(horse, horseData.name)
                Citizen.InvokeNative(0x5653AB26C82938CF, horse, 41611, horseData.gender == 'male' and 0.0 or 1.0)
                PlayerWagonHorses[horse] = horseData

                if NtHorseAppearance.Apply(horse, horseData.appearance, false) then
                    attachedCount = attachedCount + 1
                else
                    print(('Nt_Stables: missing or invalid cached appearance for %s in wagon %s slot %d.'):format(
                        tostring(horseData.name),
                        tostring(wagonData.model),
                        slot
                    ))
                end
            else
                print(('Nt_Stables: wagon %s did not create a horse in slot %d for %s.'):format(
                    tostring(wagonData.model),
                    slot,
                    tostring(horseData.name)
                ))
            end
        else
            print(('Nt_Stables: no assigned horse found for wagon %s slot %d.'):format(
                tostring(wagonData.model),
                slot
            ))
        end
    end

    return attachedCount
end

local function ApplyWagonCustomization(wagon, wagonData)
    Citizen.InvokeNative(0x8268B098F6FCA4E2, wagon, tonumber(wagonData.tint) or 0)

    local livery = tonumber(wagonData.livery) or -1
    if livery >= 0 then
        Citizen.InvokeNative(0xF89D82A0582E46ED, wagon, livery)
    end

    if wagonData.props and wagonData.props ~= '' and wagonData.props ~= '0' then
        Citizen.InvokeNative(0x75F90E4051CC084C, wagon, joaat(wagonData.props))
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

local function RemoveWagonTarget(wagon)
    if wagon == 0 then return end
    exports.ox_target:removeLocalEntity(wagon, {
        'nt_player_wagon_inventory',
        'nt_player_wagon_hitch_horses',
    })
end

local function SetupWagonTarget(wagon, wagonData)
    exports.ox_target:addLocalEntity(wagon, {
        {
            name = 'nt_player_wagon_inventory',
            icon = 'fa-solid fa-box-open',
            label = 'Wagon Storage',
            distance = 3.0,
            onSelect = function()
                TriggerServerEvent('nt_stables:server:openWagonInventory', wagonData.id)
            end,
        },
        {
            name = 'nt_player_wagon_hitch_horses',
            icon = 'fa-solid fa-link',
            label = 'Hitch Horses',
            distance = 3.0,
            canInteract = function(entity)
                return activeWagonContext and activeWagonContext.broken and entity == PlayerWagon
                    and not activeWagonContext.destroyed
            end,
            onSelect = function()
                HitchWagonHorses(wagon, wagonData)
            end,
        },
    })
end

local function ClearPlayerWagonState(wagon)
    if PlayerWagon ~= wagon then return end

    RemoveWagonTarget(wagon)
    wagonDriveId = wagonDriveId + 1
    if wagonBlip then
        RemoveBlip(wagonBlip)
        wagonBlip = nil
    end

    PlayerWagon = 0
    PlayerWagonData = nil
    PlayerWagonHorses = {}
end

local function DeletePlayerWagon()
    local wagon = PlayerWagon
    if wagon == 0 then return end

    WagonSync.Remove(wagon)

    if activeWagonContext and PlayerWagonData and activeWagonContext.wagon == wagon
        and DoesEntityExist(wagon) and IsEntityDead(wagon) then
        activeWagonContext.destroyed = true
    end
    if activeWagonContext then activeWagonContext.isSpawned = false end

    if activeWagonContext and activeWagonContext.destroyed and PlayerWagonData then
        TriggerServerEvent('nt_stables:server:wagonDestroyed', PlayerWagonData.id)
    end
    RemoveWagonTarget(wagon)
    wagonDriveId = wagonDriveId + 1
    wagonMonitorId = wagonMonitorId + 1

    if wagonBlip then
        RemoveBlip(wagonBlip)
        wagonBlip = nil
    end

    if DoesEntityExist(wagon) then
        SetEntityAsMissionEntity(wagon, true, true)
        DeleteVehicle(wagon)
        if DoesEntityExist(wagon) then DeleteEntity(wagon) end
    end

    for horse, horseData in pairs(PlayerWagonHorses) do
        local horseState = state.horse[horseData.id]
        if horseState and horseState.entity == horse then
            if DoesEntityExist(horse) then horseState.dead = IsEntityDead(horse) end
            horseState.isSpawned = false
            if horseState.dead then
                TriggerServerEvent('nt_stables:server:horseFailedRevive', horseData.id)
            end
            state.horse[horseData.id] = nil
        end
        if DoesEntityExist(horse) then
            if activeWagonContext and activeWagonContext.destroyed and not IsEntityDead(horse) then
                ClearPedTasks(horse)
                TaskSmartFleePed(horse, cache.ped, 5.0, 3000, 0, 1.0, cache.ped)
                SetEntityAsNoLongerNeeded(horse)
            else
                SetEntityAsMissionEntity(horse, true, true)
                DeletePed(horse)
                if DoesEntityExist(horse) then DeleteEntity(horse) end
            end
        end
    end

    if PlayerWagonData and state.wagon[PlayerWagonData.id] == activeWagonContext then
        state.wagon[PlayerWagonData.id] = nil
    end
    ClearPlayerWagonState(wagon)
    activeWagonContext = nil
end

local function FleeAndDespawnWagonHorse(horse, horseState)
    ClearPedTasks(horse)
    TaskSmartFleePed(horse, cache.ped, 5.0, 3000, 0, 1.0, cache.ped)
    horseState.fleeTicks = 40

    while horseState.isSpawned and DoesEntityExist(horse) and horseState.fleeTicks > 0 do
        Wait(500)
        horseState.fleeTicks = horseState.fleeTicks - 1
    end

    horseState.isSpawned = false
    if DoesEntityExist(horse) then
        SetEntityAsMissionEntity(horse, true, true)
        DeletePed(horse)
        if DoesEntityExist(horse) then DeleteEntity(horse) end
    end
end

local function StartWagonHorseMonitor(horse, horseData, context)
    local horseState = {
        entity = horse,
        isSpawned = true,
        dead = false,
        deathPending = false,
        detached = false,
    }
    state.horse[horseData.id] = horseState

    CreateThread(function()
        while state.horse[horseData.id] == horseState and horseState.isSpawned and DoesEntityExist(horse) do
            Wait(500)
            if state.horse[horseData.id] ~= horseState then return end
            if not horseState.isSpawned or not DoesEntityExist(horse) then break end
            horseState.dead = IsEntityDead(horse)

            if horseState.dead then
                context.broken = true
                local deathCoords = GetEntityCoords(horse)
                local reviveDeadline = GetGameTimer() + ConfigStables.Settings.HorseReviveTime
                local tenSecondWarning = false
                horseState.deathPending = true
                lib.notify({
                    title = horseData.name .. ' has died.',
                    description = 'Use a horse reviver within 3 minutes.',
                    type = 'error',
                    duration = 10000,
                })
                if NetworkGetEntityIsNetworked(horse) then
                    SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(horse), false)
                end
                if DoesEntityExist(context.wagon) then
                    Citizen.InvokeNative(0x4402960666000E62, context.wagon, tonumber(horseData.slot) - 1)
                end
                horseState.detached = true
                SetEntityAsNoLongerNeeded(horse)

                while horseState.isSpawned and DoesEntityExist(horse) and IsEntityDead(horse) and GetGameTimer() < reviveDeadline
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

                if state.horse[horseData.id] ~= horseState then return end
                if horseState.isSpawned and DoesEntityExist(horse) and not IsEntityDead(horse) then
                    horseState.dead = false
                    horseState.deathPending = false
                    SetEntityHealth(horse, GetEntityMaxHealth(horse))
                    SetBlockingOfNonTemporaryEvents(horse, false)

                    if context.destroyed or not DoesEntityExist(context.wagon) or IsEntityDead(context.wagon) then
                        if NetworkGetEntityIsNetworked(horse) then
                            SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(horse), false)
                        end
                        FleeAndDespawnWagonHorse(horse, horseState)
                        if state.horse[horseData.id] == horseState then state.horse[horseData.id] = nil end
                        return
                    end

                    SetEntityAsMissionEntity(horse, true, true)
                    if NetworkGetEntityIsNetworked(horse) then
                        SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(horse), true)
                    end
                    ClearPedTasks(horse)
                    Citizen.InvokeNative(0x931B241409216C1F, cache.ped, horse, false)
                    exports.ox_target:addLocalEntity(horse, {
                        {
                            name = 'nt_wagon_horse_lead',
                            icon = 'fa-solid fa-horse',
                            label = 'Lead Horse',
                            distance = 2.5,
                            canInteract = function(entity)
                                return not context.destroyed and not IsEntityDead(entity) and DoesEntityExist(context.wagon)
                                    and not IsEntityDead(context.wagon)
                            end,
                            onSelect = function()
                                if DoesEntityExist(horse) and not IsEntityDead(horse) then
                                    Citizen.InvokeNative(0x9A7A4A54596FE09D, cache.ped, horse)
                                end
                            end,
                        },
                    })
                    while horseState.isSpawned and DoesEntityExist(horse) and not IsEntityDead(horse)
                        and DoesEntityExist(context.wagon) and not context.destroyed and not IsEntityDead(context.wagon) do
                        Wait(500)
                    end
                    exports.ox_target:removeLocalEntity(horse, { 'nt_wagon_horse_lead' })
                else
                    horseState.isSpawned = false
                    if horseState.dead and horseState.deathPending then
                        TriggerServerEvent('nt_stables:server:horseFailedRevive', horseData.id)
                    end
                    if state.horse[horseData.id] == horseState then state.horse[horseData.id] = nil end
                    PlayerWagonHorses[horse] = nil
                    return
                end
            elseif context.destroyed then
                if DoesEntityExist(context.wagon) then
                    Citizen.InvokeNative(0x4402960666000E62, context.wagon, tonumber(horseData.slot) - 1)
                end
                if NetworkGetEntityIsNetworked(horse) then
                    SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(horse), false)
                end
                FleeAndDespawnWagonHorse(horse, horseState)
                if state.horse[horseData.id] == horseState then state.horse[horseData.id] = nil end
                return
            end
        end

        if state.horse[horseData.id] == horseState then
            horseState.isSpawned = false
            if horseState.dead and horseState.deathPending then
                TriggerServerEvent('nt_stables:server:horseFailedRevive', horseData.id)
            end
            state.horse[horseData.id] = nil
        end
    end)
end

local function ReleaseDestroyedWagon(wagon, wagonData, context)
    if context.destroyed then return end
    context.destroyed = true

    WagonSync.Remove(wagon)

    wagonDriveId = wagonDriveId + 1

    if NetworkGetEntityIsNetworked(wagon) then
        SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(wagon), false)
    end
    SetEntityAsNoLongerNeeded(wagon)
end

local function StartWagonMonitor(wagon, wagonData, context)
    wagonMonitorId = wagonMonitorId + 1
    local monitorId = wagonMonitorId

    for horse, horseData in pairs(PlayerWagonHorses) do
        StartWagonHorseMonitor(horse, horseData, context)
    end

    CreateThread(function()
        while wagonMonitorId == monitorId and PlayerWagon == wagon and context.isSpawned
            and state.wagon[wagonData.id] == context and DoesEntityExist(wagon) do
            Wait(500)
            if wagonMonitorId ~= monitorId or PlayerWagon ~= wagon or state.wagon[wagonData.id] ~= context then return end
            if not context.isSpawned or not DoesEntityExist(wagon) then break end
            if IsEntityDead(wagon) then
                ReleaseDestroyedWagon(wagon, wagonData, context)
            end

            if #(GetEntityCoords(cache.ped) - GetEntityCoords(wagon)) > ConfigStables.Settings.WagonSpawnDistance then
                DeletePlayerWagon()
                return
            end
        end

        if wagonMonitorId == monitorId and PlayerWagon == wagon and state.wagon[wagonData.id] == context then
            if context.destroyed then
                TriggerServerEvent('nt_stables:server:wagonDestroyed', wagonData.id)
                state.wagon[wagonData.id] = nil
                ClearPlayerWagonState(wagon)
                activeWagonContext = nil
            else
                DeletePlayerWagon()
            end
        end
    end)
end

HitchWagonHorses = function(wagon, wagonData)
    if not activeWagonContext or not activeWagonContext.broken
        or state.wagon[wagonData.id] ~= activeWagonContext
        or wagon ~= PlayerWagon or not DoesEntityExist(wagon) then return end

    local wagonConfig = ConfigWagon.Wagons[wagonData.model]
    local nearbyCount = 0
    for horse, horseData in pairs(PlayerWagonHorses) do
        local horseOffset = wagonConfig.horseOffsets[tonumber(horseData.slot)]
        local hitchCoords = GetOffsetFromEntityInWorldCoords(wagon, horseOffset.x, horseOffset.y, horseOffset.z)
        if DoesEntityExist(horse) and not IsEntityDead(horse)
            and #(GetEntityCoords(horse) - hitchCoords) <= ConfigStables.Settings.WagonHorseReattachDistance then
            nearbyCount = nearbyCount + 1
        end
    end

    local response = lib.alertDialog({
        header = 'Hitch Horses',
        content = ('Nearby horses: %d\n\nOnly living assigned horses beside the wagon will be hitched.'):format(nearbyCount),
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Hitch',
            cancel = 'Exit',
        },
    })
    if response ~= 'confirm' or not activeWagonContext or not activeWagonContext.broken
        or state.wagon[wagonData.id] ~= activeWagonContext
        or wagon ~= PlayerWagon or not DoesEntityExist(wagon) then return end

    if IsEntityDead(wagon) then
        ReleaseDestroyedWagon(wagon, wagonData, activeWagonContext)
        return
    end

    local nearbyHorses = {}
    local nearbyEntities = {}
    for horse, horseData in pairs(PlayerWagonHorses) do
        local horseOffset = wagonConfig.horseOffsets[tonumber(horseData.slot)]
        local hitchCoords = GetOffsetFromEntityInWorldCoords(wagon, horseOffset.x, horseOffset.y, horseOffset.z)
        if DoesEntityExist(horse) and not IsEntityDead(horse)
            and #(GetEntityCoords(horse) - hitchCoords) <= ConfigStables.Settings.WagonHorseReattachDistance then
            nearbyHorses[#nearbyHorses + 1] = horseData
            nearbyEntities[horse] = true
        end
    end

    if #nearbyHorses == 0 then
        lib.notify({ title = 'There are no living wagon horses close enough to hitch.', type = 'error', duration = 5000 })
        return
    end

    local modelHash = joaat(wagonData.model)
    local timeout = GetGameTimer() + 10000
    RequestModel(modelHash, false)
    while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do Wait(0) end
    if not HasModelLoaded(modelHash) then
        lib.notify({ title = 'Failed to load your wagon.', type = 'error', duration = 10000 })
        return
    end

    activeWagonContext.broken = false
    local wagonCoords = GetEntityCoords(wagon)
    local wagonHeading = GetEntityHeading(wagon)
    local hitchWagonData = {
        model = wagonData.model,
        horses = nearbyHorses,
    }

    RemoveWagonTarget(wagon)
    activeWagonContext.isSpawned = false
    wagonDriveId = wagonDriveId + 1
    wagonMonitorId = wagonMonitorId + 1
    if wagonBlip then
        RemoveBlip(wagonBlip)
        wagonBlip = nil
    end

    local ledHorse = Citizen.InvokeNative(0xEFC4303DDC6E60D3, cache.ped)
        and Citizen.InvokeNative(0xED1F514AF4732258, cache.ped, Citizen.ResultAsInteger()) or 0
    if nearbyEntities[ledHorse] then Citizen.InvokeNative(0xED27560703F37258, cache.ped) end

    for horse, horseData in pairs(PlayerWagonHorses) do
        exports.ox_target:removeLocalEntity(horse, { 'nt_wagon_horse_lead' })
        local horseState = state.horse[horseData.id]
        if horseState and horseState.entity == horse then
            if DoesEntityExist(horse) then horseState.dead = IsEntityDead(horse) end
            horseState.isSpawned = false
            if horseState.dead then
                TriggerServerEvent('nt_stables:server:horseFailedRevive', horseData.id)
                state.horse[horseData.id] = nil
            else
                state.horse[horseData.id] = nil
            end
        end
        if DoesEntityExist(horse) then
            if nearbyEntities[horse] then
                SetEntityAsMissionEntity(horse, true, true)
                DeletePed(horse)
                if DoesEntityExist(horse) then DeleteEntity(horse) end
            else
                if NetworkGetEntityIsNetworked(horse) then
                    SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(horse), false)
                end
                SetEntityAsNoLongerNeeded(horse)
            end
        end
    end
    PlayerWagonHorses = {}

    if state.wagon[wagonData.id] == activeWagonContext then state.wagon[wagonData.id] = nil end
    WagonSync.Remove(wagon)
    SetEntityAsMissionEntity(wagon, true, true)
    DeleteVehicle(wagon)
    if DoesEntityExist(wagon) then DeleteEntity(wagon) end
    Wait(750)

    PlayerWagon = CreateVehicle(
        modelHash,
        wagonCoords.x,
        wagonCoords.y,
        wagonCoords.z,
        wagonHeading,
        true,
        true,
        false,
        false
    )
    SetModelAsNoLongerNeeded(modelHash)

    if PlayerWagon == 0 or not DoesEntityExist(PlayerWagon) then
        PlayerWagon = 0
        PlayerWagonData = nil
        activeWagonContext = nil
        lib.notify({ title = 'Failed to rebuild your wagon.', type = 'error', duration = 10000 })
        return
    end

    PlayerWagonData = wagonData
    activeWagonContext = { wagon = PlayerWagon, wagonId = wagonData.id, isSpawned = true, destroyed = false, broken = false }
    state.wagon[wagonData.id] = activeWagonContext
    SetEntityAsMissionEntity(PlayerWagon, true, true)
    SetDraftVehicleAnimalsCanDetach(PlayerWagon, false)
    SetDraftVehicleAllowDraftAnimalAutoCreation(PlayerWagon, true)
    Citizen.InvokeNative(0x7263332501E07F52, PlayerWagon, true)
    SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(PlayerWagon), true)
    local attachedCount = SpawnWagonHorses(PlayerWagon, hitchWagonData)
    ApplyWagonCustomization(PlayerWagon, wagonData)
    SetVehicleDirtLevel(PlayerWagon, 0.0)
    WagonSync.Register(PlayerWagon, wagonData.id)

    wagonBlip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, -1230993421, PlayerWagon)
    SetBlipSprite(wagonBlip, joaat('blip_player_coach'), true)
    Citizen.InvokeNative(0x9CB1A1623062F402, wagonBlip, wagonData.name)
    SetupWagonTarget(PlayerWagon, wagonData)
    StartWagonMonitor(PlayerWagon, wagonData, activeWagonContext)

    if attachedCount ~= #nearbyHorses then
        lib.notify({
            title = 'Some horses failed to hitch.',
            description = ('Hitched %d of %d nearby horses.'):format(attachedCount, #nearbyHorses),
            type = 'error',
            duration = 10000,
        })
    end
end

local function CallPlayerWagon()
    if PlayerWagon ~= 0 and DoesEntityExist(PlayerWagon) then
        if activeWagonContext and activeWagonContext.destroyed then
            lib.notify({ title = 'Your wagon has been destroyed.', type = 'error', duration = 10000 })
            return
        end
        DriveWagonToPlayer()
        return
    end

    NtHorseAppearance.BackfillMissing()
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

    local roadSpawn
    if ConfigStables.testSpawn then
        roadSpawn = {
            coords = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 10.0, 0.0),
            heading = GetEntityHeading(cache.ped),
        }
    else
        roadSpawn = FindStableRoadSpawn(
            GetEntityCoords(cache.ped),
            GetEntityHeading(cache.ped),
            ConfigStables.Settings.WagonCallSpawnDistance
        )
    end
    if not roadSpawn then
        SetModelAsNoLongerNeeded(modelHash)
        lib.notify({ title = 'No suitable road was found for your wagon.', type = 'error', duration = 10000 })
        return
    end

    PlayerWagon = CreateVehicle(modelHash, roadSpawn.coords.x, roadSpawn.coords.y, roadSpawn.coords.z, roadSpawn.heading, true, true, false, false)
    SetModelAsNoLongerNeeded(modelHash)

    if PlayerWagon == 0 or not DoesEntityExist(PlayerWagon) then
        PlayerWagon = 0
        lib.notify({ title = 'Failed to spawn your wagon.', type = 'error', duration = 10000 })
        return
    end

    PlayerWagonData = wagonData
    activeWagonContext = { wagon = PlayerWagon, wagonId = wagonData.id, isSpawned = true, destroyed = false, broken = false }
    state.wagon[wagonData.id] = activeWagonContext
    SetEntityAsMissionEntity(PlayerWagon, true, true)
    SetDraftVehicleAnimalsCanDetach(PlayerWagon, false)
    SetDraftVehicleAllowDraftAnimalAutoCreation(PlayerWagon, true)
    Citizen.InvokeNative(0x7263332501E07F52, PlayerWagon, true)
    SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(PlayerWagon), true)
    local attachedCount = SpawnWagonHorses(PlayerWagon, wagonData)
    if attachedCount ~= ConfigWagon.Wagons[wagonData.model].horseCount then
        lib.notify({
            title = 'Wagon horses failed to attach.',
            description = ('Attached %d of %d horses. Check the client console.'):format(
                attachedCount,
                ConfigWagon.Wagons[wagonData.model].horseCount
            ),
            type = 'error',
            duration = 10000,
        })
    end
    ApplyWagonCustomization(PlayerWagon, wagonData)
    SetVehicleDirtLevel(PlayerWagon, 0.0)
    WagonSync.Register(PlayerWagon, wagonData.id)

    wagonBlip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, -1230993421, PlayerWagon)
    SetBlipSprite(wagonBlip, joaat('blip_player_coach'), true)
    Citizen.InvokeNative(0x9CB1A1623062F402, wagonBlip, wagonData.name)
    SetupWagonTarget(PlayerWagon, wagonData)
    DriveWagonToPlayer()
    StartWagonMonitor(PlayerWagon, wagonData, activeWagonContext)
end

RegisterNetEvent('nt_stables:client:callWagon', CallPlayerWagon)
RegisterNetEvent('nt_stables:client:dismissWagon', DeletePlayerWagon)
RegisterNetEvent('nt_stables:client:ridingWagonChanged', DeletePlayerWagon)

exports('GetPlayerWagon', function()
    return PlayerWagon
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    DeletePlayerWagon()
end)
