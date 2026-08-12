# Wagon Horses

We already have stable slots for horses and wagons, wagon customization, and a working method for replacing a wagon's default horses with player-owned customized horses.

## Horse and wagon states

A horse can be assigned as a wagon horse or selected as the player's active riding horse.

- A horse can be assigned to more than one wagon because only one wagon can be active and spawned at a time.
- A horse can only occupy one slot on the same wagon.
- Setting a wagon horse as the active riding horse removes it from every wagon it is assigned to and leaves those wagon slots empty.
- Assigning the active riding horse to a wagon clears it as the player's active riding horse.
- A player can have no active riding horse or one active riding horse.
- A player can have no active wagon or one active wagon.
- A wagon with any required horse slot empty cannot be set as active.
- If a riding or wagon horse dies, that horse is temporarily unavailable.

The stable menu controls which horse is active for riding and which wagon is active.

## Wagon horse slots

Use `ConfigWagon.Wagons[model].horseCount` to determine whether the wagon requires one, two, or four horses.

For four-horse wagons, the slots are:

1. Closest to the wagon on the left.
2. Closest to the wagon on the right.
3. In front of slot 1 on the left.
4. In front of slot 2 on the right.

Build the assignment diagram from the separate `html/imgs/wagon.png` and `html/imgs/horse.png` assets. The wagon image is the fixed, non-interactive base. Add one horse-image button for each slot required by the wagon's configured `horseCount`, so the same diagram supports one, two, or four horses without separate combined images.

Position each horse button according to its slot number. The horse artwork is the clickable part of the slot. Empty slots still show the horse image so the player can select them and assign a horse. Use the button's background, border, or highlight to show its state without covering the artwork:

- Empty slot: normal horse image, available to select.
- Assigned slot: highlighted horse button with the assigned horse's name.
- Selected slot: stronger highlight while its horse-selection popup is open.
- Unused slot: do not create it for that wagon.

When a player selects a wagon, add an **Assign Horses** button. It opens a menu containing the composed wagon diagram. The player selects a horse slot and then chooses one of their available horses from a popup list. The assigned horse's name and slot state are then updated on the diagram.

## Stored assignment data

The wagon slot assignment is the authoritative relationship. Keep the data simple, equivalent to:

```lua
wagon.slots[1] = horseId
```

Do not separately store a list of wagons on each horse. Derive whether a horse is assigned to any wagon from the wagon-slot assignments and expose `isWagonHorse` with the horse data sent to the menu for easy display and tracking.

Show a wagon icon on horses where `isWagonHorse` is true.

If a wagon horse is sold or selected as the active riding horse, remove that horse from every wagon assignment and leave each affected slot empty. An affected wagon cannot be made active until all of its required horse slots are filled again.

Server-side assignment checks should confirm:

- The player owns the horse and wagon.
- The slot is valid for the wagon's configured `horseCount`.
- The horse is not already assigned to another slot on that same wagon.
- The assignment does not exceed the wagon's horse count.

## Horse and wagon display order

Give every owned horse and wagon a hidden display-order number. Items are shown in that order, but the number is not shown to the player.

Selecting **Edit Order** for horses or wagons opens a list with up and down controls. Moving an item only swaps or updates display-order numbers. Do not allow gaps between occupied display positions.

Stable capacity remains the number of horses or wagons the player can own; changing display order does not change ownership slots. The bottom-most slot is always the slot sold. It cannot be sold while occupied, so the player must have fewer owned items than their current capacity before selling a slot.

This ordering lets players group wagon horses, riding horses, and wagons however they prefer.

## Calling active animals and wagons

- Restore the **H** key so it only calls the player's active riding horse.
- Add a radial-menu client event that calls the player's active wagon.
- Only the active wagon can be called, so only one player-owned wagon can be spawned at a time.

## Icons

`Config.Icons` currently uses `trailer` for wagons and `horse` for horses. Since the existing menus use Font Awesome, `fa-solid fa-wagon-covered` (if included in the installed Font Awesome set) is a clearer wagon choice, and `fa-solid fa-horse-head` is already used elsewhere in this resource. A separate small badge using the wagon icon is preferable to changing the horse's main icon.

Native game textures are not a direct replacement for Font Awesome icons inside the HTML NUI. Using them would require exporting suitable texture assets or drawing a separate native/scaleform interface, so the existing icon system is the simpler choice for this menu.



Wagon NUI

H = horse, we hide the slots not in use by not showing the horse picture and allowing the slot to be clicked.
W = Wagon

[H] | [H]
[H] | [H]
   [W]
