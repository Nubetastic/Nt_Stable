local RSGCore = exports['rsg-core']:GetCoreObject()
local syncedWagons = {}

local function GetWagonHorses(citizenid, wagonId)
    return MySQL.query.await([[SELECT assignments.slot, horses.id, horses.name, horses.gender,
        horses.appearance FROM nt_stable_wagon_horses assignments
        INNER JOIN nt_stable_horses horses ON horses.id = assignments.horse_id
        WHERE assignments.wagon_id = ? AND assignments.citizenid = ? AND horses.citizenid = ?
        ORDER BY assignments.slot]], {
        wagonId,
        citizenid,
        citizenid,
    })
end

local function BroadcastWagon(wagonData)
    TriggerClientEvent('nt_stables:client:addWagonSync', -1, wagonData)
end

local function RemovePlayerWagon(source)
    for networkId, wagonData in pairs(syncedWagons) do
        if wagonData.owner == source then
            syncedWagons[networkId] = nil
            TriggerClientEvent('nt_stables:client:removeWagonSync', -1, networkId)
        end
    end
end

RegisterSqlEvent('nt_stables:server:registerWagonSync', function(src, wagonId, networkId)
    local Player = RSGCore.Functions.GetPlayer(src)
    wagonId = tonumber(wagonId)
    networkId = tonumber(networkId)
    if not Player or not wagonId or not networkId then return end
    if tonumber(Player.PlayerData.metadata.stable_active_wagon) ~= wagonId then return end

    local wagonData = MySQL.single.await([[SELECT id, wagonid, model, name, livery, tint, extras, lantern
        FROM nt_stable_wagons WHERE id = ? AND citizenid = ?]], {
        wagonId,
        Player.PlayerData.citizenid,
    })
    if not wagonData then return end

    local timeout = GetGameTimer() + 5000
    local wagon = NetworkGetEntityFromNetworkId(networkId)
    while (wagon == 0 or not DoesEntityExist(wagon)) and GetGameTimer() < timeout do
        Wait(100)
        wagon = NetworkGetEntityFromNetworkId(networkId)
    end
    if wagon == 0 or not DoesEntityExist(wagon) or NetworkGetEntityOwner(wagon) ~= src then return end
    if GetEntityModel(wagon) ~= joaat(wagonData.model) then return end

    RemovePlayerWagon(src)
    syncedWagons[networkId] = {
        owner = src,
        wagonId = wagonId,
        networkId = networkId,
        wagon = wagonData,
        horses = GetWagonHorses(Player.PlayerData.citizenid, wagonId),
    }
    BroadcastWagon(syncedWagons[networkId])
end)

RegisterNetEvent('nt_stables:server:removeWagonSync', function(networkId)
    networkId = tonumber(networkId)
    local wagonData = networkId and syncedWagons[networkId]
    if not wagonData or wagonData.owner ~= source then return end

    syncedWagons[networkId] = nil
    TriggerClientEvent('nt_stables:client:removeWagonSync', -1, networkId)
end)

RegisterNetEvent('nt_stables:server:requestWagonSync', function()
    TriggerClientEvent('nt_stables:client:setWagonSync', source, syncedWagons)
end)

AddEventHandler('playerDropped', function()
    RemovePlayerWagon(source)
end)
