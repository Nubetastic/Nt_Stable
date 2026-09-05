local stableZones = {}
local stableInventoryOpen = false
local stableInventoryName

local function CloseStableInventory()
    stableInventoryOpen = false
    stableInventoryName = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeStableInventory' })
end

local function OpenStableInventory(stableName)
    local inventory = lib.callback.await('nt_stables:server:getStableInventory', false, stableName)
    if not inventory then return end
    stableInventoryOpen = true
    stableInventoryName = stableName
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openStableInventory', inventory = inventory })
end

CreateThread(function()
    for stableName, stable in pairs(ConfigStables.Locations) do
        local selectedStable = stableName

        stableZones[selectedStable] = exports.ox_target:addSphereZone({
            coords = stable.npcCoords,
            radius = ConfigStables.Settings.NpcZoneRadius,
            drawSprite = false,
            options = {
                {
                    name = 'nt_stables:open:' .. selectedStable,
                    icon = 'fa-solid fa-horse-head',
                    label = 'Open Stable',
                    distance = ConfigStables.Settings.ZoneDistance,
                    onSelect = function()
                        OpenHorseManager(selectedStable)
                    end,
                },
                {
                    name = 'nt_stables:storage:' .. selectedStable,
                    icon = 'fa-solid fa-box-open',
                    label = 'Stable Storage',
                    distance = ConfigStables.Settings.ZoneDistance,
                    onSelect = function()
                        OpenStableInventory(selectedStable)
                    end,
                },
            },
        })
    end
end)

RegisterNUICallback('transferStableInventory', function(data, cb)
    if not stableInventoryOpen then return cb({ success = false }) end
    local result = lib.callback.await('nt_stables:server:transferStableInventory', false, stableInventoryName, data.destination, data.slots)
    if not result or not result.success then
        lib.notify({ title = result and result.message or 'The item transfer failed.', type = 'error' })
    end
    cb(result or { success = false })
end)

RegisterNUICallback('closeStableInventory', function(_, cb)
    CloseStableInventory()
    cb(1)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for _, zoneId in pairs(stableZones) do
        exports.ox_target:removeZone(zoneId)
    end
    if stableInventoryOpen then CloseStableInventory() end
end)
