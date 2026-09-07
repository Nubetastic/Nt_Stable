local HorseStats = lib.load('shared.horse_stats')

local stableAssignments = {}
local stallHorses = {}
local openStable
local openHorseModel

function CloseHorseInfo()
    local returnToManager = HorseManagerOpen == true
    SetNuiFocus(returnToManager, returnToManager)
    SendNUIMessage({ action = 'closeHorse', returnToManager = returnToManager })
    openStable = nil
    openHorseModel = nil
end

function ShowHorseInfo(horse, showBuy, stableName)
    openStable = stableName
    horse.showBuy = showBuy
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openHorse',
        horse = horse,
    })
end

local function OpenHorseInfo(stableName, model)
    local stats = HorseStats.Get(model)
    openHorseModel = model

    ShowHorseInfo({
            model = model,
            breed = stats.breed,
            tameLevel = ConfigStables.Settings.StockTameLevel,
            price = stats.price,
            health = stats.health,
            stamina = stats.stamina,
            agility = stats.agility,
            speed = stats.speed,
            acceleration = stats.acceleration,
            strength = stats.strength,
            carryWeight = HorseStats.GetCarryWeight(stats.strength),
            pullWeight = HorseStats.GetPullWeight(stats.strength),
    }, true, stableName)
end

local function DeleteStableHorses(stableName)
    if not stallHorses[stableName] then return end

    for _, stallHorse in pairs(stallHorses[stableName]) do
        exports.ox_target:removeLocalEntity(stallHorse.entity, stallHorse.target)

        if DoesEntityExist(stallHorse.entity) then
            SetEntityAsMissionEntity(stallHorse.entity, true, true)
            DeletePed(stallHorse.entity)
            DeleteEntity(stallHorse.entity)
        end
    end

    stallHorses[stableName] = nil

    if openStable == stableName then
        CloseHorseInfo()
    end
end

local function DeleteAllStallHorses()
    for stableName in pairs(stallHorses) do
        DeleteStableHorses(stableName)
    end
end

local function SpawnStableHorses(stableName)
    stallHorses[stableName] = {}

    for stallNumber, model in pairs(stableAssignments[stableName]) do
        stallNumber = tonumber(stallNumber)
        local horseModel = model

        local modelHash = joaat(horseModel)
        local timeout = GetGameTimer() + 10000

        RequestModel(modelHash, false)
        while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
            Wait(0)
        end

        if HasModelLoaded(modelHash) then
            local stallCoords = ConfigStables.Locations[stableName].Stale[stallNumber]
            local horse = CreatePed(modelHash, stallCoords.x, stallCoords.y, stallCoords.z - 1.0, stallCoords.w, false, false, 0, 0)
            SetModelAsNoLongerNeeded(modelHash)

            if horse ~= 0 and DoesEntityExist(horse) then
                local targetName = ('nt_stables:%s:%s'):format(stableName, stallNumber)

                SetEntityAsMissionEntity(horse, true, true)
                SetEntityInvincible(horse, true)
                FreezeEntityPosition(horse, true)
                SetBlockingOfNonTemporaryEvents(horse, true)
                SetRandomOutfitVariation(horse, true)

                exports.ox_target:addLocalEntity(horse, {
                    {
                        name = targetName,
                        icon = 'fas fa-horse',
                        label = 'View Horse',
                        distance = ConfigStables.Settings.ZoneDistance,
                        onSelect = function()
                            OpenHorseInfo(stableName, horseModel)
                        end,
                    },
                })

                stallHorses[stableName][stallNumber] = {
                    entity = horse,
                    model = horseModel,
                    target = targetName,
                }
            end
        else
            print(('[Nt_Stables] Failed to load stall horse model: %s'):format(horseModel))
        end
    end
end

RegisterNetEvent('nt_stables:client:setStalls', function(assignments)
    DeleteAllStallHorses()
    stableAssignments = assignments
end)

RegisterNUICallback('closeHorse', function(_, cb)
    CloseHorseInfo()
    cb(1)
end)

RegisterNUICallback('buyHorse', function(data, cb)
    if not openStable or not openHorseModel then return cb({ success = false }) end

    local horseName = tostring(data.name or ''):match('^%s*(.-)%s*$')
    if horseName == '' or #horseName > 32 then
        lib.notify({ title = 'Horse names must contain 1 to 32 characters.', type = 'error', duration = 10000 })
        return cb({ success = false })
    end

    if data.gender ~= 'male' and data.gender ~= 'female' then
        lib.notify({ title = 'Select a horse gender.', type = 'error', duration = 10000 })
        return cb({ success = false })
    end

    local stableName = openStable
    local model = openHorseModel
    local result = lib.callback.await('nt_stables:server:buyHorse', false,
        stableName,
        model,
        horseName,
        data.gender,
        {}
    )

    if not result or not result.success then
        lib.notify({ title = result and result.message or 'Unable to buy this horse.', type = 'error', duration = 10000 })
        return cb({ success = false })
    end

    local appearanceSaved = false
    for _, stallHorse in pairs(stallHorses[stableName] or {}) do
        if stallHorse.model == model and DoesEntityExist(stallHorse.entity) then
            appearanceSaved = NtHorseAppearance.Save(result.horseId, stallHorse.entity)
            break
        end
    end
    if not appearanceSaved then CreateThread(NtHorseAppearance.BackfillMissing) end

    TriggerEvent('nt_stables:client:ridingHorseChanged')
    CloseHorseInfo()
    lib.notify({ title = horseName .. ' is now your active horse.', type = 'success', duration = 10000 })
    cb({ success = true })
end)

CreateThread(function()
    Wait(0)
    TriggerServerEvent('nt_stables:server:requestStalls')

    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())

        for stableName, stable in pairs(ConfigStables.Locations) do
            if stableAssignments[stableName] then
                local distance = #(playerCoords - stable.npcCoords)

                if distance <= ConfigStables.Settings.SpawnDistance and not stallHorses[stableName] then
                    SpawnStableHorses(stableName)
                elseif distance > ConfigStables.Settings.SpawnDistance and stallHorses[stableName] then
                    DeleteStableHorses(stableName)
                end
            end
        end

        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CloseHorseInfo()
    DeleteAllStallHorses()
end)
