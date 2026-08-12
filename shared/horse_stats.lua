local HorseStats = {}

-- One direct starting-stat entry per horse model.
-- Starting ranks: health/stamina/strength 1-5; agility/speed/acceleration 0-5.
local horses = {
    a_c_horse_mp_mangy_backup = { breed = 'Mangy Starter Horse', size = 'small', health = 1, stamina = 1, agility = 1, speed = 1, acceleration = 0, strength = 1 },
    a_c_horse_morgan_liverchestnut_pc = { breed = 'Morgan', size = 'small', health = 2, stamina = 3, agility = 3, speed = 3, acceleration = 4, strength = 2 },
    a_c_horse_morgan_bay = { breed = 'Morgan', size = 'small', health = 2, stamina = 2, agility = 4, speed = 4, acceleration = 4, strength = 2 },
    a_c_horse_morgan_bayroan = { breed = 'Morgan', size = 'small', health = 2, stamina = 2, agility = 4, speed = 4, acceleration = 4, strength = 2 },
    a_c_horse_morgan_flaxenchestnut = { breed = 'Morgan', size = 'small', health = 2, stamina = 2, agility = 4, speed = 4, acceleration = 4, strength = 2 },
    a_c_horse_kentuckysaddle_black = { breed = 'Kentucky Saddler', size = 'small', health = 3, stamina = 3, agility = 3, speed = 3, acceleration = 3, strength = 2 },
    a_c_horse_kentuckysaddle_chestnutpinto = { breed = 'Kentucky Saddler', size = 'small', health = 3, stamina = 3, agility = 3, speed = 3, acceleration = 3, strength = 2 },
    a_c_horse_kentuckysaddle_grey = { breed = 'Kentucky Saddler', size = 'small', health = 3, stamina = 3, agility = 3, speed = 3, acceleration = 3, strength = 2 },
    a_c_horse_kentuckysaddle_silverbay = { breed = 'Kentucky Saddler', size = 'small', health = 3, stamina = 3, agility = 3, speed = 3, acceleration = 3, strength = 2 },
    a_c_horse_kentuckysaddle_buttermilkbuckskin_pc = { breed = 'Kentucky Saddler', size = 'small', health = 2, stamina = 3, agility = 4, speed = 4, acceleration = 4, strength = 2 },
    a_c_horse_tennesseewalker_chestnut = { breed = 'Tennessee Walker', size = 'medium', health = 3, stamina = 3, agility = 3, speed = 3, acceleration = 3, strength = 2 },
    a_c_horse_tennesseewalker_goldpalomino_pc = { breed = 'Tennessee Walker', size = 'medium', health = 3, stamina = 3, agility = 3, speed = 3, acceleration = 3, strength = 2 },
    a_c_horse_tennesseewalker_redroan = { breed = 'Tennessee Walker', size = 'medium', health = 3, stamina = 3, agility = 3, speed = 3, acceleration = 3, strength = 2 },
    a_c_horse_tennesseewalker_flaxenroan = { breed = 'Tennessee Walker', size = 'medium', health = 2, stamina = 3, agility = 4, speed = 4, acceleration = 4, strength = 2 },
    a_c_horse_belgian_blondchestnut = { breed = 'Belgian Draft', size = 'large', health = 4, stamina = 4, agility = 2, speed = 2, acceleration = 2, strength = 4 },
    a_c_horse_belgian_mealychestnut = { breed = 'Belgian Draft', size = 'large', health = 4, stamina = 4, agility = 2, speed = 2, acceleration = 2, strength = 4 },
    a_c_horse_shire_lightgrey = { breed = 'Shire', size = 'large', health = 4, stamina = 4, agility = 2, speed = 2, acceleration = 2, strength = 4 },
    a_c_horse_suffolkpunch_sorrel = { breed = 'Suffolk Punch', size = 'large', health = 4, stamina = 4, agility = 2, speed = 2, acceleration = 2, strength = 4 },
    a_c_horse_americanpaint_tobiano = { breed = 'American Paint', size = 'medium', health = 3, stamina = 3, agility = 3, speed = 3, acceleration = 3, strength = 3 },
    a_c_horse_americanpaint_splashedwhite = { breed = 'American Paint', size = 'medium', health = 3, stamina = 3, agility = 3, speed = 3, acceleration = 3, strength = 3 },
    a_c_horse_appaloosa_blanket = { breed = 'Appaloosa', size = 'medium', health = 3, stamina = 3, agility = 3, speed = 3, acceleration = 3, strength = 3 },
    a_c_horse_appaloosa_brownleopard = { breed = 'Appaloosa', size = 'medium', health = 3, stamina = 3, agility = 3, speed = 3, acceleration = 3, strength = 3 },
    a_c_horse_mustang_grullodun = { breed = 'Mustang', size = 'medium', health = 3, stamina = 3, agility = 3, speed = 3, acceleration = 3, strength = 3 },
    a_c_horse_mustang_wildbay = { breed = 'Mustang', size = 'medium', health = 3, stamina = 3, agility = 3, speed = 3, acceleration = 3, strength = 3 },
    a_c_horse_mustang_goldendun = { breed = 'Mustang', size = 'medium', health = 4, stamina = 5, agility = 3, speed = 4, acceleration = 3, strength = 3 },
    a_c_horse_mustang_reddunovero = { breed = 'Mustang', size = 'medium', health = 4, stamina = 5, agility = 3, speed = 4, acceleration = 3, strength = 3 },
    a_c_horse_nokota_blueroan = { breed = 'Nokota', size = 'small', health = 2, stamina = 3, agility = 3, speed = 4, acceleration = 4, strength = 2 },
    a_c_horse_nokota_whiteroan = { breed = 'Nokota', size = 'small', health = 2, stamina = 3, agility = 3, speed = 4, acceleration = 4, strength = 2 },
    a_c_horse_thoroughbred_dapplegrey = { breed = 'Thoroughbred', size = 'medium', health = 2, stamina = 3, agility = 3, speed = 4, acceleration = 4, strength = 2 },
    a_c_horse_thoroughbred_blackchestnut = { breed = 'Thoroughbred', size = 'medium', health = 2, stamina = 3, agility = 4, speed = 5, acceleration = 4, strength = 1 },
    a_c_horse_americanstandardbred_palominodapple = { breed = 'American Standardbred', size = 'medium', health = 2, stamina = 3, agility = 3, speed = 4, acceleration = 4, strength = 2 },
    a_c_horse_americanstandardbred_lightbuckskin = { breed = 'American Standardbred', size = 'medium', health = 2, stamina = 3, agility = 4, speed = 4, acceleration = 4, strength = 2 },
    a_c_horse_americanstandardbred_silvertailbuckskin = { breed = 'American Standardbred', size = 'medium', health = 2, stamina = 3, agility = 4, speed = 5, acceleration = 4, strength = 1 },
    a_c_horse_norfolkroadster_speckledgrey = { breed = 'Norfolk Roadster', size = 'medium', health = 3, stamina = 3, agility = 3, speed = 4, acceleration = 4, strength = 2 },
    a_c_horse_norfolkroadster_piebaldroan = { breed = 'Norfolk Roadster', size = 'medium', health = 3, stamina = 3, agility = 3, speed = 4, acceleration = 4, strength = 2 },
    a_c_horse_norfolkroadster_spottedtricolor = { breed = 'Norfolk Roadster', size = 'medium', health = 3, stamina = 3, agility = 3, speed = 5, acceleration = 4, strength = 2 },
    a_c_horse_criollo_dun = { breed = 'Criollo', size = 'small', health = 3, stamina = 4, agility = 4, speed = 3, acceleration = 3, strength = 2 },
    a_c_horse_criollo_sorrelovero = { breed = 'Criollo', size = 'small', health = 3, stamina = 4, agility = 4, speed = 4, acceleration = 4, strength = 2 },
    a_c_horse_breton_redroan = { breed = 'Breton', size = 'large', health = 3, stamina = 3, agility = 3, speed = 3, acceleration = 2, strength = 3 },
    a_c_horse_breton_sorrel = { breed = 'Breton', size = 'large', health = 3, stamina = 3, agility = 3, speed = 3, acceleration = 2, strength = 3 },
    a_c_horse_breton_grullodun = { breed = 'Breton', size = 'large', health = 4, stamina = 4, agility = 3, speed = 3, acceleration = 2, strength = 4 },
    a_c_horse_breton_steelgrey = { breed = 'Breton', size = 'large', health = 5, stamina = 4, agility = 2, speed = 2, acceleration = 2, strength = 4 },
    a_c_horse_gypsycob_whiteblagdon = { breed = 'Gypsy Cob', size = 'large', health = 3, stamina = 3, agility = 3, speed = 3, acceleration = 2, strength = 3 },
    a_c_horse_gypsycob_skewbald = { breed = 'Gypsy Cob', size = 'large', health = 4, stamina = 4, agility = 3, speed = 3, acceleration = 2, strength = 4 },
    a_c_horse_gypsycob_splashedpiebald = { breed = 'Gypsy Cob', size = 'large', health = 5, stamina = 5, agility = 1, speed = 1, acceleration = 1, strength = 5 },
    a_c_horse_kladruber_black = { breed = 'Kladruber', size = 'large', health = 3, stamina = 3, agility = 3, speed = 3, acceleration = 2, strength = 3 },
    a_c_horse_kladruber_white = { breed = 'Kladruber', size = 'large', health = 3, stamina = 3, agility = 3, speed = 3, acceleration = 2, strength = 3 },
    a_c_horse_kladruber_cremello = { breed = 'Kladruber', size = 'large', health = 4, stamina = 4, agility = 3, speed = 4, acceleration = 3, strength = 3 },
    a_c_horse_kladruber_dapplerosegrey = { breed = 'Kladruber', size = 'large', health = 4, stamina = 5, agility = 3, speed = 4, acceleration = 3, strength = 3 },
    a_c_horse_dutchwarmblood_chocolateroan = { breed = 'Dutch Warmblood', size = 'large', health = 3, stamina = 3, agility = 3, speed = 3, acceleration = 3, strength = 3 },
    a_c_horse_dutchwarmblood_sootybuckskin = { breed = 'Dutch Warmblood', size = 'large', health = 3, stamina = 3, agility = 3, speed = 3, acceleration = 3, strength = 3 },
    a_c_horse_hungarianhalfbred_liverchestnut = { breed = 'Hungarian Half-bred', size = 'large', health = 4, stamina = 4, agility = 2, speed = 2, acceleration = 2, strength = 4 },
    a_c_horse_andalusian_rosegray = { breed = 'Andalusian', size = 'large', health = 5, stamina = 4, agility = 2, speed = 2, acceleration = 2, strength = 4 },
    a_c_horse_ardennes_irongreyroan = { breed = 'Ardennes', size = 'large', health = 5, stamina = 4, agility = 2, speed = 2, acceleration = 2, strength = 4 },
    a_c_horse_turkoman_darkbay = { breed = 'Turkoman', size = 'large', health = 4, stamina = 5, agility = 3, speed = 4, acceleration = 3, strength = 3 },
    a_c_horse_turkoman_silver = { breed = 'Turkoman', size = 'large', health = 4, stamina = 5, agility = 3, speed = 4, acceleration = 3, strength = 3 },
    a_c_horse_turkoman_gold = { breed = 'Turkoman', size = 'large', health = 4, stamina = 5, agility = 3, speed = 4, acceleration = 3, strength = 3 },
    a_c_horse_missourifoxtrotter_silverdapplepinto = { breed = 'Missouri Fox Trotter', size = 'medium', health = 3, stamina = 4, agility = 4, speed = 4, acceleration = 4, strength = 2 },
    a_c_horse_missourifoxtrotter_buckskinbrindle = { breed = 'Missouri Fox Trotter', size = 'medium', health = 3, stamina = 4, agility = 4, speed = 5, acceleration = 5, strength = 2 },
    a_c_horse_missourifoxtrotter_dapplegrey = { breed = 'Missouri Fox Trotter', size = 'medium', health = 3, stamina = 4, agility = 4, speed = 5, acceleration = 5, strength = 2 },
    a_c_horse_arabian_white = { breed = 'Arabian', size = 'small', health = 3, stamina = 4, agility = 4, speed = 5, acceleration = 5, strength = 2 },
}

