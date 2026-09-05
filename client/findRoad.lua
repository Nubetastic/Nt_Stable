function FindStableRoadSpawn(playerCoords, playerHeading, maxDistance)
    local targetDistance = maxDistance - ConfigStables.RoadSpawn.NodeDistance
    if targetDistance < ConfigStables.RoadSpawn.MinimumDistance then return nil end

    local radians = math.rad(playerHeading)
    local targetCoords = vector3(
        playerCoords.x - (math.sin(radians) * targetDistance),
        playerCoords.y + (math.cos(radians) * targetDistance),
        playerCoords.z
    )
    local foundRoad, roadCoords, roadHeading = GetNthClosestVehicleNodeFavourDirection(
        targetCoords.x,
        targetCoords.y,
        targetCoords.z,
        playerCoords.x,
        playerCoords.y,
        playerCoords.z,
        1,
        1,
        3.0,
        0
    )
    if not foundRoad or not roadCoords or type(roadHeading) ~= 'number' then return nil end

    local distance = #(playerCoords - roadCoords)
    if distance < ConfigStables.RoadSpawn.MinimumDistance
        or distance > maxDistance
        or not IsPointOnRoad(roadCoords.x, roadCoords.y, roadCoords.z, 0)
    then
        return nil
    end

    return {
        coords = roadCoords,
        heading = roadHeading,
    }
end
