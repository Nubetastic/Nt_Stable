local RSGCore = exports['rsg-core']:GetCoreObject()
local HorseStats = lib.load('shared.horse_stats')
local auctionLocks = {}

local function RoundMoney(value)
    return math.floor(((tonumber(value) or 0) * 100) + 0.5) / 100
end

local function DecodeHorse(data)
    if type(data) == 'table' then return data end
    local success, horse = pcall(json.decode, data or '')
    return success and horse or nil
end

local function GetCharacterName(Player)
    local info = Player.PlayerData.charinfo or {}
    return ((info.firstname or '') .. ' ' .. (info.lastname or '')):match('^%s*(.-)%s*$')
end

local function GetSlots(Player)
    local stored = Player.PlayerData.metadata.stable_slots
    if type(stored) ~= 'table' then return Config.StableSlots.Horse.DefaultSlots end
    return math.max(Config.StableSlots.Horse.DefaultSlots, math.floor(tonumber(stored.horse) or 0))
end

local function AddFunds(citizenid, amount, reason, listingId)
    amount = RoundMoney(amount)
    if amount <= 0 then return end
    MySQL.insert.await([[INSERT INTO nt_stable_auction_funds (citizenid, amount, reason, listing_id)
        VALUES (?, ?, ?, ?)]], { citizenid, amount, reason, listingId })
end

local function BuildHorse(horse)
    local base, stats, level = HorseStats.Calculate(horse)
    if not base then return end

    local modifiers = {}
    if horse.wild == 1 or horse.wild == true or horse.wild == '1' then
        local decoded = DecodeHorse(horse.stat_modifiers)
        modifiers = decoded and decoded.modifiers or {}
        if modifiers.strength == nil and modifiers.carry ~= nil then modifiers.strength = modifiers.carry end
    end

    horse.breed = base.breed
    horse.level = level
    horse.stats = stats
    horse.carryWeight = HorseStats.GetCarryWeight(stats.strength)
    horse.pullWeight = HorseStats.GetPullWeight(stats.strength)
    horse.wildModifiers = modifiers
    return horse
end

local function FinishExpiredListing(listing)
    if auctionLocks[listing.id] then return end
    auctionLocks[listing.id] = true

    local changed = MySQL.update.await([[UPDATE nt_stable_horse_listings SET status = ?, completed_at = NOW()
        WHERE id = ? AND status = 'active' AND expires_at <= NOW()]], {
        listing.highest_bidder and 'sold' or 'expired', listing.id,
    })

    if changed and changed > 0 then
        local recipient = listing.highest_bidder or listing.seller_citizenid
        local reason = listing.highest_bidder and 'auction_won' or 'expired'
        local receivingId = MySQL.insert.await([[INSERT INTO nt_stable_horse_receiving
            (listing_id, recipient_citizenid, reason, horse_data) VALUES (?, ?, ?, ?)]], {
            listing.id, recipient, reason, listing.horse_data,
        })
        if not receivingId then
            MySQL.update.await("UPDATE nt_stable_horse_listings SET status = 'active', completed_at = NULL WHERE id = ?", { listing.id })
        elseif listing.highest_bidder then
            local cut = RoundMoney((tonumber(listing.current_bid) or 0) * (Config.HorseAuction.StableCutPercent / 100))
            AddFunds(listing.seller_citizenid, (tonumber(listing.current_bid) or 0) - cut, 'auction_sale', listing.id)
        end
    end

    auctionLocks[listing.id] = nil
end

local function ProcessExpiredListings()
    local listings = MySQL.query.await([[SELECT * FROM nt_stable_horse_listings
        WHERE status = 'active' AND expires_at <= NOW()]])
    for _, listing in ipairs(listings) do FinishExpiredListing(listing) end
