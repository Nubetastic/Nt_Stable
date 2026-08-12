# Nt_Stables NUI Outline

This is the review outline for the first implementation phase. Visual rules come from `Nt_UI Guide.md`: Special Elite, dark panel, gold trim, warm text, transparent page, upper-right controls, Escape close, and a 50%-200% viewport-clamped scale control saved under `nt_stables_ui_scale`.

## Shared layout

- The 3D horse, wagon, or NPC remains visible on the left/center of the game view.
- Compact NPC menu appears beside the NPC.
- Management panels occupy the right side and stay below roughly half the screen width where practical.
- Header: stable/title on left; scale, back, and close on right.
- Main content: searchable/scrollable object list, selected-object details, and contextual controls.
- Footer: primary actions plus current price/fee. Destructive actions use red and always require confirmation.
- Busy overlay blocks duplicate purchases/saves while awaiting the server.

## Screen map

```text
NPC popup
|- Manage Horses
|  |- Owned Horses
|  |  |- Modify
|  |  |- Stats
|  |  `- Sell confirmation
|  |- Buy Horse / Daily Stock
|  `- Horse Slots
|- Manage Wagons
|  |- Owned Wagons
|  |  |- Modify
|  |  |- Assign Horses
|  |  |- Storage Entitlement
|  |  `- Sell confirmation
|  |- Buy Wagon
|  `- Wagon Slots
`- Exit
```

## NPC popup

Small panel beside the focused NPC:

- Manage Horses
- Manage Wagons
- Exit

No landing splash or long description.

## Owned horses

- Horse list shows name, breed, active/stabled state, and wild/stable-bred badge.
- Select the active riding horse by default; otherwise select the first owned horse.
- Selecting a horse spawns it in the isolated customization area.
- Footer actions: Modify, Stats, Sell, Leave.
- Slot counter: `owned / total`, with Manage Slots button.

### Horse customization

- Submenu groups: Mane, Tail, Saddle, Blanket, Saddlebags, Stirrups, Horn, Bedroll, Mask, Mustache.
- Each group shows simple previous/next arrows or a short option list.
- Mane/tail and future saddle segments show limited numbered color choices only after compatible style/color mappings are collected.
- Update the 3D preview immediately; show unsaved-change state and running price.
- Actions: Reset Current Group, Reset All, Save, Back.

### Horse stats

Show each row as final rank plus its breakdown beneath it:

```text
Health  6
Base 4  |  Wild -1  |  Training +3
```

Rows: Health, Stamina, Agility, Speed, Acceleration, Strength. Strength details show carry capacity (`strength × 5 kg`) and pull capacity (`strength × 10 kg`). Also show size, gender, training level/XP, clean percentage, saddle-bag weight, overload penalty, and current sell value.

### Buy horse

- Daily stock list shows name, breed, coat/model label, price, and core stat summary.
- Selecting stock updates the 3D preview.
- Purchase asks for name and gender, then shows one final confirmation with price.
- Disable purchase when slots are full and link to Horse Slots.

## Owned wagons

- Wagon list shows name, type, stored/spawned state, assigned horses, and storage entitlement.
- Selecting a wagon updates the 3D preview.
- Footer actions: Modify, Assign Horses, Storage, Sell, Leave.
- Slot counter: `owned / total`, with Manage Slots button.

### Wagon customization

- Groups: Tint, Livery, Props, Lantern, Extra.
- Only tested options for the selected model appear.
- Update preview immediately and show the running price.
- Actions: Reset, Save, Back.

### Assign horses

- Show required hitch positions for the selected wagon.
- Eligible owned horses list shows size, strength, health, stamina, and whether already assigned.
- Ineligible horses remain visible but disabled with a short reason such as `Too small` or `Not enough strength`.
- Summary shows combined pull rating and the wagon's requirement.

### Wagon storage

- Clearly show whether this wagon has inventory access.
- First entitlement is free; later entitlements show the server-calculated price.
- Buying storage access must not create or move items until server confirmation succeeds.

## Slot management

Horse and wagon slots have separate screens:

- Defaults: 3 horse slots and 1 wagon slot.
- Show default slots, purchased slots, next buy price, and current sell refund.
- Purchased slots may be sold only when owned count will still fit afterward.
- Default slots can never be sold.

## Confirmations and errors

- Confirmation modal for buy, sell, slot sale, storage entitlement, and paid customization.
- Modal states exact object name and exact server-provided amount.
- On server rejection, keep the relevant manager open, restore controls, and show the returned reason.
- Escape closes a modal first; from a main screen it exits the stable session and runs full cleanup.

## First NUI build order

1. Shared frame, scale, close/back behavior, and message router.
2. NPC popup.
3. Owned-horse list and selected preview state.
4. Horse stats and confirmation modal.
5. Horse customization navigation.
6. Daily horse stock and purchase flow.
7. Mirror the proven structure for wagons.
8. Slot, assignment, and storage-entitlement screens.
