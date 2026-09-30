function FindStableRoadSpawn(playerCoords, playerHeading, maxDistance)
    local targetDistance = maxDistance - ConfigStables.RoadSpawn.NodeDistance
    if targetDistance < ConfigStables.RoadSpawn.MinimumDistance then return nil end

    local gap = ConfigStables.RoadSpawn.GridGap
    local headingOffsets = { 0.0, 15.0, -15.0, 30.0, -30.0, 45.0, -45.0 }
    local searchOffsets = {
        { x = 0.0, y = 0.0 },
        { x = gap, y = gap },
        { x = gap, y = -gap },
        { x = -gap, y = gap },
        { x = -gap, y = -gap },
        { x = gap * 2.0, y = gap * 2.0 },
        { x = gap * 2.0, y = gap * -2.0 },
        { x = gap * -2.0, y = gap * 2.0 },
        { x = gap * -2.0, y = gap * -2.0 },
    }

    for _, headingOffset in ipairs(headingOffsets) do
        local radians = math.rad(playerHeading + headingOffset)
        local targetCoords = vector3(
            playerCoords.x - (math.sin(radians) * targetDistance),
            playerCoords.y + (math.cos(radians) * targetDistance),
            playerCoords.z
        )

        for _, offset in ipairs(searchOffsets) do
            local foundRoad, roadCoords, roadHeading = GetNthClosestVehicleNodeFavourDirection(
                targetCoords.x + offset.x,
                targetCoords.y + offset.y,
                targetCoords.z,
                playerCoords.x,
                playerCoords.y,
                playerCoords.z,
                1,
                1,
                3.0,
                0
            )

            if foundRoad and roadCoords and type(roadHeading) == 'number' then
                local distance = #(playerCoords - roadCoords)
                if distance >= ConfigStables.RoadSpawn.MinimumDistance
                    and distance <= maxDistance
                    and IsPointOnRoad(roadCoords.x, roadCoords.y, roadCoords.z, 0)
                then
                    return {
                        coords = roadCoords,
                        heading = roadHeading,
                    }
                end
            end
        end
    end

    return nil
end
