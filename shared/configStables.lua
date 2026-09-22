ConfigStables = {}

ConfigStables.testSpawn = false -- sets it to spawn 10 distance from player instead of on the road.

ConfigStables.Blip = {
    blipName = "Stables",
    blipSprite = 'blip_shop_horse',
    blipScale = 0.1
}

ConfigStables.Settings = {
    SpawnDistance = 200,
    WagonSpawnDistance = 200,
    HorseReviveTime = 180000,
    WagonHorseReattachDistance = 5.0,
    HorseCallSpawnDistance = 150.0,
    WagonCallSpawnDistance = 150.0,
    ZoneDistance = 3, -- Ox_target zone on horses.
    NpcZoneRadius = 1.5,
    StockTameLevel = 1,
    SaddleBagWeight = 20000,
    SaddleBagSlots = 20,
    SellPricePerLevel = 0.25,
}

ConfigStables.Training = {
    CheckInterval = 1000,
    AwardTime = 600,
    MinimumSpeed = 0.2,
    MaximumXP = 4000,
    RidingXP = 10,
    LeadingXP = 11,
    WagonXP = {
        [1] = 10,
        [2] = 7,
        [4] = 5,
    },
    CareCooldown = 600,
    CareXP = {
        petting = 1,
        grooming = 2,
        feeding = 2,
    },
}

ConfigStables.RoadSpawn = {
    MinimumDistance = 60.0,
    NodeDistance = 20.0,
    GridSize = 5,
    GridGap = 5.0,
}

ConfigStables.WagonApproach = {
    Speed = 5.0,
    DrivingFlags = 786603,
    StopDistance = 10.0,
}

ConfigStables.WildHorseRegistration = {
    Fee = 25,
    NotifyDistance = 20.0,
    OpenDistance = 3.0,
    TamingPollInterval = 500,
    SaddleCategory = 0xBAA7E618,
}


