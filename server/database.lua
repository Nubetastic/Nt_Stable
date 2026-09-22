local HorseStats = lib.load('shared.horse_stats')

local SCHEMA_VERSION = 1
local queue = {}
local queueHead = 1
local queueTail = 0
local databaseReady = false
local databaseFailed = false

local function WriteSqlError(operation, citizenid, entityId, step, err, action)
    local entry = json.encode({
        time = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        operation = operation,
        citizenid = citizenid,
        entity_id = entityId,
        step = step,
        error = tostring(err),
        action = action,
    })
    local path = GetResourcePath(GetCurrentResourceName()) .. '/sqlErrors.jsonl'
    local existing = io.open(path, 'rb')
    if existing then
        local size = existing:seek('end') or 0
        existing:close()
        if size >= 1048576 then
            os.rename(path, GetResourcePath(GetCurrentResourceName())
                .. ('/sqlErrors-%s.jsonl'):format(os.date('!%Y%m%d-%H%M%S')))
        end
    end
    local file = io.open(path, 'a')
    if file then
        file:write(entry, '\n')
        file:close()
    else
        print(('[Nt_Stables] SQL error: %s'):format(entry))
    end
end

function LogSqlError(operation, citizenid, entityId, step, err, action)
    WriteSqlError(operation, citizenid, entityId, step, err, action)
end

local function RunSqlQueue()
    CreateThread(function()
        while databaseReady do
            if queueHead > queueTail then
                Wait(10)
            else
                local job = queue[queueHead]
                queue[queueHead] = nil
                queueHead = queueHead + 1
                if queueHead > queueTail then
                    queueHead = 1
                    queueTail = 0
                end

                local started = GetGameTimer()
                local success, result = pcall(job.handler)
                local duration = GetGameTimer() - started
                if duration >= 2000 then
                    print(('[Nt_Stables] Slow sqlAction %s took %sms. Queue depth: %s'):format(
                        job.name, duration, math.max(0, queueTail - queueHead + 1)))
                end

                if success then
                    job.promise:resolve(result)
                else
                    WriteSqlError(job.name, job.citizenid, job.entityId, 'sql_action', result,
                        'The action failed and the SQL queue continued.')
                    job.promise:resolve(nil)
                end
            end
        end
    end)
end

function sqlAction(name, source, handler, citizenid, entityId)
    if databaseFailed then return nil end

    local result = promise.new()
    queueTail = queueTail + 1
    queue[queueTail] = {
        name = name,
        source = source,
        citizenid = citizenid,
        entityId = entityId,
        handler = handler,
        promise = result,
        queuedAt = GetGameTimer(),
    }
    return Citizen.Await(result)
end

function RegisterSqlCallback(name, handler)
    lib.callback.register(name, function(source, ...)
        local args = table.pack(...)
        return sqlAction(name, source, function()
            return handler(source, table.unpack(args, 1, args.n))
        end)
    end)
end

function RunSqlEvent(name, source, handler)
    CreateThread(function()
        sqlAction(name, source, handler)
    end)
end

function RegisterSqlEvent(name, handler)
    RegisterNetEvent(name, function(...)
        local src = source
        local args = table.pack(...)
        RunSqlEvent(name, src, function()
            handler(src, table.unpack(args, 1, args.n))
        end)
    end)
end

function ReserveStableEntityId(citizenid, entityType)
    local changed = MySQL.update.await([[UPDATE nt_stable_entity_counter
        SET last_id = last_id + 1 WHERE id = 1]])
    if changed ~= 1 then return end

    local id = tonumber(MySQL.scalar.await('SELECT last_id FROM nt_stable_entity_counter WHERE id = 1'))
    if not id then return end
    return id, ('%s_%s_%s'):format(citizenid, entityType, id)
end

