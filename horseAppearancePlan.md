# Horse Appearance Cache Implementation

## Data contract

Add `player_horses.appearance` as nullable `LONGTEXT`. Store JSON containing:

- `version`
- `scale`, truncated to two decimal places
- `categories`, as category hashes
- `components`, with each complete drawable, albedo, normal, material, palette, and tint tuple

Dirt remains in the existing `dirt` column and is not part of the appearance cache.

## Capture paths

1. Stable-stall purchase captures the purchased stall entity before it closes and saves the cache against the returned horse database ID.
2. Auction horse data carries `appearance` through listing, receiving, and insertion into the buyer's stable.
3. Auction receipt triggers missing-cache backfill for legacy auction records.
4. Horse customization captures the final preview entity and saves `components` and `appearance` together.
5. Player load requests owned horses whose appearance is null or empty. The client spawns each model locally, applies its saved gender and customization, captures it, saves it, and deletes it.

## Wagon application

1. Spawn the wagon networked and allow its engine-created draft horses to remain attached.
2. Do not detach, delete, replace, or network-register the engine-created horses.
3. Cache each engine horse's current tags so its harness tags remain available.
4. Remove the mapped head, body, mane, tail, and feathering categories.
5. Apply the assigned horse's cached complete tags.
6. Refresh MetaPed variation, wait 500 ms, apply cached scale with native `0x25ACFC650B65C538`, and wait another 500 ms.
7. Keep the existing assigned-horse lifecycle and wagon monitoring data attached to the retained engine horse handles.

## Validation

- Stable purchase immediately creates an appearance cache.
- Auction transfer preserves an existing cache and backfills a legacy missing cache.
- Saving customization updates the cache.
- Player load backfills only missing records and deletes temporary horses.
- Wagon horse keeps its harness while matching coat, head, mane, tail, feathering state, and scale.
- Test both feathered and non-feathered assigned horses.
- Test one-horse and multi-horse wagons, wagon recall, distance despawn, destruction, and rebuild/rehitch.
- Test from a second client because attached engine horses are locally created/non-networked entities.
