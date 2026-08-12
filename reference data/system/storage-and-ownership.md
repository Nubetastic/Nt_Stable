# Storage And Ownership Reference

## Existing `player_horses` storage

| Field | Current meaning |
| --- | --- |
| `id` | Database primary key |
| `stable` | Stable ID |
| `citizenid` | Owner |
| `horseid` | Public/unique horse identifier |
| `name` | Player name for horse |
| `horse` | Model string |
| `dirt` | Dirt value |
| `horsexp` | Training XP |
| `components` | JSON component indexes |
| `gender` | `male` or `female` |
| `wild` | Wild flag; newer registration code migrates it to `TINYINT(1)` |
| `stat_modifiers` | Wild-roll JSON, added by runtime migration if missing |
| `active` | Current active horse flag |
| `born` | Unix creation timestamp |

Reuse this table so existing owned horses remain available. Add columns with explicit migrations rather than replacing or renaming existing fields immediately.

## Existing `wagonmaker_wagons` storage

| Field | Current meaning |
| --- | --- |
| `id` | Primary key |
| `citizenid` | Owner |
| `model` | Wagon model string |
| `name` | Player wagon name |
| `plate` | Unique plate/reference string |
| `spawned` | Spawn-state flag |
| `props` | Prop customization text |
| `livery` | Livery index, default `-1` |
| `tint` | Tint index |
| `lantern` | Lantern model/name |
| `extra` | Extra index |
| `parking_location` | Parking/stable location ID |
| `created_at` | Creation timestamp |

The source also has transfer and log tables, but the stable plan does not require the wagonmaker job, employees, management funds, crafting, or material recipes.

## Inventory behavior worth reusing

### Horses

`rsg-horses` currently creates a per-horse stash identifier from `horse name + horseid`, with XP-dependent capacity. The new plan requires one player saddle-bag inventory that moves with the selected horse, capped at 20 kg. Therefore, do not preserve the name-based stash identifier as the new identity; renaming a horse would otherwise affect storage lookup.

Recommended stable identity concept: a citizen-owned constant stash ID, independent of horse name and active horse. Horse strength changes movement penalties, not the inventory ID or stored items.

### Wagons

`rsg-wagonmaker` uses `wagon_<database id>` and registers capacity from the wagon config. The new plan requires one free storage-enabled wagon and paid entitlements for additional wagon inventories. Keep wagon inventory identity tied to the database ID, but gate opening/registration on server-owned entitlement data.

## Ownership/security patterns to retain

- Derive `citizenid` from the server-side player object or framework identifier.
- Query by both object ID and citizen ID before every mutation.
- Validate model against server config before purchase/spawn.
- Validate component category and option bounds on the server.
- Calculate purchase, customization, and sale prices on the server.
- Remove money before inserting a purchase; refund on a failed insert if the database operation is awaited and fails.
- Never trust client-supplied stash capacity, slot entitlement, sale price, stable fee, or active state.
- Permit at most one active horse and one active wagon unless the final design explicitly changes that rule.

## New persistent data required by `Stables.md`

These are design fields, not migrations applied yet:

- Horse slot purchases above the 3 default slots.
- Wagon slot purchases above the 1 default slot.
- Resellable purchased-slot counts, never allowing defaults to be sold.
- Stable-fee playtime accumulator, updated server-side and persisted across disconnects.
- Wagon inventory entitlement count or per-wagon entitlement.
- Horse-to-wagon assignment, including ordered hitch position(s).
- Horse strength rank is canonical; carry and pull kilograms are derived rather than stored.
- Daily stable stock state and its next refresh time if stock must survive restarts.

For hourly stable fees, persist accumulated active play minutes in player metadata or a dedicated table. Increment it from a server timer while the player is online, charge at 60, subtract 60 only after handling the charge, and retain the remainder across logout.