local function CreateSchema()
    MySQL.query.await([[CREATE TABLE nt_stable_schema_version (
        id TINYINT UNSIGNED NOT NULL,
        version INT UNSIGNED NOT NULL,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    MySQL.query.await([[CREATE TABLE nt_stable_entity_counter (
        id TINYINT UNSIGNED NOT NULL,
        last_id INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    MySQL.query.await([[CREATE TABLE nt_stable_horses (
        id INT UNSIGNED NOT NULL,
        horseid VARCHAR(80) NOT NULL,
        legacy_horseid VARCHAR(80) NULL,
        citizenid VARCHAR(50) NOT NULL,
        name VARCHAR(255) NOT NULL,
        horse VARCHAR(100) NOT NULL,
        horsexp INT NOT NULL DEFAULT 0,
        components LONGTEXT NOT NULL,
        gender VARCHAR(11) NOT NULL DEFAULT 'male',
        wild TINYINT(1) NOT NULL DEFAULT 0,
        stat_modifiers LONGTEXT NULL,
        appearance LONGTEXT NULL,
        active TINYINT(1) NOT NULL DEFAULT 0,
        location ENUM('stable', 'auction') NOT NULL DEFAULT 'stable',
        PRIMARY KEY (id),
        UNIQUE KEY horseid (horseid),
        KEY owner_stable (citizenid, location, active, name)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    MySQL.query.await([[CREATE TABLE nt_stable_wagons (
        id INT UNSIGNED NOT NULL,
        wagonid VARCHAR(80) NOT NULL,
        citizenid VARCHAR(50) NOT NULL,
        model VARCHAR(100) NOT NULL,
        name VARCHAR(100) NOT NULL,
        livery INT NOT NULL DEFAULT 0,
        tint INT NOT NULL DEFAULT 0,
        extras LONGTEXT NULL,
        lantern VARCHAR(100) NOT NULL DEFAULT '0',
        needs_repair TINYINT(1) NOT NULL DEFAULT 0,
        PRIMARY KEY (id),
        UNIQUE KEY wagonid (wagonid),
        KEY owner_name (citizenid, name)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    MySQL.query.await([[CREATE TABLE nt_stable_wagon_horses (
        wagon_id INT UNSIGNED NOT NULL,
        slot TINYINT UNSIGNED NOT NULL,
        horse_id INT UNSIGNED NOT NULL,
        citizenid VARCHAR(50) NOT NULL,
        PRIMARY KEY (wagon_id, slot),
        UNIQUE KEY wagon_horse (wagon_id, horse_id),
        KEY owner_wagon (citizenid, wagon_id),
        KEY owner_horse (citizenid, horse_id),
        CONSTRAINT nt_stable_assignment_wagon FOREIGN KEY (wagon_id)
            REFERENCES nt_stable_wagons (id) ON DELETE CASCADE,
        CONSTRAINT nt_stable_assignment_horse FOREIGN KEY (horse_id)
            REFERENCES nt_stable_horses (id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    MySQL.query.await([[CREATE TABLE nt_stable_horse_listings (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        horse_id INT UNSIGNED NOT NULL,
        seller_citizenid VARCHAR(50) NOT NULL,
        seller_name VARCHAR(100) NOT NULL,
        listing_type ENUM('direct', 'auction') NOT NULL,
        status ENUM('active', 'awaiting_claim') NOT NULL DEFAULT 'active',
        price DECIMAL(12,2) NOT NULL,
        current_bid DECIMAL(12,2) NULL,
        highest_bidder VARCHAR(50) NULL,
        recipient_citizenid VARCHAR(50) NULL,
        claim_reason VARCHAR(30) NULL,
        expires_at TIMESTAMP NOT NULL,
        PRIMARY KEY (id),
        UNIQUE KEY horse_id (horse_id),
        KEY status_expires (status, expires_at),
        KEY seller_status (seller_citizenid, status, expires_at),
        KEY recipient_status (recipient_citizenid, status),
        CONSTRAINT nt_stable_listing_horse FOREIGN KEY (horse_id)
            REFERENCES nt_stable_horses (id) ON DELETE RESTRICT
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    MySQL.query.await([[CREATE TABLE nt_stable_horse_tracking (
        listing_id INT UNSIGNED NOT NULL,
        citizenid VARCHAR(50) NOT NULL,
        PRIMARY KEY (listing_id, citizenid),
        KEY citizen_listing (citizenid, listing_id),
        CONSTRAINT nt_stable_tracking_listing FOREIGN KEY (listing_id)
            REFERENCES nt_stable_horse_listings (id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    MySQL.query.await([[CREATE TABLE nt_stable_auction_funds (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        citizenid VARCHAR(50) NOT NULL,
        amount DECIMAL(12,2) NOT NULL,
        reason VARCHAR(30) NOT NULL,
        listing_id INT UNSIGNED NULL,
        PRIMARY KEY (id),
        UNIQUE KEY obligation (citizenid, listing_id, reason),
        KEY citizenid (citizenid)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    MySQL.query.await([[CREATE TABLE nt_stable_operations (
        operation_id VARCHAR(160) NOT NULL,
        operation_type VARCHAR(50) NOT NULL,
        citizenid VARCHAR(50) NOT NULL,
        related_id INT UNSIGNED NULL,
        amount DECIMAL(12,2) NULL,
        state ENUM('pending', 'compensating', 'needs_review') NOT NULL DEFAULT 'pending',
        step VARCHAR(50) NOT NULL,
        context LONGTEXT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (operation_id),
        KEY unresolved (state, citizenid)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    MySQL.insert.await('INSERT INTO nt_stable_schema_version (id, version) VALUES (1, ?)', { SCHEMA_VERSION })
    MySQL.insert.await('INSERT INTO nt_stable_entity_counter (id, last_id) VALUES (1, 0)')
end

local function ValidJson(value, fallback)
    if type(value) ~= 'string' or value == '' then return fallback end
    local success = pcall(json.decode, value)
    return success and value or fallback
end

local function ImportRsgHorses()
    local tableExists = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = DATABASE() AND table_name = 'player_horses']])) or 0
    if tableExists == 0 then return {} end

    local columns = MySQL.query.await([[SELECT column_name FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'player_horses']])
    local available = {}
    for _, column in ipairs(columns) do available[column.column_name] = true end
    if not available.citizenid or not available.horse then
        print('[Nt_Stables] player_horses is missing citizenid or horse. Import skipped.')
        return {}
    end

    local order = available.id and ' ORDER BY id' or ''
    local rows = MySQL.query.await('SELECT * FROM player_horses' .. order)
    local imported = {}
    local activeCitizens = {}
    local skipped = 0

    for _, row in ipairs(rows) do
        local citizenid = row.citizenid and tostring(row.citizenid)
        local model = row.horse and tostring(row.horse):lower()
        if not citizenid or citizenid == '' or not model or model == '' then
            skipped = skipped + 1
        else
            local id, horseid = ReserveStableEntityId(citizenid, 'H')
            if not id then error('Unable to reserve an imported horse ID.') end

            local gender = row.gender == 'female' and 'female' or 'male'
            local active = (row.active == 1 or row.active == true) and not activeCitizens[citizenid]
            if active then activeCitizens[citizenid] = true end
            local horse = {
                id = id,
                horseid = horseid,
                legacy_horseid = row.horseid and tostring(row.horseid) or nil,
                citizenid = citizenid,
                name = tostring(row.name or 'Unnamed Horse'),
                horse = model,
                horsexp = tonumber(row.horsexp) or 0,
                components = ValidJson(row.components, '{}'),
                gender = gender,
                wild = row.wild == 1 or row.wild == true,
                stat_modifiers = ValidJson(row.stat_modifiers, nil),
                appearance = ValidJson(row.appearance, nil),
                active = active,
            }
            local inserted = MySQL.insert.await([[INSERT INTO nt_stable_horses
                (id, horseid, legacy_horseid, citizenid, name, horse, horsexp, components, gender,
                    wild, stat_modifiers, appearance, active, location)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'stable')]], {
                horse.id, horse.horseid, horse.legacy_horseid, horse.citizenid, horse.name, horse.horse,
                horse.horsexp, horse.components, horse.gender, horse.wild and 1 or 0,
                horse.stat_modifiers, horse.appearance, horse.active and 1 or 0,
            })
            if not inserted then error(('Unable to import horse for %s.'):format(citizenid)) end
            imported[#imported + 1] = horse
        end
    end

    print(('[Nt_Stables] RSG horse import complete. Imported: %s, skipped: %s.'):format(#imported, skipped))
    return imported
end

local function InventoryHasItems(inventory)
    return inventory and inventory.items and next(inventory.items) ~= nil
end

local function CopyLegacySaddlebags(imported)
    if #imported == 0 then return end

    local byCitizen = {}
    for _, horse in ipairs(imported) do
        byCitizen[horse.citizenid] = byCitizen[horse.citizenid] or {}
        byCitizen[horse.citizenid][#byCitizen[horse.citizenid] + 1] = horse
    end

    for citizenid, horses in pairs(byCitizen) do
        local saddleId = 'horse_saddlebag_' .. citizenid
        local stableId = 'stable_storage_' .. citizenid
        exports['rsg-inventory']:CreateInventory(saddleId, {})
        exports['rsg-inventory']:CreateInventory(stableId, {})
        local saddle = exports['rsg-inventory']:GetInventory(saddleId)
        local stable = exports['rsg-inventory']:GetInventory(stableId)

        local capacityHorse = horses[1]
        for _, horse in ipairs(horses) do
            if horse.active then
                capacityHorse = horse
                break
            end
        end
        local _, stats = HorseStats.Calculate(capacityHorse)
        local saddleWeight = stats and HorseStats.GetCarryWeight(stats.strength) * 1000 or 0
        local legacyInventories = {}
        local legacyWeight = 0
        for _, horse in ipairs(horses) do
            if horse.legacy_horseid then
                local legacyId = horse.name .. ' ' .. horse.legacy_horseid
                local legacy = exports['rsg-inventory']:GetInventory(legacyId)
                legacyInventories[tonumber(horse.id)] = { id = legacyId, inventory = legacy }
                if InventoryHasItems(legacy) then
                    legacyWeight = legacyWeight + exports['rsg-inventory']:GetTotalWeight(legacy.items)
                end
            end
        end
        local currentWeight = exports['rsg-inventory']:GetTotalWeight(saddle.items or {})
            + exports['rsg-inventory']:GetTotalWeight(stable.items or {})
        local resizeWeight = Config.StableSlots.StableOverflow.ResizeWeight * 1000
        local stableWeight = math.max(resizeWeight, math.ceil((currentWeight + legacyWeight) / resizeWeight) * resizeWeight)
        exports['rsg-inventory']:CreateInventory(saddleId, {
            label = 'Horse Saddlebag',
            maxweight = saddleWeight,
            slots = ConfigStables.Settings.SaddleBagSlots,
        })
        exports['rsg-inventory']:CreateInventory(stableId, {
            label = 'Stable Storage',
            maxweight = stableWeight,
            slots = Config.StableSlots.StableOverflow.Slots,
        })

        for _, horse in ipairs(horses) do
            if horse.legacy_horseid then
                local source = legacyInventories[tonumber(horse.id)]
                local legacyId = source.id
                local legacy = source.inventory
                for _, item in pairs(legacy and legacy.items or {}) do
                    local copied = exports['rsg-inventory']:AddItem(
                        saddleId, item.name, item.amount, nil, item.info, 'legacy saddlebag copy')
                    if not copied then
                        copied = exports['rsg-inventory']:AddItem(
                            stableId, item.name, item.amount, nil, item.info, 'legacy saddlebag overflow copy')
                    end
                    if not copied then
                        error(('Unable to copy legacy saddlebag %s for %s.'):format(legacyId, citizenid))
                    end
                end
                MySQL.update.await('UPDATE nt_stable_horses SET legacy_horseid = NULL WHERE id = ?', { horse.id })
            end
        end

        exports['rsg-inventory']:SaveStash(saddleId)
        exports['rsg-inventory']:SaveStash(stableId)
    end
end

local function CheckIntegrity()
    local duplicateHorseId = MySQL.scalar.await([[SELECT horseid FROM nt_stable_horses
        GROUP BY horseid HAVING COUNT(*) > 1 LIMIT 1]])
    local duplicateWagonId = MySQL.scalar.await([[SELECT wagonid FROM nt_stable_wagons
        GROUP BY wagonid HAVING COUNT(*) > 1 LIMIT 1]])
    local duplicateActive = MySQL.scalar.await([[SELECT citizenid FROM nt_stable_horses
        WHERE active = 1 GROUP BY citizenid HAVING COUNT(*) > 1 LIMIT 1]])
    if duplicateHorseId or duplicateWagonId or duplicateActive then
        error('Startup integrity checks found duplicate public IDs or active horses.')
    end
end

local function GetIntegrityIssues()
    local checks = {
        { 'duplicate horse public IDs', [[SELECT COUNT(*) FROM (SELECT horseid FROM nt_stable_horses GROUP BY horseid HAVING COUNT(*) > 1) duplicates]] },
        { 'duplicate wagon public IDs', [[SELECT COUNT(*) FROM (SELECT wagonid FROM nt_stable_wagons GROUP BY wagonid HAVING COUNT(*) > 1) duplicates]] },
        { 'citizens with multiple active horses', [[SELECT COUNT(*) FROM (SELECT citizenid FROM nt_stable_horses WHERE active = 1 GROUP BY citizenid HAVING COUNT(*) > 1) duplicates]] },
        { 'assignment ownership mismatches', [[SELECT COUNT(*) FROM nt_stable_wagon_horses assignments
            LEFT JOIN nt_stable_wagons wagons ON wagons.id = assignments.wagon_id
            LEFT JOIN nt_stable_horses horses ON horses.id = assignments.horse_id
            WHERE wagons.id IS NULL OR horses.id IS NULL OR assignments.citizenid <> wagons.citizenid
                OR assignments.citizenid <> horses.citizenid]] },
        { 'invalid auction horse locations', [[SELECT COUNT(*) FROM nt_stable_horse_listings listings
            LEFT JOIN nt_stable_horses horses ON horses.id = listings.horse_id
            WHERE horses.id IS NULL OR horses.location <> 'auction']] },
        { 'invalid awaiting-claim listings', [[SELECT COUNT(*) FROM nt_stable_horse_listings listings
            LEFT JOIN nt_stable_horses horses ON horses.id = listings.horse_id
            WHERE listings.status = 'awaiting_claim' AND (listings.recipient_citizenid IS NULL
                OR listings.claim_reason IS NULL OR horses.citizenid <> listings.recipient_citizenid)]] },
        { 'unresolved operations', [[SELECT COUNT(*) FROM nt_stable_operations]] },
        { 'invalid stored JSON', [[SELECT COUNT(*) FROM nt_stable_horses
            WHERE JSON_VALID(components) = 0 OR (appearance IS NOT NULL AND JSON_VALID(appearance) = 0)
                OR (stat_modifiers IS NOT NULL AND JSON_VALID(stat_modifiers) = 0)]] },
        { 'entity counter below an existing ID', [[SELECT IF(
            (SELECT last_id FROM nt_stable_entity_counter WHERE id = 1) < GREATEST(
                COALESCE((SELECT MAX(id) FROM nt_stable_horses), 0),
                COALESCE((SELECT MAX(id) FROM nt_stable_wagons), 0)), 1, 0)]] },
    }
    local issues = {}
    for _, check in ipairs(checks) do
        local count = tonumber(MySQL.scalar.await(check[2])) or 0
        if count > 0 then issues[#issues + 1] = ('%s: %s'):format(check[1], count) end
    end
    return issues
end

RegisterCommand('ntstablecheck', function(source)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'command.ntstablecheck') then return end
    CreateThread(function()
        local issues = sqlAction('integrity_check', source, GetIntegrityIssues)
        local message = not issues and 'Database is not available.'
            or #issues > 0 and table.concat(issues, '; ')
            or 'No integrity issues found.'
        print('[Nt_Stables] ' .. message)
        if source ~= 0 then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Nt Stables integrity check',
                description = message,
                type = issues and #issues > 0 and 'warning' or 'success',
                duration = 10000,
            })
        end
    end)
end, false)

CreateThread(function()
    local success, err = pcall(function()
        local ntTableCount = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.tables
            WHERE table_schema = DATABASE() AND table_name LIKE 'nt_stable_%']])) or 0

        if ntTableCount == 0 then
            CreateSchema()
            local imported = ImportRsgHorses()
            CopyLegacySaddlebags(imported)
            MySQL.query.await('ALTER TABLE nt_stable_horses DROP COLUMN legacy_horseid')
        else
            local versionTable = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.tables
                WHERE table_schema = DATABASE() AND table_name = 'nt_stable_schema_version']])) or 0
            local version = versionTable > 0
                and tonumber(MySQL.scalar.await('SELECT version FROM nt_stable_schema_version WHERE id = 1')) or nil
            if version ~= SCHEMA_VERSION then
                error('An older or partial Nt Stables schema exists. Remove every nt_stable_* table before this clean setup.')
            end

            local legacyColumn = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.columns
                WHERE table_schema = DATABASE() AND table_name = 'nt_stable_horses'
                    AND column_name = 'legacy_horseid']])) or 0
            if legacyColumn > 0 then
                local imported = MySQL.query.await([[SELECT * FROM nt_stable_horses
                    WHERE legacy_horseid IS NOT NULL ORDER BY id]])
                CopyLegacySaddlebags(imported)
                MySQL.query.await('ALTER TABLE nt_stable_horses DROP COLUMN legacy_horseid')
            end
        end

        CheckIntegrity()
    end)

    if not success then
        databaseFailed = true
        WriteSqlError('database_startup', nil, nil, 'initialize', err,
            'Database readiness was not enabled. Correct the issue and restart Nt Stables.')
        print(('[Nt_Stables] Database startup failed: %s'):format(err))
        return
    end

    databaseReady = true
    RunSqlQueue()
    print('[Nt_Stables] Database ready.')
end)