ConfigStables.Locations = {
    ["Valentine"] = {
        label = "Stables",
        npcCoords = vector3(-364.0396, 790.7434, 116.2135), -- ox_target zone and blip coords
        CustomizeCoords = vector4(-371.6367, 786.4064, 116.1939, 271.8404), -- horse and wagon coords
        CustomizeCamera = vector4(-365.5176, 787.9203, 118.6290, 100.5626),
        RegisterCoords = vector3(-371.6367, 786.4064, 116.1939),
        Stall = {
            [1] = vector4(-369.6695, 792.1826, 116.1744, 181.8601), -- Horse coords
            [2] = vector4(-372.4890, 791.9486, 116.1630, 181.3436),
            [3] = vector4(-375.3791, 791.8517, 116.1634, 178.3054),
            [4] = vector4(-374.8139, 781.4225, 116.2230, 9.0880),
            [5] = vector4(-371.9882, 781.5493, 116.2011, 4.2361),
            [6] = vector4(-369.0489, 781.6635, 116.1849, 0.7482),
            [7] = vector4(-366.1811, 781.9995, 116.1764,8.2545),
            [8] = vector4(-363.4095, 782.0371, 116.1929, 353.1425),
            [9] = vector4(-357.5600, 771.6939, 116.4906, 2.2613),
            [10] = vector4(-362.4500, 771.6187, 116.4547, 18.8914),
            [11] = vector4(-367.6668, 771.2888, 116.4696, 13.2599),
            [12] = vector4(-372.4790, 771.2417, 116.3582, 16.2991),
            [13] = vector4(-378.0147, 770.5601, 116.2298, 359.3249),
        },
        Breeds = {
            "riding",
            "draft",
            "work",
            "war",
            "multi",
        }
    },
    ["VanHorn"] = {
        label = "Stables",
        npcCoords = vector3(2967.7144, 791.9626, 52.5143),
        CustomizeCoords = vector4(2968.7588, 796.8846, 51.4325, 96.9677),
        CustomizeCamera = vector4(2962.7991, 796.9788, 53.8414, 267.3893),
        RegisterCoords = vector3(2968.7588, 796.8846, 51.4325),
        Stall = {
            [1] = vector4(2961.3600, 802.1100, 51.5000, 177.9700),
            [2] = vector4(2964.5300, 802.1900, 51.4900, 177.9700),
            [3] = vector4(2967.3400, 802.3600, 51.4200, 177.9700),
            [4] = vector4(2970.2800, 802.5200, 51.5200, 177.9700),
            [5] = vector4(2973.1200, 802.2700, 51.5200, 177.9700),
            [6] = vector4(2972.7400, 791.4700, 51.5000, 3.9700),
        },
        Breeds = {
            "riding",
            "race",
            "war",
            "multi",
        }
    },
    ["SaintDenis"] = {
        label = "Stables",
        npcCoords = vector3(2512.3518, -1456.9178, 46.3420),
        CustomizeCoords = vector4(2502.3513, -1450.3950, 46.3426, 182.2882),
        CustomizeCamera = vector4(2502.5737, -1457.5787, 48.9046, 2.5684),
        RegisterCoords = vector3(2502.3513, -1450.3950, 46.3426),
        Stall = {
            [1] = vector4(2508.9900, -1452.4500, 46.4200, 90.0000),
            [2] = vector4(2508.9800, -1449.3200, 46.4000, 90.0000),
            [3] = vector4(2508.7100, -1446.4800, 46.4200, 90.0000),
            [4] = vector4(2508.9200, -1444.3100, 46.4300, 90.0000),
            [5] = vector4(2508.9900, -1438.3000, 46.4400, 90.0000),
            [6] = vector4(2508.6200, -1441.2600, 46.5100, 90.0000),
        },
        Breeds = {
            "riding",
            "race",
            "multi",
        }
    },
    ["Rhodes"] = {
        label = "Stables",
        npcCoords = vector3(1215.0846, -189.6010, 100.8072),
        CustomizeCoords = vector4(1210.5880, -207.5038, 101.1856, 261.4997),
        CustomizeCamera = vector4(1220.6719, -205.6469, 104.9012, 91.6166),
        RegisterCoords = vector3(1209.4341, -193.8587, 101.4540),
        Stall = {
            [1] = vector4(1203.0300, -190.5600, 101.4800, 281.0000),
            [2] = vector4(1203.5900, -193.5800, 101.4900, 281.0000),
            [3] = vector4(1204.5300, -195.6600, 101.3900, 281.0000),
            [4] = vector4(1205.6300, -198.6600, 101.4900, 281.0000),
            [5] = vector4(1216.0800, -195.5400, 101.3800, 110.0000),
            [6] = vector4(1214.9500, -192.8900, 101.4500, 110.0000),
        },
        Breeds = {
            "riding",
            "draft",
            "war",
            "multi",
        }
    },
    ["Strawberry"] = {
        label = "Stables",
        npcCoords = vector3(-1819.8859, -568.4932, 155.5276),
        CustomizeCoords = vector4(-1828.5820, -576.9075, 155.9861, 262.4728),
        CustomizeCamera = vector4(-1820.1489, -578.4099, 159.8454, 68.4113),
        RegisterCoords = vector3(-1828.5820, -576.9075, 155.9861),
        Stall = {
            [1] = vector4(-1814.4300, -557.6600, 156.1700, 160.0000),
            [2] = vector4(-1817.1600, -557.1000, 156.1800, 160.0000),
            [3] = vector4(-1820.2500, -556.2800, 156.1300, 160.0000),
            [4] = vector4(-1822.8000, -555.5400, 156.1800, 160.0000),
            [5] = vector4(-1826.1200, -565.8300, 156.0600, 344.0000),
            [6] = vector4(-1822.9200, -566.6800, 156.1200, 344.0000),
        },
        Breeds = {
            "work",
            "race",
            "multi",
            "superior",
        }
    },
    ["Blackwater"] = {
        label = "Stables",
        npcCoords = vector3(-877.9753, -1361.9745, 43.0297),
        CustomizeCoords = vector4(-866.1851, -1366.2970, 43.5700, 84.6134),
        CustomizeCamera = vector4(-874.8462, -1366.8088, 47.0160, 272.1489),
        RegisterCoords = vector3(-866.1851, -1366.2970, 43.5700),
        Stall = {
            [1] = vector4(-866.9600, -1370.8800, 43.6800, 40.0000),
            [2] = vector4(-863.8700, -1370.8000, 43.7100, 40.0000),
            [3] = vector4(-860.3400, -1371.1200, 43.7100, 40.0000),
            [4] = vector4(-860.5200, -1361.7200, 43.6600, 140.0000),
            [5] = vector4(-863.5300, -1361.5500, 43.6500, 140.0000),
            [6] = vector4(-867.0200, -1361.5000, 43.6600, 140.0000),
        },
        Breeds = {
            "riding",
            "race",
            "multi",
        }
    },
    ["Tumbleweed"] = {
        label = "Stables",
        npcCoords = vector3(-5515.3052, -3039.4504, -2.3577),
        CustomizeCoords = vector4(-5519.3096, -3044.5073, -2.3577, 271.9804),
        CustomizeCamera = vector4(-5513.2202, -3044.7002, 0.0858, 87.7848),
        RegisterCoords = vector3(-5519.3096, -3044.5073, -2.3577),
        Stall = {
            [1] = vector4(-5513.4500, -3050.7000, -2.3900, 5.0000),
            [2] = vector4(-5516.5200, -3050.3600, -2.3900, 5.0000),
            [3] = vector4(-5519.1400, -3050.1700, -2.3900, 5.0000),
            [4] = vector4(-5522.1000, -3050.1400, -2.3600, 5.0000),
            [5] = vector4(-5525.2100, -3050.1200, -2.3900, 5.0000),
            [6] = vector4(-5525.0900, -3038.7700, -2.3200, 200.0000),
            [7] = vector4(-5522.0500, -3039.2500, -2.1800, 150.0000),
            [8] = vector4(-5519.0700, -3039.0000, -2.2100, 150.0000),
            [9] = vector4(-5534.5500, -3051.6100, -1.4200, 5.0000),
            [10] = vector4(-5538.8400, -3052.6100, -1.1100, 5.0000),
            [11] = vector4(-5543.7200, -3053.4900, -0.8900, 5.0000),
        },
        Breeds = {
            "draft",
            "work",
            "war",
            "multi",
        }
    },
}