local prices = {
    a_c_horse_dutchwarmblood_chocolateroan = 250,
    a_c_horse_dutchwarmblood_sootybuckskin = 250,
    a_c_horse_kentuckysaddle_silverbay = 50,
    a_c_horse_kentuckysaddle_buttermilkbuckskin_pc = 120,
    a_c_horse_morgan_bay = 55,
    a_c_horse_morgan_bayroan = 55,
    a_c_horse_mustang_reddunovero = 500,
    a_c_horse_suffolkpunch_sorrel = 120,
    a_c_horse_turkoman_darkbay = 925,
    a_c_horse_turkoman_gold = 950,
    a_c_horse_andalusian_rosegray = 440,
    a_c_horse_breton_redroan = 150,
    a_c_horse_americanpaint_tobiano = 130,
    a_c_horse_gypsycob_splashedpiebald = 950,
    a_c_horse_missourifoxtrotter_dapplegrey = 1125,
    a_c_horse_missourifoxtrotter_buckskinbrindle = 1125,
    a_c_horse_norfolkroadster_speckledgrey = 150,
    a_c_horse_norfolkroadster_spottedtricolor = 950,
    a_c_horse_breton_steelgrey = 950,
    a_c_horse_kladruber_black = 150,
    a_c_horse_hungarianhalfbred_liverchestnut = 300,
    a_c_horse_kentuckysaddle_black = 50,
    a_c_horse_morgan_liverchestnut_pc = 27.50,
    a_c_horse_thoroughbred_blackchestnut = 450,
    a_c_horse_turkoman_silver = 950,
    a_c_horse_tennesseewalker_chestnut = 60,
    a_c_horse_tennesseewalker_goldpalomino_pc = 60,
    a_c_horse_americanstandardbred_lightbuckskin = 350,
    a_c_horse_tennesseewalker_flaxenroan = 150,
    a_c_horse_tennesseewalker_redroan = 60,
    a_c_horse_kladruber_white = 150,
    a_c_horse_morgan_flaxenchestnut = 55,
    a_c_horse_kladruber_dapplerosegrey = 950,
    a_c_horse_kladruber_cremello = 550,
    a_c_horse_breton_sorrel = 150,
    a_c_horse_ardennes_irongreyroan = 450,
    a_c_horse_shire_lightgrey = 120,
    a_c_horse_arabian_white = 1200,
    a_c_horse_belgian_blondchestnut = 120,
    a_c_horse_gypsycob_whiteblagdon = 150,
    a_c_horse_gypsycob_skewbald = 550,
    a_c_horse_americanpaint_splashedwhite = 140,
    a_c_horse_norfolkroadster_piebaldroan = 400,
    a_c_horse_thoroughbred_dapplegrey = 130,
    a_c_horse_mustang_grullodun = 130,
    a_c_horse_nokota_whiteroan = 130,
    a_c_horse_nokota_blueroan = 130,
    a_c_horse_kentuckysaddle_grey = 50,
    a_c_horse_kentuckysaddle_chestnutpinto = 50,
    a_c_horse_mustang_wildbay = 130,
    a_c_horse_mustang_goldendun = 500,
    a_c_horse_missourifoxtrotter_silverdapplepinto = 950,
    a_c_horse_appaloosa_blanket = 130,
    a_c_horse_appaloosa_brownleopard = 450,
    a_c_horse_americanstandardbred_palominodapple = 150,
    a_c_horse_americanstandardbred_silvertailbuckskin = 400,
    a_c_horse_belgian_mealychestnut = 120,
    a_c_horse_breton_grullodun = 550,
    a_c_horse_criollo_sorrelovero = 550,
    a_c_horse_criollo_dun = 150,
}

