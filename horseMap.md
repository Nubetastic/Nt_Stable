# Wagon Horse MetaPed Map

## Capture set

This map uses 30 wagon/clone pairs from:

- `wagon_capture_20260906_211248.json`
- `wagon_capture_20260906_211616.json`
- `wagon_capture_20260906_211656.json`

All 30 captures returned complete asset and tint data. In every pair, the attached wagon horse and its free clone had identical category sets and identical component-tag sets when compared without array order.

## Confirmed identifiers

| Identifier | Meaning | Stable after clone |
|---|---|---|
| Model hash | Base horse model/variation | Yes |
| Category hash | MetaPed slot such as head, body, mane, or tail | Yes |
| Drawable hash | The component asset installed in a slot | Yes |
| Albedo hash | Color/pattern texture used by the drawable | Yes |
| Normal hash | Surface-detail texture | Yes |
| Material hash | Material/shading definition | Yes |
| Palette hash and tint 0-2 | Colors applied to the component | Yes |
| Complete tag tuple | Drawable, albedo, normal, material, palette, and three tints | Yes |
| Category array index | Current enumeration position only | No |
| Component array index | Current enumeration position only | No |
| Outfit hash | Returned `0` for all captured generated outfits | No useful value |

The safest identity for an installed appearance part is its complete tag tuple. The category hash is the durable identity for the slot that the tag belongs to. The current capture records both sets, but it does not yet prove which active tag belongs to which category.

## Known horse categories

These names are confirmed by the existing stable configuration, their JOAAT names, or the Shire/Arabian comparison capture.

| Part | Category hash | Signed decimal | Attached-wagon category index |
|---|---:|---:|---:|
| Head | `0x87C878D4` | `-2016905004` | 8 |
| Body | `0x6E50D98C` | `1850792332` | 12 |
| Tail | `0xA63CAE10` | `-1505972720` | 15-18 |
| Mane | `0xAA0217AB` | `-1442703445` | 17-19 |
| Feathering (hoof hair) | `0xEEDC3C76` | `-287556490` | 15-19 |

Feathering is optional and only some horse models contain it. The feathering, mane, and tail indexes can move, but their hashes remain unchanged.

## Captured category map

The attached wagon horses had a fixed category prefix from index 0 through 14. Categories after index 14 changed order. The free clone preserved the same category hashes but only indexes 0 through 5 stayed in the same positions.

| Attached index | Category hash | Signed decimal | Observation |
|---:|---:|---:|---|
| 0 | `0x2454D0C0` | `609538240` | Present in 30/30; wagon/clone index stable |
| 1 | `0xAE23BD33` | `-1373389517` | Present in 30/30; wagon/clone index stable |
| 2 | `0xCEF2FE70` | `-822935952` | Present in 30/30; wagon/clone index stable |
| 3 | `0xD033ABB3` | `-801920077` | Present in 30/30; wagon/clone index stable |
| 4 | `0xD5F7712C` | `-705203924` | Present in 30/30; wagon/clone index stable |
| 5 | `0xEA523E18` | `-363708904` | Present in 30/30; wagon/clone index stable |
| 6 | `0x1BAE3F84` | `464404356` | Present in 30/30 |
| 7 | `0x2E51DCBA` | `777116858` | Present in 30/30 |
| 8 | `0x87C878D4` | `-2016905004` | Head |
| 9 | `0x97468069` | `-1756987287` | Present in 30/30 |
| 10 | `0xE4E083CF` | `-455048241` | Present in 30/30 |
| 11 | `0x4A4A3A1A` | `1246378522` | Present in 30/30 |
| 12 | `0x6E50D98C` | `1850792332` | Body |
| 13 | `0x7446508B` | `1950765195` | Present in 30/30 |
| 14 | `0xBEF64EB2` | `-1091154254` | Present in 30/30 |
| 15-19 | `0x8ACCE4B0` | `-1966283600` | Present in 30/30; order varies |
| 15-18 | `0xA63CAE10` | `-1505972720` | Tail; order varies |
| 16-18 | `0x070A7291` | `118125201` | Present in 30/30; order varies |
| 17-19 | `0xAA0217AB` | `-1442703445` | Mane; order varies |
| 15-19 | `0xEEDC3C76` | `-287556490` | Feathering (hoof hair); present in 20/30 |
| 19-20 | `0x5AC01D3B` | `1522539835` | Present in 30/30; order varies |
| 20-21 | `0x9734599B` | `-1758176869` | Present in 30/30; order varies |
| 21-22 | `0xAB3DE20D` | `-1422007795` | Present in 30/30; order varies |
| 22-23 | `0xCFCF2E90` | `-808505712` | Present in 30/30; order varies |
| 23-24 | `0x36A6D9FF` | `916904447` | Present in 30/30; order varies |
| 24-25 | `0xFACFC3C0` | `-87047232` | Present in 30/30; order varies |

