local RSGCore = exports['rsg-core']:GetCoreObject()
local HorseStats = lib.load('shared.horse_stats')
local operationSequence = 0

local function RoundMoney(value)
    return math.floor(((tonumber(value) or 0) * 100) + 0.5) / 100
end

local function DecodeData(data)
    if type(data) == 'table' then return data end
    local success, decoded = pcall(json.decode, data or '')
    return success and decoded or nil
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

local function BuildHorse(horse)
    local base, stats, level, maximumStats = HorseStats.Calculate(horse)
    if not base then return end

    local modifiers = {}
    if horse.wild == 1 or horse.wild == true or horse.wild == '1' then
        local decoded = DecodeData(horse.stat_modifiers)
        modifiers = decoded and decoded.modifiers or {}
        if modifiers.strength == nil and modifiers.carry ~= nil then modifiers.strength = modifiers.carry end
    end

    horse.breed = base.breed
    horse.level = level
    horse.stats = stats
    horse.maximumStats = maximumStats
    horse.maximumStat = HorseStats.MaximumRank
    horse.carryWeight = HorseStats.GetCarryWeight(stats.strength)
    horse.pullWeight = HorseStats.GetPullWeight(stats.strength)
    horse.wildModifiers = modifiers
    return horse
end

local function NewOperation(operationType, citizenid, relatedId, amount, step)
    operationSequence = operationSequence + 1
    local operationId = ('%s:%s:%s:%s:%s'):format(operationType, citizenid, os.time(), GetGameTimer(), operationSequence)
    local inserted = MySQL.insert.await([[INSERT INTO nt_stable_operations
        (operation_id, operation_type, citizenid, related_id, amount, state, step)
        VALUES (?, ?, ?, ?, ?, 'pending', ?)]], {
        operationId, operationType, citizenid, relatedId, amount, step,
    })
    return inserted and operationId or nil
end

local function UpdateOperation(operationId, state, step, context)
    MySQL.update.await([[UPDATE nt_stable_operations SET state = ?, step = ?, context = ?
        WHERE operation_id = ?]], { state, step, context and json.encode(context) or nil, operationId })
end

local function FinishOperation(operationId)
    MySQL.update.await('DELETE FROM nt_stable_operations WHERE operation_id = ?', { operationId })
end

local function AddFundsQuery(citizenid, amount, reason, listingId)
    return {
        query = [[INSERT INTO nt_stable_auction_funds (citizenid, amount, reason, listing_id)
            VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE amount = amount + VALUES(amount)]],
        values = { citizenid, RoundMoney(amount), reason, listingId },
    }
end

local function TryPayFund(citizenid, listingId, reason)
    local Player
    for _, playerId in ipairs(GetPlayers()) do
        local onlinePlayer = RSGCore.Functions.GetPlayer(tonumber(playerId))
        if onlinePlayer and onlinePlayer.PlayerData.citizenid == citizenid then
            Player = onlinePlayer
            break
        end
    end
    if not Player then return false end

    local fund = MySQL.single.await([[SELECT id, amount FROM nt_stable_auction_funds
        WHERE citizenid = ? AND listing_id = ? AND reason = ?]], { citizenid, listingId, reason })
    if not fund then return true end

    local operationId = NewOperation('auction_fund_payment', citizenid, listingId, fund.amount, 'money_add')
    if not operationId then return false end
    local added = Player.Functions.AddMoney(Config.HorseAuction.MoneyType, tonumber(fund.amount))
    if added == false then
        UpdateOperation(operationId, 'needs_review', 'money_add_failed', { fund_id = fund.id })
        return false
    end

    local deleted = MySQL.update.await('DELETE FROM nt_stable_auction_funds WHERE id = ?', { fund.id })
    if deleted ~= 1 then
        UpdateOperation(operationId, 'needs_review', 'fund_cleanup_failed', { fund_id = fund.id })
        return false
    end
    FinishOperation(operationId)
    return true
end

local LISTING_SELECT = [[SELECT listings.id AS listing_id, listings.horse_id,
    listings.seller_citizenid, listings.seller_name, listings.listing_type, listings.status,
    listings.price, listings.current_bid, listings.highest_bidder, listings.recipient_citizenid,
    listings.claim_reason, listings.expires_at,
    horses.id, horses.horseid, horses.citizenid, horses.name, horses.horse, horses.horsexp,
    horses.components, horses.gender, horses.wild, horses.stat_modifiers, horses.appearance,
    horses.active, horses.location,
    TIMESTAMPDIFF(SECOND, NOW(), listings.expires_at) AS seconds_left
    FROM nt_stable_horse_listings listings
    INNER JOIN nt_stable_horses horses ON horses.id = listings.horse_id ]]

