# Nt_Stables Reference Index

These notes extract reusable data and behavior from the bundled `rsg-horses` and `rsg-wagonmaker` resources. They are build references, not a request to modify either source resource.

## Horses

- [breeds.md](horses/breeds.md) - current sale models, breed, size, base stats, prices, and stable assignments.
- [stats-and-progression.md](horses/stats-and-progression.md) - stat ranks, training, wild modifiers, selling, and pull-strength design notes.
- [components.md](horses/components.md) - component categories, counts, hashes, indexes, and customization behavior.
- [natives.md](horses/natives.md) - horse spawning, ownership, stats, components, interaction, and camera natives used by `rsg-horses`.

## Wagons

- [models.md](wagons/models.md) - active wagon models, categories, storage values, grades, and option counts.
- [natives.md](wagons/natives.md) - wagon spawn, preview, draft-horse cleanup, and customization natives used by `rsg-wagonmaker`.

## Shared systems

- [storage-and-ownership.md](system/storage-and-ownership.md) - current SQL fields, inventories, ownership checks, and fields the new design still needs.
- [world-and-bridge.md](system/world-and-bridge.md) - stable/world flow, routing buckets, camera flow, and NUI message conventions.

## Source cautions

- Native names in these notes use the names or comments present in the source scripts. Hash-only calls marked **unresolved** must be verified in RedM before relying on a guessed name.
- The horse catalog contains a source-label mismatch: model `a_c_horse_turkoman_silver` is displayed as **Thoroughbred Silver**. Its stat profile identifies it as a Turkoman.
- `rsg-horses` does not contain per-model outfit counts. Those must be collected in game and then added to `breeds.md` or the final config.
- `rsg-wagonmaker` has additional wagon definitions inside Lua block comments. `wagons/models.md` lists only currently active definitions.

## Primary source files

- `rsg-horses/shared/horse_settings.lua`
- `rsg-horses/shared/horse_stats.lua`
- `rsg-horses/shared/wild_horse_stats.lua`
- `rsg-horses/shared/horse_progression.lua`
- `rsg-horses/shared/horse_comp.lua`
- `rsg-horses/client/client.lua`
- `rsg-horses/server/server.lua`
- `rsg-wagonmaker/config/config.lua`
- `rsg-wagonmaker/client/preview.lua`
- `rsg-wagonmaker/client/parking.lua`
- `rsg-wagonmaker/server/parking.lua`
- `rsg-wagonmaker/sql/wagonmaker.sql`

