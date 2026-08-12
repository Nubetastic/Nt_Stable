# Horse and Wagon Speed/Weight Systems

## Shared stat rules

Horse speed, strength, and stamina begin at their breed values in `shared/horse_stats.lua`.
Training bonuses can raise a stat to rank 9 at tame level 10, so calculations normalize horse stats against 9.

Existing weight values:

```text
horseCarryCapacityKg = horseStrength * 5
horsePullCapacityKg = horseStrength * 10
```

Inventory weights are stored in grams and must be converted before comparison:

```text
currentWeightKg = currentInventoryWeight / 1000
```

Inventory capacity and horse capacity serve different purposes:

- Wagon `maxWeight` is the wagon inventory limit.
- A riding horse inventory has a fixed 20 kg limit.
- Horse carry and pull capacities do not reject inventory items.
- Carry and pull capacities determine the speed penalty caused by the stored weight.

## Wagon speed system

All wagon models use the same absolute `wagonMaxSpeed`. The assigned horses determine what percentage of that speed the wagon can reach.

For a team, average the speed and strength stats of all harnessed horses and add their pull capacities together:

```text
averageSpeed = sum of horse speed / horse count
averageStrength = sum of horse strength / horse count
combinedPullCapacityKg = sum of (horse strength * 10)
```

Calculate the unloaded ability of the team:

```text
speedRating = averageSpeed / 9
strengthRating = averageStrength / 9

horseRating =
    (speedRating * 0.40)
    + (strengthRating * 0.60)

driveFactor = 0.60 + (horseRating * 0.40)
```

Strength receives 60% of the wagon rating so that strong horses are not worse wagon horses merely because their riding speed is low. The base factor of 0.60 keeps low-stat teams usable.

Calculate cargo burden against the combined pull capacity:

```text
loadRatio = currentWeightKg / combinedPullCapacityKg
loadFactor = 1 / (1 + 0.35 * loadRatio^2)
```

Final wagon speed:

```text
finalWagonSpeed = wagonMaxSpeed * driveFactor * loadFactor
```

The squared load ratio makes overload increasingly expensive without producing negative speed or an abrupt stop.

### Wagon comparison

This comparison uses a two-horse wagon with a 150 kg inventory maximum and an example `wagonMaxSpeed` of 10.

Teams at tame level 1:

| Team | Average speed | Average strength | Combined pull |
| --- | ---: | ---: | ---: |
| Two fast horses | 5 | 2 | 40 kg |
| Two strong horses | 1 | 5 | 100 kg |

| Cargo | Fast team | Strong team |
| ---: | ---: | ---: |
| 0 kg | 7.42 | 7.51 |
| 75 kg | 3.33 | 6.28 |
| 150 kg | 1.25 | 4.20 |

Teams at tame level 10 receive `+4 speed` and `+4 strength`:

| Team | Average speed | Average strength | Combined pull |
| --- | ---: | ---: | ---: |
| Two fast horses | 9 | 6 | 120 kg |
| Two strong horses | 5 | 9 | 180 kg |

| Cargo | Fast team | Strong team |
| ---: | ---: | ---: |
| 0 kg | 9.20 | 9.29 |
| 75 kg | 8.09 | 8.76 |
| 150 kg | 5.95 | 7.47 |

The strong team is slightly better empty and gains a clear advantage as cargo increases. Training makes both teams substantially better without removing the strong team's cargo advantage.

## Riding-horse speed system

A ridden horse uses its speed stat for unloaded pace. Strength affects riding speed only through the amount of cargo the horse can carry comfortably.

```text
carryCapacityKg = horseStrength * 5
loadRatio = currentWeightKg / carryCapacityKg

speedFactor = 0.60 + (0.40 * (horseSpeed / 9))
loadFactor = 1 / (1 + 0.35 * loadRatio^2)

finalHorseSpeed = horseMaxSpeed * speedFactor * loadFactor
```

`horseMaxSpeed` is the shared upper speed used for a perfect speed-rank-9 horse. Strength does not directly increase unloaded riding speed.

### Riding-horse comparison

This comparison uses the fixed 20 kg horse inventory and an example `horseMaxSpeed` of 10.

| Horse | Tame level | Speed | Strength | Carry capacity |
| --- | ---: | ---: | ---: | ---: |
| Fast horse | 1 | 5 | 2 | 10 kg |
| Strong horse | 1 | 1 | 5 | 25 kg |
| Fast horse | 10 | 9 | 6 | 30 kg |
| Strong horse | 10 | 5 | 9 | 45 kg |

| Horse | Tame level | Empty | 10 kg | 20 kg |
| --- | ---: | ---: | ---: | ---: |
| Fast horse | 1 | 8.22 | 6.09 | 3.43 |
| Strong horse | 1 | 6.44 | 6.10 | 5.27 |
| Fast horse | 10 | 10.00 | 9.63 | 8.65 |
| Strong horse | 10 | 8.22 | 8.08 | 7.69 |

An empty fast horse remains faster. Cargo allows strength to matter: at tame level 1 the horses are nearly equal at 10 kg, and the strong horse is faster at the full 20 kg. At maximum tame, training gives the fast horse enough strength to remain the faster mount while the strong horse experiences very little cargo slowdown.

## Stamina system

The same load ratio used by each speed system also controls stamina drain:

```text
staminaEfficiency = 1.35 - (averageStaminaRank * 0.07)
loadDrain = 1.00 + (1.50 * loadRatio^2)
staminaDrain = baseDrain * staminaEfficiency * loadDrain
```

For a ridden horse, `averageStaminaRank` is its stamina rank. For a wagon, it is the average stamina rank of the harnessed team.

Recommended starting rates:

| Movement | Base stamina change |
| --- | ---: |
| Sprinting | -1.00 per second |
| Running below sprint | -0.35 per second |
| Walking or stopped | +1.50 per second |

Recommended low-stamina behavior:

| Stamina | Effect |
| ---: | --- |
| 25-100 | No additional speed limit |
| 1-25 | Gradually reduce final speed by up to 25% |
| 0 | Limit movement to walking speed until stamina recovers |

## Runtime rules

- Recalculate weight factors when an inventory changes rather than querying inventory every frame.
- Recalculate wagon team values when assigned horses change.
- A wagon without harnessed horses cannot be driven.
- Invalid or missing horse stats should report the bad data instead of silently supplying fallback stats.
- Reject inventory above its configured inventory maximum through the inventory system.
- Weight beyond horse carry or pull capacity remains valid but causes increasing speed and stamina penalties.
- Keep `wagonMaxSpeed`, `horseMaxSpeed`, and the `0.35` load penalty as config values for in-game tuning.