local function FormatListing(row, tracked)
    local horse = BuildHorse({
        id = tonumber(row.id), horseid = row.horseid, citizenid = row.citizenid,
        name = row.name, horse = row.horse, horsexp = tonumber(row.horsexp),
        components = row.components, gender = row.gender, wild = row.wild,
        stat_modifiers = row.stat_modifiers, appearance = row.appearance,
        active = row.active, location = row.location,
    })
    if not horse then return end

    return {
        id = tonumber(row.listing_id),
        listingType = row.listing_type,
        price = tonumber(row.price),
        currentBid = tonumber(row.current_bid),
        sellerName = row.seller_name,
        secondsLeft = math.max(0, tonumber(row.seconds_left) or 0),
        horse = horse,
        minimumBid = row.current_bid
            and RoundMoney(tonumber(row.current_bid) + Config.HorseAuction.MinimumBidIncrease)
            or tonumber(row.price),
        tracked = tracked == true,
    }
end

local function FinishExpiredListing(listing)
    if listing.highest_bidder then
        local amount = tonumber(listing.current_bid) or 0
        local cut = RoundMoney(amount * (Config.HorseAuction.StableCutPercent / 100))
        return MySQL.transaction.await({
            {
                query = [[UPDATE nt_stable_horse_listings SET status = 'awaiting_claim',
                    recipient_citizenid = ?, claim_reason = 'auction_won'
                    WHERE id = ? AND status = 'active' AND expires_at <= NOW()]],
                values = { listing.highest_bidder, listing.id },
            },
            {
                query = [[UPDATE nt_stable_horses SET citizenid = ?, active = 0
                    WHERE id = ? AND citizenid = ? AND location = 'auction']],
                values = { listing.highest_bidder, listing.horse_id, listing.seller_citizenid },
            },
            AddFundsQuery(listing.seller_citizenid, amount - cut, 'auction_sale', listing.id),
        })
    end

    return MySQL.transaction.await({
        {
            query = [[UPDATE nt_stable_horse_listings SET status = 'awaiting_claim',
                recipient_citizenid = ?, claim_reason = 'listing_expired'
                WHERE id = ? AND status = 'active' AND expires_at <= NOW()]],
            values = { listing.seller_citizenid, listing.id },
        },
    })
end

local function ProcessExpiredListings()
    local listings = MySQL.query.await([[SELECT * FROM nt_stable_horse_listings
        WHERE status = 'active' AND expires_at <= NOW()]])
    for _, listing in ipairs(listings) do
        local success = FinishExpiredListing(listing)
        if not success then
            LogSqlError('expire_auction_listing', listing.seller_citizenid, listing.horse_id,
                'sql_transaction', 'Transaction failed', 'The listing remains unresolved for review.')
        end
    end
end

CreateThread(function()
    Wait(1000)
    while true do
        sqlAction('process_expired_auctions', 0, ProcessExpiredListings)
        Wait(Config.HorseAuction.ExpirationInterval * 1000)
    end
end)

RegisterSqlCallback('nt_stables:server:getAuctionHome', function(source)
    ProcessExpiredListings()
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    return {
        selling = MySQL.scalar.await([[SELECT COUNT(*) FROM nt_stable_horse_listings
            WHERE seller_citizenid = ? AND status = 'active']], { citizenid }) or 0,
        receiving = MySQL.scalar.await([[SELECT COUNT(*) FROM nt_stable_horse_listings
            WHERE recipient_citizenid = ? AND status = 'awaiting_claim']], { citizenid }) or 0,
        tracking = MySQL.scalar.await([[SELECT COUNT(*) FROM nt_stable_horse_tracking tracking
            INNER JOIN nt_stable_horse_listings listings ON listings.id = tracking.listing_id
            WHERE tracking.citizenid = ? AND listings.status = 'active'
                AND listings.listing_type = 'auction' AND listings.expires_at > NOW()]], { citizenid }) or 0,
        funds = tonumber(MySQL.scalar.await([[SELECT COALESCE(SUM(amount), 0)
            FROM nt_stable_auction_funds WHERE citizenid = ?]], { citizenid })) or 0,
    }
end)

