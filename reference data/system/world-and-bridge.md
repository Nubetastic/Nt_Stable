# World, Routing, Camera, And NUI Bridge

## Existing stable/world data

`rsg-horses/shared/config.lua` defines stable IDs, NPC model/coords, interaction coords, customization horse coords, and blip visibility. Active locations are Van Horn, Saint Denis, Rhodes, Valentine, Strawberry, Blackwater, Tumbleweed, and Emerald Ranch; Colter is present but commented out.

`horse_settings.lua` additionally embeds one world spawn coordinate per sale horse. The new daily-stock system should replace that one-model-per-coordinate structure with:

- Stable identity and NPC/camera/customization coordinates.
- A keyed model catalog.
- A keyed list of eligible stock models per stable.
- A small set of display spawn points per stable.
- Server-selected daily stock entries and refresh timestamp.

## Suggested combined session flow

1. Player uses the stable NPC interaction.
2. Client focuses the configured NPC camera and opens the compact choice popup.
3. Horse or wagon management requests server-owned data.
4. Server validates the session and moves the player to bucket `2000 + source`.
5. Client fades out, spawns only the selected preview entity at configured preview coords, creates the scripted camera, then fades in.
6. NUI sends preview changes locally for immediate visuals.
7. Save/buy/sell actions go to the server for validation and persistence.
8. Exit closes NUI, destroys the camera and preview entities, restores controls/HUD, returns bucket 0, and places the player back at the stable NPC safely.

Every exit path should run the same cleanup: close button, Escape, resource stop, death, disconnect, NUI error, and server rejection.

## Existing NUI bridge pattern from wagonmaker

Client to browser uses `SendNUIMessage` action objects. Browser to client uses JSON POST to `https://${GetParentResourceName()}/callbackName` handled by `RegisterNUICallback`.

Observed browser actions:

- `open` - supplies wagon cards and material config.
- `close` - hides UI.
- `openOptions` - supplies title, options, callback name, and layout.
- `openManagement` - supplies balance, grade, and job.

Observed callback patterns include `close`, `selectWagon`, `selectLivery`, `selectTint`, `parkingMenuSelect`, and `parkingWagonOptionSelect`. The new NUI should use stable action names rather than sending an arbitrary callback name from Lua.

## Recommended bridge contract

### Client to NUI

| Action | Essential payload |
| --- | --- |
| `openNpcMenu` | `stableId`, NPC display name |
| `openHorseManager` | owned horse summaries, selected ID, slot totals |
| `openHorseShop` | daily stock summaries, selected model |
| `openHorseCustomize` | selected horse, component groups, current selections, prices |
| `openHorseStats` | base, wild modifier, training bonus, final stats, condition, sell value |
| `openWagonManager` | owned wagon summaries, selected ID, slot/inventory entitlements |
| `openWagonShop` | available models and price/category summaries |
| `openWagonCustomize` | selected wagon and tested options |
| `setPreview` | current entity summary and totals after server/client changes |
| `showConfirm` | title, warning, price, confirmation action token |
| `setBusy` | boolean plus optional label |
| `notifyError` | player-readable error |
| `close` | no payload |

### NUI to client

| Callback | Essential payload |
| --- | --- |
| `close` | current screen/session |
| `back` | current screen |
| `openSection` | fixed section ID |
| `selectHorse` | database horse ID |
| `selectStockHorse` | model ID/stock ID |
| `selectWagon` | database wagon ID or stock model ID |
| `previewHorseComponent` | horse ID, category, option index |
| `previewWagonOption` | wagon/model ID, category, option value |
| `requestSaveCustomization` | selected object ID and final selection set |
| `requestBuy` | stable stock ID/model plus player-entered name/gender when needed |
| `requestSell` | owned object ID |
| `assignHorseToWagon` | wagon ID, horse ID, hitch position |
| `manageSlot` | type (`horse`/`wagon`), operation (`buy`/`sell`) |
| `setScale` | scale value if Lua needs it; normal scale persistence can remain in browser local storage |

Validate every callback payload and treat preview updates as disposable. Only explicit server-confirmed actions change ownership or persistent configuration.

