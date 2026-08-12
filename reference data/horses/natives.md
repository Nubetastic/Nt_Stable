# Horse Native Reference

This is an observed-use reference from `rsg-horses`, not an independent native database. Hash names come from source comments where present; unresolved calls stay unresolved.

## Spawn and ownership

| Native/function | Observed call | Purpose in source |
| --- | --- | --- |
| `CreatePed` | `CreatePed(model, coords, heading, isNetwork, ...)` | Spawns sale, preview, and owned horses. Sale/preview horses can be local; active owned horses are networked. |
| `SetRandomOutfitVariation` / `0x283978A15512B2FE` | `(horsePed, true)` | Chooses the base horse outfit. It does not return the outfit count. |
| `GET_NUM_META_PED_OUTFITS` / `0x10C70A515BC03707` | `(horsePed)` | Returns the number of meta-ped outfits for a spawned horse; used by root `outfit.lua`. |
| `0x931B241409216C1F` | `(playerPed, horsePed, false)` | Commented `SetPedOwnsAnimal`. |
| `0xE6D4E435B56D5BD0` | `(playerId, horsePed)` | Commented `SetPlayerOwnsMount`; skipped when two-player riding is enabled. |
| `0xB8B6430EAD2D2437` | `(horsePed, GetHashKey('PLAYER_HORSE'))` | Commented `SetPedPersonality`. |
| `0xDF93973251FB2CA5` | `(playerId, true)` | Commented `SetPlayerMountStateActive`. |
| `0xAEB97D84CDF3C00B` | `(horsePed, false)` | Commented `SetAnimalIsWild`. |
| `0xCC97B29285B1DC3B` | `(horsePed, 1)` | Commented `SetAnimalMood`. |
| `0xFE26E4609B1C3772` | `(horsePed, 'HorseCompanion', true)` | Commented `DecorSetBool`. |
| `0xA691C10054275290` | Seen with `(playerPed, horsePed, 0)` and `(horsePed, playerId, 431)` | **Unresolved** relationship/ownership setup call. Verify before reuse. |
| `0xED1C764997A86D5A` | `(playerPed, horsePed)` | **Unresolved** ownership setup call. Verify before reuse. |
| `0x6734F0A6A52C371C` | `(playerId, 431)` | **Unresolved** player/horse setup call. |
| `0x024EC9B649111915` | `(horsePed, true)` | **Unresolved** horse setup call. |
| `0xEB8886E1065654CD` | `(horsePed, 10, 'ALL', 0)` | **Unresolved** horse setup call. |

The source also applies ped config flags with `0x1913FE4CBF41C463`. Flags are behavior-sensitive and should be copied only after testing the specific owned-horse behavior.

## Stats, cores, bonding, and condition

| Native/function | Observed call | Purpose |
| --- | --- | --- |
| `SetAttributePoints` | `(horse, attributeIndex, points)` | Applies health 0, stamina 1, agility 4, speed 5, acceleration 6. |
| `0x09A59688C26D88DF` | `(horse, 7, bondingPoints)` | Hash form of `SetAttributePoints` used for bonding. |
| `GetAttributePoints` | `(horse, 7)` | Reads bonding points. |
| `GetMaxAttributePoints` | `(horse, 7)` | Reads maximum bonding points. |
| `EnableAttributeOverpower` | `(horse, 0 or 1, 5000.0)` | Enables health/stamina overpower at the source's top level. |
| `0xF6A7C08DF2E28B28` | `(horse, 0 or 1, value + 0.0)` | Sets health or stamina overpower value. |
| `0x36731AC041289BB1` | `(horse, 0 or 1)` | Commented `GetAttributeCoreValue`. |
| `0xC6258F41D86676E0` | `(horse, 0 or 1, value)` | Commented `SetAttributeCoreValue`; used by feed/drink/graze. |
| `0x5DA12E025D47D4E5` | `(horse, 16, dirt)` | Applies stored horse dirt. |
| `0x147149F2E909323C` | `(horse, 16, ResultAsInteger())` | Reads horse dirt. |
| `0x5653AB26C82938CF` | `(horse, 41611, 0.0 or 1.0)` | Commented `SetCharExpression`; used to represent gender. |

The source's stat point application is client-side after a server callback. The new system should keep the calculated inputs server-owned and send only trusted horse data to the client.

## Components and variation

| Native/function | Observed call | Purpose |
| --- | --- | --- |
| `0xD3A7B003ED343FD9` | `(horse, shopItemHash, true, true, true)` | Commented `ApplyShopItemToPed`. |
| `0xD710A5007C2AC539` | `(horse, categoryHash, 0)` | Removes a component category. |
| `0xCC8CA3E88256E58F` | `(horse, false/0, true/1, true/1, true/1, false/0)` | Refreshes ped variation after component changes. |
| `0xA0BC8FAED8CFEB3C` | variadic ped call | Wrapped as `IsPedReadyToRender`. |
| `0x704C908E9C405136` | `(ped)` | Part of the source `UpdatePedVariation` sequence; unresolved. |

