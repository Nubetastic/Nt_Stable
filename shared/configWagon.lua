ConfigWagon = {}

ConfigWagon.Prices = {
    livery = 5,
    tint = 10,
    extras = 20, -- per extra added
    lanterns = 20,
    repair = 0.25, -- percentage of the wagon purchase price
}


ConfigWagon.Wagons = {
    -------------------------------------------------
    -- Basic Carts
    -------------------------------------------------
    cart01 = {
        label = "Light Peasant Cart",
        description = "A simple one-horse cart for light loads" .. ", Storage: 50",
        category = "carts",
        horseCount = 1,
        horseOffsets = { [1] = { x = 0.0, y = 3.5, z = 0.0 } },
        price = 85.00,
        maxWeight = 50000,
        slots = 5,
        customizations = {
            livery = { -1, 0, 1, 2, 3 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            extras = { 0, 1, 4 },
            lanterns = { 0, "pg_teamster_cart01_lightupgrade1", "pg_teamster_cart01_lightupgrade2", "pg_teamster_cart01_lightupgrade3", "pg_veh_cart01_lanterns01" }
        }
    },
    cart02 = {
        label = "Peasant Cart with Sides",
        description = "A cart with raised sides for better cargo security" .. ", Storage: 50",
        category = "carts",
        horseCount = 1,
        horseOffsets = { [1] = { x = 0.0, y = 3.5, z = 0.0 } },
        price = 103.50,
        maxWeight = 50000,
        slots = 5,
        customizations = {
            livery = { -1, 0, 1, 2, 3 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            extras = { 0 }
        }
    },
    cart03 = {
        label = "Small Market Cart",
        description = "Compact cart ideal for market vendors" .. ", Storage: 50",
        category = "carts",
        horseCount = 1,
        horseOffsets = { [1] = { x = 0.0, y = 3.5, z = 0.0 } },
        price = 66.80,
        maxWeight = 50000,
        slots = 5,
        customizations = {
            livery = { -1, 0, 1, 2 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8 },
            extras = { 0 }
        }
    },
    cart04 = {
        label = "Compact Farm Cart",
        description = "Handy cart for farm work" .. ", Storage: 60",
        category = "carts",
        horseCount = 1,
        horseOffsets = { [1] = { x = 0.0, y = 3.5, z = 0.0 } },
        price = 81.20,
        maxWeight = 60000,
        slots = 6,
        customizations = {
            livery = { -1, 0, 1, 2 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8 },
            extras = { 0 }
        }
    },

    cart06 = {
        label = "General Cargo Cart",
        description = "Versatile cart for various cargo" .. ", Storage: 100",
        category = "carts",
        horseCount = 1,
        horseOffsets = { [1] = { x = 0.0, y = 3.5, z = 0.0 } },
        price = 150.50,
        maxWeight = 100000,
        slots = 10,
        customizations = {
            livery = { -1, 0, 1, 2, 3 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 },
            extras = { 0 },
            lanterns = { 0, "pg_re_deadbodies01x_lights", "pg_teamster_cart06_lightupgrade1", "pg_teamster_cart06_lightupgrade2", "pg_teamster_cart06_lightupgrade3", "pg_veh_cart06_lanterns01" }
        }
    },
    cart07 = {
        label = "Farmer's Cart",
        description = "Reliable farm cart" .. ", Storage: 80",
        category = "carts",
        horseCount = 1,
        horseOffsets = { [1] = { x = 0.0, y = 3.5, z = 0.0 } },
        price = 99.40,
        maxWeight = 80000,
        slots = 8,
        customizations = {
            livery = { -1, 0, 1, 2 },
            tint = { 0, 1, 2, 3, 4, 5, 6 },
            extras = { 0, 1 }
        }
    },
    cart08 = {
        label = "Rural Utility Cart",
        description = "Multi-purpose utility cart" .. ", Storage: 100",
        category = "carts",
        horseCount = 1,
        horseOffsets = { [1] = { x = 0.0, y = 3.5, z = 0.0 } },
        price = 117.80,
        maxWeight = 100000,
        slots = 10,
        customizations = {
            livery = { -1, 0, 1, 2, 3 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8 },
            extras = { 0, 4 }
        }
    },

    -------------------------------------------------
    -- Work Wagons
    -------------------------------------------------
    huntercart01 = {
        label = "Hunter Cart",
        description = "Cart that only fit to carry pelts, hides and furs" .. ", Storage: 200",
        category = "work",
        horseCount = 1,
        horseOffsets = { [1] = { x = 0.0, y = 3.5, z = 0.0 } },
        price = 82.00,
        maxWeight = 100000,
        slots = 10,
        customizations = {
            livery = { -1, 0, 1, 2, 3 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8 },
            extras = { 0 },
            lanterns = { 0, "pg_re_deadbodies01x_lights", "pg_teamster_cart06_lightupgrade1", "pg_teamster_cart06_lightupgrade2", "pg_teamster_cart06_lightupgrade3", "pg_veh_cart06_lanterns01" }
        }
    },
    wagon02x = {
        label = "Standard Camping Wagon",
        description = "A reliable covered wagon for long journeys" .. ", Storage: 150",
        category = "work",
        horseCount = 2,
        horseOffsets = { [1] = { x = -1.0, y = 3.5, z = 0.0 }, [2] = { x = 1.0, y = 3.5, z = 0.0 } },
        price = 192.00,
        maxWeight = 150000,
        slots = 15,
        customizations = {
            livery = { -1, 0, 1, 2, 3, 4, 5 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            extras = { 0, 1, 2, 3, 5 },
            lanterns = { 0, "pg_teamster_wagon02x_lightupgrade1", "pg_teamster_wagon02x_lightupgrade2", "pg_teamster_wagon02x_lightupgrade3", "pg_veh_wagon02x_lanterns01", "pg_veh_wagonsuffrage_lanterns01" }
        }
    },
    wagon03x = {
        label = "Reinforced Camping Wagon",
        description = "A sturdier wagon with extra storage" .. ", Storage: 150",
        category = "work",
        horseCount = 2,
        horseOffsets = { [1] = { x = -1.0, y = 3.5, z = 0.0 }, [2] = { x = 1.0, y = 3.5, z = 0.0 } },
        price = 276.50,
        maxWeight = 150000,
        slots = 15,
        customizations = {
            livery = { -1, 0, 1, 2, 3, 4, 5, 6 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            extras = { 0 }
        }
    },
    wagon04x = {
        label = "Light Farm Wagon",
        description = "Lightweight wagon for farming" .. ", Storage: 100",
        category = "work",
        horseCount = 2,
        horseOffsets = { [1] = { x = -1.0, y = 3.5, z = 0.0 }, [2] = { x = 1.0, y = 3.5, z = 0.0 } },
        price = 133.80,
        maxWeight = 100000,
        slots = 10,
        customizations = {
            livery = { -1, 0, 1, 2, 3 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8 },
            extras = { 0, 1, 2, 3 },
            lanterns = { 0, "pg_teamster_wagon04x_lightupgrade1", "pg_teamster_wagon04x_lightupgrade2", "pg_teamster_wagon04x_lightupgrade3", "pg_veh_wagon04x_lanterns01" }
        }
    },
    wagon05x = {
        label = "Open Utility Wagon",
        description = "Open wagon for versatile use" .. ", Storage: 200",
        category = "work",
        horseCount = 2,
        horseOffsets = { [1] = { x = -1.0, y = 3.5, z = 0.0 }, [2] = { x = 1.0, y = 3.5, z = 0.0 } },
        price = 152.00,
        maxWeight = 200000,
        slots = 20,
        customizations = {
            livery = { -1, 0, 1, 2, 3, 4 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 },
            extras = { 0, 5 },
            lanterns = { 0, "pg_teamster_wagon05x_lightupgrade1", "pg_teamster_wagon05x_lightupgrade2", "pg_teamster_wagon05x_lightupgrade3", "pg_veh_wagon05x_2_lanterns01", "pg_veh_wagon05x_lanterns01", "pg_veh_wagon05x_lanterns02" }
        }
    },
    wagon06x = {
        label = "Covered Supply Wagon",
        description = "Covered wagon for protected cargo" .. ", Storage: 100",
        category = "work",
        horseCount = 1,
        horseOffsets = { [1] = { x = 0.0, y = 3.5, z = 0.0 } },
        price = 212.20,
        maxWeight = 100000,
        slots = 10,
        customizations = {
            livery = { -1, 0, 1, 2, 3, 4, 5 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            extras = { 0, 1, 2 },
            lanterns = { 0, "pg_teamster_wagon06x_lightupgrade1", "pg_teamster_wagon06x_lightupgrade2", "pg_teamster_wagon06x_lightupgrade3" }
        }
    },
    chuckwagon000x = {
        label = "Kitchen Wagon (Chuckwagon)",
        description = "A mobile kitchen for feeding workers" .. ", Storage: 150",
        category = "work",
        horseCount = 2,
        horseOffsets = { [1] = { x = -1.0, y = 3.5, z = 0.0 }, [2] = { x = 1.0, y = 3.5, z = 0.0 } },
        price = 318.00,
        maxWeight = 150000,
        slots = 15,
        customizations = {
            livery = { -1, 0, 1, 2, 3, 4 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            extras = { 0, 1, 2, 3 },
            lanterns = { 0, "pg_teamster_chuckwagon000x_lightupgrade1", "pg_teamster_chuckwagon000x_lightupgrade2", "pg_teamster_chuckwagon000x_lightupgrade3", "pg_veh_chuckwagon000x_lanterns" }
        }
    },
    chuckwagon002x = {
        label = "Tool Cargo Wagon",
        description = "Wagon designed for tools and equipment" .. ", Storage: 100",
        category = "work",
        horseCount = 2,
        horseOffsets = { [1] = { x = -1.0, y = 3.5, z = 0.0 }, [2] = { x = 1.0, y = 3.5, z = 0.0 } },
        price = 298.80,
        maxWeight = 100000,
        slots = 10,
        customizations = {
            livery = { -1, 0, 1, 2, 3, 4 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            extras = { 0, 1, 2, 3 },
            lanterns = { 0, "pg_teamster_chuckwagon002x_lightupgrade1", "pg_teamster_chuckwagon002x_lightupgrade2", "pg_teamster_chuckwagon002x_lightupgrade3", "pg_veh_chuckwagon002x_lanterns01" }
        }
    },
    supplywagon = {
        label = "Large Supply Wagon",
        description = "Heavy-duty wagon for bulk cargo" .. ", Storage: 200",
        category = "work",
        horseCount = 2,
        horseOffsets = { [1] = { x = -1.0, y = 3.5, z = 0.0 }, [2] = { x = 1.0, y = 3.5, z = 0.0 } },
        price = 508.00,
        maxWeight = 200000,
        slots = 20,
        customizations = {
            livery = { -1, 0, 1, 2, 3, 4, 5, 6 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            extras = { 0, 1, 2, 4 }
        }
    },
    utilliwag = {
        label = "Low Utility Wagon (Buckboard)",
        description = "Light buckboard wagon" .. ", Storage: 100",
        category = "work",
        horseCount = 1,
        horseOffsets = { [1] = { x = 0.0, y = 3.5, z = 0.0 } },
        price = 115.50,
        maxWeight = 100000,
        slots = 10,
        customizations = {
            livery = { -1, 0, 1, 2, 3 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8 },
            extras = { 0, 2 },
            lanterns = { 0, "pg_veh_utilliwag_lightupgrade_1", "pg_veh_utilliwag_lightupgrade_2", "pg_veh_utilliwag_lightupgrade_3", "pg_veh_utilliwag_lanterns01" }
        }
    },
    gatchuck = {
        label = "Articulated Heavy Cargo Wagon",
        description = "Massive freight wagon" .. ", Storage: 100",
        category = "work",
        horseCount = 1,
        horseOffsets = { [1] = { x = 0.0, y = 3.5, z = 0.0 } },
        price = 634.50,
        maxWeight = 100000,
        slots = 10,
        requiredGrade = 2,
        customizations = {
            livery = { -1, 0, 1, 2, 3 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 },
            extras = { 0, 1, 2, 3, 4 },
            lanterns = { 0, "pg_teamster_gatchuck_lightupgrade1", "pg_teamster_gatchuck_lightupgrade2", "pg_teamster_gatchuck_lightupgrade3", "pg_veh_gatchuck_lanterns01" }
        }
    },

    -------------------------------------------------
    -- Coaches & Carriages
    -------------------------------------------------
    coach2 = {
        label = "Light Closed Carriage (Brougham)",
        description = "Elegant carriage for 2-4 passengers" .. ", Storage: 30",
        category = "coaches",
        horseCount = 4,
        horseOffsets = {
            [1] = { x = -1.0, y = 3.5, z = 0.0 },
            [2] = { x = 1.0, y = 3.5, z = 0.0 },
            [3] = { x = -1.0, y = 6.5, z = 0.0 },
            [4] = { x = 1.0, y = 6.5, z = 0.0 },
        },
        price = 414.25,
        maxWeight = 30000,
        slots = 3,
        customizations = {
            livery = { -1, 0, 1, 2, 3, 4, 5, 6 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            extras = { 0, 1, 2, 3, 5 }
        }
    },
    coach3 = {
        label = "Rental Carriage (Fiacre)",
        description = "Urban passenger transport" .. ", Storage: 60",
        category = "coaches",
        horseCount = 2,
        horseOffsets = { [1] = { x = -1.0, y = 3.5, z = 0.0 }, [2] = { x = 1.0, y = 3.5, z = 0.0 } },
        price = 284.50,
        maxWeight = 60000,
        slots = 6,
        customizations = {
            livery = { -1, 0, 1, 2, 3, 4, 5 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            extras = { 0 }
        }
    },
    coach4 = {
        label = "Landau Carriage",
        description = "Luxury convertible carriage" .. ", Storage: 40",
        category = "coaches",
        horseCount = 1,
        horseOffsets = { [1] = { x = 0.0, y = 3.5, z = 0.0 } },
        price = 374.00,
        maxWeight = 40000,
        slots = 4,
        customizations = {
            livery = { -1, 0, 1, 2, 3, 4, 5, 6 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            extras = { 0 }
        }
    },
    coach5 = {
        label = "Elegant Victoria",
        description = "Open carriage for outings" .. ", Storage: 40",
        category = "coaches",
        horseCount = 1,
        horseOffsets = { [1] = { x = 0.0, y = 3.5, z = 0.0 } },
        price = 321.05,
        maxWeight = 40000,
        slots = 4,
        customizations = {
            livery = { -1, 0, 1, 2, 3, 4, 5, 6 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            extras = { 0 }
        }
    },
    coach6 = {
        label = "Open Excursion Carriage",
        description = "Group transport for events" .. ", Storage: 40",
        category = "coaches",
        horseCount = 1,
        horseOffsets = { [1] = { x = 0.0, y = 3.5, z = 0.0 } },
        price = 323.20,
        maxWeight = 40000,
        slots = 4,
        customizations = {
            livery = { -1, 0, 1, 2, 3, 4, 5 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            extras = { 0 }
        }
    },
    buggy01 = {
        label = "Luxury Buggy (Leather Top)",
        description = "Elegant buggy for personal use" .. ", Storage: 30",
        category = "coaches",
        horseCount = 1,
        horseOffsets = { [1] = { x = 0.0, y = 3.5, z = 0.0 } },
        price = 154.75,
        maxWeight = 30000,
        slots = 3,
        customizations = {
            livery = { -1, 0, 1, 2, 3, 4 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            extras = { 0 }
        }
    },
    buggy02 = {
        label = "Standard Buggy (Runabout)",
        description = "Common light buggy" .. ", Storage: 20",
        category = "coaches",
        horseCount = 1,
        horseOffsets = { [1] = { x = 0.0, y = 3.5, z = 0.0 } },
        price = 105.50,
        maxWeight = 20000,
        slots = 2,
        customizations = {
            livery = { -1, 0, 1, 2, 3 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            extras = { 0 }
        }
    },
    buggy03 = {
        label = "Family Buggy (Light Surrey)",
        description = "Buggy for 4 people" .. ", Storage: 10",
        category = "coaches",
        horseCount = 1,
        horseOffsets = { [1] = { x = 0.0, y = 3.5, z = 0.0 } },
        price = 176.20,
        maxWeight = 10000,
        slots = 1,
        customizations = {
            livery = { -1, 0, 1, 2, 3, 4 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            extras = { 0 }
        }
    },

    -------------------------------------------------
    -- Stagecoaches
    -------------------------------------------------
    stagecoach001x = {
        label = "Common Stagecoach (Concord)",
        description = "Standard intercity stagecoach" .. ", Storage: 50",
        category = "stagecoaches",
        horseCount = 2,
        horseOffsets = { [1] = { x = -1.0, y = 3.5, z = 0.0 }, [2] = { x = 1.0, y = 3.5, z = 0.0 } },
        price = 652.00,
        maxWeight = 50000,
        slots = 5,
        customizations = {
            livery = { -1, 0, 1, 2, 3, 4, 5, 6, 7 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            extras = { 0, 1, 2 }
        }
    },
    stagecoach002x = {
        label = "Light Rural Stagecoach",
        description = "Smaller stagecoach for rural routes" .. ", Storage: 50",
        category = "stagecoaches",
        horseCount = 2,
        horseOffsets = { [1] = { x = -1.0, y = 3.5, z = 0.0 }, [2] = { x = 1.0, y = 3.5, z = 0.0 } },
        price = 500.50,
        maxWeight = 50000,
        slots = 5,
        customizations = {
            livery = { -1, 0, 1, 2, 3, 4, 5, 6 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            extras = { 0, 1, 2 }
        }
    },
    stagecoach003x = {
        label = "Simple Passenger Carriage",
        description = "Basic closed town coach" .. ", Storage: 50",
        category = "stagecoaches",
        horseCount = 2,
        horseOffsets = { [1] = { x = -1.0, y = 3.5, z = 0.0 }, [2] = { x = 1.0, y = 3.5, z = 0.0 } },
        price = 304.50,
        maxWeight = 50000,
        slots = 5,
        customizations = {
            livery = { -1, 0, 1, 2, 3, 4, 5 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            extras = { 0 },
            lanterns = { 0, "pg_veh_stagecoach003x_lanterns01" }
        }
    },
    stagecoach005x = {
        label = "Long-Distance Stagecoach",
        description = "Robust stagecoach for long routes" .. ", Storage: 50",
        category = "stagecoaches",
        horseCount = 2,
        horseOffsets = { [1] = { x = -1.0, y = 3.5, z = 0.0 }, [2] = { x = 1.0, y = 3.5, z = 0.0 } },
        price = 733.00,
        maxWeight = 50000,
        slots = 5,
        customizations = {
            livery = { -1, 0, 1, 2, 3, 4, 5, 6, 7 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            extras = { 0, 1 }
        }
    },
    stagecoach006x = {
        label = "Urban Omnibus Stagecoach",
        description = "Mass transit public coach" .. ", Storage: 50",
        category = "stagecoaches",
        horseCount = 2,
        horseOffsets = { [1] = { x = -1.0, y = 3.5, z = 0.0 }, [2] = { x = 1.0, y = 3.5, z = 0.0 } },
        price = 571.25,
        maxWeight = 50000,
        slots = 5,
        customizations = {
            livery = { -1, 0, 1, 2, 3, 4, 5, 6 },
            tint = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            extras = { 0 }
        }
    },
}
