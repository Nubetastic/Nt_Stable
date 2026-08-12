# Horse Components

Source: `rsg-horses/shared/horse_comp.lua`, `shared/config.lua`, `shared/functions.lua`, and `client/client.lua`.

The source stores a selected component as `{ Category = hashid }`. `hashid = 0` means remove that category. The full item hashes remain in `rsg-horses/shared/horse_comp.lua`; duplicating all 562 rows here would create a second catalog that could drift.

| Config key | Stored category | Category hash | Options | Current change price | First item hash | Last item hash |
| --- | --- | --- | ---: | ---: | --- | --- |
| Blankets | `blankets` | `0x17CEB41A` | 65 | $5 | `0x0FAE487F` | `0xC7688D20` |
| Saddles | `saddles` | `0xBAA7E618` | 138 | $2 | `0xAD4A6355` | `0x4BC19FC4` |
| Horns | `horns` | `0x05447332` | 14 | $10 | `0xC6C381F5` | `0xF09C56EE` |
| Saddlebags | `saddlebags` | `0x80451C25` | 50 | $3 | `0x5277E9BA` | `0xB433E1C3` |
| Stirrups | `stirrups` | `0xDA6DADCA` | 11 | $4 | `0x587DD49F` | `0x8D0BC7DA` |
| Bedrolls | `bedrolls` | `0xEFB31921` | 30 | $5 | `0x9FD99D7D` | `0x73D157B4` |
| Tails | `tails` | `0xA63CAE10` | 85 | $4 | `0x04951F22` | `0xF867D611` |
| Manes | `manes` | `0xAA0217AB` | 102 | $3 | `0x0235DBF1` | `0xFFF3B76A` |
| Masks | `masks` | `0xD3500E5D` | 51 | $3 | `0x08A78F53` | `0x5B22BA68` |
| Mustaches | `mustaches` | `0x30DEFDDF` | 16 | $2 | `0x004BBEED` | `0xF7203FC3` |

## Apply/remove sequence

Apply a selected item with native `0xD3A7B003ED343FD9`, then refresh the ped variation. Remove a category with native `0xD710A5007C2AC539` using the category hash, then refresh variation with `0xCC8CA3E88256E58F` and the script's `UpdatePedVariation` sequence.

The current price calculation charges once per category whose nonzero value differs from the initially loaded value. The server validates that the category exists and the index is between 0 and the category's option count before saving JSON.

## Design implications

- The source component data is a flat option list. It does not group saddle models into saddle types or identify color segments.
- Mane and tail options are flat shop-item hashes; they are not separated into style and color. The planned style selector plus color slider needs a curated mapping built from visual testing.
- Do not assume every component hash fits every horse model. The source does not contain compatibility metadata.
- Preserve the raw selected hashes or indexes while a horse is assigned to a wagon, even if its saddle is visually removed from the spawned draft horse.

## Outfit-count collector

Neither reference script originally enumerated the number of base outfits for each breed model. Root `outfit.lua` now provides `/houtfits`, which spawns each configured model temporarily and calls `GET_NUM_META_PED_OUTFITS`/`0x10C70A515BC03707`. Its F8 output is a Lua-ready `HorseOutfits` table.
