# Wagon Native Reference

Observed in `rsg-wagonmaker/client/preview.lua` and `client/parking.lua`.

## Spawn, network, and ownership

| Native/function | Observed call | Purpose |
| --- | --- | --- |
| `CreateVehicle` | `(modelHash, x, y, z, heading, true, true, false, false)` | Spawns preview or owned wagon. Preview is frozen and invincible. |
| `0x7263332501E07F52` | `(wagon, true)` | Source comment says place wagon on ground properly. Native name is unresolved in the source. |
| `NetworkRegisterEntityAsNetworked` | `(wagon)` | Explicitly networks an owned wagon. |
| `NetworkGetNetworkIdFromEntity` | `(wagon)` | Produces the net ID stored in the server's active-wagon map. |
| `0xD0E02AA618020D17` | `(PlayerId(), wagon)` | Source uses this during owned-wagon setup; exact native name is unresolved. |
| `0x23F74C2FDA6E7C61` | `(-1230993421, wagon)` | Commented `BlipAddForEntity`. |
| `0x9CB1A1623062F402` | `(blip, wagon.name)` | Commented `SetBlipName`. |
| `DeleteVehicle` / `DeleteEntity` | `(wagon)` | Removes preview/stored wagons after requesting network control when needed. |

The server verifies `wagonId + citizenid` before marking a wagon spawned, stored, renamed, moved, or deleted. Keep that pattern in the combined resource.

## Draft-horse handling

| Native/function | Observed call | Purpose |
| --- | --- | --- |
| `0xB32A5813C7F87B09` | `(wagon)` | Source calls this repeatedly during preview to delete/remove automatically spawned draft horses. Exact native name is unresolved. |
| `GetGamePool('CPed')` | pool scan | Preview fallback finds nearby peds. |
| `IsEntityAttachedToEntity` | `(ped, wagon)` | Detects draft peds attached to the preview wagon. |
| `IsModelAHorse` | `(GetEntityModel(ped))` | Fallback filters nearby peds before deletion. |

The fallback deletes any horse within 15 meters of the preview after checking attachments. That is too broad for a shared stable customization area. The new resource should isolate previews and target only known spawned/attached draft entities.

Neither script shows how to attach a specific player-owned horse to a wagon. This is a genuine missing research item and should be verified in RedM before implementation.

## Customization

| Native hash | Observed call | Source meaning |
| --- | --- | --- |
| `0x8268B098F6FCA4E2` | `(wagon, tintIndex)` | Apply wagon tint/color. |
| `0xF89D82A0582E46ED` | `(wagon, liveryIndex)` | Apply wagon livery when index is 0 or greater. |
| `0x75F90E4051CC084C` | `(wagon, GetHashKey(propsName))` | Apply wagon props. |
| `0xC0F0417A90402742` | `(wagon, GetHashKey(lanternName))` | Apply wagon lantern. |
| `0xBB6F89150BC9D16B` | `(wagon, extraIndex, disable)` | Disable all existing extras, then enable the selected extra by passing `false`. |
| `DoesExtraExist` | `(wagon, index)` | Tests extra indexes 0 through 10 before toggling. |

Apply order in the source is tint, livery, props, lantern, disable existing extras, enable selected extra. Persistence fields are `props`, `livery`, `tint`, `lantern`, and `extra`.

Current source customization prices are livery $15, tint $25, props $20, and lantern $10. The combined stable design can retain these only as starting reference values.

## Preview behavior

- Load model, create a networked wagon, place on ground, freeze, make invincible, and remove auto-created draft horses.
- Apply saved/default customization and clean dirt with `SetVehicleDirtLevel(wagon, 0.0)`.
- Add local target entries for livery and tint.
- Rotate with `SetEntityHeading` while left/right controls are held.
- End preview on prompt/timeout, remove target entries, delete the wagon, and clear state.

The source preview does not create a scripted camera or routing bucket. The combined system should reuse the horse isolation/camera concept for consistent horse and wagon management.

## Prompt and map hashes also used

| Hash | Observed role |
| --- | --- |
| `0x04F97DE45A519419` | Begins prompt registration for preview, parking, stash, store, and crafting prompts. |
| `0xC92AC953F0A982AE` | Tests whether a prompt completed. |
| `0x554D9D53F696D002` | Adds a coordinate/radius-style blip for wagon NPCs/zones. |
| `0x74F74D3207ED525C` | Applies the configured blip sprite. |
| `0x9CB1A1623062F402` | Applies the blip name. |
| `0xD38744167B2FA257` | Applies the blip scale. |
