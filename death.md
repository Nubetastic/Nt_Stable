# Horse and Wagon Death

## Goal

Define how owned horses and wagons should behave when a spawned horse dies or a spawned wagon is destroyed.

This document records the agreed horse-death and wagon-destruction behavior.

## Horse Death Behavior

When the player's spawned riding horse dies, cache its death coordinates, mark the entity as no longer needed, and begin a three-minute revive window. During that window, monitor the horse's alive state, its distance from the owning player, and whether its released entity still exists.

### Revived Within Three Minutes

- Register `horse_reviver` as a usable inventory item. Do not depend on ox_target to select a dead horse.
- When used, find the closest dead horse ped within 1.5 units. This may be the player's horse, another player's horse, a wagon horse, or an ambient horse.
- Also attach a native Revive Horse prompt to every streamed dead horse ped. It appears with the standard right-mouse entity interactions and provides a second way to use the item.
- Both methods use the dead horse entity for approach and positioning. Walk the player toward it, shift the player beside it, face the horse, and then run the shared revive animation and logic.
- The player must have the `horse_reviver` item.
- Use the actual syringe animation path from `rsg-medic`: animation dictionary `mech_revive@unapproved`, animation name `revive`, prop `p_syringe01x`, attached to `SKEL_R_HAND`, with the existing three-second animation duration.
- Immediately before revival, check `IsEntityDead` again. If the horse is already alive, stop without reviving it or removing an item.
- Request network control of the horse before changing its dead or health state. Calling revival natives without control may only change a remote networked ped locally and is not reliable.
- Revive the horse ped with full health.
- After confirming the ped is alive, notify the server to remove one `horse_reviver` from the reviving player.
- If multiple players attempt the same horse, the last `IsEntityDead` check should normally stop later attempts. If two clients still complete simultaneously, both may lose their reviver items; no additional revive lock is required.
- The revive interaction only makes the horse ped alive again. It does not need to know whether the horse is owned, assigned to a wagon, or controlled by another resource.
- Do not use the reviving player's client action as the authoritative signal that the horse was revived.
- `Nt_Stables` independently monitors its tracked dead horses and recognizes a successful revive when `IsEntityDead` changes from dead to alive.
- Remove the riding horse's entity targets while it is dead and restore them after revival.
- Notify the owner when the horse dies that there are three minutes to revive it.
- Send one additional warning when ten seconds remain. Do not display a constant countdown.
- If revived, make the riding horse a mission entity again so the resource resumes controlling it.
- Restore the horse to a usable state so the player can continue riding and interacting with it.
- Cancel the permanent-death timer and retain the horse's ownership, active status, inventory, equipment, and training data.

### Permanent Death

- The horse becomes permanently dead when the three-minute revive window expires, when its cached death coordinates exceed the configured horse despawn distance from the owning player, or when its released dead entity despawns before revival.
- Remove the horse from the player's stable.
- The saddlebag belongs only to the active riding horse. Wagon horses do not use it.
- Do not provide saddlebag access on a dead horse.
- Do not clear, drop, or move the saddlebag inventory when a riding horse permanently dies.
- The character's saddlebag inventory remains stored and is applied to the next active riding horse.
- The dead horse was already marked as no longer needed when it died, allowing the corpse to despawn naturally at any time.
- Remove its target and blip and clear the local riding-horse state without explicitly deleting the corpse.
- The permanently dead horse cannot be called or recovered from a stable.

### Horse Death Requirements

- The server removes `horse_reviver` after the client reports a completed revive; horse ownership is not required for the generic revive interaction.
- The server must confirm horse ownership before permanently removing a tracked owned horse from stable records.
- Only one revive or permanent-death result may complete for a death, even if multiple players interact at the same time.
- The horse must not be removed from the stable before the complete three-minute revive window expires unless it exceeds the configured despawn distance or its released dead entity despawns first.
- Report an owned horse's pending death to the server when its revive window begins.
- If the owning player disconnects during that window, the server finalizes permanent horse removal but leaves the character's saddlebag inventory unchanged. No pending death is restored when the player reconnects.
- A successful revive cancels the server's pending-death state.

## Wagon Destruction Behavior

When the player's spawned wagon is destroyed, keep its storage tied to the wreck, mark the wreck as no longer needed, and begin handling each attached wagon horse.

### Wagon Horses

