# Active Wagon Models

Source: active entries in `rsg-wagonmaker/config/config.lua`. Definitions inside `--[[ ... ]]` blocks are excluded.

`maxWeight` is converted from the source's gram-style value to kilograms for readability. `L/T/E` are the number of configured livery, tint, and extra choices; they are option lists, not proof that every listed choice visibly works on the model.

| Model | Label | Category | Max weight | Slots | Grade | L | T | E |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `cart01` | Light Peasant Cart | carts | 50 kg | 5 | 0 | 5 | 11 | 4 |
| `cart02` | Peasant Cart with Sides | carts | 50 kg | 5 | 0 | 5 | 11 | 4 |
| `cart03` | Small Market Cart | carts | 50 kg | 5 | 0 | 4 | 9 | 3 |
| `cart04` | Compact Farm Cart | carts | 60 kg | 6 | 0 | 4 | 9 | 3 |
| `cart06` | General Cargo Cart | carts | 100 kg | 10 | 0 | 5 | 10 | 4 |
| `cart07` | Farmer's Cart | carts | 80 kg | 8 | 0 | 4 | 7 | 3 |
| `cart08` | Rural Utility Cart | carts | 100 kg | 10 | 0 | 5 | 9 | 4 |
| `huntercart01` | Hunter Cart | work | 100 kg | 10 | 0 | 5 | 9 | 4 |
| `wagon02x` | Standard Camping Wagon | work | 150 kg | 15 | 0 | 7 | 11 | 5 |
| `wagon03x` | Reinforced Camping Wagon | work | 150 kg | 15 | 0 | 8 | 11 | 6 |
| `wagon04x` | Light Farm Wagon | work | 100 kg | 10 | 0 | 5 | 9 | 4 |
| `wagon05x` | Open Utility Wagon | work | 200 kg | 20 | 0 | 6 | 10 | 5 |
| `wagon06x` | Covered Supply Wagon | work | 100 kg | 10 | 0 | 7 | 11 | 5 |
| `chuckwagon000x` | Kitchen Wagon (Chuckwagon) | work | 150 kg | 15 | 0 | 6 | 11 | 6 |
| `chuckwagon002x` | Tool Cargo Wagon | work | 100 kg | 10 | 0 | 6 | 11 | 5 |
| `supplywagon` | Large Supply Wagon | work | 200 kg | 20 | 0 | 8 | 11 | 7 |
| `utilliwag` | Low Utility Wagon (Buckboard) | work | 100 kg | 10 | 0 | 5 | 9 | 4 |
| `gatchuck` | Articulated Heavy Cargo Wagon | work | 100 kg | 10 | 2 | 5 | 10 | 5 |
| `coach2` | Light Closed Carriage (Brougham) | coaches | 30 kg | 3 | 0 | 8 | 11 | 5 |
| `coach3` | Rental Carriage (Fiacre) | coaches | 60 kg | 6 | 0 | 7 | 11 | 5 |
| `coach4` | Landau Carriage | coaches | 40 kg | 4 | 0 | 8 | 11 | 6 |
| `coach5` | Elegant Victoria | coaches | 40 kg | 4 | 0 | 8 | 11 | 5 |
| `coach6` | Open Excursion Carriage | coaches | 40 kg | 4 | 0 | 7 | 11 | 5 |
| `buggy01` | Luxury Buggy (Leather Top) | coaches | 30 kg | 3 | 0 | 6 | 11 | 4 |
| `buggy02` | Standard Buggy (Runabout) | coaches | 20 kg | 2 | 0 | 5 | 11 | 3 |
| `buggy03` | Family Buggy (Light Surrey) | coaches | 10 kg | 1 | 0 | 6 | 11 | 4 |
| `stagecoach001x` | Common Stagecoach (Concord) | stagecoaches | 50 kg | 5 | 0 | 9 | 11 | 6 |
| `stagecoach002x` | Light Rural Stagecoach | stagecoaches | 50 kg | 5 | 0 | 8 | 11 | 5 |
| `stagecoach003x` | Simple Passenger Carriage | stagecoaches | 50 kg | 5 | 0 | 7 | 11 | 5 |
| `stagecoach005x` | Long-Distance Stagecoach | stagecoaches | 50 kg | 5 | 0 | 9 | 11 | 7 |
| `stagecoach006x` | Urban Omnibus Stagecoach | stagecoaches | 50 kg | 5 | 0 | 8 | 11 | 6 |
| `policewagon01x` | Police Patrol Wagon | special | 20 kg | 2 | 2 | 4 | 7 | 3 |

## Disabled source definitions

The config also contains block-commented models including `cart05`, oil/coal wagons, armored and prison wagons, combat wagons, circus wagons, dairy/apothecary/traveler/delivery wagons, and others. They are useful candidates but should not silently enter the new catalog until each model and customization set is tested.

## New design fields to add

- Purchase price and stable stock groups. Current active entries have `price = 0` because the source is crafting/material based.
- Empty wagon weight and maximum safe pull weight.
- Required horse count and allowed hitch positions.
- Minimum total horse strength and size restrictions.
- Passenger seats and intended role.
- Whether the owner has purchased an inventory entitlement for this wagon.
- Tested livery/tint/extra bounds rather than assumed ranges.

