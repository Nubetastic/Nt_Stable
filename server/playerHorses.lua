local RSGCore = exports['rsg-core']:GetCoreObject()
local HorseStats = lib.load('shared.horse_stats')
local HorseComponents = lib.load('shared.horse_components')

local function GetInventoryWeight(identifier)
    local storedItems = MySQL.scalar.await('SELECT items FROM inventories WHERE identifier = ?', { identifier })
    if not storedItems or storedItems == '' then return 0 end

    local success, items = pcall(json.decode, storedItems)
    if not success or type(items) ~= 'table' then return 0 end

    local totalWeight = 0
    for _, item in pairs(items) do
        local itemData = RSGCore.Shared.Items[item.name]
        local amount = tonumber(item.amount)
        if itemData and amount then
            totalWeight = totalWeight + (itemData.weight * amount)
        end
    end

    return totalWeight
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `nt_stable_wagon_horses` (
            `wagon_id` INT NOT NULL,
            `slot` TINYINT UNSIGNED NOT NULL,
            `horse_id` INT NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            PRIMARY KEY (`wagon_id`, `slot`),
            UNIQUE KEY `wagon_horse` (`wagon_id`, `horse_id`),
            KEY `horse_id` (`horse_id`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    if not MySQL.single.await("SHOW COLUMNS FROM `wagonmaker_wagons` LIKE 'lantern'") then
        MySQL.query.await("ALTER TABLE `wagonmaker_wagons` ADD COLUMN `lantern` VARCHAR(100) NOT NULL DEFAULT '0'")
    end
    if not MySQL.single.await("SHOW COLUMNS FROM `wagonmaker_wagons` LIKE 'extras'") then
        MySQL.query.await("ALTER TABLE `wagonmaker_wagons` ADD COLUMN `extras` TEXT NULL")
    end
end)

local function IncludesValue(values, selectedValue)
    for _, value in ipairs(values or {}) do
        if value == selectedValue then return true end
    end
    return false
end

local function ValidateWagonCustomization(model, livery, tint, extras, lantern)
    local wagon = ConfigWagon.Wagons[model]
    if not wagon then return end

    livery = tonumber(livery)
    tint = tonumber(tint)
    lantern = lantern == 0 and 0 or tostring(lantern or '')
    if not livery or not tint or type(extras) ~= 'table' then return end
    if livery % 1 ~= 0 or tint % 1 ~= 0 then return end
    if not IncludesValue(wagon.customizations.livery, livery)
        or not IncludesValue(wagon.customizations.tint, tint)
        or not IncludesValue(wagon.customizations.lanterns or { 0 }, lantern) then
        return
    end

    local validatedExtras = {}
    for _, extra in ipairs(extras) do
        extra = tonumber(extra)
        if not extra or extra == 0 or extra % 1 ~= 0 or not IncludesValue(wagon.customizations.extras, extra) then return end
        if not IncludesValue(validatedExtras, extra) then validatedExtras[#validatedExtras + 1] = extra end
    end

    return { livery = livery, tint = tint, extras = validatedExtras, lantern = lantern }
end

local function ValidateComponents(components)
    if type(components) ~= 'table' then return end

    local allowedCategories = {}
    local allowedTintKeys = {}
    for _, category in ipairs(ConfigStables.Customization) do
        allowedCategories[category.key] = true
        allowedTintKeys[category.tintKey] = true
    end

    local validated = {}
    for category, value in pairs(components) do
        if allowedTintKeys[category] then
            if type(value) ~= 'table' then return end

            local tint0 = tonumber(value.tint0)
            local tint1 = tonumber(value.tint1)
            local tint2 = tonumber(value.tint2)
            if not tint0 or not tint1 or not tint2 then return end
            if tint0 % 1 ~= 0 or tint1 % 1 ~= 0 or tint2 % 1 ~= 0 then return end
            if tint0 < 0 or tint0 > 255 or tint1 < 0 or tint1 > 255 or tint2 < 0 or tint2 > 255 then return end

            validated[category] = { tint0 = tint0, tint1 = tint1, tint2 = tint2 }
        else
            value = tonumber(value)
            if not allowedCategories[category] or not value or value % 1 ~= 0 or value < 0 then return end
            if value > 0 and not HorseComponents[category][value] then return end
            validated[category] = value
        end
    end

    return validated
end

local function GenerateHorseId()
    while true do
        local horseId = tostring(RSGCore.Shared.RandomStr(3) .. RSGCore.Shared.RandomInt(3)):upper()
        local exists = MySQL.scalar.await('SELECT COUNT(*) FROM player_horses WHERE horseid = ?', { horseId })
        if exists == 0 then return horseId end
    end
end

local function GetStableSlots(Player)
    local storedSlots = Player.PlayerData.metadata.stable_slots

    if type(storedSlots) ~= 'table' then
        return {
            horse = Config.StableSlots.Horse.DefaultSlots,
            wagon = Config.StableSlots.Wagon.DefaultSlots,
        }
    end

    return {
        horse = math.max(Config.StableSlots.Horse.DefaultSlots, math.floor(tonumber(storedSlots.horse) or 0)),
        wagon = math.max(Config.StableSlots.Wagon.DefaultSlots, math.floor(tonumber(storedSlots.wagon) or 0)),
    }
end

local function GetSlotPrice(slotType, slotNumber)
    local slotConfig = slotType == 'horse' and Config.StableSlots.Horse or Config.StableSlots.Wagon
    return slotConfig.BaseSlotPrice * (Config.StableSlots.AdditionalSlotMultiplier ^ (slotNumber - 1))
end

local function GetActiveWagonId(Player)
    local storedActiveWagon = Player.PlayerData.metadata.stable_active_wagon
    if storedActiveWagon ~= nil then return tonumber(storedActiveWagon) end

    local activeRide = Player.PlayerData.metadata.stable_active_ride
    if type(activeRide) == 'table' and activeRide.type == 'wagon' and tonumber(activeRide.wagonId) then
        local wagonId = tonumber(activeRide.wagonId)
        Player.Functions.SetMetaData('stable_active_wagon', wagonId)
        Player.Functions.SetMetaData('stable_active_ride', { type = 'horse' })
        return wagonId
    end
end

local function GetWagonHorseAssignments(citizenid)
    local assignments = MySQL.query.await([[SELECT assignments.wagon_id, assignments.slot,
        horses.* FROM nt_stable_wagon_horses assignments
        INNER JOIN player_horses horses ON horses.id = assignments.horse_id
        WHERE assignments.citizenid = ? AND horses.citizenid = ?
        ORDER BY assignments.wagon_id, assignments.slot]], { citizenid, citizenid })
    local wagonHorses = {}
    local assignedHorses = {}

    for _, horse in ipairs(assignments) do
        local wagonId = tonumber(horse.wagon_id)
        wagonHorses[wagonId] = wagonHorses[wagonId] or {}
        wagonHorses[wagonId][#wagonHorses[wagonId] + 1] = horse
        assignedHorses[tonumber(horse.id)] = true
    end

    return wagonHorses, assignedHorses
end

local function WagonHasRequiredHorses(citizenid, wagon)
    local wagonConfig = wagon and ConfigWagon.Wagons[wagon.model]
    if not wagonConfig then return false end

    local assigned = MySQL.scalar.await([[SELECT COUNT(*) FROM nt_stable_wagon_horses assignments
        INNER JOIN player_horses horses ON horses.id = assignments.horse_id
        WHERE assignments.wagon_id = ? AND assignments.citizenid = ? AND horses.citizenid = ?]], {
        wagon.id,
        citizenid,
        citizenid,
    })
    return tonumber(assigned) == wagonConfig.horseCount
end

local function ClearIncompleteActiveWagon(Player)
    local wagonId = GetActiveWagonId(Player)
    if not wagonId then return false end

    local wagon = MySQL.single.await('SELECT id, model FROM wagonmaker_wagons WHERE id = ? AND citizenid = ?', {
        wagonId,
        Player.PlayerData.citizenid,
    })
    if wagon and WagonHasRequiredHorses(Player.PlayerData.citizenid, wagon) then return false end

    Player.Functions.SetMetaData('stable_active_wagon', false)
    return true
end

local function GetStableManagerData(Player, slots)
    local horses = MySQL.query.await('SELECT * FROM player_horses WHERE citizenid = ? ORDER BY active DESC, name ASC', {
        Player.PlayerData.citizenid,
    })
    local wagons = MySQL.query.await('SELECT * FROM wagonmaker_wagons WHERE citizenid = ? ORDER BY name ASC', {
        Player.PlayerData.citizenid,
    })
    ClearIncompleteActiveWagon(Player)
    local wagonHorses, assignedHorses = GetWagonHorseAssignments(Player.PlayerData.citizenid)
    local activeWagonId = GetActiveWagonId(Player)
    for _, wagon in ipairs(wagons) do
        wagon.horses = wagonHorses[tonumber(wagon.id)] or {}
        wagon.active = activeWagonId == tonumber(wagon.id)
        wagon.ready = #wagon.horses == ConfigWagon.Wagons[wagon.model].horseCount
    end
    for _, horse in ipairs(horses) do
        horse.isWagonHorse = assignedHorses[tonumber(horse.id)] == true
    end
    slots = slots or GetStableSlots(Player)

    if #horses > slots.horse or #wagons > slots.wagon then
        slots.horse = math.max(slots.horse, #horses)
        slots.wagon = math.max(slots.wagon, #wagons)
        Player.Functions.SetMetaData('stable_slots', slots)
    end

    return {
        horses = horses,
        wagons = wagons,
        debt = tonumber(Player.PlayerData.metadata.stable_debt) or 0,
        horseSlots = {
            total = slots.horse,
            used = #horses,
            buyPrice = GetSlotPrice('horse', slots.horse + 1),
            sellPrice = slots.horse > Config.StableSlots.Horse.DefaultSlots and GetSlotPrice('horse', slots.horse) * Config.StableSlots.SellPriceMultiplier or 0,
            canSell = slots.horse > Config.StableSlots.Horse.DefaultSlots and #horses < slots.horse,
        },
        wagonSlots = {
            total = slots.wagon,
            used = #wagons,
            buyPrice = GetSlotPrice('wagon', slots.wagon + 1),
            sellPrice = slots.wagon > Config.StableSlots.Wagon.DefaultSlots and GetSlotPrice('wagon', slots.wagon) * Config.StableSlots.SellPriceMultiplier or 0,
            canSell = slots.wagon > Config.StableSlots.Wagon.DefaultSlots and #wagons < slots.wagon,
        },
        activeWagonId = activeWagonId,
    }
end

local function GetTrainingLevel(xp)
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

local function GetSellPrice(horse)
    local stats = HorseStats.Get(horse.horse)
    if not stats or not stats.price then return end

    local shopPrice = stats.price

    if horse.wild == true or horse.wild == 1 or horse.wild == '1' then
        local success, wildStats = pcall(json.decode, horse.stat_modifiers or '')
        if success and wildStats and wildStats.modifiers and wildStats.selected then
            local totalModifier = 0
            local modifierCount = 0

            for _, stat in ipairs(wildStats.selected) do
                if stat == 'carry' then stat = 'strength' end

                if HorseStats.MinimumRank[stat] then
                    local storedStat = stat == 'strength' and wildStats.modifiers.strength == nil and 'carry' or stat
                    local startingStat = math.floor(stats[stat] + (tonumber(wildStats.modifiers[storedStat]) or 0) + 0.5)
                    startingStat = math.max(HorseStats.MinimumRank[stat], math.min(5, startingStat))
                    totalModifier = totalModifier + (startingStat - stats[stat])
                    modifierCount = modifierCount + 1
                end
            end

            if modifierCount > 0 then
                shopPrice = math.max(0, math.floor((shopPrice * (1 + ((totalModifier / modifierCount) * 0.20))) + 0.5))
            end
        end
    end

    local level = GetTrainingLevel(horse.horsexp)
    return math.floor(((shopPrice * 0.50) + (level * shopPrice * ConfigStables.Settings.SellPricePerLevel)) + 0.5)
end

lib.callback.register('nt_stables:server:getActiveHorse', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end

    return MySQL.single.await('SELECT * FROM player_horses WHERE citizenid = ? AND active = ?', {
        Player.PlayerData.citizenid,
        1,
    })
end)

lib.callback.register('nt_stables:server:getHorseInventoryWeight', function(source, horseId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end

    local horse = MySQL.single.await('SELECT horseid, name FROM player_horses WHERE horseid = ? AND citizenid = ? AND active = ?', {
        horseId,
        Player.PlayerData.citizenid,
        1,
    })
    if not horse then return end

    return GetInventoryWeight(horse.name .. ' ' .. horse.horseid)
end)

lib.callback.register('nt_stables:server:getPlayerHorses', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end

    return MySQL.query.await('SELECT * FROM player_horses WHERE citizenid = ? ORDER BY active DESC, name ASC', {
        Player.PlayerData.citizenid,
    })
end)

lib.callback.register('nt_stables:server:getStableManagerData', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end

    return GetStableManagerData(Player)
end)

lib.callback.register('nt_stables:server:changeStableSlots', function(source, slotType, action)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end
    if slotType ~= 'horse' and slotType ~= 'wagon' then
        return { success = false, message = 'Invalid stable slot type.' }
    end

    local slots = GetStableSlots(Player)
    local slotConfig = slotType == 'horse' and Config.StableSlots.Horse or Config.StableSlots.Wagon
    local owned = MySQL.scalar.await(slotType == 'horse'
        and 'SELECT COUNT(*) FROM player_horses WHERE citizenid = ?'
        or 'SELECT COUNT(*) FROM wagonmaker_wagons WHERE citizenid = ?', {
        Player.PlayerData.citizenid,
    })

    if owned > slots[slotType] then
        slots[slotType] = owned
        Player.Functions.SetMetaData('stable_slots', slots)
    end

    if action == 'buy' then
        local price = GetSlotPrice(slotType, slots[slotType] + 1)
        if not Player.Functions.RemoveMoney(Config.StableSlots.MoneyType, price) then
            return { success = false, message = 'You do not have enough cash.' }
        end

        slots[slotType] = slots[slotType] + 1
        Player.Functions.SetMetaData('stable_slots', slots)
    elseif action == 'sell' then
        if slots[slotType] <= slotConfig.DefaultSlots then
            return { success = false, message = 'Default stable slots cannot be sold.' }
        end
        if owned >= slots[slotType] then
            return { success = false, message = 'Only empty stable slots can be sold.' }
        end

        local price = GetSlotPrice(slotType, slots[slotType]) * Config.StableSlots.SellPriceMultiplier
        slots[slotType] = slots[slotType] - 1
        Player.Functions.SetMetaData('stable_slots', slots)
        Player.Functions.AddMoney(Config.StableSlots.MoneyType, price)
    else
        return { success = false, message = 'Invalid stable slot action.' }
    end

    local data = GetStableManagerData(Player, slots)
    data.success = true
    return data
end)

lib.callback.register('nt_stables:server:setRidingHorse', function(source, horseId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end

    local owned = MySQL.scalar.await('SELECT COUNT(*) FROM player_horses WHERE id = ? AND citizenid = ?', {
        horseId,
        Player.PlayerData.citizenid,
    })
    if not owned or owned < 1 then return false end

    MySQL.update.await('DELETE FROM nt_stable_wagon_horses WHERE horse_id = ? AND citizenid = ?', {
        horseId,
        Player.PlayerData.citizenid,
    })
    local clearedWagon = ClearIncompleteActiveWagon(Player)
    MySQL.update.await('UPDATE player_horses SET active = 0 WHERE citizenid = ?', { Player.PlayerData.citizenid })
    MySQL.update.await('UPDATE player_horses SET active = 1 WHERE id = ? AND citizenid = ?', {
        horseId,
        Player.PlayerData.citizenid,
    })
    return { success = true, clearedWagon = clearedWagon }
end)

lib.callback.register('nt_stables:server:setRidingWagon', function(source, wagonId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end

    wagonId = tonumber(wagonId)
    if not wagonId then return false end

    local wagon = MySQL.single.await('SELECT id, model FROM wagonmaker_wagons WHERE id = ? AND citizenid = ?', {
        wagonId,
        Player.PlayerData.citizenid,
    })
    if not wagon then return { success = false, message = 'Wagon not found.' } end
    if not WagonHasRequiredHorses(Player.PlayerData.citizenid, wagon) then
        return { success = false, message = 'Assign a horse to every wagon slot before setting it active.' }
    end

    Player.Functions.SetMetaData('stable_active_wagon', wagonId)
    return { success = true }
end)

lib.callback.register('nt_stables:server:getActiveStableRideType', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return 'horse' end
    return GetActiveWagonId(Player) and 'wagon' or 'horse'
end)

lib.callback.register('nt_stables:server:getActiveWagon', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end

    local wagonId = GetActiveWagonId(Player)
    if not wagonId then return end

    local wagon = MySQL.single.await('SELECT * FROM wagonmaker_wagons WHERE id = ? AND citizenid = ?', {
        wagonId,
        Player.PlayerData.citizenid,
    })
    if not wagon or not WagonHasRequiredHorses(Player.PlayerData.citizenid, wagon) then
        Player.Functions.SetMetaData('stable_active_wagon', false)
        return
    end

    local wagonHorses = GetWagonHorseAssignments(Player.PlayerData.citizenid)
    wagon.horses = wagonHorses[tonumber(wagon.id)] or {}
    return wagon
end)

lib.callback.register('nt_stables:server:getWagonInventoryWeight', function(source, wagonId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or GetActiveWagonId(Player) ~= tonumber(wagonId) then return end

    local owned = MySQL.scalar.await('SELECT COUNT(*) FROM wagonmaker_wagons WHERE id = ? AND citizenid = ?', {
        wagonId,
        Player.PlayerData.citizenid,
    })
    if tonumber(owned) ~= 1 then return end

    return GetInventoryWeight('wagon_' .. wagonId)
end)

lib.callback.register('nt_stables:server:setWagonHorse', function(source, wagonId, slot, horseId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end

    wagonId = tonumber(wagonId)
    slot = tonumber(slot)
    horseId = tonumber(horseId)
    if not wagonId or not slot or slot % 1 ~= 0 then
        return { success = false, message = 'Invalid wagon horse slot.' }
    end

    local wagon = MySQL.single.await('SELECT id, model FROM wagonmaker_wagons WHERE id = ? AND citizenid = ?', {
        wagonId,
        Player.PlayerData.citizenid,
    })
    local wagonConfig = wagon and ConfigWagon.Wagons[wagon.model]
    if not wagonConfig or slot < 1 or slot > wagonConfig.horseCount then
        return { success = false, message = 'Invalid wagon horse slot.' }
    end

    if not horseId then
        MySQL.update.await('DELETE FROM nt_stable_wagon_horses WHERE wagon_id = ? AND slot = ? AND citizenid = ?', {
            wagonId,
            slot,
            Player.PlayerData.citizenid,
        })
        local clearedWagon = ClearIncompleteActiveWagon(Player)
        return { success = true, clearedWagon = clearedWagon }
    end

    local horse = MySQL.single.await('SELECT id, active FROM player_horses WHERE id = ? AND citizenid = ?', {
        horseId,
        Player.PlayerData.citizenid,
    })
    if not horse then return { success = false, message = 'Horse not found.' } end

    MySQL.update.await('DELETE FROM nt_stable_wagon_horses WHERE wagon_id = ? AND horse_id = ? AND citizenid = ?', {
        wagonId,
        horseId,
        Player.PlayerData.citizenid,
    })
    MySQL.query.await([[INSERT INTO nt_stable_wagon_horses (wagon_id, slot, horse_id, citizenid)
        VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE horse_id = VALUES(horse_id), citizenid = VALUES(citizenid)]], {
        wagonId,
        slot,
        horseId,
        Player.PlayerData.citizenid,
    })

    local wasRiding = horse.active == 1 or horse.active == true
    if wasRiding then
        MySQL.update.await('UPDATE player_horses SET active = 0 WHERE id = ? AND citizenid = ?', {
            horseId,
            Player.PlayerData.citizenid,
        })
    end

    return {
        success = true,
        wasRiding = wasRiding,
        activeWagonChanged = GetActiveWagonId(Player) == wagonId,
    }
end)

lib.callback.register('nt_stables:server:buyWagon', function(source, model, wagonName, livery, tint, extras, lantern)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end

    model = tostring(model or ''):lower()
    wagonName = tostring(wagonName or ''):match('^%s*(.-)%s*$')
    if wagonName == '' or #wagonName > 32 or wagonName:find("[^%w%s%-']") then
        return { success = false, message = 'Wagon names must contain 1 to 32 valid characters.' }
    end

    local wagonConfig = ConfigWagon.Wagons[model]
    local customization = ValidateWagonCustomization(model, livery, tint, extras, lantern)
    if not wagonConfig or not customization then
        return { success = false, message = 'Invalid wagon or customization.' }
    end

    local wagonCount = MySQL.scalar.await('SELECT COUNT(*) FROM wagonmaker_wagons WHERE citizenid = ?', {
        Player.PlayerData.citizenid,
    })
    local slots = GetStableSlots(Player)
    if wagonCount > slots.wagon then
        slots.wagon = wagonCount
        Player.Functions.SetMetaData('stable_slots', slots)
    end
    if wagonCount >= slots.wagon then
        return { success = false, message = 'You do not have an empty wagon slot.' }
    end

    local price = wagonConfig.price
    if customization.livery ~= wagonConfig.customizations.livery[1] then price = price + ConfigWagon.Prices.livery end
    if customization.tint ~= wagonConfig.customizations.tint[1] then price = price + ConfigWagon.Prices.tint end
    price = price + (#customization.extras * ConfigWagon.Prices.extras)
    if customization.lantern ~= 0 then price = price + ConfigWagon.Prices.lanterns end

    if not Player.Functions.RemoveMoney(Config.StableSlots.MoneyType, price) then
        return { success = false, message = 'You do not have enough cash.' }
    end

    local wagonId = MySQL.insert.await([[INSERT INTO wagonmaker_wagons
        (citizenid, model, name, livery, tint, extra, extras, lantern, parking_location)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        Player.PlayerData.citizenid,
        model,
        wagonName,
        customization.livery,
        customization.tint,
        0,
        json.encode(customization.extras),
        customization.lantern,
        1,
    })

    if not wagonId then
        Player.Functions.AddMoney(Config.StableSlots.MoneyType, price)
        return { success = false, message = 'The wagon purchase could not be saved.' }
    end

    return { success = true, wagonId = wagonId, price = price }
end)

lib.callback.register('nt_stables:server:saveWagonCustomization', function(source, wagonId, livery, tint, extras, lantern)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end

    local wagon = MySQL.single.await('SELECT model, livery, tint, extra, extras, lantern FROM wagonmaker_wagons WHERE id = ? AND citizenid = ?', {
        tonumber(wagonId),
        Player.PlayerData.citizenid,
    })
    if not wagon then return { success = false, message = 'Wagon not found.' } end

    local customization = ValidateWagonCustomization(wagon.model, livery, tint, extras, lantern)
    if not customization then return { success = false, message = 'Invalid wagon customization.' } end

    local currentExtras = {}
    if wagon.extras then
        local success, storedExtras = pcall(json.decode, wagon.extras)
        if success and type(storedExtras) == 'table' then currentExtras = storedExtras end
    elseif tonumber(wagon.extra) and tonumber(wagon.extra) > 0 then
        currentExtras[1] = tonumber(wagon.extra)
    end

    local price = 0
    if customization.livery ~= tonumber(wagon.livery) then price = price + ConfigWagon.Prices.livery end
    if customization.tint ~= tonumber(wagon.tint) then price = price + ConfigWagon.Prices.tint end
    for _, extra in ipairs(customization.extras) do
        if not IncludesValue(currentExtras, extra) then price = price + ConfigWagon.Prices.extras end
    end
    local currentLantern = wagon.lantern ~= '0' and wagon.lantern or 0
    if customization.lantern ~= currentLantern then price = price + ConfigWagon.Prices.lanterns end

    if price > 0 and not Player.Functions.RemoveMoney(Config.StableSlots.MoneyType, price) then
        return { success = false, message = 'You do not have enough cash for these changes.' }
    end

    local updated = MySQL.update.await([[UPDATE wagonmaker_wagons
        SET livery = ?, tint = ?, extra = 0, extras = ?, lantern = ? WHERE id = ? AND citizenid = ?]], {
        customization.livery,
        customization.tint,
        json.encode(customization.extras),
        customization.lantern,
        tonumber(wagonId),
        Player.PlayerData.citizenid,
    })

    if not updated or (price > 0 and updated < 1) then
        if price > 0 then Player.Functions.AddMoney(Config.StableSlots.MoneyType, price) end
        return { success = false, message = 'The wagon customization could not be saved.' }
    end
    return { success = true, price = price }
end)

lib.callback.register('nt_stables:server:renameWagon', function(source, wagonId, wagonName)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end

    wagonName = tostring(wagonName or ''):match('^%s*(.-)%s*$')
    if wagonName == '' or #wagonName > 32 or wagonName:find("[^%w%s%-']") then return false end

    local updated = MySQL.update.await('UPDATE wagonmaker_wagons SET name = ? WHERE id = ? AND citizenid = ?', {
        wagonName,
        tonumber(wagonId),
        Player.PlayerData.citizenid,
    })
    return updated and updated > 0
end)

lib.callback.register('nt_stables:server:getWagonSellPrice', function(source, wagonId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end

    local wagon = MySQL.single.await('SELECT model FROM wagonmaker_wagons WHERE id = ? AND citizenid = ?', {
        tonumber(wagonId),
        Player.PlayerData.citizenid,
    })
    local wagonConfig = wagon and ConfigWagon.Wagons[wagon.model]
    if not wagonConfig then return end

    return math.floor((wagonConfig.price * Config.StableSlots.SellPriceMultiplier) + 0.5)
end)

lib.callback.register('nt_stables:server:sellWagon', function(source, wagonId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end

    wagonId = tonumber(wagonId)
    local wagon = MySQL.single.await('SELECT * FROM wagonmaker_wagons WHERE id = ? AND citizenid = ?', {
        wagonId,
        Player.PlayerData.citizenid,
    })
    local wagonConfig = wagon and ConfigWagon.Wagons[wagon.model]
    if not wagonConfig then return end

    local sellPrice = math.floor((wagonConfig.price * Config.StableSlots.SellPriceMultiplier) + 0.5)
    local deleted = MySQL.update.await('DELETE FROM wagonmaker_wagons WHERE id = ? AND citizenid = ?', {
        wagonId,
        Player.PlayerData.citizenid,
    })
    if not deleted or deleted < 1 then return end

    MySQL.update.await('DELETE FROM nt_stable_wagon_horses WHERE wagon_id = ? AND citizenid = ?', {
        wagonId,
        Player.PlayerData.citizenid,
    })
    local wasActive = GetActiveWagonId(Player) == wagonId
    if wasActive then Player.Functions.SetMetaData('stable_active_wagon', false) end
    MySQL.update('DELETE FROM inventories WHERE identifier = ?', { 'wagon_' .. wagonId })
    Player.Functions.AddMoney(Config.StableSlots.MoneyType, sellPrice)

    return { price = sellPrice, wasActive = wasActive }
end)

lib.callback.register('nt_stables:server:buyHorse', function(source, stableName, model, horseName, gender, components)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end

    horseName = tostring(horseName or ''):match('^%s*(.-)%s*$')
    if horseName == '' or #horseName > 32 or horseName:find("[^%w%s%-']") then
        return { success = false, message = 'Horse names must contain 1 to 32 valid characters.' }
    end

    if gender ~= 'male' and gender ~= 'female' then
        return { success = false, message = 'Select a valid horse gender.' }
    end

    local validComponents = ValidateComponents(components)
    if not validComponents then
        return { success = false, message = 'Invalid horse customization.' }
    end

    local isStableHorse = false
    for _, stableModel in pairs(StableStalls[stableName] or {}) do
        if stableModel == model then
            isStableHorse = true
            break
        end
    end

    local stats = HorseStats.Get(model)
    if not isStableHorse or not stats then
        return { success = false, message = 'That horse is not available at this stable.' }
    end

    local horseCount = MySQL.scalar.await('SELECT COUNT(*) FROM player_horses WHERE citizenid = ?', {
        Player.PlayerData.citizenid,
    })
    local slots = GetStableSlots(Player)
    if horseCount > slots.horse then
        slots.horse = horseCount
        Player.Functions.SetMetaData('stable_slots', slots)
    end
    if horseCount >= slots.horse then
        return { success = false, message = 'You do not have an empty horse slot.' }
    end

    if not Player.Functions.RemoveMoney('cash', stats.price) then
        return { success = false, message = 'You do not have enough cash.' }
    end

    local horseId = GenerateHorseId()
    local databaseId = MySQL.insert.await([[INSERT INTO player_horses
        (stable, citizenid, horseid, name, horse, dirt, horsexp, components, gender, active, born)
        VALUES (?, ?, ?, ?, ?, 0, 0, ?, ?, 0, ?)]], {
        stableName,
        Player.PlayerData.citizenid,
        horseId,
        horseName,
        model,
        json.encode(validComponents),
        gender,
        os.time(),
    })

    if not databaseId then
        Player.Functions.AddMoney('cash', stats.price)
        return { success = false, message = 'The horse purchase could not be saved.' }
    end

    MySQL.update.await('UPDATE player_horses SET active = 0 WHERE citizenid = ?', {
        Player.PlayerData.citizenid,
    })
    MySQL.update.await('UPDATE player_horses SET active = 1 WHERE id = ? AND citizenid = ?', {
        databaseId,
        Player.PlayerData.citizenid,
    })
    Player.Functions.SetMetaData('stable_active_ride', { type = 'horse' })

    return { success = true, horseId = databaseId }
end)

local function ChargeStableFee(Player)
    local horseCount = MySQL.scalar.await('SELECT COUNT(*) FROM player_horses WHERE citizenid = ?', {
        Player.PlayerData.citizenid,
    })
    local wagonCount = MySQL.scalar.await('SELECT COUNT(*) FROM wagonmaker_wagons WHERE citizenid = ?', {
        Player.PlayerData.citizenid,
    })
    local stableFee = (horseCount * Config.StableSlots.Horse.CostPerHour)
        + (wagonCount * Config.StableSlots.Wagon.CostPerHour)
    local debt = tonumber(Player.PlayerData.metadata.stable_debt) or 0
    local debtPayment = debt * Config.StableSlots.DebtPaymentPercent
    local total = math.floor(((stableFee + debtPayment) * 100) + 0.5) / 100

    if total > 0 and Player.Functions.RemoveMoney(Config.StableSlots.MoneyType, total) then
        debt = math.floor(((debt - debtPayment) * 100) + 0.5) / 100
        Player.Functions.SetMetaData('stable_debt', debt)
        TriggerClientEvent('ox_lib:notify', Player.PlayerData.source, {
            title = ('Stable fee paid: $%.2f'):format(total),
            type = 'success',
        })
    elseif stableFee > 0 then
        debt = math.floor(((debt + stableFee) * 100) + 0.5) / 100
        Player.Functions.SetMetaData('stable_debt', debt)
        TriggerClientEvent('ox_lib:notify', Player.PlayerData.source, {
            title = ('Stable fee added to debt: $%.2f'):format(stableFee),
            description = ('Stable debt: $%.2f'):format(debt),
            type = 'error',
        })
    end
end

CreateThread(function()
    while true do
        Wait(60000)

        for _, playerId in ipairs(GetPlayers()) do
            local Player = RSGCore.Functions.GetPlayer(tonumber(playerId))
            if Player then
                local stablePlayTime = (tonumber(Player.PlayerData.metadata.stablePlayTime) or 0) + 1

                if stablePlayTime >= Config.StableSlots.FeeInterval then
                    Player.Functions.SetMetaData('stablePlayTime', 0)
                    ChargeStableFee(Player)
                else
                    Player.Functions.SetMetaData('stablePlayTime', stablePlayTime)
                end
            end
        end
    end
end)

lib.callback.register('nt_stables:server:saveHorseComponents', function(source, horseId, components)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end

    local validComponents = ValidateComponents(components)
    if not validComponents then return { success = false, message = 'Invalid horse customization.' } end

    local horse = MySQL.single.await('SELECT components FROM player_horses WHERE id = ? AND citizenid = ?', {
        horseId,
        Player.PlayerData.citizenid,
    })
    if not horse then return { success = false, message = 'Horse not found.' } end

    local currentComponents = {}
    if type(horse.components) == 'string' and horse.components ~= '' then
        local success, decoded = pcall(json.decode, horse.components)
        if success and type(decoded) == 'table' then currentComponents = decoded end
    end

    local price = 0
    for _, category in ipairs(ConfigStables.Customization) do
        local currentValue = tonumber(currentComponents[category.key]) or 0
        local newValue = tonumber(validComponents[category.key]) or 0
        local currentTints = currentComponents[category.tintKey] or validComponents[category.tintKey] or {}
        local newTints = validComponents[category.tintKey] or {}
        local tintsChanged = (tonumber(currentTints.tint0) or 0) ~= (tonumber(newTints.tint0) or 0)
            or (tonumber(currentTints.tint1) or 0) ~= (tonumber(newTints.tint1) or 0)
            or (tonumber(currentTints.tint2) or 0) ~= (tonumber(newTints.tint2) or 0)

        if currentValue ~= newValue or tintsChanged then price = price + category.price end
    end

    if price > 0 and not Player.Functions.RemoveMoney('cash', price) then
        return { success = false, message = 'You do not have enough cash for these changes.' }
    end

    local updated = MySQL.update.await('UPDATE player_horses SET components = ? WHERE id = ? AND citizenid = ?', {
        json.encode(validComponents),
        horseId,
        Player.PlayerData.citizenid,
    })

    if price > 0 and (not updated or updated < 1) then
        Player.Functions.AddMoney('cash', price)
        return { success = false, message = 'The customization could not be saved.' }
    end

    return { success = true, price = price }
end)

lib.callback.register('nt_stables:server:renameHorse', function(source, horseId, horseName)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end

    horseName = tostring(horseName or ''):match('^%s*(.-)%s*$')
    if horseName == '' or #horseName > 32 then return false end

    local horse = MySQL.single.await('SELECT horseid, name FROM player_horses WHERE id = ? AND citizenid = ?', {
        horseId,
        Player.PlayerData.citizenid,
    })
    if not horse then return false end

    MySQL.update.await('UPDATE player_horses SET name = ? WHERE id = ? AND citizenid = ?', {
        horseName,
        horseId,
        Player.PlayerData.citizenid,
    })
    MySQL.update('UPDATE inventories SET identifier = ? WHERE identifier = ?', {
        horseName .. ' ' .. horse.horseid,
        horse.name .. ' ' .. horse.horseid,
    })

    return true
end)

lib.callback.register('nt_stables:server:getHorseSellPrice', function(source, horseId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end

    local horse = MySQL.single.await('SELECT * FROM player_horses WHERE id = ? AND citizenid = ?', {
        horseId,
        Player.PlayerData.citizenid,
    })
    if not horse then return end

    return GetSellPrice(horse)
end)

lib.callback.register('nt_stables:server:sellHorse', function(source, horseId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end

    local horse = MySQL.single.await('SELECT * FROM player_horses WHERE id = ? AND citizenid = ?', {
        horseId,
        Player.PlayerData.citizenid,
    })
    if not horse then return end

    local sellPrice = GetSellPrice(horse)
    if not sellPrice then return end

    local deleted = MySQL.update.await('DELETE FROM player_horses WHERE id = ? AND citizenid = ?', {
        horseId,
        Player.PlayerData.citizenid,
    })
    if not deleted or deleted < 1 then return end

    MySQL.update.await('DELETE FROM nt_stable_wagon_horses WHERE horse_id = ? AND citizenid = ?', {
        horseId,
        Player.PlayerData.citizenid,
    })
    local clearedWagon = ClearIncompleteActiveWagon(Player)

    MySQL.update('DELETE FROM inventories WHERE identifier = ?', { horse.name .. ' ' .. horse.horseid })
    Player.Functions.AddMoney('cash', sellPrice)

    return {
        price = sellPrice,
        wasActive = horse.active == 1 or horse.active == true,
        clearedWagon = clearedWagon,
    }
end)

RegisterNetEvent('nt_stables:server:openSaddleBag', function(horseId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local horse = MySQL.single.await('SELECT horseid, name FROM player_horses WHERE horseid = ? AND citizenid = ? AND active = ?', {
        horseId,
        Player.PlayerData.citizenid,
        1,
    })

    if not horse then return end

    exports['rsg-inventory']:OpenInventory(src, horse.name .. ' ' .. horse.horseid, {
        label = 'Horse Saddlebag',
        maxweight = ConfigStables.Settings.SaddleBagWeight,
        slots = ConfigStables.Settings.SaddleBagSlots,
    })
end)

RegisterNetEvent('nt_stables:server:setHorseDirt', function(dirt)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end

    dirt = tonumber(dirt)
    if not dirt or dirt < 0 or dirt > 100 then return end

    MySQL.update('UPDATE player_horses SET dirt = ? WHERE citizenid = ? AND active = ?', {
        dirt,
        Player.PlayerData.citizenid,
        1,
    })
end)
