local ridingTime = 0
local leadingTime = 0
local wagonTime = 0
local ridingHorse
local leadingHorse
local trainingWagon
local horseBeingPatted = false

local function ResetHorseTraining()
    ridingTime = 0
    leadingTime = 0
    ridingHorse = nil
    leadingHorse = nil
end

local function ResetWagonTraining()
    wagonTime = 0
    trainingWagon = nil
end

CreateThread(function()
    while true do
        Wait(ConfigStables.Training.CheckInterval)

        if IsEntityDead(cache.ped) then
            ResetHorseTraining()
            ResetWagonTraining()
        else
            local interval = ConfigStables.Training.CheckInterval / 1000

            if PlayerHorse ~= 0 and DoesEntityExist(PlayerHorse) and not IsEntityDead(PlayerHorse) and not PlayerHorseFleeing then
                if GetMount(cache.ped) == PlayerHorse and GetEntitySpeed(PlayerHorse) >= ConfigStables.Training.MinimumSpeed then
                    if ridingHorse ~= PlayerHorse then
                        ResetHorseTraining()
                        ridingHorse = PlayerHorse
                    end

                    ridingTime = ridingTime + interval
                    if ridingTime >= ConfigStables.Training.AwardTime then
                        ridingTime = ridingTime - ConfigStables.Training.AwardTime
                        TriggerServerEvent('nt_stables:server:addHorseTraining', 'riding')
                    end
                end

                local isLeading = Citizen.InvokeNative(0xEFC4303DDC6E60D3, cache.ped)
                local ledHorse = isLeading and Citizen.InvokeNative(0xED1F514AF4732258, cache.ped, Citizen.ResultAsInteger()) or 0

                if ledHorse == PlayerHorse and GetEntitySpeed(PlayerHorse) >= ConfigStables.Training.MinimumSpeed then
                    if leadingHorse ~= PlayerHorse then
                        ResetHorseTraining()
                        leadingHorse = PlayerHorse
                    end

                    leadingTime = leadingTime + interval
                    if leadingTime >= ConfigStables.Training.AwardTime then
                        leadingTime = leadingTime - ConfigStables.Training.AwardTime
                        TriggerServerEvent('nt_stables:server:addHorseTraining', 'leading')
                    end
                end

                local isBeingPatted = Citizen.InvokeNative(0x454AD4DA6C41B5BD, PlayerHorse, Citizen.ResultAsInteger()) == 5
                if isBeingPatted and not horseBeingPatted then
                    TriggerServerEvent('nt_stables:server:addHorseCareTraining', 'petting')
                end
                horseBeingPatted = isBeingPatted
            else
                ResetHorseTraining()
                horseBeingPatted = false
            end

            if PlayerWagon ~= 0 and DoesEntityExist(PlayerWagon) and PlayerWagonData and IsVehicleDriveable(PlayerWagon, false) then
                local isDriver = GetPedInVehicleSeat(PlayerWagon, -1) == cache.ped
                if isDriver and GetEntitySpeed(PlayerWagon) >= ConfigStables.Training.MinimumSpeed then
                    if trainingWagon ~= PlayerWagon then
                        ResetWagonTraining()
                        trainingWagon = PlayerWagon
                    end

                    wagonTime = wagonTime + interval
                    if wagonTime >= ConfigStables.Training.AwardTime then
                        wagonTime = wagonTime - ConfigStables.Training.AwardTime
                        local horseIds = {}
                        for horse, horseData in pairs(PlayerWagonHorses) do
                            if DoesEntityExist(horse) and not IsEntityDead(horse) then
                                horseIds[#horseIds + 1] = horseData.id
                            end
                        end
                        TriggerServerEvent('nt_stables:server:addWagonTraining', PlayerWagonData.id, horseIds)
                    end
                end
            else
                ResetWagonTraining()
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(0)

        if PlayerHorse ~= 0 and DoesEntityExist(PlayerHorse) then
            local eventCount = GetNumberOfEvents(0)
            for eventIndex = 0, eventCount - 1 do
                if GetEventAtIndex(0, eventIndex) == `EVENT_PLAYER_PROMPT_TRIGGERED` then
                    local eventData = string.rep('\0', 80)
                    local hasData = Citizen.InvokeNative(0x57EC5FA4D4D6AFCA, 0, eventIndex, eventData, 10)
                    if hasData and PlayerHorse == string.unpack('<i4', eventData, 17) then
                        local promptType = string.unpack('<i4', eventData)
                        if promptType == 49 then
                            TriggerServerEvent('nt_stables:server:addHorseCareTraining', 'grooming')
                        elseif promptType == 50 then
                            TriggerServerEvent('nt_stables:server:addHorseCareTraining', 'feeding')
                        end
                    end
                end
            end
        else
            Wait(500)
        end
    end
end)

RegisterNetEvent('nt_stables:client:horseTrainingAwarded', function(horseId, horseXP, message, leveledMessage)
    if PlayerHorseData and tonumber(PlayerHorseData.id) == tonumber(horseId) then
        PlayerHorseData.horsexp = horseXP
    end

    lib.notify({ title = message, type = 'success', duration = 5000 })
    if leveledMessage then
        lib.notify({ title = leveledMessage, type = 'success', duration = 10000 })
    end
end)