## Wagon models captured

| Model hash | Samples | Active components | Categories | Feathering category `0xEEDC3C76` |
|---:|---:|---:|---:|---|
| `1066034872` | 6 | 10 | 26 | Present |
| `-586898625` | 4 | 10 | 26 | Present |
| `36009259` | 5 | 10 | 26 | Present |
| `937246805` | 5 | 10 | 26 | Present |
| `-1599683008` | 4 | 9 | 25 | Absent |
| `-1693870200` | 6 | 9 | 25 | Absent |

The feathering category correlates exactly with the tenth active component in this sample.

## Active component patterns

Across all 30 attached wagon horses:

| Component index | Drawable variation | Other variation |
|---:|---:|---|
| 0 | 1 drawable | All recorded values fixed |
| 1 | 1 drawable | 3 albedos |
| 2 | 1 drawable | All recorded values fixed |
| 3 | 1 drawable | All recorded values fixed |
| 4 | 1 drawable | 4 albedos and 6 tint sets |
| 5 | 1 drawable | 4 albedos and 6 tint sets |
| 6 | 1 drawable | 6 tint sets |
| 7 | 5 drawables | 3 albedos and 6 tint sets |
| 8 | 5 drawables | 3 albedos and 6 tint sets |
| 9 | 3 drawables | Present only on the four 10-component models; 2 albedos and 4 tint sets |

This shows that drawable alone is not always enough to describe a variation. Components 1 and 4-8 reuse drawables while changing albedo or tint values. Use the complete tag tuple when comparing or caching an appearance.

## Confirmed clone reorder

The active component permutation repeated for every model:

- Attached indexes `0, 1, 2` became clone indexes `2, 0, 1`.
- Attached indexes `3, 4, 5, 6` remained `3, 4, 5, 6`.
- For 9-component horses, attached indexes `7, 8` became clone indexes `8, 7`.
- For 10-component horses, attached indexes `7, 8, 9` became clone indexes `9, 7, 8`.

This proves that component index is deterministic for these two entity states, but it is not the identity of the part.

## Missing link

The captures enumerate category hashes with `_GET_PED_COMPONENT_CATEGORY_BY_INDEX` and active tags with `GET_META_PED_ASSET_GUIDS`. Those are separate arrays. Their identical numeric indexes do not establish a relationship.

The project already uses native `0x9B90842304C938A7` to request the category for an active component index on stable horses. That native is the intended bridge between the active tag and category hash, but the earlier attached-wagon test returned `0`. Until it returns a real category on the wagon horse or another mapping method is confirmed, assigning names such as coat, mane, or tail to component indexes would be speculation.

## Current conclusion

There are reliable identifiers shared across the variations:

1. Use the model hash for the base horse variation.
2. Use the category hash for a body-part slot.
3. Use the complete component tag tuple for the installed appearance asset.
4. Use palette and tint values as part of that tuple because several components share drawable hashes while their visible colors differ.
5. Do not use either array index as the permanent identifier.

The next useful diagnostic is a narrow category-to-active-tag mapping test. It should record the result of `0x9B90842304C938A7` beside every active component using the attached wagon horse and its clone, without changing either horse.