for model, price in pairs(prices) do
    horses[model].price = price
end

local function Copy(source)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    return result
end

function HorseStats.Get(model)
    if type(model) ~= 'string' then return nil end
    local stats = horses[model:lower()]
    return stats and Copy(stats) or nil
end

function HorseStats.Exists(model)
    return type(model) == 'string' and horses[model:lower()] ~= nil
end

function HorseStats.GetAll()
    local result = {}
    for model, stats in pairs(horses) do result[model] = Copy(stats) end
    return result
end

HorseStats.StatNames = { 'health', 'stamina', 'agility', 'speed', 'acceleration', 'strength' }
HorseStats.MinimumRank = { health = 1, stamina = 1, strength = 1, agility = 0, speed = 0, acceleration = 0 }
HorseStats.MaximumStartingRank = 5
HorseStats.CarryWeightPerStrength = 5
HorseStats.PullWeightPerStrength = 10
HorseStats.StarterModel = 'a_c_horse_mp_mangy_backup'

HorseStats.TrainingBonus = {
    [1] = { health = 0, stamina = 0, agility = 0, speed = 0, acceleration = 0, strength = 0 },
    [2] = { health = 1, stamina = 0, agility = 0, speed = 0, acceleration = 0, strength = 1 },
    [3] = { health = 1, stamina = 1, agility = 0, speed = 1, acceleration = 0, strength = 1 },
    [4] = { health = 1, stamina = 1, agility = 1, speed = 1, acceleration = 1, strength = 1 },
    [5] = { health = 2, stamina = 2, agility = 1, speed = 2, acceleration = 1, strength = 2 },
    [6] = { health = 2, stamina = 3, agility = 2, speed = 3, acceleration = 2, strength = 2 },
    [7] = { health = 3, stamina = 3, agility = 3, speed = 3, acceleration = 3, strength = 3 },
    [8] = { health = 4, stamina = 3, agility = 3, speed = 3, acceleration = 3, strength = 4 },
    [9] = { health = 4, stamina = 4, agility = 3, speed = 4, acceleration = 3, strength = 4 },
    [10] = { health = 4, stamina = 4, agility = 4, speed = 4, acceleration = 4, strength = 4 },
}

