local stableBlips = {}

CreateThread(function()
    for _, stable in pairs(ConfigStables.Locations) do
        local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, stable.npcCoords.x, stable.npcCoords.y, stable.npcCoords.z)

        if blip and blip ~= 0 then
            Citizen.InvokeNative(0x74F74D3207ED525C, blip, joaat(ConfigStables.Blip.blipSprite), true)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, CreateVarString(10, 'LITERAL_STRING', ConfigStables.Blip.blipName))
            Citizen.InvokeNative(0xD38744167B2FA257, blip, ConfigStables.Blip.blipScale)
            stableBlips[#stableBlips + 1] = blip
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for _, blip in ipairs(stableBlips) do
        RemoveBlip(blip)
    end
end)
