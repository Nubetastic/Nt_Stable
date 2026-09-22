# Nt_Stables

## [Showcase](https://www.youtube.com/watch?v=ia56ZwEolWk)

An RSG Framework stable system for buying, owning, training, customizing, and trading horses and wagons in RedM.
This script does not spawn stable NPC's, it only places a ox_target zone for where an npc would be placed.

## Features

- Configurable stable locations, horse stock, wagons, prices, storage, and capacity fees
    - Each stable sells certain breeds that change on script/server reset.
- Horse and wagon management, spawning, renaming, selling, customization, and repairs
    - Inventory capacity depends on horse stats.
    - Easy color editing for horse and wagon
- Riding-horse and wagon-horse assignment with synchronized wagon teams
    - Wagons use player owned horses assigned to the wagon.
    - Same horse can be assigned to multiple wagons, only 1 active wagon at a time.
- Horse training through riding, leading, wagon work, and care
- Tamed wild-horse registration
    - Wild horses get +- modifers, allowing players to get better stat horses from the wild.
- Direct sales and auctions with day length experiation.
    - Allows players to sell horses to the rest of the server easily from one central location.
    - Auction off a horse, or sell a horse at a set price.
- Saddlebag, wagon, and shared stable storage
    - Single saddle bag inventory for all horses
    - Wagons each have their own inventory
    - Stable has temporary inventory as needed.
        - Players can only remove from cannot add to.
        - Added to stable hourly fee depending on amount used.
- Hourly stable fee, based on number of owned slots.
    - Players get 3 starting stable slots and 1 wagon slot

## Dependencies

- `rsg-core`
- `rsg-inventory`
- `ox_lib`
- `ox_target`
- `oxmysql`

Imports from `player_horses`, uses a new database for horses with new inventories as well.

## Installation

1. Place `Nt_Stables` in your server resources folder.
2. Update npcCoords in configStables.lua with where you want the ox_target zone for each stable to be.
3. Start the dependencies before this resource.
4. Add `ensure Nt_Stables` to `server.cfg` and restart the server.