function HorseStats.GetTrainingLevel(xp)
    xp = tonumber(xp) or 0
    if xp <= 99 then return 1 end
    if xp <= 199 then return 2 end
    if xp <= 299 then return 3 end
    if xp <= 399 then return 4 end
    if xp <= 499 then return 5 end
    if xp <= 999 then return 6 end
    if xp <= 1999 then return 7 end
    if xp <= 2999 then return 8 end
    if xp <= 3999 then return 9 end
    return 10
end

function HorseStats.Calculate(data)
    local base = data and HorseStats.Get(data.horse)
    if not base then return end

    local modifiers = {}
    if data.wild == true or data.wild == 1 or data.wild == '1' then
        local storedModifiers = data.stat_modifiers
        if type(storedModifiers) == 'string' and storedModifiers ~= '' then
            local success, decoded = pcall(json.decode, storedModifiers)
            if success and decoded and decoded.modifiers then
                modifiers = decoded.modifiers
                if modifiers.strength == nil and modifiers.carry ~= nil then
                    modifiers.strength = modifiers.carry
                end
            end
        end
    end

    local level = HorseStats.GetTrainingLevel(data.horsexp)
    local finalStats = {}

    for _, stat in ipairs(HorseStats.StatNames) do
        local startingStat = math.floor(base[stat] + (tonumber(modifiers[stat]) or 0) + 0.5)
        startingStat = math.max(HorseStats.MinimumRank[stat], math.min(5, startingStat))
        finalStats[stat] = math.max(HorseStats.MinimumRank[stat], math.min(9, startingStat + HorseStats.TrainingBonus[level][stat]))
    end

    return base, finalStats, level
end

function HorseStats.GetCarryWeight(strength)
    return (tonumber(strength) or 0) * HorseStats.CarryWeightPerStrength
end

function HorseStats.GetPullWeight(strength)
    return (tonumber(strength) or 0) * HorseStats.PullWeightPerStrength
end

return HorseStats