ConfigStables.SaddleModels = {
    { value = 1, name = 'Uncatalogued Saddle', first = 1, last = 1 },
    { value = 2, name = 'Big Valley Double Fork', first = 2, last = 2 },
    { value = 3, name = 'Charro Improved', first = 3, last = 8 },
    { value = 9, name = 'Charro Special', first = 9, last = 9 },
    { value = 10, name = 'Charro Stock', first = 10, last = 21 },
    { value = 22, name = 'High Plains Cutting', first = 22, last = 22 },
    { value = 23, name = 'McClellan Improved', first = 23, last = 28 },
    { value = 29, name = 'McClellan Special', first = 29, last = 29 },
    { value = 30, name = 'McClellan Stock', first = 30, last = 41 },
    { value = 42, name = 'Mother Hubbard Improved', first = 42, last = 47 },
    { value = 48, name = 'Mother Hubbard Special', first = 48, last = 48 },
    { value = 49, name = 'Mother Hubbard Stock', first = 49, last = 60 },
    { value = 61, name = 'Western 1 Improved', first = 61, last = 66 },
    { value = 67, name = 'Western 1 Special', first = 67, last = 67 },
    { value = 68, name = 'Western 1 Stock', first = 68, last = 79 },
    { value = 80, name = 'Western 2 Improved', first = 80, last = 85 },
    { value = 86, name = 'Western 2 Special', first = 86, last = 86 },
    { value = 87, name = 'Western 2 Stock', first = 87, last = 98 },
    { value = 99, name = 'Western 3 Improved', first = 99, last = 104 },
    { value = 105, name = 'Western 3 Special', first = 105, last = 105 },
    { value = 106, name = 'Western 3 Stock', first = 106, last = 117 },
    { value = 118, name = 'Western 4 Improved', first = 118, last = 123 },
    { value = 124, name = 'Western 4 Special', first = 124, last = 124 },
    { value = 125, name = 'Western 4 Stock', first = 125, last = 136 },
    { value = 137, name = 'Moonshiner', first = 137, last = 137 },
    { value = 138, name = 'Naturalist', first = 138, last = 138 },
}

ConfigStables.BlanketModels = {
    { value = 1, name = 'Special', first = 1, last = 5 },
    { value = 6, name = 'Blanket 1', first = 6, last = 10 },
    { value = 11, name = 'Blanket 2', first = 11, last = 15 },
    { value = 16, name = 'Blanket 3', first = 16, last = 20 },
    { value = 21, name = 'Blanket 4', first = 21, last = 25 },
    { value = 26, name = 'Blanket 5', first = 26, last = 30 },
    { value = 31, name = 'Blanket 6', first = 31, last = 35 },
    { value = 36, name = 'Blanket 7', first = 36, last = 40 },
    { value = 41, name = 'Blanket 8', first = 41, last = 45 },
    { value = 46, name = 'Blanket 9', first = 46, last = 50 },
    { value = 51, name = 'Blanket 10', first = 51, last = 55 },
    { value = 56, name = 'Blanket 11', first = 56, last = 60 },
    { value = 61, name = 'Blanket 12', first = 61, last = 65 },
}

ConfigStables.SaddlebagModels = {
    { value = 1, name = 'Standard', values = { 1, 2, 3, 4, 5, 16, 17, 18, 19, 20 } },
    { value = 6, name = 'Upgraded', first = 6, last = 15 },
    { value = 21, name = 'Saddlebag 3', first = 21, last = 30 },
    { value = 31, name = 'Saddlebag 4', first = 31, last = 40 },
    { value = 41, name = 'Saddlebag 5', first = 41, last = 45 },
    { value = 46, name = 'Saddlebag 6', first = 46, last = 50 },
}