- Track whether each horse attached to the wagon is alive or dead when the wagon is destroyed.
- Living wagon horses flee and return to the stable.
- Mark each dead wagon horse as no longer needed and monitor the same revive timer and entity-despawn conditions used for a dead riding horse.
- Any nearby player may use a `horse_reviver` inventory item while within 1.5 units of a dead wagon horse.
- Recognize revival by tracking the horse entity changing from dead to alive, not from a client revive event.
- If its assigned wagon still exists and is driveable, the revived wagon horse remains available for the player to lead back to the wagon.
- Clear the horse's saved wagon slot when it dies and assign the revived horse to the player so the native Lead interaction becomes available.
- When a revived assigned horse comes within 5 units of its driveable wagon, attach it back into its saved wagon slot.
- Confirm the saved slot contains that horse after the attach native; continue monitoring if the attach attempt fails.
- If its assigned wagon has been destroyed, the revived wagon horse flees and returns to the stable.
- A wagon horse that flees after its wagon is destroyed is not made a mission entity again and naturally despawns.
- If a dead wagon horse is not revived before its revive window expires, or its released dead entity despawns first, it becomes permanently dead.
- Permanently dead wagon horses are removed from the player's horse ownership and stable records exactly like permanently dead riding horses.
- Removing a permanently dead wagon horse also removes all of its wagon assignments.
- Wagon horses do not carry the horse's saddlebag inventory while attached to a wagon. Their death must not drop, remove, or otherwise change the horse's saddlebag items.
- Dead and fleeing wagon-horse entities remain marked as no longer needed so they can despawn naturally.

### Wagon Entity and Inventory

- Keep the wagon storage `ox_target` option on the destroyed wagon while its wreck entity exists so the owner can remove cargo directly from the wreck.
- Do not reduce or relocate wreck cargo based on the surviving wagon horses' pull capacity.
- Remove the wagon blip and mark the destroyed wagon entity as no longer needed so the game can despawn the wreck naturally.
- When the wreck entity despawns, remove its target, clear the local wagon state, and delete whatever cargo remains in its inventory.
- If the owner disconnects while the wreck still exists, delete whatever cargo remains in its inventory.
- Do not explicitly delete the wagon wreck.
- Wagon destruction does not remove the owned wagon from the stable or clear its surviving horse assignments. Any permanently dead horse is removed from its assignment.
- The wagon can be spawned again after the destroyed instance has been cleaned up and every required horse slot has been filled.
- Treat `IsVehicleDriveable` as the candidate check for whether the wagon has become a wreck. This native must be verified in RedM before implementation.
- A wagon that remains driveable with at least one living horse attached is not considered destroyed. The player may return it to a stable or allow it to despawn normally.
- A wagon cannot be spawned from the stable unless every horse slot required by its configured wagon model is filled.

## Per-Entity Monitor Lifecycle

- Start a dedicated monitor thread whenever a riding horse or wagon is summoned.
- Keep the thread running while the tracked entity exists and its monitor flag is `true`.
- The thread records state changes while the entity is valid, including death, revival, wagon driveability, the revive deadline, inventory handling, and whether the entity was released as no longer needed.
- Cache every final state needed for cleanup before the entity disappears. Do not call entity natives after the entity no longer exists.
- When a horse dies, mark it as no longer needed but continue monitoring while its corpse exists.
- If the horse becomes alive during the revive window, record it as revived and perform the correct riding-horse or wagon-horse recovery behavior.
- If three minutes pass while the riding-horse corpse still exists, record permanent death and set the monitor flag to `false` without changing the saddlebag inventory.
- If a released dead entity despawns first, the entity-existence condition ends the thread. Its cached dead state then triggers permanent stable cleanup without changing the saddlebag inventory.
- After the monitoring loop ends, use the cached final-state flags to perform any required stable, metadata, wagon-assignment, and inventory changes.
- Each summoned entity receives one monitor, and its final processing must run only once.

## Remaining Validation

- Verify that `IsVehicleDriveable` reliably identifies a destroyed but still-existing RedM wagon.
- Prevent a destroyed wagon or its horses from earning training XP while cleanup or revival is pending.

## Implementation Areas

- `client/riding.lua`: detect riding-horse death and handle call/cleanup behavior.
- `client/ridingWagon.lua`: detect wagon destruction, track attached wagon-horse deaths and revivals, release the wreck, and return living horses to the stable.
- `client/training.lua`: ensure dead horses and destroyed wagons cannot earn training XP.
- `server/playerHorses.lua`: validate horse ownership, control revive deadlines, remove permanently dead horses, and clear inventory left behind when the tracked entity lifecycle ends.

Any RedM native used to determine whether a wagon is destroyed but still exists must be confirmed before implementation.
