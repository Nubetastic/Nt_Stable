local RSGCore = exports['rsg-core']:GetCoreObject()
local HorseStats = lib.load('shared.horse_stats')
local HorseComponents = lib.load('shared.horse_components')
local inventoryTransfers = {}
local wildHorseRegistrationLocks = {}
local wildHorsePlayerLocks = {}
local trainingAwards = {}
local horseCareCooldowns = {}

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
    local allowedCustomizationKeys = { ManeCustomized = true, TailCustomized = true }
    for _, category in ipairs(ConfigStables.Customization) do
        allowedCategories[category.key] = true
        allowedTintKeys[category.tintKey] = true
    end

    local validated = {}
    for category, value in pairs(components) do
        if allowedCustomizationKeys[category] then
            if value ~= true then return end
            validated[category] = true
        elseif allowedTintKeys[category] then
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

local function ValidateAppearance(appearance)
    if type(appearance) ~= 'table'
        or tonumber(appearance.version) ~= 3
        or type(appearance.horse) ~= 'table'
        or type(appearance.equipment) ~= 'table'
        or type(appearance.horse.categories) ~= 'table'
        or type(appearance.horse.components) ~= 'table'
        or type(appearance.equipment.components) ~= 'table'
        or #appearance.horse.categories > 64
        or #appearance.horse.components == 0
        or #appearance.horse.components + #appearance.equipment.components > 32
    then
        return
    end

    local scale = tonumber(appearance.horse.scale)
    if not scale or scale < 0.5 or scale > 2.0 then return end

    local validated = {
        version = 3,
        horse = {
            scale = math.floor(scale * 100) / 100,
            categories = {},
            components = {},
        },
        equipment = {
            components = {},
        },
    }
    for _, category in ipairs(appearance.horse.categories) do
        category = tonumber(category)
        if not category or category % 1 ~= 0 or category < -2147483648 or category > 4294967295 then return end
        validated.horse.categories[#validated.horse.categories + 1] = category
    end

    local fields = { 'drawable', 'albedo', 'normal', 'material', 'palette', 'tint0', 'tint1', 'tint2' }
    for _, groupName in ipairs({ 'horse', 'equipment' }) do
        for _, component in ipairs(appearance[groupName].components) do
            if type(component) ~= 'table' then return end

            local validatedComponent = {}
            for _, field in ipairs(fields) do
                local value = tonumber(component[field])
                if not value or value % 1 ~= 0 or value < -2147483648 or value > 4294967295 then return end
                if (field == 'tint0' or field == 'tint1' or field == 'tint2') and (value < 0 or value > 255) then return end
                validatedComponent[field] = value
            end
            validated[groupName].components[#validated[groupName].components + 1] = validatedComponent
        end
    end

    return validated
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

local function IsNearStable(source, stableName)
    local stable = ConfigStables.Locations[stableName]
    if not stable or not stable.RegisterCoords then return false end
    return #(GetEntityCoords(GetPlayerPed(source)) - stable.RegisterCoords) < ConfigStables.WildHorseRegistration.OpenDistance
end

local function IsNearStableNpc(source, stableName)
    local stable = ConfigStables.Locations[stableName]
    if not stable or not stable.npcCoords then return false end
    return #(GetEntityCoords(GetPlayerPed(source)) - stable.npcCoords) < ConfigStables.Settings.ZoneDistance
end

local function GetWildHorseRegistrationCosts(Player)
    local horseCount = MySQL.scalar.await("SELECT COUNT(*) FROM nt_stable_horses WHERE citizenid = ? AND location = 'stable'", {
        Player.PlayerData.citizenid,
    })
    local slots = GetStableSlots(Player)

    if horseCount > slots.horse then
        slots.horse = horseCount
        Player.Functions.SetMetaData('stable_slots', slots)
    end

    local slotRequired = horseCount >= slots.horse
    local registrationFee = tonumber(ConfigStables.WildHorseRegistration.Fee) or 0
    local slotFee = slotRequired and GetSlotPrice('horse', slots.horse + 1) or 0
    local total = math.floor(((registrationFee + slotFee) * 100) + 0.5) / 100

    return {
        registrationFee = registrationFee,
        slotFee = slotFee,
        slotRequired = slotRequired,
        total = total,
        slots = slots,
    }
end

local function BuildWildHorseModifiers(model, nativeRanks)
    local baseStats = HorseStats.Get(model)
    if not baseStats or type(nativeRanks) ~= 'table' then return end

    local differences = {}
    for _, stat in ipairs({ 'health', 'stamina', 'agility', 'speed', 'acceleration' }) do
        local rank = math.floor((tonumber(nativeRanks[stat]) or baseStats[stat]) + 0.5)
        rank = math.max(HorseStats.MinimumRank[stat], math.min(HorseStats.MaximumStartingRank, rank))
        differences[#differences + 1] = { stat = stat, modifier = rank - baseStats[stat] }
    end

    table.sort(differences, function(left, right)
        return math.abs(left.modifier) > math.abs(right.modifier)
    end)

    local selected = {}
    local modifiers = {}
    for index = 1, 3 do
        selected[index] = differences[index].stat
        modifiers[differences[index].stat] = differences[index].modifier
    end

    return {
        version = 2,
        selected = selected,
        modifiers = modifiers,
    }
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
        INNER JOIN nt_stable_horses horses ON horses.id = assignments.horse_id
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
        INNER JOIN nt_stable_horses horses ON horses.id = assignments.horse_id
        WHERE assignments.wagon_id = ? AND assignments.citizenid = ? AND horses.citizenid = ?]], {
        wagon.id,
        citizenid,
        citizenid,
    })
    return tonumber(assigned) == wagonConfig.horseCount
end

local function GetStableInventoryId(citizenid)
    return 'stable_storage_' .. citizenid
end

local function GetStableInventoryWeight(citizenid)
    local identifier = GetStableInventoryId(citizenid)
    exports['rsg-inventory']:CreateInventory(identifier, {
        label = 'Stable Storage',
        maxweight = Config.StableSlots.StableOverflow.ResizeWeight * 1000,
        slots = Config.StableSlots.StableOverflow.Slots,
    })
    local inventory = exports['rsg-inventory']:GetInventory(identifier)
    return exports['rsg-inventory']:GetTotalWeight(inventory.items), inventory
end

local function GetStableInventoryMaxWeight(weight)
    local resizeWeight = Config.StableSlots.StableOverflow.ResizeWeight * 1000
    return math.max(resizeWeight, math.ceil(weight / resizeWeight) * resizeWeight)
end

local function ResizeStableInventory(citizenid, extraWeight)
    local weight = GetStableInventoryWeight(citizenid)
    local maxWeight = GetStableInventoryMaxWeight(weight + (extraWeight or 0))
    exports['rsg-inventory']:CreateInventory(GetStableInventoryId(citizenid), {
        label = 'Stable Storage',
        maxweight = maxWeight,
        slots = Config.StableSlots.StableOverflow.Slots,
    })
    return weight, maxWeight
end

