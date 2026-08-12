# Horse Stats And Progression

Source: `rsg-horses/shared/horse_stats.lua`, `wild_horse_stats.lua`, `horse_progression.lua`, `horse_stats_client.lua`, and `server/server.lua`.

## Current stat model

| Stat | Native attribute index | Starting range | Final cap | Planned meaning |
| --- | ---: | ---: | ---: | --- |
| Health | 0 | 1-5 | 9 | Damage tolerance |
| Stamina | 1 | 1-5 | 9 | Sustained activity |
| Agility | 4 | 0-5 | 9 | Handling |
| Speed | 5 | 0-5 | 9 | Maximum travel speed |
| Acceleration | 6 | 0-5 | 9 | Time to reach speed |
| Strength | No native application | 1-5 | 9 | Saddle-bag carry and wagon pull capacity |

The former `carry` rank is now named `strength`. Existing breed values are unchanged. Strength is a logical script stat; neither reference resource supplies a native strength attribute.

## Strength weight scale

Carry capacity is 5 kg per current strength point. Pull capacity is double carry capacity, or 10 kg per strength point.

```text
carryWeight = strength * 5 kg
pullWeight = carryWeight * 2
```

| Strength | Carry weight | Pull weight |
| ---: | ---: | ---: |
| 1 | 5 kg | 10 kg |
| 2 | 10 kg | 20 kg |
| 3 | 15 kg | 30 kg |
| 4 | 20 kg | 40 kg |
| 5 | 25 kg | 50 kg |
| 6 | 30 kg | 60 kg |
| 7 | 35 kg | 70 kg |
| 8 | 40 kg | 80 kg |
| 9 | 45 kg | 90 kg |

The saddle bag still has a hard 20 kg inventory limit. Strength 1-3 horses become overloaded before reaching that limit; strength 4+ horses can carry a full saddle bag without a strength-based overload penalty.

For multi-horse wagons, total pull capacity is the sum of each assigned horse's pull weight. For example, two strength-4 horses provide `40 + 40 = 80 kg` of pull capacity.

## Native point mapping

`horse_stats_client.lua` converts calculated rank to `SetAttributePoints` values:

| Rank | Points |
| ---: | ---: |
| 0 | 0 |
| 1 | 50 |
| 2 | 100 |
| 3 | 200 |
| 4 | 350 |
| 5 | 550 |
| 6 | 800 |
| 7 | 1100 |
| 8 | 1400 |
| 9 | 1700 |

## Training levels

The current progression thresholds are read from `Config.HorseTraining.LevelThresholds`. The client logic presently resolves these XP bands: level 1 `0-99`, 2 `100-199`, 3 `200-299`, 4 `300-399`, 5 `400-499`, 6 `500-999`, 7 `1000-1999`, 8 `2000-2999`, 9 `3000-3999`, and 10 `4000+`.

| Level | Health | Stamina | Agility | Speed | Acceleration | Strength |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | +0 | +0 | +0 | +0 | +0 | +0 |
| 2 | +1 | +0 | +0 | +0 | +0 | +1 |
| 3 | +1 | +1 | +0 | +1 | +0 | +1 |
| 4 | +1 | +1 | +1 | +1 | +1 | +1 |
| 5 | +2 | +2 | +1 | +2 | +1 | +2 |
| 6 | +2 | +3 | +2 | +3 | +2 | +2 |
| 7 | +3 | +3 | +3 | +3 | +3 | +3 |
| 8 | +4 | +3 | +3 | +3 | +3 | +4 |
| 9 | +4 | +4 | +3 | +4 | +3 | +4 |
| 10 | +4 | +4 | +4 | +4 | +4 | +4 |

Final rank formula: `clamp(starting rank + training bonus, native minimum, 9)`.

## Wild-horse modifier system

- Randomly selects 3 of the 6 stats.
- Rolls 3 integers from `-3` through `+5` for each selected stat.
- The modifier is the three-roll average, rounded to two decimals.
- Applied starting ranks are clamped to the stat minimum and 5.
- Price changes by 20% per effective average modifier point.
- Stored JSON includes `version`, `selected`, `rolls`, `modifiers`, `average`, and `priceMultiplier`.

Price formula: `round(basePrice * (1 + effectiveAverageModifier * 0.20))`, never below zero.

## Current sale formula

Stable-bred base price comes from `horse_settings.lua`. Wild horses first receive the wild price multiplier. The server then calculates:

```text
sellPrice = round((adjustedShopPrice * 0.50) + (trainingLevel * adjustedShopPrice * SellPricePerLevel))
```

The server calculates this from trusted model, XP, wild state, and stored modifiers rather than accepting a client-supplied price.

## New-system decisions still needed

- Define the overload speed penalty curve above the 20 kg saddle-bag target.
- Decide which sizes are ineligible to pull wagons. Current sizes are `small`, `medium`, and `large`; size alone is available immediately as a first eligibility check.
- Decide whether native ranks should remain 0/1-9 internally or be converted to a player-facing percentage.
