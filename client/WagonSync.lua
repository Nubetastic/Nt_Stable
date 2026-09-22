WagonSync = {
    UpdatedWagons = {},
    NotUpdatedWagons = {},
}

local scanRunning = false
local initialSyncRequested = false

local function RequestInitialSync()
    if initialSyncRequested then return end
    initialSyncRequested = true
    TriggerServerEvent('nt_stables:server:requestWagonSync')
end

local function ScanWagons()
    if scanRunning then return end
    scanRunning = true

    CreateThread(function()
        while next(WagonSync.NotUpdatedWagons) do
            for networkId, wagonData in pairs(WagonSync.NotUpdatedWagons) do
                local wagon = NetworkGetEntityFromNetworkId(networkId)
                if wagon ~= 0 and DoesEntityExist(wagon) then
                    local updated = true

                    for _, horseData in ipairs(wagonData.horses or {}) do
                        local slot = tonumber(horseData.slot)
                        if not slot or not wagonData.updatedHorses[slot] then
                            local horse = slot and Citizen.InvokeNative(
                                0xA8BA0BAE0173457B,
                                wagon,
                                slot - 1,
                                Citizen.ResultAsInteger()
                            ) or 0

                            if horse == 0 or not DoesEntityExist(horse) then
                                updated = false
                            else
                                SetPedPromptName(horse, horseData.name)
                                Citizen.InvokeNative(
                                    0x5653AB26C82938CF,
                                    horse,
                                    41611,
                                    horseData.gender == 'male' and 0.0 or 1.0
                                )
                                if NtHorseAppearance.Apply(horse, horseData.appearance, false) then
                                    wagonData.updatedHorses[slot] = true
                                else
                                    updated = false
                                end
                            end
                        end
                    end

                    if updated then
                        WagonSync.UpdatedWagons[networkId] = {
                            wagon = wagon,
                            data = wagonData,
                        }
                        WagonSync.NotUpdatedWagons[networkId] = nil
                    end
                end
            end

            Wait(500)
        end

        scanRunning = false
    end)
end

local function AddWagon(wagonData)
    local networkId = wagonData and tonumber(wagonData.networkId)
    if not networkId then return end

    wagonData.updatedHorses = {}
    WagonSync.UpdatedWagons[networkId] = nil
    WagonSync.NotUpdatedWagons[networkId] = wagonData

    local wagon = NetworkGetEntityFromNetworkId(networkId)
    if wagon ~= 0 and wagon == PlayerWagon then
        WagonSync.UpdatedWagons[networkId] = {
            wagon = wagon,
            data = wagonData,
        }
        WagonSync.NotUpdatedWagons[networkId] = nil
        return
    end

    ScanWagons()
end

local function RemoveWagon(networkId)
    networkId = tonumber(networkId)
    if not networkId then return end

    WagonSync.UpdatedWagons[networkId] = nil
    WagonSync.NotUpdatedWagons[networkId] = nil
end

function WagonSync.Register(wagon, wagonId)
    if wagon == 0 or not DoesEntityExist(wagon) or not NetworkGetEntityIsNetworked(wagon) then return end

    TriggerServerEvent(
        'nt_stables:server:registerWagonSync',
        tonumber(wagonId),
        NetworkGetNetworkIdFromEntity(wagon)
    )
end

function WagonSync.Remove(wagon)
    if wagon == 0 or not DoesEntityExist(wagon) or not NetworkGetEntityIsNetworked(wagon) then return end
    TriggerServerEvent('nt_stables:server:removeWagonSync', NetworkGetNetworkIdFromEntity(wagon))
end

RegisterNetEvent('nt_stables:client:addWagonSync', AddWagon)
RegisterNetEvent('nt_stables:client:removeWagonSync', RemoveWagon)
RegisterNetEvent('nt_stables:client:setWagonSync', function(wagons)
    WagonSync.UpdatedWagons = {}
    WagonSync.NotUpdatedWagons = {}

    for _, wagonData in pairs(wagons or {}) do
        AddWagon(wagonData)
    end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    RequestInitialSync()
end)

CreateThread(function()
    Wait(1000)
    RequestInitialSync()
end)
