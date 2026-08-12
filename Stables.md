This scripts plan is to make a brand new horse and wagon script with one npc that manages it all.

Use existing rsg-horse sql storage system so existing horses are apart of the script, and expand the sql data as needed for the new system.

The whole script will use a custom NUI for better clareity and easy of use.
- We will not use native hose details.
- We will use native horse interaction buttons.

Design from the players point of view.
Horses spawn at the stable for purchase.
    - Each day the horse stock changes randomly based on that stables horse stock list.
        - Horse stock will be designed based on stable locations, saint denis having higher priced and vanhorn having lower priced for example.
Review of horse outfits. For each breed, get the number of outfits for that breed model and store it in config.
    - can do a temp lua file that runs the natives and prints to a jason file in a lua formated vertical data table.

Horse customization
    - We will have main and tail types, with a color slider for each.
        - this will make it easy for players to customize the hair on their horse.
    - Saddles will be grouped into types.
        - We will have color sliders for different segments of the saddles for further player customization. 
            - We will have the same colors available for all saddle parts.
    - Saddle addons, horn and stirrups are customizations only need to replace existing ones if any with the selected models.

Wagon Customization
    - we will use the native options to customize the wagon.
    - we will use player owned horses to pull the wagon, the horse stats will modify stats on the wagon.
        - certain breeds, tiny ones, will not be elegable to pull the wagon.

Horse stats
    - We will use existing base and max health, stamina, acceleration and speed values
        - This is for game mechanic reasons.
        - We will add a strength value.
    - Strength - carry weight is 5kg per strength point, pull weight is double carry weight.
    - We will set stats based on breed.
        - Work horses will have high strenth, health and stamina but low acceleration and speed.
        - race horses will have avg stamina, high and high speed.
        - lets expand on the rest of the horse types as there are several. We can make a breedStates.md where we list each breed by type, then have the breed type stats. We can then later build up further on breeds by variying the stats a little.

NUI - this code needs to be done first.
    - We will use Nt_ui guide.md as a template to build off of.
    - There will be a lot of NUI use so setting up an example for the NUI we will need will be helpful.
    - Talk to npc
        - Camer goes in and focuses on npc, will use config camera coords
            - Small popup menu beside the npc with options.
                - So list example options.
                    - Manage Horses
                    - Manage Wagons
                    - exit button at bottom.
    - Manage Horses
        - larger window on the right side of the screen.
        - Player will switch routing buckets, 2000 + server id, and camera will move to horse customization area config value.
        - Menu on right side of screen, listing each horse.
            - Selected horse, will select current riding horse by default, will spawn in customize area.
            - Player clicks on horse name, then one of the options at the bottom of the menu.
                - Modify, view stats, sell, leave.
                - Modify brings up horse and saddle customization options.
                    - Can be a series of menu and sub menus.
                        - Can be a list of saddle parts, click the part the player can use arrow buttons or a list of options to pick from and then color sliders below to modify the look.
                        - color sliders should have a simple number, like 1-2 digits so players can get the same color on another piece. Lets limit the options.
            - States will open a list of the horses stats, showing wild/tame modifiers in state details below each one.
            - Sell, will open a sell window, it will show the horses current price and give them a final sell button.
    - Manage Wagons
        - It will work in a simular way
            - let player buy new wagons by going through the various wagon types.
            - a simple wagon customization window.
        - For owned wagons, horses must be applied to the wagon. Saddles will be removed from horse when spawned to wagon but will keep its saddle data.

Inventory
    - There will be 1 single horse inventory, called saddle bag.
        - A horse can have more weight then they can carry in the bag as a speed reduction.
        - Bag max weight will be 20kg.
            - This will keep inventory simple, one inventory weight moves around but modifiers horse speed if to heavy for weaker horse.
    - Wagon
        - I don't want wagons to be treated as free storage.
            - Each wagon can have its own inventory, but players need to buy wagon storage slots for additional wagons. They get 1 free one. price goes up as they own more.

Stable Slots
    - Wagon and horses will have their own stable slots
        - 3 default for horses
        - 1 default for wagon
    - Players can buy/sell additional slots, so if they buy 1 horse slot they can later sell that slot. they cannot sell a default slot.
    - While players are playing they will be charged a stable fee every hour of game time.
        - This will be fully server side and need to manage it in an easy way for disconnects and logging out.
            - Suggestion, playtime meta data that is updated every minute. It reaches 60 they get charged and it resets.
                - this way if a player logs out the time remains until they come back in and it continues where they left off.