end

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS nt_stable_horse_listings (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        seller_citizenid VARCHAR(50) NOT NULL,
        seller_name VARCHAR(100) NOT NULL,
        listing_type ENUM('direct', 'auction') NOT NULL,
        status ENUM('active', 'sold', 'expired', 'cancelled') NOT NULL DEFAULT 'active',
        price DECIMAL(12,2) NOT NULL,
        current_bid DECIMAL(12,2) NULL,
        highest_bidder VARCHAR(50) NULL,
        listing_fee DECIMAL(12,2) NOT NULL,
        horse_data LONGTEXT NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        expires_at TIMESTAMP NOT NULL,
        completed_at TIMESTAMP NULL,
        PRIMARY KEY (id), KEY status_expires (status, expires_at), KEY seller (seller_citizenid)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS nt_stable_horse_bids (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        listing_id INT UNSIGNED NOT NULL,
        bidder_citizenid VARCHAR(50) NOT NULL,
        amount DECIMAL(12,2) NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id), KEY listing_id (listing_id), KEY bidder (bidder_citizenid)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS nt_stable_horse_tracking (
        listing_id INT UNSIGNED NOT NULL,
        citizenid VARCHAR(50) NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (listing_id, citizenid), KEY citizenid (citizenid)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS nt_stable_horse_receiving (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        listing_id INT UNSIGNED NOT NULL,
        recipient_citizenid VARCHAR(50) NOT NULL,
        reason VARCHAR(30) NOT NULL,
        horse_data LONGTEXT NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        received_at TIMESTAMP NULL,
        PRIMARY KEY (id), UNIQUE KEY listing_recipient (listing_id, recipient_citizenid),
        KEY recipient (recipient_citizenid, received_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS nt_stable_auction_funds (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        citizenid VARCHAR(50) NOT NULL,
        amount DECIMAL(12,2) NOT NULL,
        reason VARCHAR(30) NOT NULL,
        listing_id INT UNSIGNED NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        collected_at TIMESTAMP NULL,
        PRIMARY KEY (id), KEY citizen_funds (citizenid, collected_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    ProcessExpiredListings()
    while true do
        Wait(Config.HorseAuction.ExpirationInterval * 1000)
        ProcessExpiredListings()
    end
end)

lib.callback.register('nt_stables:server:getAuctionHome', function(source)
    ProcessExpiredListings()
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    return {
        selling = MySQL.scalar.await("SELECT COUNT(*) FROM nt_stable_horse_listings WHERE seller_citizenid = ? AND status = 'active'", { citizenid }) or 0,
        receiving = MySQL.scalar.await('SELECT COUNT(*) FROM nt_stable_horse_receiving WHERE recipient_citizenid = ? AND received_at IS NULL', { citizenid }) or 0,
        tracking = MySQL.scalar.await([[SELECT COUNT(*) FROM nt_stable_horse_tracking tracking
            INNER JOIN nt_stable_horse_listings listings ON listings.id = tracking.listing_id
            WHERE tracking.citizenid = ? AND listings.status = 'active' AND listings.listing_type = 'auction' AND listings.expires_at > NOW()]], { citizenid }) or 0,
        funds = tonumber(MySQL.scalar.await('SELECT COALESCE(SUM(amount), 0) FROM nt_stable_auction_funds WHERE citizenid = ? AND collected_at IS NULL', { citizenid })) or 0,
    }
end)

lib.callback.register('nt_stables:server:getAuctionListings', function(source, listingType, filters)
    ProcessExpiredListings()
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or (listingType ~= 'direct' and listingType ~= 'auction') then return {} end

    filters = type(filters) == 'table' and filters or {}
    local rows = MySQL.query.await([[SELECT *, TIMESTAMPDIFF(SECOND, NOW(), expires_at) AS seconds_left FROM nt_stable_horse_listings
        WHERE status = 'active' AND listing_type = ? AND seller_citizenid <> ? AND expires_at > NOW() ORDER BY expires_at ASC]], {
        listingType, Player.PlayerData.citizenid,
    })
    local trackedRows = MySQL.query.await('SELECT listing_id FROM nt_stable_horse_tracking WHERE citizenid = ?', {
        Player.PlayerData.citizenid,
    })
    local tracked = {}
    for _, row in ipairs(trackedRows) do tracked[tonumber(row.listing_id)] = true end
    local result = {}
    for _, row in ipairs(rows) do
        local horse = BuildHorse(DecodeHorse(row.horse_data))
        local shownPrice = tonumber(row.current_bid) or tonumber(row.price) or 0
        local minimumLevel = tonumber(filters.minimumLevel)
        local maximumLevel = tonumber(filters.maximumLevel)
        local minimumPrice = tonumber(filters.minimumPrice)
        local maximumPrice = tonumber(filters.maximumPrice)
        local matches = horse
            and (not minimumLevel or horse.level >= minimumLevel)
            and (not maximumLevel or horse.level <= maximumLevel)
            and (not minimumPrice or shownPrice >= minimumPrice)
            and (not maximumPrice or shownPrice <= maximumPrice)
        for _, stat in ipairs(HorseStats.StatNames) do
            local minimum = tonumber(filters['minimum_' .. stat])
            local maximum = tonumber(filters['maximum_' .. stat])
            if horse and minimum and horse.stats[stat] < minimum then matches = false end
            if horse and maximum and horse.stats[stat] > maximum then matches = false end
        end
        if matches then
            result[#result + 1] = {
                id = row.id, listingType = row.listing_type, price = tonumber(row.price),
                currentBid = tonumber(row.current_bid), sellerName = row.seller_name,
                secondsLeft = math.max(0, tonumber(row.seconds_left) or 0), horse = horse,
                minimumBid = row.current_bid
                    and RoundMoney(tonumber(row.current_bid) + Config.HorseAuction.MinimumBidIncrease)
                    or tonumber(row.price),
                tracked = tracked[tonumber(row.id)] == true,
            }
        end
    end
    return result
end)

lib.callback.register('nt_stables:server:createAuctionListing', function(source, horseId, listingType, price, days)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end
    horseId, price, days = tonumber(horseId), RoundMoney(price), tonumber(days)
    if listingType ~= 'direct' and listingType ~= 'auction' then return { success = false, message = 'Invalid listing type.' } end
    if not days or days % 1 ~= 0 or days < Config.HorseAuction.MinimumDays or days > Config.HorseAuction.MaximumDays then
        return { success = false, message = 'Invalid listing duration.' }
    end
    if price < Config.HorseAuction.MinimumPrice or price > Config.HorseAuction.MaximumPrice then
        return { success = false, message = 'Invalid listing price.' }
    end

    local citizenid = Player.PlayerData.citizenid
    local horse = MySQL.single.await('SELECT * FROM player_horses WHERE id = ? AND citizenid = ?', { horseId, citizenid })
    if not horse then return { success = false, message = 'Horse not found.' } end
    local fee = RoundMoney(days * Config.HorseAuction.ListingFeePerDay)
    if not Player.Functions.RemoveMoney(Config.HorseAuction.MoneyType, fee) then
        return { success = false, message = ('You need $%.2f for the listing fee.'):format(fee) }
    end

    local prepared = exports[GetCurrentResourceName()]:PrepareHorseForAuction(source, horseId)
    if not prepared or not prepared.success then
        Player.Functions.AddMoney(Config.HorseAuction.MoneyType, fee)
        return prepared or { success = false, message = 'The horse could not be prepared for auction.' }
    end

    local wasActive = horse.active == 1 or horse.active == true
    local removed = MySQL.update.await('DELETE FROM player_horses WHERE id = ? AND citizenid = ?', { horseId, citizenid })
    if not removed or removed < 1 then
        Player.Functions.AddMoney(Config.HorseAuction.MoneyType, fee)
        return { success = false, message = 'The horse could not be moved to the auction.' }
    end
    MySQL.update.await('DELETE FROM nt_stable_wagon_horses WHERE horse_id = ? AND citizenid = ?', { horseId, citizenid })
    horse.active = 0
    local listingId = MySQL.insert.await([[INSERT INTO nt_stable_horse_listings
        (seller_citizenid, seller_name, listing_type, price, listing_fee, horse_data, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, FROM_UNIXTIME(?))]], {
        citizenid, GetCharacterName(Player), listingType, price, fee, json.encode(horse), os.time() + (days * 86400),
    })
    if not listingId then
        horse.citizenid = citizenid
        MySQL.insert.await([[INSERT INTO player_horses
            (id, stable, citizenid, horseid, name, horse, dirt, horsexp, components, gender, wild, stat_modifiers, appearance, active, born)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)]], {
            horse.id, horse.stable, citizenid, horse.horseid, horse.name, horse.horse, horse.dirt,
            horse.horsexp, horse.components, horse.gender, horse.wild, horse.stat_modifiers, horse.appearance, horse.born,
        })
        Player.Functions.AddMoney(Config.HorseAuction.MoneyType, fee)
        return { success = false, message = 'The listing failed and your payment was refunded.' }
    end

    return { success = true, listingId = listingId, wasActive = wasActive, clearedWagon = prepared.clearedWagon }
end)

lib.callback.register('nt_stables:server:buyAuctionHorse', function(source, listingId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end
    listingId = tonumber(listingId)
    if auctionLocks[listingId] then return { success = false, message = 'This listing is being updated.' } end
    auctionLocks[listingId] = true
    local listing = MySQL.single.await("SELECT * FROM nt_stable_horse_listings WHERE id = ? AND status = 'active' AND listing_type = 'direct' AND expires_at > NOW()", { listingId })
    if not listing or listing.seller_citizenid == Player.PlayerData.citizenid then
        auctionLocks[listingId] = nil
        return { success = false, message = 'This horse is no longer available.' }
    end
    local price = tonumber(listing.price)
    if not Player.Functions.RemoveMoney(Config.HorseAuction.MoneyType, price) then
        auctionLocks[listingId] = nil
        return { success = false, message = 'You do not have enough cash.' }
    end
    local changed = MySQL.update.await("UPDATE nt_stable_horse_listings SET status = 'sold', completed_at = NOW() WHERE id = ? AND status = 'active'", { listingId })
    if not changed or changed < 1 then
        Player.Functions.AddMoney(Config.HorseAuction.MoneyType, price)
        auctionLocks[listingId] = nil
        return { success = false, message = 'Another player bought this horse first.' }
    end
    local receivingId = MySQL.insert.await([[INSERT INTO nt_stable_horse_receiving
        (listing_id, recipient_citizenid, reason, horse_data) VALUES (?, ?, 'purchased', ?)]], {
        listingId, Player.PlayerData.citizenid, listing.horse_data,
    })
    if not receivingId then
        MySQL.update.await("UPDATE nt_stable_horse_listings SET status = 'active', completed_at = NULL WHERE id = ? AND status = 'sold'", { listingId })
        Player.Functions.AddMoney(Config.HorseAuction.MoneyType, price)
        auctionLocks[listingId] = nil
        return { success = false, message = 'The purchase failed and your payment was refunded.' }
    end
    local cut = RoundMoney(price * (Config.HorseAuction.StableCutPercent / 100))
    AddFunds(listing.seller_citizenid, price - cut, 'direct_sale', listingId)
    auctionLocks[listingId] = nil
    return { success = true }
end)

lib.callback.register('nt_stables:server:placeAuctionBid', function(source, listingId, amount)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end
    listingId, amount = tonumber(listingId), RoundMoney(amount)
    if auctionLocks[listingId] then return { success = false, message = 'This auction is being updated.' } end
    auctionLocks[listingId] = true
    local listing = MySQL.single.await("SELECT * FROM nt_stable_horse_listings WHERE id = ? AND status = 'active' AND listing_type = 'auction' AND expires_at > NOW()", { listingId })
    if not listing or listing.seller_citizenid == Player.PlayerData.citizenid then
        auctionLocks[listingId] = nil
        return { success = false, message = 'This auction is no longer available.' }
    end
    local minimum = listing.current_bid
        and RoundMoney(tonumber(listing.current_bid) + Config.HorseAuction.MinimumBidIncrease)
        or tonumber(listing.price)
    if amount < minimum or amount > Config.HorseAuction.MaximumPrice then
        auctionLocks[listingId] = nil
        return { success = false, message = ('The minimum bid is $%.2f.'):format(minimum) }
    end
    local citizenid = Player.PlayerData.citizenid
    local previousOwnBid = listing.highest_bidder == citizenid and tonumber(listing.current_bid) or 0
    local charge = RoundMoney(amount - previousOwnBid)
    if not Player.Functions.RemoveMoney(Config.HorseAuction.MoneyType, charge) then
        auctionLocks[listingId] = nil
        return { success = false, message = 'You do not have enough cash.' }
    end
    if listing.highest_bidder and listing.highest_bidder ~= citizenid then
        AddFunds(listing.highest_bidder, listing.current_bid, 'outbid_refund', listingId)
    end
    MySQL.update.await('UPDATE nt_stable_horse_listings SET current_bid = ?, highest_bidder = ? WHERE id = ? AND status = ?', {
        amount, citizenid, listingId, 'active',
    })
    MySQL.insert.await('INSERT INTO nt_stable_horse_bids (listing_id, bidder_citizenid, amount) VALUES (?, ?, ?)', {
        listingId, citizenid, amount,
    })
    MySQL.insert.await('INSERT IGNORE INTO nt_stable_horse_tracking (listing_id, citizenid) VALUES (?, ?)', {
        listingId, citizenid,
    })
    auctionLocks[listingId] = nil
    return { success = true }
end)

lib.callback.register('nt_stables:server:trackAuction', function(source, listingId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end
    listingId = tonumber(listingId)
    local listing = MySQL.single.await([[SELECT id FROM nt_stable_horse_listings
        WHERE id = ? AND seller_citizenid <> ? AND listing_type = 'auction' AND status = 'active' AND expires_at > NOW()]], {
        listingId, Player.PlayerData.citizenid,
    })
    if not listing then return { success = false, message = 'This auction is no longer available.' } end
    MySQL.insert.await('INSERT IGNORE INTO nt_stable_horse_tracking (listing_id, citizenid) VALUES (?, ?)', {
        listingId, Player.PlayerData.citizenid,
    })
    return { success = true }
end)

lib.callback.register('nt_stables:server:untrackAuction', function(source, listingId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end
    MySQL.update.await('DELETE FROM nt_stable_horse_tracking WHERE listing_id = ? AND citizenid = ?', {
        tonumber(listingId), Player.PlayerData.citizenid,
    })
    return { success = true }
end)

lib.callback.register('nt_stables:server:getTrackedAuctions', function(source)
    ProcessExpiredListings()
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return {} end
    local rows = MySQL.query.await([[SELECT listings.*, TIMESTAMPDIFF(SECOND, NOW(), listings.expires_at) AS seconds_left
        FROM nt_stable_horse_tracking tracking
        INNER JOIN nt_stable_horse_listings listings ON listings.id = tracking.listing_id
        WHERE tracking.citizenid = ? AND listings.status = 'active' AND listings.listing_type = 'auction'
            AND listings.expires_at > NOW() ORDER BY listings.expires_at ASC]], { Player.PlayerData.citizenid })
    local result = {}
    for _, row in ipairs(rows) do
        local horse = BuildHorse(DecodeHorse(row.horse_data))
        if horse then
            result[#result + 1] = {
                id = row.id, listingType = 'auction', price = tonumber(row.price), currentBid = tonumber(row.current_bid),
                sellerName = row.seller_name, secondsLeft = math.max(0, tonumber(row.seconds_left) or 0), horse = horse,
                minimumBid = row.current_bid
                    and RoundMoney(tonumber(row.current_bid) + Config.HorseAuction.MinimumBidIncrease)
                    or tonumber(row.price),
                tracked = true,
            }
        end
    end
    return result
end)

lib.callback.register('nt_stables:server:getHeldHorses', function(source)
    ProcessExpiredListings()
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    local sellingRows = MySQL.query.await("SELECT *, TIMESTAMPDIFF(SECOND, NOW(), expires_at) AS seconds_left FROM nt_stable_horse_listings WHERE seller_citizenid = ? AND status = 'active' ORDER BY expires_at", { citizenid })
    local receivingRows = MySQL.query.await('SELECT * FROM nt_stable_horse_receiving WHERE recipient_citizenid = ? AND received_at IS NULL ORDER BY created_at', { citizenid })
    local selling, receiving = {}, {}
    for _, row in ipairs(sellingRows) do
        selling[#selling + 1] = { id = row.id, listingType = row.listing_type, price = tonumber(row.price), currentBid = tonumber(row.current_bid), secondsLeft = math.max(0, tonumber(row.seconds_left) or 0), horse = BuildHorse(DecodeHorse(row.horse_data)) }
    end
    for _, row in ipairs(receivingRows) do
        receiving[#receiving + 1] = { id = row.id, reason = row.reason, horse = BuildHorse(DecodeHorse(row.horse_data)) }
    end
    return {
        selling = selling, receiving = receiving,
        funds = tonumber(MySQL.scalar.await('SELECT COALESCE(SUM(amount), 0) FROM nt_stable_auction_funds WHERE citizenid = ? AND collected_at IS NULL', { citizenid })) or 0,
    }
end)

lib.callback.register('nt_stables:server:cancelAuctionListing', function(source, listingId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end
    listingId = tonumber(listingId)
    if auctionLocks[listingId] then return { success = false, message = 'This listing is being updated.' } end
    auctionLocks[listingId] = true
    local listing = MySQL.single.await("SELECT * FROM nt_stable_horse_listings WHERE id = ? AND seller_citizenid = ? AND status = 'active'", { listingId, Player.PlayerData.citizenid })
    if not listing then
        auctionLocks[listingId] = nil
        return { success = false, message = 'This listing can no longer be cancelled.' }
    end
    local changed = MySQL.update.await("UPDATE nt_stable_horse_listings SET status = 'cancelled', completed_at = NOW() WHERE id = ? AND status = 'active'", { listingId })
    if changed and changed > 0 then
        local receivingId = MySQL.insert.await([[INSERT INTO nt_stable_horse_receiving
            (listing_id, recipient_citizenid, reason, horse_data) VALUES (?, ?, 'cancelled', ?)]], {
            listingId, Player.PlayerData.citizenid, listing.horse_data,
        })
        if not receivingId then
            MySQL.update.await("UPDATE nt_stable_horse_listings SET status = 'active', completed_at = NULL WHERE id = ? AND status = 'cancelled'", { listingId })
            auctionLocks[listingId] = nil
            return { success = false, message = 'The horse could not be returned. The listing remains active.' }
        end
        if listing.highest_bidder then AddFunds(listing.highest_bidder, listing.current_bid, 'cancelled_refund', listingId) end
    end
    auctionLocks[listingId] = nil
    return { success = changed and changed > 0 }
end)

lib.callback.register('nt_stables:server:receiveAuctionHorse', function(source, receiveId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end
    receiveId = tonumber(receiveId)
    if auctionLocks['receive_' .. tostring(receiveId)] then return { success = false, message = 'This horse is being received.' } end
    auctionLocks['receive_' .. tostring(receiveId)] = true
    local citizenid = Player.PlayerData.citizenid
    local held = MySQL.single.await('SELECT * FROM nt_stable_horse_receiving WHERE id = ? AND recipient_citizenid = ? AND received_at IS NULL', { receiveId, citizenid })
    if not held then
        auctionLocks['receive_' .. tostring(receiveId)] = nil
        return { success = false, message = 'Horse not found.' }
    end
    local count = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM player_horses WHERE citizenid = ?', { citizenid })) or 0
    if count >= GetSlots(Player) then
        auctionLocks['receive_' .. tostring(receiveId)] = nil
        return { success = false, message = 'You need an empty horse slot.' }
    end
    local horse = DecodeHorse(held.horse_data)
    local claimed = MySQL.update.await('UPDATE nt_stable_horse_receiving SET received_at = NOW() WHERE id = ? AND received_at IS NULL', { receiveId })
    if not claimed or claimed < 1 then
        auctionLocks['receive_' .. tostring(receiveId)] = nil
        return { success = false, message = 'This horse has already been received.' }
    end
    local inserted = MySQL.insert.await([[INSERT INTO player_horses
        (stable, citizenid, horseid, name, horse, dirt, horsexp, components, gender, wild, stat_modifiers, appearance, active, born)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)]], {
        horse.stable, citizenid, horse.horseid, horse.name, horse.horse, horse.dirt, horse.horsexp,
        horse.components, horse.gender, horse.wild, horse.stat_modifiers, horse.appearance, horse.born,
    })
    if not inserted then
        MySQL.update.await('UPDATE nt_stable_horse_receiving SET received_at = NULL WHERE id = ?', { receiveId })
        auctionLocks['receive_' .. tostring(receiveId)] = nil
        return { success = false, message = 'The horse could not be added to your stable.' }
    end
    auctionLocks['receive_' .. tostring(receiveId)] = nil
    return { success = true, horseId = inserted }
end)

lib.callback.register('nt_stables:server:collectAuctionFunds', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end
    local citizenid = Player.PlayerData.citizenid
    local lockId = 'funds_' .. citizenid
    if auctionLocks[lockId] then return { success = false, message = 'Your auction funds are being collected.' } end
    auctionLocks[lockId] = true
    local amount = tonumber(MySQL.scalar.await('SELECT COALESCE(SUM(amount), 0) FROM nt_stable_auction_funds WHERE citizenid = ? AND collected_at IS NULL', { citizenid })) or 0
    if amount <= 0 then
        auctionLocks[lockId] = nil
        return { success = false, message = 'You have no auction funds to collect.' }
    end
    local changed = MySQL.update.await('UPDATE nt_stable_auction_funds SET collected_at = NOW() WHERE citizenid = ? AND collected_at IS NULL', { citizenid })
    if not changed or changed < 1 then
        auctionLocks[lockId] = nil
        return { success = false, message = 'Auction funds could not be collected.' }
    end
    Player.Functions.AddMoney(Config.HorseAuction.MoneyType, amount)
    auctionLocks[lockId] = nil
    return { success = true, amount = amount }
end)
