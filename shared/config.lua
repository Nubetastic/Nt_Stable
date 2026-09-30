Config = {}

Config.HorseFeed = {
    horse_carrot = { health = 10, stamina = 10, isMedicine = false },
    horse_apple = { health = 15, stamina = 15, isMedicine = false },
    sugarcube = { health = 25, stamina = 25, isMedicine = false },
    haysnack = { health = 50, stamina = 50, isMedicine = false },
    horsemeal = { health = 75, stamina = 75, isMedicine = false },
    horse_stimulant = { health = 100, stamina = 100, isMedicine = true, medicineHash = 'consumable_horse_stimulant' },
}

Config.StableSlots = {
    AdditionalSlotMultiplier = 1.5,
    SellPriceMultiplier = 0.5,
    DebtPaymentPercent = 0.10,
    FeeInterval = 60, -- minutes
    MoneyType = 'cash',
    Horse = {
        DefaultSlots = 3,
        BaseSlotPrice = 5,
        CostPerHour = 0.05,
    },
    Wagon = {
        DefaultSlots = 1,
        BaseSlotPrice = 50,
        CostPerHour = 0.10,
    },
    StableOverflow = {
        NonChargeWeight = 20, -- the first 20kg of used storage has no hourly fee.
        BaseWeightPrice = 10, -- charge once for every 10kg of used storage over the free weight.
        CostPerHour = 0.05,
        ResizeWeight = 100, -- minimum capacity and resize step in kg.
        Slots = 200,
    },
}

Config.HorseAuction = {
    ListingFeePerDay = 1,
    StableCutPercent = 5,
    MinimumDays = 1,
    MaximumDays = 30,
    MinimumPrice = 1,
    MaximumPrice = 100000,
    MinimumBidIncrease = 1,
    ExpirationInterval = 60,
    MoneyType = 'cash',
}