ConfigStables.StirrupModels = {
    { value = 1, name = 'Stirrup 1', first = 1, last = 1 },
    { value = 2, name = 'Stirrup 2', first = 2, last = 2 },
    { value = 3, name = 'Stirrup 3', first = 3, last = 3 },
    { value = 4, name = 'Stirrup 4', first = 4, last = 4 },
    { value = 5, name = 'Stirrup 5', first = 5, last = 5 },
    { value = 6, name = 'Stirrup 6', first = 6, last = 6 },
    { value = 7, name = 'Stirrup 7', first = 7, last = 7 },
    { value = 8, name = 'Stirrup 8', first = 8, last = 8 },
    { value = 9, name = 'Stirrup 9', first = 9, last = 9 },
    { value = 10, name = 'Stirrup 10', first = 10, last = 10 },
    { value = 11, name = 'Stirrup 11', first = 11, last = 11 },
}

ConfigStables.BedrollModels = {
    { value = 1, name = 'Bedroll 1', first = 1, last = 10 },
    { value = 11, name = 'Bedroll 2', first = 11, last = 20 },
    { value = 21, name = 'Bedroll 3', first = 21, last = 30 },
}

ConfigStables.ManeModels = {
    { value = 1, name = 'Long', first = 1, last = 1 },
    { value = 2, name = 'Very Short', first = 2, last = 2 },
    { value = 11, name = 'Short', first = 11, last = 11 },
    { value = 3, name = 'Dreadlock', first = 3, last = 3 },
    { value = 4, name = 'Braided', first = 4, last = 4 },
    { value = 6, name = 'Mohawk', first = 6, last = 6 },
}

ConfigStables.TailModels = {
    { value = 1, name = 'Dreadlock', first = 1, last = 1 },
    { value = 2, name = 'Long', first = 2, last = 2 },
    { value = 6, name = 'Short', first = 6, last = 6 },
    { value = 8, name = 'Braided', first = 8, last = 8 },
}

ConfigStables.Customization = {
    { key = 'Saddles', label = 'Saddle', defaultLabel = 'Bareback', price = 2, categoryHash = 0xBAA7E618, tintKey = 'SaddleTints', tintPalette = 'metaped_tint_horse_leather', models = ConfigStables.SaddleModels },
    { key = 'Blankets', label = 'Blanket', price = 5, categoryHash = 0x17CEB41A, tintKey = 'BlanketTints', tintPalette = 'metaped_tint_horse_leather', models = ConfigStables.BlanketModels },
    { key = 'Saddlebags', label = 'Saddlebag', price = 3, categoryHash = 0x80451C25, tintKey = 'SaddlebagTints', tintPalette = 'metaped_tint_horse_leather', models = ConfigStables.SaddlebagModels },
    { key = 'Stirrups', label = 'Stirrups', price = 4, categoryHash = 0xDA6DADCA, tintKey = 'StirrupTints', tintPalette = 'metaped_tint_horse_leather', models = ConfigStables.StirrupModels },
    { key = 'Bedrolls', label = 'Bedroll', price = 5, categoryHash = 0xEFB31921, tintKey = 'BedrollTints', tintPalette = 'metaped_tint_horse_leather', models = ConfigStables.BedrollModels },
    { key = 'Manes', label = 'Mane', defaultLabel = 'Natural', price = 3, categoryHash = 0xAA0217AB, tintKey = 'ManeTints', tintPalette = 'metaped_tint_horse', models = ConfigStables.ManeModels },
    { key = 'Tails', label = 'Tail', defaultLabel = 'Natural', price = 4, categoryHash = 0xA63CAE10, tintKey = 'TailTints', tintPalette = 'metaped_tint_horse', models = ConfigStables.TailModels },
}

ConfigStables.RidingHorseComponents = {
    Saddles = true,
    Blankets = true,
    Saddlebags = true,
    Stirrups = true,
    Bedrolls = true,
}

ConfigStables.WagonHorse = {
    HarnessOutfit = 0xC81D2897,
}
















ConfigStables.BreedTypes = {
    riding = {
        label = 'Riding',
        breeds = {
            'kentucky_saddler',
            'morgan',
            'tennessee_walker',
        },
    },
    draft = {
        label = 'Draft',
        breeds = {
            'belgian_draft',
            'shire',
            'suffolk_punch',
        },
    },
    work = {
        label = 'Work',
        breeds = {
            'american_paint',
            'appaloosa',
            'dutch_warmblood',
        },
    },
    race = {
        label = 'Race',
        breeds = {
            'american_standardbred',
            'nokota',
            'norfolk_roadster',
            'thoroughbred',
        },
    },
    war = {
        label = 'War',
        breeds = {
            'andalusian',
            'ardennes',
            'breton',
            'hungarian_halfbred',
        },
    },
    multi = {
        label = 'Multi-Class',
        breeds = {
            'criollo',
            'gypsy_cob',
            'kladruber',
            'missouri_fox_trotter',
            'mustang',
            'turkoman',
        },
    },
    superior = {
        label = 'Superior',
        breeds = {
            'arabian',
        },
    },
}
