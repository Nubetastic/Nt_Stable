local stableZones = {}

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
            },
        })
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for _, zoneId in pairs(stableZones) do
        exports.ox_target:removeZone(zoneId)
    end
end)
