local HorseStats = lib.load('shared.horse_stats')

StableStalls = {}

local modelsByBreed = {}

for model, stats in pairs(HorseStats.GetAll()) do
    local breedKey = stats.breed:lower():gsub('[%s%-]+', '_')
    if breedKey == 'hungarian_half_bred' then breedKey = 'hungarian_halfbred' end

    modelsByBreed[breedKey] = modelsByBreed[breedKey] or {}
    modelsByBreed[breedKey][#modelsByBreed[breedKey] + 1] = model
end

math.randomseed(os.time())

for stableName, stable in pairs(ConfigStables.Locations) do
    local availableModels = {}

    for _, breedType in ipairs(stable.Breeds) do
        for _, breedKey in ipairs(ConfigStables.BreedTypes[breedType].breeds) do
            for _, model in ipairs(modelsByBreed[breedKey] or {}) do
                availableModels[#availableModels + 1] = model
            end
        end
    end

    table.sort(availableModels)
    StableStalls[stableName] = {}

    for stallNumber in pairs(stable.Stale) do
        if #availableModels == 0 then break end

        local modelIndex = math.random(#availableModels)
        StableStalls[stableName][stallNumber] = availableModels[modelIndex]
        table.remove(availableModels, modelIndex)
    end
end

RegisterNetEvent('nt_stables:server:requestStalls', function()
    TriggerClientEvent('nt_stables:client:setStalls', source, StableStalls)
end)