RegisterSqlCallback('nt_stables:server:getAuctionListings', function(source, listingType, filters)
    ProcessExpiredListings()
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or (listingType ~= 'direct' and listingType ~= 'auction') then return {} end

    filters = type(filters) == 'table' and filters or {}
    local rows = MySQL.query.await(LISTING_SELECT .. [[WHERE listings.status = 'active'
        AND listings.listing_type = ? AND listings.seller_citizenid <> ?
        AND listings.expires_at > NOW() ORDER BY listings.expires_at ASC]], {
        listingType, Player.PlayerData.citizenid,
    })
    local trackedRows = MySQL.query.await('SELECT listing_id FROM nt_stable_horse_tracking WHERE citizenid = ?', {
        Player.PlayerData.citizenid,
    })
    local tracked = {}
    for _, row in ipairs(trackedRows) do tracked[tonumber(row.listing_id)] = true end

    local result = {}
    for _, row in ipairs(rows) do
        local listing = FormatListing(row, tracked[tonumber(row.listing_id)])
        local horse = listing and listing.horse
        local shownPrice = tonumber(row.current_bid) or tonumber(row.price) or 0
        local matches = horse
            and (not tonumber(filters.minimumLevel) or horse.level >= tonumber(filters.minimumLevel))
            and (not tonumber(filters.maximumLevel) or horse.level <= tonumber(filters.maximumLevel))
            and (not tonumber(filters.minimumPrice) or shownPrice >= tonumber(filters.minimumPrice))
            and (not tonumber(filters.maximumPrice) or shownPrice <= tonumber(filters.maximumPrice))
        for _, stat in ipairs(HorseStats.StatNames) do
            local minimum = tonumber(filters['minimum_' .. stat])
            local maximum = tonumber(filters['maximum_' .. stat])
            if horse and minimum and horse.stats[stat] < minimum then matches = false end
            if horse and maximum and horse.stats[stat] > maximum then matches = false end
        end
        if matches then result[#result + 1] = listing end
    end
    return result
end)

RegisterSqlCallback('nt_stables:server:createAuctionListing', function(source, horseId, listingType, price, days)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end
    horseId, price, days = tonumber(horseId), RoundMoney(price), tonumber(days)
    if listingType ~= 'direct' and listingType ~= 'auction' then
        return { success = false, message = 'Invalid listing type.' }
    end
    if not days or days % 1 ~= 0 or days < Config.HorseAuction.MinimumDays or days > Config.HorseAuction.MaximumDays then
        return { success = false, message = 'Invalid listing duration.' }
    end
    if price < Config.HorseAuction.MinimumPrice or price > Config.HorseAuction.MaximumPrice then
        return { success = false, message = 'Invalid listing price.' }
    end

    local citizenid = Player.PlayerData.citizenid
    local horse = MySQL.single.await([[SELECT * FROM nt_stable_horses
        WHERE id = ? AND citizenid = ? AND location = 'stable']], { horseId, citizenid })
    if not horse then return { success = false, message = 'Horse not found.' } end

    local fee = RoundMoney(days * Config.HorseAuction.ListingFeePerDay)
    local operationId = NewOperation('auction_listing_fee', citizenid, horseId, fee, 'money_remove')
    if not operationId then return { success = false, message = 'The listing could not be started.' } end
    if not Player.Functions.RemoveMoney(Config.HorseAuction.MoneyType, fee) then
        FinishOperation(operationId)
        return { success = false, message = ('You need $%.2f for the listing fee.'):format(fee) }
    end

    local prepared = exports[GetCurrentResourceName()]:PrepareHorseForAuction(source, horseId)
    if not prepared or not prepared.success then
        Player.Functions.AddMoney(Config.HorseAuction.MoneyType, fee)
        FinishOperation(operationId)
        return prepared or { success = false, message = 'The horse could not be prepared for auction.' }
    end

    UpdateOperation(operationId, 'pending', 'sql_commit')
    local success = MySQL.transaction.await({
        {
            query = [[INSERT INTO nt_stable_horse_listings
                (horse_id, seller_citizenid, seller_name, listing_type, price, expires_at)
                VALUES (?, ?, ?, ?, ?, FROM_UNIXTIME(?))]],
            values = { horseId, citizenid, GetCharacterName(Player), listingType, price, os.time() + (days * 86400) },
        },
        { query = 'DELETE FROM nt_stable_wagon_horses WHERE horse_id = ? AND citizenid = ?', values = { horseId, citizenid } },
        {
            query = [[UPDATE nt_stable_horses SET location = 'auction', active = 0
                WHERE id = ? AND citizenid = ? AND location = 'stable']],
            values = { horseId, citizenid },
        },
    })
    if not success then
        local refunded = Player.Functions.AddMoney(Config.HorseAuction.MoneyType, fee)
        if refunded == false then
            UpdateOperation(operationId, 'needs_review', 'money_refund_failed')
        else
            FinishOperation(operationId)
        end
        return { success = false, message = 'The listing failed and your payment was refunded.' }
    end

    local listingId = MySQL.scalar.await('SELECT id FROM nt_stable_horse_listings WHERE horse_id = ?', { horseId })
    if horse.active == 1 or horse.active == true then Player.Functions.SetMetaData('stable_active_horse', false) end
    UpdateFreeHorseStableSlots(Player)
    FinishOperation(operationId)
    return { success = true, listingId = listingId, wasActive = horse.active == 1 or horse.active == true,
        clearedWagon = prepared.clearedWagon }
end)

RegisterSqlCallback('nt_stables:server:buyAuctionHorse', function(source, listingId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end
    listingId = tonumber(listingId)
    local listing = MySQL.single.await([[SELECT * FROM nt_stable_horse_listings
        WHERE id = ? AND status = 'active' AND listing_type = 'direct' AND expires_at > NOW()]], { listingId })
    if not listing or listing.seller_citizenid == Player.PlayerData.citizenid then
        return { success = false, message = 'This horse is no longer available.' }
    end

    local price = tonumber(listing.price)
    local citizenid = Player.PlayerData.citizenid
    local operationId = NewOperation('auction_purchase', citizenid, listingId, price, 'money_remove')
    if not operationId then return { success = false, message = 'The purchase could not be started.' } end
    if not Player.Functions.RemoveMoney(Config.HorseAuction.MoneyType, price) then
        FinishOperation(operationId)
        return { success = false, message = 'You do not have enough cash.' }
    end

    local cut = RoundMoney(price * (Config.HorseAuction.StableCutPercent / 100))
    UpdateOperation(operationId, 'pending', 'sql_commit')
    local success = MySQL.transaction.await({
        {
            query = [[UPDATE nt_stable_horse_listings SET status = 'awaiting_claim',
                recipient_citizenid = ?, claim_reason = 'purchased'
                WHERE id = ? AND status = 'active']],
            values = { citizenid, listingId },
        },
        {
            query = [[UPDATE nt_stable_horses SET citizenid = ?, active = 0
                WHERE id = ? AND citizenid = ? AND location = 'auction']],
            values = { citizenid, listing.horse_id, listing.seller_citizenid },
        },
        AddFundsQuery(listing.seller_citizenid, price - cut, 'direct_sale', listingId),
    })
    if not success then
        local refunded = Player.Functions.AddMoney(Config.HorseAuction.MoneyType, price)
        if refunded == false then UpdateOperation(operationId, 'needs_review', 'money_refund_failed')
        else FinishOperation(operationId) end
        return { success = false, message = 'The purchase failed and your payment was refunded.' }
    end
    FinishOperation(operationId)
    return { success = true }
end)

RegisterSqlCallback('nt_stables:server:placeAuctionBid', function(source, listingId, amount)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end
    listingId, amount = tonumber(listingId), RoundMoney(amount)
    local listing = MySQL.single.await([[SELECT * FROM nt_stable_horse_listings
        WHERE id = ? AND status = 'active' AND listing_type = 'auction' AND expires_at > NOW()]], { listingId })
    if not listing or listing.seller_citizenid == Player.PlayerData.citizenid then
        return { success = false, message = 'This auction is no longer available.' }
    end

    local minimum = listing.current_bid
        and RoundMoney(tonumber(listing.current_bid) + Config.HorseAuction.MinimumBidIncrease)
        or tonumber(listing.price)
    if amount < minimum or amount > Config.HorseAuction.MaximumPrice then
        return { success = false, message = ('The minimum bid is $%.2f.'):format(minimum) }
    end

    local citizenid = Player.PlayerData.citizenid
    local previousOwnBid = listing.highest_bidder == citizenid and tonumber(listing.current_bid) or 0
    local charge = RoundMoney(amount - previousOwnBid)
    local operationId = NewOperation('auction_bid', citizenid, listingId, charge, 'money_remove')
    if not operationId then return { success = false, message = 'The bid could not be started.' } end
    if not Player.Functions.RemoveMoney(Config.HorseAuction.MoneyType, charge) then
        FinishOperation(operationId)
        return { success = false, message = 'You do not have enough cash.' }
    end

    local statements = {
        {
            query = [[UPDATE nt_stable_horse_listings SET current_bid = ?, highest_bidder = ?
                WHERE id = ? AND status = 'active']],
            values = { amount, citizenid, listingId },
        },
        {
            query = 'INSERT IGNORE INTO nt_stable_horse_tracking (listing_id, citizenid) VALUES (?, ?)',
            values = { listingId, citizenid },
        },
    }
    if listing.highest_bidder and listing.highest_bidder ~= citizenid then
        statements[#statements + 1] = AddFundsQuery(
            listing.highest_bidder, listing.current_bid, 'outbid_refund', listingId)
    end

    UpdateOperation(operationId, 'pending', 'sql_commit')
    local success = MySQL.transaction.await(statements)
    if not success then
        local refunded = Player.Functions.AddMoney(Config.HorseAuction.MoneyType, charge)
        if refunded == false then UpdateOperation(operationId, 'needs_review', 'money_refund_failed')
        else FinishOperation(operationId) end
        return { success = false, message = 'The bid failed and your payment was refunded.' }
    end

    FinishOperation(operationId)
    if listing.highest_bidder and listing.highest_bidder ~= citizenid then
        TryPayFund(listing.highest_bidder, listingId, 'outbid_refund')
    end
    return { success = true }
end)

RegisterSqlCallback('nt_stables:server:trackAuction', function(source, listingId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end
    listingId = tonumber(listingId)
    local listing = MySQL.single.await([[SELECT id FROM nt_stable_horse_listings
        WHERE id = ? AND seller_citizenid <> ? AND listing_type = 'auction'
            AND status = 'active' AND expires_at > NOW()]], { listingId, Player.PlayerData.citizenid })
    if not listing then return { success = false, message = 'This auction is no longer available.' } end
    MySQL.insert.await('INSERT IGNORE INTO nt_stable_horse_tracking (listing_id, citizenid) VALUES (?, ?)', {
        listingId, Player.PlayerData.citizenid,
    })
    return { success = true }
end)

RegisterSqlCallback('nt_stables:server:untrackAuction', function(source, listingId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end
    MySQL.update.await('DELETE FROM nt_stable_horse_tracking WHERE listing_id = ? AND citizenid = ?', {
        tonumber(listingId), Player.PlayerData.citizenid,
    })
    return { success = true }
end)

RegisterSqlCallback('nt_stables:server:getTrackedAuctions', function(source)
    ProcessExpiredListings()
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return {} end
    local rows = MySQL.query.await(LISTING_SELECT .. [[INNER JOIN nt_stable_horse_tracking tracking
        ON tracking.listing_id = listings.id WHERE tracking.citizenid = ?
        AND listings.status = 'active' AND listings.listing_type = 'auction'
        AND listings.expires_at > NOW() ORDER BY listings.expires_at ASC]], { Player.PlayerData.citizenid })
    local result = {}
    for _, row in ipairs(rows) do
        local listing = FormatListing(row, true)
        if listing then result[#result + 1] = listing end
    end
    return result
end)

RegisterSqlCallback('nt_stables:server:getHeldHorses', function(source)
    ProcessExpiredListings()
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    local sellingRows = MySQL.query.await(LISTING_SELECT .. [[WHERE listings.seller_citizenid = ?
        AND listings.status = 'active' ORDER BY listings.expires_at]], { citizenid })
    local receivingRows = MySQL.query.await(LISTING_SELECT .. [[WHERE listings.recipient_citizenid = ?
        AND listings.status = 'awaiting_claim' ORDER BY listings.id]], { citizenid })
    local selling, receiving = {}, {}
    for _, row in ipairs(sellingRows) do
        local listing = FormatListing(row, false)
        if listing then selling[#selling + 1] = listing end
    end
    for _, row in ipairs(receivingRows) do
        local listing = FormatListing(row, false)
        if listing then receiving[#receiving + 1] = {
            id = listing.id, reason = row.claim_reason, horse = listing.horse,
        } end
    end
    return {
        selling = selling,
        receiving = receiving,
        funds = tonumber(MySQL.scalar.await([[SELECT COALESCE(SUM(amount), 0)
            FROM nt_stable_auction_funds WHERE citizenid = ?]], { citizenid })) or 0,
    }
end)

RegisterSqlCallback('nt_stables:server:cancelAuctionListing', function(source, listingId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end
    listingId = tonumber(listingId)
    local citizenid = Player.PlayerData.citizenid
    local listing = MySQL.single.await([[SELECT * FROM nt_stable_horse_listings
        WHERE id = ? AND seller_citizenid = ? AND status = 'active']], { listingId, citizenid })
    if not listing then return { success = false, message = 'This listing can no longer be cancelled.' } end

    local statements = {
        {
            query = [[UPDATE nt_stable_horse_listings SET status = 'awaiting_claim',
                recipient_citizenid = ?, claim_reason = 'listing_cancelled'
                WHERE id = ? AND status = 'active']],
            values = { citizenid, listingId },
        },
    }
    if listing.highest_bidder then
        statements[#statements + 1] = AddFundsQuery(
            listing.highest_bidder, listing.current_bid, 'cancelled_refund', listingId)
    end
    local success = MySQL.transaction.await(statements)
    if success and listing.highest_bidder then
        TryPayFund(listing.highest_bidder, listingId, 'cancelled_refund')
    end
    return { success = success == true }
end)

RegisterSqlCallback('nt_stables:server:receiveAuctionHorse', function(source, listingId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end
    listingId = tonumber(listingId)
    local citizenid = Player.PlayerData.citizenid
    local listing = MySQL.single.await([[SELECT listings.id, listings.horse_id FROM nt_stable_horse_listings listings
        INNER JOIN nt_stable_horses horses ON horses.id = listings.horse_id
        WHERE listings.id = ? AND listings.recipient_citizenid = ? AND listings.status = 'awaiting_claim'
            AND horses.citizenid = ? AND horses.location = 'auction']], { listingId, citizenid, citizenid })
    if not listing then return { success = false, message = 'Horse not found.' } end

    local count = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM nt_stable_horses
        WHERE citizenid = ? AND location = 'stable']], { citizenid })) or 0
    if count >= GetSlots(Player) then
        return { success = false, message = 'You need a free horse slot before you can stable this horse.' }
    end

    local success = MySQL.transaction.await({
        {
            query = [[UPDATE nt_stable_horses SET location = 'stable', active = 0
                WHERE id = ? AND citizenid = ? AND location = 'auction']],
            values = { listing.horse_id, citizenid },
        },
        { query = 'DELETE FROM nt_stable_horse_listings WHERE id = ? AND status = ?', values = { listingId, 'awaiting_claim' } },
    })
    if not success then return { success = false, message = 'The horse could not be added to your stable.' } end
    UpdateFreeHorseStableSlots(Player)
    return { success = true, horseId = tonumber(listing.horse_id) }
end)

RegisterSqlCallback('nt_stables:server:collectAuctionFunds', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return { success = false, message = 'Player not found.' } end
    local citizenid = Player.PlayerData.citizenid
    local amount = tonumber(MySQL.scalar.await([[SELECT COALESCE(SUM(amount), 0)
        FROM nt_stable_auction_funds WHERE citizenid = ?]], { citizenid })) or 0
    if amount <= 0 then return { success = false, message = 'You have no auction funds to collect.' } end

    local operationId = NewOperation('collect_auction_funds', citizenid, nil, amount, 'money_add')
    if not operationId then return { success = false, message = 'Auction funds could not be collected.' } end
    local added = Player.Functions.AddMoney(Config.HorseAuction.MoneyType, amount)
    if added == false then
        UpdateOperation(operationId, 'needs_review', 'money_add_failed')
        return { success = false, message = 'Auction funds could not be collected.' }
    end

    local deleted = MySQL.update.await('DELETE FROM nt_stable_auction_funds WHERE citizenid = ?', { citizenid })
    if not deleted or deleted < 1 then
        UpdateOperation(operationId, 'needs_review', 'fund_cleanup_failed')
        return { success = false, message = 'Funds were paid, but SQL cleanup requires administrator review.' }
    end
    FinishOperation(operationId)
    return { success = true, amount = amount }
end)