local function MoveInventoryToStable(Player, identifier, label, description)
    local citizenid = Player.PlayerData.citizenid
    if inventoryTransfers[citizenid] then return false end

    exports['rsg-inventory']:CreateInventory(identifier, {})
    local inventory = exports['rsg-inventory']:GetInventory(identifier)
    if not inventory or not next(inventory.items) then return true end

    inventoryTransfers[citizenid] = true
    local items = {}
    local totalWeight = exports['rsg-inventory']:GetTotalWeight(inventory.items)
    for _, item in pairs(inventory.items) do items[#items + 1] = item end
    ResizeStableInventory(citizenid, totalWeight)

    for _, item in ipairs(items) do
        local removed = exports['rsg-inventory']:RemoveItem(identifier, item.name, item.amount, item.slot, 'stable overflow transfer')
        if not removed or not exports['rsg-inventory']:AddItem(GetStableInventoryId(citizenid), item.name, item.amount, nil, item.info, 'stable overflow transfer') then
            if removed then
                exports['rsg-inventory']:AddItem(identifier, item.name, item.amount, item.slot, item.info, 'stable overflow rollback')
            end
            inventoryTransfers[citizenid] = nil
            return false
        end
    end

    exports['rsg-inventory']:SaveStash(identifier)
    exports['rsg-inventory']:SaveStash(GetStableInventoryId(citizenid))
    ResizeStableInventory(citizenid)
    inventoryTransfers[citizenid] = nil
    TriggerClientEvent('ox_lib:notify', Player.PlayerData.source, {
        title = label .. ' moved to stable storage',
        description = description or 'Its storage weight exceeded the new carrying capacity.',
        type = 'warning',
        duration = 10000,
    })
    return true
end

local function GetHorseCarryWeight(horse)
    local _, stats = HorseStats.Calculate(horse)
    return stats and HorseStats.GetCarryWeight(stats.strength) * 1000 or 0
end

local function GetWagonInventoryMaxWeight(citizenid, wagonId, model, excludedHorseId)
    local wagonConfig = ConfigWagon.Wagons[model]
    if not wagonConfig then return 0 end

    local horses = MySQL.query.await([[SELECT horses.* FROM nt_stable_wagon_horses assignments
        INNER JOIN nt_stable_horses horses ON horses.id = assignments.horse_id
        WHERE assignments.wagon_id = ? AND assignments.citizenid = ? AND horses.citizenid = ?
            AND horses.id <> ?]], {
        wagonId,
        citizenid,
        citizenid,
        tonumber(excludedHorseId) or 0,
    })
    local pullWeight = 0
    for _, horse in ipairs(horses) do
        local _, stats = HorseStats.Calculate(horse)
        if stats then pullWeight = pullWeight + (HorseStats.GetPullWeight(stats.strength) * 1000) end
    end
    return math.min(pullWeight, wagonConfig.maxWeight)
end

local function GetStableStorageFee(weight)
    local stableWeight = weight / 1000
    local chargedWeight = math.max(0, stableWeight - Config.StableSlots.StableOverflow.NonChargeWeight)
    return math.ceil(chargedWeight / Config.StableSlots.StableOverflow.BaseWeightPrice)
        * Config.StableSlots.StableOverflow.CostPerHour
end

local function GetStableInventoryTransferData(Player)
    local citizenid = Player.PlayerData.citizenid
    local stableWeight, stableInventory = GetStableInventoryWeight(citizenid)
    local items = {}
    for slot, item in pairs(stableInventory.items or {}) do
        items[#items + 1] = {
            slot = tonumber(item.slot) or tonumber(slot), name = item.name, label = item.label,
            image = item.image or (item.name .. '.png'), amount = item.amount, weight = item.weight,
        }
    end
    table.sort(items, function(a, b) return a.slot < b.slot end)

    local function GetDestination(identifier, label, maxWeight, slots)
        exports['rsg-inventory']:CreateInventory(identifier, { label = label, maxweight = maxWeight, slots = slots })
        local inventory = exports['rsg-inventory']:GetInventory(identifier)
        local usedSlots = 0
        for _ in pairs(inventory.items or {}) do usedSlots = usedSlots + 1 end
        return {
            identifier = identifier, label = label,
            currentWeight = exports['rsg-inventory']:GetTotalWeight(inventory.items), maxWeight = maxWeight,
            freeSlots = math.max(0, slots - usedSlots),
        }
    end

    local horseDestination
    local horse = MySQL.single.await('SELECT * FROM nt_stable_horses WHERE citizenid = ? AND active = ?', { citizenid, 1 })
    if horse then
        horseDestination = GetDestination('horse_saddlebag_' .. citizenid, horse.name .. ' Saddlebag',
            GetHorseCarryWeight(horse), ConfigStables.Settings.SaddleBagSlots)
    end

    local wagonDestination
    local wagonId = GetActiveWagonId(Player)
    if wagonId then
        local wagon = MySQL.single.await('SELECT id, model, name, needs_repair FROM nt_stable_wagons WHERE id = ? AND citizenid = ?', { wagonId, citizenid })
        if wagon and wagon.needs_repair ~= 1 and wagon.needs_repair ~= true and ConfigWagon.Wagons[wagon.model] then
            wagonDestination = GetDestination('wagon_' .. wagon.id, wagon.name .. ' Storage',
                GetWagonInventoryMaxWeight(citizenid, wagon.id, wagon.model), ConfigWagon.Wagons[wagon.model].slots)
        end
    end

    return {
        items = items, stableWeight = stableWeight, storageFee = GetStableStorageFee(stableWeight),
        horse = horseDestination, wagon = wagonDestination,
    }
end

local function MoveWagonToStableIfOver(Player, wagonId, model, excludedHorseId)
    local identifier = 'wagon_' .. wagonId
    exports['rsg-inventory']:CreateInventory(identifier, {
        maxweight = ConfigWagon.Wagons[model].maxWeight,
        slots = ConfigWagon.Wagons[model].slots,
    })
    local inventory = exports['rsg-inventory']:GetInventory(identifier)
    local maxWeight = GetWagonInventoryMaxWeight(Player.PlayerData.citizenid, wagonId, model, excludedHorseId)
    if exports['rsg-inventory']:GetTotalWeight(inventory.items) <= maxWeight then return true end
    return MoveInventoryToStable(Player, identifier, 'Wagon cargo')
end

local function ClearIncompleteActiveWagon(Player)
    local wagonId = GetActiveWagonId(Player)
    if not wagonId then return false end

    local wagon = MySQL.single.await('SELECT id, model, needs_repair FROM nt_stable_wagons WHERE id = ? AND citizenid = ?', {
        wagonId,
        Player.PlayerData.citizenid,
    })
    if wagon and wagon.needs_repair ~= 1 and wagon.needs_repair ~= true
        and WagonHasRequiredHorses(Player.PlayerData.citizenid, wagon) then return false end

    Player.Functions.SetMetaData('stable_active_wagon', false)
    return true
end

exports('PrepareHorseForAuction', function(source, horseId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end

    local horse = MySQL.single.await("SELECT * FROM nt_stable_horses WHERE id = ? AND citizenid = ? AND location = 'stable'", {
        horseId,
        Player.PlayerData.citizenid,
    })
    if not horse then return { success = false, message = 'Horse not found.' } end
    local wasActive = horse.active == 1 or horse.active == true
    if wasActive and not MoveInventoryToStable(Player, 'horse_saddlebag_' .. Player.PlayerData.citizenid, 'Horse saddlebag') then
        return { success = false, message = 'The saddlebag could not be moved to stable storage.' }
    end

    local affectedWagons = MySQL.query.await([[SELECT wagons.id, wagons.model
        FROM nt_stable_wagon_horses assignments
        INNER JOIN nt_stable_wagons wagons ON wagons.id = assignments.wagon_id
        WHERE assignments.horse_id = ? AND assignments.citizenid = ? AND wagons.citizenid = ?]], {
        horseId,
        Player.PlayerData.citizenid,
        Player.PlayerData.citizenid,
    })
    for _, wagon in ipairs(affectedWagons) do
        if not MoveWagonToStableIfOver(Player, tonumber(wagon.id), wagon.model, horseId) then
            return { success = false, message = 'The wagon cargo could not be moved to stable storage.' }
        end
    end

    if wasActive then Player.Functions.SetMetaData('stable_active_horse', false) end
    local clearedWagon = false
    local activeWagonId = GetActiveWagonId(Player)
    for _, wagon in ipairs(affectedWagons) do
        if tonumber(wagon.id) == activeWagonId then
            Player.Functions.SetMetaData('stable_active_wagon', false)
            clearedWagon = true
            break
        end
    end
    return { success = true, wasActive = wasActive, clearedWagon = clearedWagon }
end)

local GetSellPrice

local function GetStableManagerData(Player, slots)
    local horses = MySQL.query.await("SELECT * FROM nt_stable_horses WHERE citizenid = ? AND location = 'stable' ORDER BY active DESC, name ASC", {
        Player.PlayerData.citizenid,
    })
    local wagons = MySQL.query.await('SELECT * FROM nt_stable_wagons WHERE citizenid = ? ORDER BY name ASC', {
        Player.PlayerData.citizenid,
    })
    ClearIncompleteActiveWagon(Player)
    local wagonHorses, assignedHorses = GetWagonHorseAssignments(Player.PlayerData.citizenid)
    local activeWagonId = GetActiveWagonId(Player)
    for _, wagon in ipairs(wagons) do
        wagon.horses = wagonHorses[tonumber(wagon.id)] or {}
        wagon.active = activeWagonId == tonumber(wagon.id)
        wagon.ready = #wagon.horses == ConfigWagon.Wagons[wagon.model].horseCount
        wagon.repairPrice = math.floor(((ConfigWagon.Wagons[wagon.model].price * ConfigWagon.Prices.repair) * 100) + 0.5) / 100
        wagon.sellPrice = math.floor((ConfigWagon.Wagons[wagon.model].price * Config.StableSlots.SellPriceMultiplier) + 0.5)
    end
    for _, horse in ipairs(horses) do
        horse.isWagonHorse = assignedHorses[tonumber(horse.id)] == true
        horse.sellPrice = GetSellPrice(horse)
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

GetSellPrice = function(horse)
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

RegisterSqlCallback('nt_stables:server:getActiveHorse', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end

    return MySQL.single.await("SELECT * FROM nt_stable_horses WHERE citizenid = ? AND active = ? AND location = 'stable'", {
        Player.PlayerData.citizenid,
        1,
    })
end)

RegisterSqlCallback('nt_stables:server:getPlayerHorses', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end

    return MySQL.query.await("SELECT * FROM nt_stable_horses WHERE citizenid = ? AND location = 'stable' ORDER BY active DESC, name ASC", {
        Player.PlayerData.citizenid,
    })
end)

RegisterSqlCallback('nt_stables:server:getMissingHorseAppearances', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return {} end

    return MySQL.query.await([[SELECT id, horse, gender, components, appearance FROM nt_stable_horses
        WHERE citizenid = ? AND location = 'stable'
            AND (appearance IS NULL OR appearance = '' OR appearance NOT LIKE '%"version":3%') ORDER BY id]], {
        Player.PlayerData.citizenid,
    })
end)

RegisterSqlCallback('nt_stables:server:saveHorseAppearance', function(source, horseId, appearance)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end

    horseId = tonumber(horseId)
    local validAppearance = ValidateAppearance(appearance)
    if not horseId or not validAppearance then return false end

    local updated = MySQL.update.await("UPDATE nt_stable_horses SET appearance = ? WHERE id = ? AND citizenid = ? AND location = 'stable'", {
        json.encode(validAppearance),
        horseId,
        Player.PlayerData.citizenid,
    })
    return updated and updated > 0
end)

RegisterSqlCallback('nt_stables:server:getWildHorseRegistrationQuote', function(source, stableName)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end
    if not IsNearStable(source, stableName) then
        return { success = false, message = 'You must be near the stable to register a wild horse.' }
    end

    local costs = GetWildHorseRegistrationCosts(Player)
    return {
        success = true,
        registrationFee = costs.registrationFee,
        slotFee = costs.slotFee,
        slotRequired = costs.slotRequired,
        total = costs.total,
    }
end)

RegisterSqlCallback('nt_stables:server:registerWildHorse', function(source, data)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or type(data) ~= 'table' then
        return { success = false, message = 'Player not found.' }
    end
    if wildHorsePlayerLocks[source] then
        return { success = false, message = 'A horse registration is already in progress.' }
    end
    if not IsNearStable(source, data.stable) then
        return { success = false, message = 'You must remain near the stable while registering.' }
    end

    local name = tostring(data.name or ''):match('^%s*(.-)%s*$')
    if name == '' or #name > 32 or name:find("[^%w%s%-']") then
        return { success = false, message = 'Horse names must contain 1 to 32 valid characters.' }
    end
    data.gender = data.gender == 'female' and 'female' or 'male'
    if not HorseStats.Exists(data.model) then
        return { success = false, message = 'That horse model cannot be registered.' }
    end

    local networkId = tonumber(data.networkId) or 0
    local horse = NetworkGetEntityFromNetworkId(networkId)
    if horse == 0 or not DoesEntityExist(horse) then
        return { success = false, message = 'The wild horse could not be verified.' }
    end
    if wildHorseRegistrationLocks[networkId] then
        return { success = false, message = 'This wild horse is already being registered.' }
    end
    if #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(horse)) > ConfigStables.WildHorseRegistration.OpenDistance then
        return { success = false, message = 'Keep the wild horse near you while registering it.' }
    end
    if GetEntityModel(horse) ~= joaat(data.model) then
        return { success = false, message = 'The wild horse model did not match.' }
    end

    local statModifiers = BuildWildHorseModifiers(data.model, data.nativeRanks)
    if not statModifiers then
        return { success = false, message = 'The wild horse stats could not be read.' }
    end
    local appearance = ValidateAppearance(data.appearance)
    if not appearance then
        return { success = false, message = 'The wild horse appearance could not be captured.' }
    end

    wildHorseRegistrationLocks[networkId] = horse
    wildHorsePlayerLocks[source] = true

    local costs = GetWildHorseRegistrationCosts(Player)
    if not Player.Functions.RemoveMoney(Config.StableSlots.MoneyType, costs.total) then
        wildHorseRegistrationLocks[networkId] = nil
        wildHorsePlayerLocks[source] = nil
        return { success = false, message = ('You need $%.2f to register this horse.'):format(costs.total) }
    end

    local databaseId, publicId = ReserveStableEntityId(Player.PlayerData.citizenid, 'H')
    local inserted = databaseId and MySQL.insert.await([[INSERT INTO nt_stable_horses
        (id, horseid, citizenid, name, horse, horsexp, components, gender, wild, stat_modifiers, appearance, active, location)
        VALUES (?, ?, ?, ?, ?, 0, ?, ?, 1, ?, ?, 0, 'stable')]], {
        databaseId,
        publicId,
        Player.PlayerData.citizenid,
        name,
        data.model,
        json.encode({}),
        data.gender,
        json.encode(statModifiers),
        json.encode(appearance),
    })

    if not inserted then
        Player.Functions.AddMoney(Config.StableSlots.MoneyType, costs.total)
        wildHorseRegistrationLocks[networkId] = nil
        wildHorsePlayerLocks[source] = nil
        return { success = false, message = 'Registration failed and your payment was refunded.' }
    end

    if costs.slotRequired then
        costs.slots.horse = costs.slots.horse + 1
        Player.Functions.SetMetaData('stable_slots', costs.slots)
    end

    wildHorsePlayerLocks[source] = nil
    return {
        success = true,
        horseId = databaseId,
        slotPurchased = costs.slotRequired,
        total = costs.total,
    }
end)

CreateThread(function()
    while true do
        Wait(10000)
        for networkId, horse in pairs(wildHorseRegistrationLocks) do
            if not DoesEntityExist(horse) then
                wildHorseRegistrationLocks[networkId] = nil
            end
        end
    end
end)

RegisterSqlCallback('nt_stables:server:getStableManagerData', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end

    return GetStableManagerData(Player)
end)

RegisterSqlCallback('nt_stables:server:changeStableSlots', function(source, slotType, action)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end
    if slotType ~= 'horse' and slotType ~= 'wagon' then
        return { success = false, message = 'Invalid stable slot type.' }
    end

    local slots = GetStableSlots(Player)
    local slotConfig = slotType == 'horse' and Config.StableSlots.Horse or Config.StableSlots.Wagon
    local owned = MySQL.scalar.await(slotType == 'horse'
        and "SELECT COUNT(*) FROM nt_stable_horses WHERE citizenid = ? AND location = 'stable'"
        or 'SELECT COUNT(*) FROM nt_stable_wagons WHERE citizenid = ?', {
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

RegisterSqlCallback('nt_stables:server:setRidingHorse', function(source, horseId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end

    local horse = MySQL.single.await("SELECT * FROM nt_stable_horses WHERE id = ? AND citizenid = ? AND location = 'stable'", {
        horseId,
        Player.PlayerData.citizenid,
    })
    if not horse then return false end

    local carryWeight = GetHorseCarryWeight(horse)
    local saddleBagId = 'horse_saddlebag_' .. Player.PlayerData.citizenid
    exports['rsg-inventory']:CreateInventory(saddleBagId, {
        label = 'Horse Saddlebag',
        maxweight = carryWeight,
        slots = ConfigStables.Settings.SaddleBagSlots,
    })
    local saddleBag = exports['rsg-inventory']:GetInventory(saddleBagId)
    if exports['rsg-inventory']:GetTotalWeight(saddleBag.items) > carryWeight
        and not MoveInventoryToStable(Player, saddleBagId, 'Horse saddlebag') then
        return { success = false, message = 'The saddlebag could not be moved to stable storage.' }
    end

    local affectedWagons = MySQL.query.await([[SELECT wagons.id, wagons.model
        FROM nt_stable_wagon_horses assignments
        INNER JOIN nt_stable_wagons wagons ON wagons.id = assignments.wagon_id
        WHERE assignments.horse_id = ? AND assignments.citizenid = ? AND wagons.citizenid = ?]], {
        horseId,
        Player.PlayerData.citizenid,
        Player.PlayerData.citizenid,
    })

    MySQL.update.await('DELETE FROM nt_stable_wagon_horses WHERE horse_id = ? AND citizenid = ?', {
        horseId,
        Player.PlayerData.citizenid,
    })
    for _, wagon in ipairs(affectedWagons) do
        MoveWagonToStableIfOver(Player, tonumber(wagon.id), wagon.model)
    end
    local clearedWagon = ClearIncompleteActiveWagon(Player)
    MySQL.update.await('UPDATE nt_stable_horses SET active = 0 WHERE citizenid = ?', { Player.PlayerData.citizenid })
    MySQL.update.await('UPDATE nt_stable_horses SET active = 1 WHERE id = ? AND citizenid = ?', {
        horseId,
        Player.PlayerData.citizenid,
    })
    return { success = true, clearedWagon = clearedWagon }
end)

RegisterSqlCallback('nt_stables:server:setRidingWagon', function(source, wagonId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end

    wagonId = tonumber(wagonId)
    if not wagonId then return false end

    local wagon = MySQL.single.await('SELECT id, model, needs_repair FROM nt_stable_wagons WHERE id = ? AND citizenid = ?', {
        wagonId,
        Player.PlayerData.citizenid,
    })
    if not wagon then return { success = false, message = 'Wagon not found.' } end
    if wagon.needs_repair == 1 or wagon.needs_repair == true then
        return { success = false, message = 'Repair this wagon before setting it active.' }
    end
    if not WagonHasRequiredHorses(Player.PlayerData.citizenid, wagon) then
        return { success = false, message = 'Assign a horse to every wagon slot before setting it active.' }
    end

    Player.Functions.SetMetaData('stable_active_wagon', wagonId)
    return { success = true }
end)

RegisterSqlCallback('nt_stables:server:repairWagon', function(source, wagonId)
    local Player = RSGCore.Functions.GetPlayer(source)
    wagonId = tonumber(wagonId)
    if not Player or not wagonId then return { success = false, message = 'Wagon not found.' } end
    local wagon = MySQL.single.await('SELECT id, model, needs_repair FROM nt_stable_wagons WHERE id = ? AND citizenid = ?', {
        wagonId,
        Player.PlayerData.citizenid,
    })
    local wagonConfig = wagon and ConfigWagon.Wagons[wagon.model]
    if not wagonConfig then return { success = false, message = 'Wagon not found.' } end
    if wagon.needs_repair ~= 1 and wagon.needs_repair ~= true then
        return { success = false, message = 'This wagon does not need repairs.' }
    end

    local price = math.floor(((wagonConfig.price * ConfigWagon.Prices.repair) * 100) + 0.5) / 100
    if price > 0 and not Player.Functions.RemoveMoney(Config.StableSlots.MoneyType, price) then
        return { success = false, message = 'You do not have enough money to repair this wagon.' }
    end

    if not MoveInventoryToStable(Player, 'wagon_' .. wagonId, 'Wagon cargo', 'The wagon was destroyed.') then
        if price > 0 then Player.Functions.AddMoney(Config.StableSlots.MoneyType, price) end
        return { success = false, message = 'The wagon cargo could not be moved to stable storage.' }
    end

    local updated = MySQL.update.await('UPDATE nt_stable_wagons SET needs_repair = 0 WHERE id = ? AND citizenid = ? AND needs_repair = 1', {
        wagonId,
        Player.PlayerData.citizenid,
    })
    if not updated or updated < 1 then
        if price > 0 then Player.Functions.AddMoney(Config.StableSlots.MoneyType, price) end
        return { success = false, message = 'Unable to repair this wagon.' }
    end

    return {
        success = true,
        price = price,
        customizations = {
            livery = customization.livery,
            tint = customization.tint,
            extras = json.encode(customization.extras),
            lantern = customization.lantern,
        },
    }
end)

RegisterSqlCallback('nt_stables:server:getActiveStableRideType', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return 'horse' end
    return GetActiveWagonId(Player) and 'wagon' or 'horse'
end)

RegisterSqlCallback('nt_stables:server:getActiveWagon', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end

    local wagonId = GetActiveWagonId(Player)
    if not wagonId then return end
    local wagon = MySQL.single.await('SELECT * FROM nt_stable_wagons WHERE id = ? AND citizenid = ?', {
        wagonId,
        Player.PlayerData.citizenid,
    })
    if not wagon or wagon.needs_repair == 1 or wagon.needs_repair == true
        or not WagonHasRequiredHorses(Player.PlayerData.citizenid, wagon) then
        Player.Functions.SetMetaData('stable_active_wagon', false)
        return
    end

    local wagonHorses = GetWagonHorseAssignments(Player.PlayerData.citizenid)
    wagon.horses = wagonHorses[tonumber(wagon.id)] or {}
    return wagon
end)

RegisterSqlCallback('nt_stables:server:setWagonHorses', function(source, wagonId, assignments)
    local Player = RSGCore.Functions.GetPlayer(source)
    wagonId = tonumber(wagonId)
    if not Player or not wagonId or type(assignments) ~= 'table' then
        return { success = false, message = 'Invalid wagon horse assignments.' }
    end

    local citizenid = Player.PlayerData.citizenid
    local wagon = MySQL.single.await('SELECT id, model FROM nt_stable_wagons WHERE id = ? AND citizenid = ?', {
        wagonId,
        citizenid,
    })
    local wagonConfig = wagon and ConfigWagon.Wagons[wagon.model]
    if not wagonConfig or #assignments > wagonConfig.horseCount then
        return { success = false, message = 'Invalid wagon horse assignments.' }
    end

    local ownedHorses = MySQL.query.await("SELECT * FROM nt_stable_horses WHERE citizenid = ? AND location = 'stable'", {
        citizenid,
    })
    local horsesById = {}
    for _, horse in ipairs(ownedHorses) do horsesById[tonumber(horse.id)] = horse end

    local selected = {}
    local usedSlots = {}
    local usedHorses = {}
    local wasRiding = false
    local pullWeight = 0
    for _, assignment in ipairs(assignments) do
        local slot = tonumber(assignment.slot)
        local horseId = tonumber(assignment.horseId or assignment.id)
        local horse = horseId and horsesById[horseId]
        if not slot or slot % 1 ~= 0 or slot < 1 or slot > wagonConfig.horseCount or not horse
            or usedSlots[slot] or usedHorses[horseId] then
            return { success = false, message = 'Invalid wagon horse assignments.' }
        end
        usedSlots[slot] = true
        usedHorses[horseId] = true
        selected[#selected + 1] = { slot = slot, horseId = horseId, horse = horse }
        wasRiding = wasRiding or horse.active == 1 or horse.active == true
        local _, stats = HorseStats.Calculate(horse)
        if stats then pullWeight = pullWeight + (HorseStats.GetPullWeight(stats.strength) * 1000) end
    end

    if wasRiding and not MoveInventoryToStable(Player, 'horse_saddlebag_' .. citizenid, 'Horse saddlebag') then
        return { success = false, message = 'The saddlebag could not be moved to stable storage.' }
    end

    local wagonInventoryId = 'wagon_' .. wagonId
    exports['rsg-inventory']:CreateInventory(wagonInventoryId, {
        maxweight = wagonConfig.maxWeight,
        slots = wagonConfig.slots,
    })
    local wagonInventory = exports['rsg-inventory']:GetInventory(wagonInventoryId)
    local maxWeight = math.min(pullWeight, wagonConfig.maxWeight)
    if exports['rsg-inventory']:GetTotalWeight(wagonInventory.items) > maxWeight
        and not MoveInventoryToStable(Player, wagonInventoryId, 'Wagon cargo') then
        return { success = false, message = 'The wagon cargo could not be moved to stable storage.' }
    end

    local wasActiveWagon = GetActiveWagonId(Player) == wagonId
    local statements = {
        {
            query = 'DELETE FROM nt_stable_wagon_horses WHERE wagon_id = ? AND citizenid = ?',
            values = { wagonId, citizenid },
        },
    }
    for _, assignment in ipairs(selected) do
        statements[#statements + 1] = {
            query = 'INSERT INTO nt_stable_wagon_horses (wagon_id, slot, horse_id, citizenid) VALUES (?, ?, ?, ?)',
            values = { wagonId, assignment.slot, assignment.horseId, citizenid },
        }
        if assignment.horse.active == 1 or assignment.horse.active == true then
            statements[#statements + 1] = {
                query = 'UPDATE nt_stable_horses SET active = 0 WHERE id = ? AND citizenid = ?',
                values = { assignment.horseId, citizenid },
            }
        end
    end

    if not MySQL.transaction.await(statements) then
        return { success = false, message = 'The wagon horse assignments could not be saved.' }
    end

    local wagonHorses = GetWagonHorseAssignments(citizenid)
    local clearedWagon = ClearIncompleteActiveWagon(Player)
    return {
        success = true,
        assignments = wagonHorses[wagonId] or {},
        wasRiding = wasRiding,
        clearedWagon = clearedWagon,
        activeWagonChanged = wasActiveWagon,
    }
end)

RegisterSqlCallback('nt_stables:server:buyWagon', function(source, model, wagonName, livery, tint, extras, lantern)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end

    model = tostring(model or ''):lower()
    wagonName = tostring(wagonName or ''):match('^%s*(.-)%s*$')
    local wagonConfig = ConfigWagon.Wagons[model]
    local customization = ValidateWagonCustomization(model, livery, tint, extras, lantern)
    if not wagonConfig or not customization then
        return { success = false, message = 'Invalid wagon or customization.' }
    end
    if wagonName == '' or #wagonName > 100
        or (wagonName ~= wagonConfig.label and wagonName:find("[^%w%s%-']")) then
        return { success = false, message = 'Wagon names must contain 1 to 100 valid characters.' }
    end

    local wagonCount = MySQL.scalar.await('SELECT COUNT(*) FROM nt_stable_wagons WHERE citizenid = ?', {
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

    local wagonId, wagonPublicId = ReserveStableEntityId(Player.PlayerData.citizenid, 'W')
    local inserted = wagonId and MySQL.insert.await([[INSERT INTO nt_stable_wagons
        (id, wagonid, citizenid, model, name, livery, tint, extras, lantern)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        wagonId,
        wagonPublicId,
        Player.PlayerData.citizenid,
        model,
        wagonName,
        customization.livery,
        customization.tint,
        json.encode(customization.extras),
        customization.lantern,
    })

    if not inserted then
        Player.Functions.AddMoney(Config.StableSlots.MoneyType, price)
        return { success = false, message = 'The wagon purchase could not be saved.' }
    end

    local savedWagon = MySQL.single.await('SELECT * FROM nt_stable_wagons WHERE id = ? AND citizenid = ?', {
        wagonId,
        Player.PlayerData.citizenid,
    })
    savedWagon.horses = {}
    savedWagon.active = false
    savedWagon.ready = false
    savedWagon.repairPrice = math.floor(((wagonConfig.price * ConfigWagon.Prices.repair) * 100) + 0.5) / 100
    savedWagon.sellPrice = math.floor((wagonConfig.price * Config.StableSlots.SellPriceMultiplier) + 0.5)
    return { success = true, wagonId = wagonId, wagon = savedWagon, price = price }
end)

RegisterSqlCallback('nt_stables:server:saveWagonCustomization', function(source, wagonId, livery, tint, extras, lantern)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end

    local wagon = MySQL.single.await('SELECT model, livery, tint, extras, lantern FROM nt_stable_wagons WHERE id = ? AND citizenid = ?', {
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

    local updated = MySQL.update.await([[UPDATE nt_stable_wagons
        SET livery = ?, tint = ?, extras = ?, lantern = ? WHERE id = ? AND citizenid = ?]], {
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

RegisterSqlCallback('nt_stables:server:renameWagon', function(source, wagonId, wagonName)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end

    wagonName = tostring(wagonName or ''):match('^%s*(.-)%s*$')
    if wagonName == '' or #wagonName > 100 or wagonName:find("[^%w%s%-'()]") then return false end

    local updated = MySQL.update.await('UPDATE nt_stable_wagons SET name = ? WHERE id = ? AND citizenid = ?', {
        wagonName,
        tonumber(wagonId),
        Player.PlayerData.citizenid,
    })
    return updated and updated > 0
end)

RegisterSqlCallback('nt_stables:server:sellWagon', function(source, wagonId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end

    wagonId = tonumber(wagonId)
    local wagon = MySQL.single.await('SELECT * FROM nt_stable_wagons WHERE id = ? AND citizenid = ?', {
        wagonId,
        Player.PlayerData.citizenid,
    })
    local wagonConfig = wagon and ConfigWagon.Wagons[wagon.model]
    if not wagonConfig then return end

    if not MoveInventoryToStable(Player, 'wagon_' .. wagonId, 'Wagon cargo') then
        return { success = false, message = 'The wagon cargo could not be moved to stable storage.' }
    end

    local sellPrice = math.floor((wagonConfig.price * Config.StableSlots.SellPriceMultiplier) + 0.5)
    local deleted = MySQL.update.await('DELETE FROM nt_stable_wagons WHERE id = ? AND citizenid = ?', {
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
    Player.Functions.AddMoney(Config.StableSlots.MoneyType, sellPrice)

    return { price = sellPrice, wasActive = wasActive }
end)

RegisterSqlCallback('nt_stables:server:buyHorse', function(source, stableName, model, horseName, gender, components, appearance)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end

    horseName = tostring(horseName or ''):match('^%s*(.-)%s*$')
    if horseName == '' or #horseName > 32 or horseName:find("[^%w%s%-']") then
        return { success = false, message = 'Horse names must contain 1 to 32 valid characters.' }
    end

    gender = gender == 'female' and 'female' or 'male'

    local validComponents = ValidateComponents(components)
    local validAppearance = ValidateAppearance(appearance)
    if not validComponents then
        return { success = false, message = 'Invalid horse customization.' }
    end
    if not validAppearance then
        return { success = false, message = 'The horse appearance could not be captured.' }
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

    local horseCount = MySQL.scalar.await("SELECT COUNT(*) FROM nt_stable_horses WHERE citizenid = ? AND location = 'stable'", {
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

    local databaseId, horseId = ReserveStableEntityId(Player.PlayerData.citizenid, 'H')
    local saved = databaseId and MySQL.transaction.await({
        {
            query = 'UPDATE nt_stable_horses SET active = 0 WHERE citizenid = ? AND location = ?',
            values = { Player.PlayerData.citizenid, 'stable' },
        },
        {
            query = [[INSERT INTO nt_stable_horses
                (id, horseid, citizenid, name, horse, horsexp, components, gender, appearance, active, location)
                VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?, 1, 'stable')]],
            values = {
        databaseId,
        horseId,
        Player.PlayerData.citizenid,
        horseName,
        model,
        json.encode(validComponents),
        gender,
        json.encode(validAppearance),
            },
        },
    })

    if not saved then
        Player.Functions.AddMoney('cash', stats.price)
        return { success = false, message = 'The horse purchase could not be saved.' }
    end

    Player.Functions.SetMetaData('stable_active_ride', { type = 'horse' })

    local savedHorse = MySQL.single.await("SELECT * FROM nt_stable_horses WHERE id = ? AND citizenid = ? AND location = 'stable'", {
        databaseId,
        Player.PlayerData.citizenid,
    })
    savedHorse.isWagonHorse = false
    savedHorse.sellPrice = GetSellPrice(savedHorse)
    return { success = true, horseId = databaseId, horse = savedHorse }
end)

local function ChargeStableFee(Player)
    local horseCount = MySQL.scalar.await("SELECT COUNT(*) FROM nt_stable_horses WHERE citizenid = ? AND location = 'stable'", {
        Player.PlayerData.citizenid,
    })
    local wagonCount = MySQL.scalar.await('SELECT COUNT(*) FROM nt_stable_wagons WHERE citizenid = ?', {
        Player.PlayerData.citizenid,
    })
    local ownershipFee = (horseCount * Config.StableSlots.Horse.CostPerHour)
        + (wagonCount * Config.StableSlots.Wagon.CostPerHour)
    local stableWeight = GetStableInventoryWeight(Player.PlayerData.citizenid) / 1000
    local overflowFee = GetStableStorageFee(stableWeight * 1000)
    local stableFee = ownershipFee + overflowFee
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
        if overflowFee > 0 then
            TriggerClientEvent('ox_lib:notify', Player.PlayerData.source, {
                title = ('Stable storage fee: $%.2f'):format(overflowFee),
                description = ('%.1f kg stored; %.1f kg is free.'):format(stableWeight, Config.StableSlots.StableOverflow.NonChargeWeight),
                type = 'error',
            })
        end
    elseif stableFee > 0 then
        debt = math.floor(((debt + stableFee) * 100) + 0.5) / 100
        Player.Functions.SetMetaData('stable_debt', debt)
        TriggerClientEvent('ox_lib:notify', Player.PlayerData.source, {
            title = ('Stable fee added to debt: $%.2f'):format(stableFee),
            description = ('Stable debt: $%.2f'):format(debt),
            type = 'error',
        })
        if overflowFee > 0 then
            TriggerClientEvent('ox_lib:notify', Player.PlayerData.source, {
                title = ('Stable storage fee added to debt: $%.2f'):format(overflowFee),
                description = ('%.1f kg stored; %.1f kg is free.'):format(stableWeight, Config.StableSlots.StableOverflow.NonChargeWeight),
                type = 'error',
            })
        end
    end
end

CreateThread(function()
    while true do
        Wait(60000)

        for _, playerId in ipairs(GetPlayers()) do
            playerId = tonumber(playerId)
            sqlAction('charge_stable_fee', playerId, function()
                local Player = RSGCore.Functions.GetPlayer(playerId)
                if Player then
                    local stablePlayTime = (tonumber(Player.PlayerData.metadata.stablePlayTime) or 0) + 1

                    if stablePlayTime >= Config.StableSlots.FeeInterval then
                        Player.Functions.SetMetaData('stablePlayTime', 0)
                        ChargeStableFee(Player)
                    else
                        Player.Functions.SetMetaData('stablePlayTime', stablePlayTime)
                    end
                end
            end)
        end
    end
end)

RegisterSqlCallback('nt_stables:server:saveHorseComponents', function(source, horseId, components, appearance)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end

    local validComponents = ValidateComponents(components)
    if not validComponents then return { success = false, message = 'Invalid horse customization.' } end
    local validAppearance = ValidateAppearance(appearance)
    if not validAppearance then return { success = false, message = 'The horse appearance could not be captured.' } end

    local horse = MySQL.single.await("SELECT components FROM nt_stable_horses WHERE id = ? AND citizenid = ? AND location = 'stable'", {
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

    local updated = MySQL.update.await("UPDATE nt_stable_horses SET components = ?, appearance = ? WHERE id = ? AND citizenid = ? AND location = 'stable'", {
        json.encode(validComponents),
        json.encode(validAppearance),
        horseId,
        Player.PlayerData.citizenid,
    })

    if price > 0 and (not updated or updated < 1) then
        Player.Functions.AddMoney('cash', price)
        return { success = false, message = 'The customization could not be saved.' }
    end

    return { success = true, price = price }
end)

RegisterSqlCallback('nt_stables:server:renameHorse', function(source, horseId, horseName)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end

    horseName = tostring(horseName or ''):match('^%s*(.-)%s*$')
    if horseName == '' or #horseName > 32 then return false end

    local horse = MySQL.single.await("SELECT id FROM nt_stable_horses WHERE id = ? AND citizenid = ? AND location = 'stable'", {
        horseId,
        Player.PlayerData.citizenid,
    })
    if not horse then return false end

    MySQL.update.await("UPDATE nt_stable_horses SET name = ? WHERE id = ? AND citizenid = ? AND location = 'stable'", {
        horseName,
        horseId,
        Player.PlayerData.citizenid,
    })
    return true
end)

RegisterSqlCallback('nt_stables:server:sellHorse', function(source, horseId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end

    local horse = MySQL.single.await("SELECT * FROM nt_stable_horses WHERE id = ? AND citizenid = ? AND location = 'stable'", {
        horseId,
        Player.PlayerData.citizenid,
    })
    if not horse then return end

    local sellPrice = GetSellPrice(horse)
    if not sellPrice then return end

    if (horse.active == 1 or horse.active == true)
        and not MoveInventoryToStable(Player, 'horse_saddlebag_' .. Player.PlayerData.citizenid, 'Horse saddlebag') then
        return { success = false, message = 'The saddlebag could not be moved to stable storage.' }
    end

    local affectedWagons = MySQL.query.await([[SELECT wagons.id, wagons.model
        FROM nt_stable_wagon_horses assignments
        INNER JOIN nt_stable_wagons wagons ON wagons.id = assignments.wagon_id
        WHERE assignments.horse_id = ? AND assignments.citizenid = ? AND wagons.citizenid = ?]], {
        horseId,
        Player.PlayerData.citizenid,
        Player.PlayerData.citizenid,
    })
    for _, wagon in ipairs(affectedWagons) do
        if not MoveWagonToStableIfOver(Player, tonumber(wagon.id), wagon.model, horseId) then
            return { success = false, message = 'The wagon cargo could not be moved to stable storage.' }
        end
    end

    local deleted = MySQL.transaction.await({
        {
            query = 'DELETE FROM nt_stable_wagon_horses WHERE horse_id = ? AND citizenid = ?',
            values = { horseId, Player.PlayerData.citizenid },
        },
        {
            query = "DELETE FROM nt_stable_horses WHERE id = ? AND citizenid = ? AND location = 'stable'",
            values = { horseId, Player.PlayerData.citizenid },
        },
    })
    if not deleted then return end

    local clearedWagon = ClearIncompleteActiveWagon(Player)

    Player.Functions.AddMoney('cash', sellPrice)

    return {
        price = sellPrice,
        wasActive = horse.active == 1 or horse.active == true,
        clearedWagon = clearedWagon,
    }
end)

RegisterSqlEvent('nt_stables:server:openSaddleBag', function(src, horseId)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local horse = MySQL.single.await("SELECT * FROM nt_stable_horses WHERE horseid = ? AND citizenid = ? AND active = ? AND location = 'stable'", {
        horseId,
        Player.PlayerData.citizenid,
        1,
    })

    if not horse then return end

    local carryWeight = GetHorseCarryWeight(horse)
    exports['rsg-inventory']:CreateInventory('horse_saddlebag_' .. Player.PlayerData.citizenid, {
        label = 'Horse Saddlebag',
        maxweight = carryWeight,
        slots = ConfigStables.Settings.SaddleBagSlots,
    })
    local saddleBag = exports['rsg-inventory']:GetInventory('horse_saddlebag_' .. Player.PlayerData.citizenid)
    if exports['rsg-inventory']:GetTotalWeight(saddleBag.items) > carryWeight
        and not MoveInventoryToStable(Player, 'horse_saddlebag_' .. Player.PlayerData.citizenid, 'Horse saddlebag') then
        return
    end

    exports['rsg-inventory']:OpenInventory(src, 'horse_saddlebag_' .. Player.PlayerData.citizenid, {
        label = 'Horse Saddlebag',
        maxweight = carryWeight,
        slots = ConfigStables.Settings.SaddleBagSlots,
    })
end)

RegisterSqlEvent('nt_stables:server:openWagonInventory', function(src, wagonId)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    wagonId = tonumber(wagonId)
    if not wagonId or GetActiveWagonId(Player) ~= wagonId then return end

    local wagon = MySQL.single.await('SELECT id, model, name FROM nt_stable_wagons WHERE id = ? AND citizenid = ?', {
        wagonId,
        Player.PlayerData.citizenid,
    })
    if not wagon then return end

    local wagonConfig = ConfigWagon.Wagons[wagon.model]
    if not wagonConfig then return end

    local maxWeight = GetWagonInventoryMaxWeight(Player.PlayerData.citizenid, wagon.id, wagon.model)
    if not MoveWagonToStableIfOver(Player, wagon.id, wagon.model) then return end

    exports['rsg-inventory']:OpenInventory(src, 'wagon_' .. wagon.id, {
        label = wagon.name .. ' Storage',
        maxweight = maxWeight,
        slots = wagonConfig.slots,
    })
end)

RegisterSqlCallback('nt_stables:server:getStableInventory', function(source, stableName)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    return GetStableInventoryTransferData(Player)
end)

RegisterSqlCallback('nt_stables:server:transferStableInventory', function(source, stableName, destinationType, selectedSlots)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not IsNearStableNpc(source, stableName) or type(selectedSlots) ~= 'table' then
        return { success = false, message = 'The stable inventory could not be accessed.' }
    end
    local citizenid = Player.PlayerData.citizenid
    if inventoryTransfers[citizenid] then return { success = false, message = 'An inventory transfer is already in progress.' } end
    inventoryTransfers[citizenid] = true

    local data = GetStableInventoryTransferData(Player)
    local destination = destinationType == 'horse' and data.horse or destinationType == 'wagon' and data.wagon
    if not destination then
        inventoryTransfers[citizenid] = nil
        return { success = false, message = 'That active inventory is not available.' }
    end

    local stableId = GetStableInventoryId(citizenid)
    local stableInventory = exports['rsg-inventory']:GetInventory(stableId)
    local selected = {}
    local selectedWeight = 0
    local selectedSlotIds = {}
    for _, slot in ipairs(selectedSlots) do
        slot = tonumber(slot)
        local item = slot and (stableInventory.items[slot] or stableInventory.items[tostring(slot)])
        if not item or selectedSlotIds[slot] then
            inventoryTransfers[citizenid] = nil
            return { success = false, message = 'The stable inventory changed. Please select the items again.' }
        end
        selectedSlotIds[slot] = true
        selected[#selected + 1] = item
        selectedWeight = selectedWeight + (item.weight * item.amount)
    end
    if #selected == 0 then
        inventoryTransfers[citizenid] = nil
        return { success = false, message = 'Select at least one item.' }
    end
    if #selected > destination.freeSlots or destination.currentWeight + selectedWeight > destination.maxWeight then
        inventoryTransfers[citizenid] = nil
        return { success = false, message = 'The selected items will not fit in that inventory.' }
    end

    local moved = {}
    for _, item in ipairs(selected) do
        local removed = exports['rsg-inventory']:RemoveItem(stableId, item.name, item.amount, item.slot, 'stable inventory transfer')
        if removed and exports['rsg-inventory']:AddItem(destination.identifier, item.name, item.amount, nil, item.info, 'stable inventory transfer') then
            moved[#moved + 1] = item
        else
            if removed then exports['rsg-inventory']:AddItem(stableId, item.name, item.amount, item.slot, item.info, 'stable inventory rollback') end
            for _, movedItem in ipairs(moved) do
                exports['rsg-inventory']:RemoveItem(destination.identifier, movedItem.name, movedItem.amount, nil, 'stable inventory rollback')
                exports['rsg-inventory']:AddItem(stableId, movedItem.name, movedItem.amount, movedItem.slot, movedItem.info, 'stable inventory rollback')
            end
            inventoryTransfers[citizenid] = nil
            return { success = false, message = 'The item transfer failed and was rolled back.' }
        end
    end

    exports['rsg-inventory']:SaveStash(stableId)
    exports['rsg-inventory']:SaveStash(destination.identifier)
    ResizeStableInventory(citizenid)
    inventoryTransfers[citizenid] = nil
    data = GetStableInventoryTransferData(Player)
    data.success = true
    return data
end)

RegisterNetEvent('rsg-inventory:server:closeInventory', function(identifier)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or identifier ~= GetStableInventoryId(Player.PlayerData.citizenid) then return end

    SetTimeout(0, function()
        ResizeStableInventory(Player.PlayerData.citizenid)
    end)
end)

local function AwardHorseTraining(src, citizenid, horse, xp)
    local oldXP = math.min(ConfigStables.Training.MaximumXP, tonumber(horse.horsexp) or 0)
    if oldXP >= ConfigStables.Training.MaximumXP then return end

    local oldLevel = GetTrainingLevel(oldXP)
    local newXP = math.min(ConfigStables.Training.MaximumXP, oldXP + xp)
    MySQL.update.await('UPDATE nt_stable_horses SET horsexp = ? WHERE id = ? AND citizenid = ?', {
        newXP,
        horse.id,
        citizenid,
    })

    local newLevel = GetTrainingLevel(newXP)
    TriggerClientEvent('nt_stables:client:horseTrainingAwarded', src, horse.id, newXP,
        ('%s gained %d training XP.'):format(horse.name, newXP - oldXP),
        newLevel > oldLevel and ('%s reached training level %d.'):format(horse.name, newLevel) or nil
    )
end

RegisterSqlEvent('nt_stables:server:addHorseTraining', function(src, method)
    local Player = RSGCore.Functions.GetPlayer(src)
    local xp = method == 'riding' and ConfigStables.Training.RidingXP or method == 'leading' and ConfigStables.Training.LeadingXP
    if not Player or not xp then return end

    trainingAwards[src] = trainingAwards[src] or {}
    local now = os.time()
    if now - (trainingAwards[src][method] or 0) < ConfigStables.Training.AwardTime - 5 then return end

    local horse = MySQL.single.await("SELECT id, name, horsexp FROM nt_stable_horses WHERE citizenid = ? AND active = ? AND location = 'stable'", {
        Player.PlayerData.citizenid,
        1,
    })
    if not horse then return end

    trainingAwards[src][method] = now
    AwardHorseTraining(src, Player.PlayerData.citizenid, horse, xp)
end)

RegisterSqlEvent('nt_stables:server:addWagonTraining', function(src, wagonId, horseIds)
    local Player = RSGCore.Functions.GetPlayer(src)
    wagonId = tonumber(wagonId)
    if not Player or not wagonId or type(horseIds) ~= 'table' or #horseIds > 4 or GetActiveWagonId(Player) ~= wagonId then return end

    local attachedHorses = {}
    for _, horseId in ipairs(horseIds) do
        horseId = tonumber(horseId)
        if horseId then attachedHorses[horseId] = true end
    end

    trainingAwards[src] = trainingAwards[src] or {}
    local now = os.time()
    if now - (trainingAwards[src].wagon or 0) < ConfigStables.Training.AwardTime - 5 then return end

    local horses = MySQL.query.await([[SELECT horses.id, horses.name, horses.horsexp
        FROM nt_stable_wagon_horses assignments
        INNER JOIN nt_stable_horses horses ON horses.id = assignments.horse_id
        WHERE assignments.wagon_id = ? AND assignments.citizenid = ? AND horses.citizenid = ?]], {
        wagonId,
        Player.PlayerData.citizenid,
        Player.PlayerData.citizenid,
    })
    for index = #horses, 1, -1 do
        if not attachedHorses[tonumber(horses[index].id)] then
            table.remove(horses, index)
        end
    end

    local xp = ConfigStables.Training.WagonXP[#horses]
    if not xp then return end

    trainingAwards[src].wagon = now
    for _, horse in ipairs(horses) do
        AwardHorseTraining(src, Player.PlayerData.citizenid, horse, xp)
    end
end)

RegisterSqlEvent('nt_stables:server:addHorseCareTraining', function(src, action)
    local Player = RSGCore.Functions.GetPlayer(src)
    local xp = ConfigStables.Training.CareXP[action]
    if not Player or not xp then return end

    local horse = MySQL.single.await("SELECT id, name, horsexp FROM nt_stable_horses WHERE citizenid = ? AND active = ? AND location = 'stable'", {
        Player.PlayerData.citizenid,
        1,
    })
    if not horse then return end

    horseCareCooldowns[src] = horseCareCooldowns[src] or {}
    horseCareCooldowns[src][horse.id] = horseCareCooldowns[src][horse.id] or {}
    local now = os.time()
    if now - (horseCareCooldowns[src][horse.id][action] or 0) < ConfigStables.Training.CareCooldown then return end

    horseCareCooldowns[src][horse.id][action] = now
    AwardHorseTraining(src, Player.PlayerData.citizenid, horse, xp)
end)

RegisterSqlEvent('nt_stables:server:horseFailedRevive', function(src, horseId)
    local Player = RSGCore.Functions.GetPlayer(src)
    horseId = tonumber(horseId)
    if not Player or not horseId then return end

    local citizenid = Player.PlayerData.citizenid
    local horse = MySQL.single.await("SELECT id, name, active FROM nt_stable_horses WHERE id = ? AND citizenid = ? AND location = 'stable'", {
        horseId,
        citizenid,
    })
    if not horse then return end

    local deleted = MySQL.transaction.await({
        {
            query = 'DELETE FROM nt_stable_wagon_horses WHERE horse_id = ? AND citizenid = ?',
            values = { horseId, citizenid },
        },
        {
            query = "DELETE FROM nt_stable_horses WHERE id = ? AND citizenid = ? AND location = 'stable'",
            values = { horseId, citizenid },
        },
    })
    if not deleted then return end

    if horse.active == 1 or horse.active == true then
        Player.Functions.SetMetaData('stable_active_horse', false)
    end
    ClearIncompleteActiveWagon(Player)
    TriggerClientEvent('ox_lib:notify', src, {
        title = horse.name .. ' has permanently died.',
        type = 'error',
        duration = 10000,
    })
end)

RSGCore.Functions.CreateUseableItem('horse_reviver', function(source)
    TriggerClientEvent('nt_stables:client:useHorseReviver', source)
end)

RegisterNetEvent('nt_stables:server:removeHorseReviver', function()
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    if Player.Functions.RemoveItem('horse_reviver', 1) then
        TriggerClientEvent('rsg-inventory:client:ItemBox', source, RSGCore.Shared.Items.horse_reviver, 'remove')
    end
end)

RegisterSqlEvent('nt_stables:server:wagonDestroyed', function(src, wagonId)
    local Player = RSGCore.Functions.GetPlayer(src)
    wagonId = tonumber(wagonId)
    if not Player or not wagonId or GetActiveWagonId(Player) ~= wagonId then return end

    local wagon = MySQL.single.await('SELECT id, model FROM nt_stable_wagons WHERE id = ? AND citizenid = ?', {
        wagonId,
        Player.PlayerData.citizenid,
    })
    if not wagon then
        return
    end

    MySQL.update.await('UPDATE nt_stable_wagons SET needs_repair = 1 WHERE id = ? AND citizenid = ?', {
        wagonId,
        Player.PlayerData.citizenid,
    })
    MoveInventoryToStable(Player, 'wagon_' .. wagonId, 'Wagon cargo', 'The wagon was destroyed.')
    if GetActiveWagonId(Player) == wagonId then Player.Functions.SetMetaData('stable_active_wagon', false) end
end)

AddEventHandler('playerDropped', function()
    local src = source
    trainingAwards[src] = nil
    horseCareCooldowns[src] = nil
end)