The optional holster shop item is `0xF772CED6`. Component category hashes and option counts are in [components.md](components.md).

## Native horse interaction prompts

| Native/function | Observed call | Purpose |
| --- | --- | --- |
| `PromptGetGroupIdForTargetEntity` | `(horsePed)` | Gets the native interaction group attached to the horse. |
| `0xA3DB37EDF9A74635` | `(playerId, horsePed, actionId, state, true)` | Commented `ModifyPlayerUiPromptForPed`. Source hides action IDs 28 cargo/items, 45 weapon storage, 49 brush, and 50 feed so its own actions can replace them. |
| `0xCD181A959CFDD7F4` | `(playerPed, horsePed, interactionHash, 0, 0)` | Commented `TaskAnimalInteraction`; used for feed, brush, and related animations. |
| `TaskMountAnimal` | `(playerPed, horsePed, timeout, seat, speed, ...)` | Optional automatic mounting. |
| `0x6A071245EB0D1882` | `(horsePed, playerPed, -1, 7.2, 2.0, 0, 0)` | Moves/calls the horse toward the player; exact native name unresolved in source. |

`action.lua` also uses:

- `0xED27560703F37258`, `0xED1F514AF4732258`, and `0xEFC4303DDC6E60D3` to retrieve horse action/scenario state; names are unresolved.
- `0xC5F428EE08FA7F2C` to enable registered prompts.
- `0xC92AC953F0A982AE` to detect prompt completion.
- `0x524B54361229154F` to start `WORLD_ANIMAL_HORSE_RESTING_DOMESTIC` in place.
- `0x57AB4A3080F85143` to test whether the horse is using a scenario.
- `0xAAB0FE202E9FC9F0` as another scenario-state check.

## Camera and isolated customization area

The horse customization flow uses these named natives:

1. Fade out and spawn a preview horse at `Config.StableSettings[*].horsecustom`.
2. Ask the server to place the player and preview entity into an isolated routing bucket.
3. `CreateCam('DEFAULT_SCRIPTED_CAMERA', true)`.
4. Position it from `GetOffsetFromEntityInWorldCoords(horse, 0, 3.5, 0)`, then add `1.5` Z.
5. `SetCamRot(camera, -15.0, 0.0, horseHeading + 180)` and `RenderScriptCams(true, ...)`.
6. Hide HUD/radar and disable player controls with `0x4D51E59243281D80`.
7. Rotate the horse with `SetEntityHeading` while left/right controls are held.
8. On exit, destroy cameras, restore controls/HUD/radar, delete preview entities, and restore bucket 0.

The source server uses `BucketID = source + 1000`. `Stables.md` specifies `2000 + server id`; the new resource should use that stated rule consistently. Also note that `SetPlayerRoutingBucket` normally takes a player source, while the reference passes the preview ped in one call. Treat entity routing as unresolved and test the correct entity bucket native/API rather than copying that call blindly.

## Other client hashes present in the source

These are retained so the reference index covers the remaining hash calls without assigning unproven names:

| Hash | Observed role |
| --- | --- |
| `0x23F74C2FDA6E7C61` | Adds the active-horse entity blip; source comment says `BlipAddForEntity`. |
| `0x9CB1A1623062F402` | Sets the active-horse blip name. |
| `0x9587913B9E772D29` | Called with `(horsePed, false)` immediately after spawn; unresolved. |
| `0x91AEF906BCA88877` | Tests the configured call-horse control. |
| `0x57EC5FA4D4D6AFCA` | Source comment says `GET_EVENT_DATA`; used for horse-related event buffers. |
| `0x50C803A4CD5932C5` | Called with `true` after medicine use; source only comments `core`. |
| `0xD4EE21B7CC7FD350` | Called with `true` after medicine use; source only comments `core`. |
| `0xE3144B932DFDFF65` | Used in the horse-cleaning sequence after brushing; unresolved. |
| `0xD8544F6260F5F01E` | Used in the horse-cleaning sequence with value 10; unresolved. |
| `0x43AD8FC02B429D33` | Gets a town/zone value from world coordinates. |
| `0x79923CD21BECE14E` | DataView call used by the DLC-presence helper. |
| `0x3B005FF0538ED2A9` | Returns the horse's wild/tamed state in wild registration. |
| `0x25ACFC650B65C538` | Sets player-ped scale during the source taming workaround. |
| `0x772A1969F649E902` | Tests whether a model is a horse model. |
| `0xFB4891BD7578CDC1` | Tests whether the horse has the configured saddle category. |
| `0x6D9F5FAA7488BA46` | Returns whether the horse ped is male. |

The wild-registration file also uses named `GetAttributeBaseRank` for health, stamina, agility, speed, and acceleration. It sends these observed ranks to the server, but the server should still validate model eligibility and clamp all values.
