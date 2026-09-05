# Horse Training

## Goal

Owned horses gain training XP through normal use. Training XP raises the existing tame level and applies the stat bonuses already defined in `shared/horse_stats.lua`.

Only registered horses can gain training XP. Wild horses must be registered first.

## Training Activities

### Riding

- Award 10 XP for every 10 minutes of active riding.
- The player must be mounted on their owned horse.
- Time only counts while the horse is moving.
- Passenger time does not count.

### Leading

- Award 11 XP for every 10 minutes of actively leading an owned horse.
- This is a 10% XP boost over riding.
- Time only counts while the player and horse are moving.

### Wagon Pulling

Wagon training is awarded only to owned horses assigned to and currently attached to the player's active wagon. Time only counts while the wagon is being driven and moving.

| Horses attached | XP per horse per 10 minutes | Total team XP |
| --- | ---: | ---: |
| 1 | 10 | 10 |
| 2 | 7 | 14 |
| 4 | 5 | 20 |

This makes training several horses together faster overall than training them individually, while each horse progresses slower than a single ridden or single wagon horse.

### Horse Care

Horse care provides minor bonus XP:

| Action | XP | Cooldown |
| --- | ---: | ---: |
| Petting | 1 | 10 minutes per horse |
| Grooming | 2 | 10 minutes per horse |
| Feeding | 2 | 10 minutes per horse |

Each action has its own cooldown. Repeating an action during its cooldown gives no additional XP.

## Existing Level Progression

The current XP thresholds remain unchanged:

| Level | XP required |
| --- | ---: |
| 1 | 0 |
| 2 | 100 |
| 3 | 200 |
| 4 | 300 |
| 5 | 400 |
| 6 | 500 |
| 7 | 1,000 |
| 8 | 2,000 |
| 9 | 3,000 |
| 10 | 4,000 |

XP stops increasing after 4,000 because level 10 is the maximum useful training level.

## Tracking Rules

- Track active riding, leading, and wagon time on the client in short intervals.
- Do not award training while stationary, dead, fleeing, or after the horse or wagon is dismissed.
- Send completed training blocks to the server instead of writing XP every interval.
- The server confirms that each horse belongs to the player before updating `player_horses.horsexp`.
- Wagon awards use the server's saved wagon assignments so a client cannot submit unrelated horse IDs.
- Petting, grooming, and feeding awards require the owned horse to be spawned and nearby.
- Training progress resets when the relevant horse or wagon entity changes. Earned completed blocks are retained.

## Player Feedback

- Do not notify for every movement check.
- Notify when XP is awarded: `Horse Name gained 10 training XP.`
- Notify when a horse reaches a new level: `Horse Name reached training level 2.`
- Refresh the current horse data after an award so the horse information screen shows the new tame level and stats.
- Newly earned stat bonuses apply immediately when practical; otherwise they apply the next time the horse is spawned.

## Implementation Areas

- `shared/configStables.lua`: training rates, movement requirement, award interval, care XP, and cooldowns.
- `client/riding.lua`: riding, leading, petting, grooming, and feeding activity detection.
- `client/ridingWagon.lua`: active wagon movement and attached owned-horse tracking.
- `server/playerHorses.lua`: ownership validation, cooldown validation, XP updates, level-up checks, and refreshed horse data.

The exact RedM events or natives used to identify leading, petting, grooming, and feeding must be confirmed against the behavior available in the running server before implementation.
