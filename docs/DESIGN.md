# Design and movement direction

The Quiet Relay is a provisional name for a single-room slice within Oblivion. A lone maintenance light explores a listening chamber that has stopped answering. Carry a resonant weight onto three drifting steps, place it in the high cradle, and restore a bridge to an eastern doorway. A lower-floor checkpoint provides recovery. Five hearts allow occasional fall mistakes; a harmless evasive dummy provides a separate training chase.

The atmosphere comes from distance, silent architecture, dust, subdued teal masonry, and small warm lights. All visuals are original procedural geometry. The first room teaches its interaction clearly; later rooms could reveal older signals through incomplete architectural patterns while keeping their rules discoverable. Reference games inform atmosphere only.

## Player movement defaults

Parameters live in `prototypes/quiet-relay/scripts/player.gd` as `@export` defaults. The player is created programmatically in `world.gd`; edit defaults or assign instance properties after creation. There is currently no scene instance for inspector-based tuning.

| Parameter | Value |
| --- | --- |
| Run speed | 255 px/s |
| Ground acceleration | 2100 px/s^2 |
| Air acceleration | 1400 px/s^2 |
| Ground braking | 2600 px/s^2 |
| Jump impulse | 550 px/s upward |
| Ascent gravity | 1450 px/s^2 |
| Descent gravity | 1850 px/s^2 |
| Terminal fall speed | 800 px/s |
| Coyote time | 105 ms |
| Jump buffer | 120 ms |
| Release jump cut | Upward speed limited to 210 px/s |
| Carry speed | 84% of normal; jump height unchanged |
| Large-fall threshold | 180 px from airborne apex to landing |
| Physics rate | 120 Hz |

Earlier automated measurements recorded 106.61 px held-jump height and 33.82 px brief-jump height. These are historical simulation measurements; human assessment of feel remains outstanding.

## Drifting platforms and cradle

All three raised platforms use `AnimatableBody2D`, with smooth sinusoidal horizontal reversals and slight independent vertical bob. The two floor sections remain static. Motion is tunable in `scripts/moving_platform.gd`, with distinct instance assignments in `world.gd`.

| Platform | Horizontal amplitude | Peak horizontal speed | Vertical amplitude |
| --- | --- | --- | --- |
| Lower | 115 px | 42 px/s | 6 px |
| Middle | 150 px | 58 px/s | 8 px |
| Upper | 170 px | 76 px/s | 5 px |

Amplitude is distance from the original center in either direction. Speeds vary through each cycle and are highest near the center. The listening cradle moves with the highest platform, and a placed weight stays with it. Grounded actors and dropped weight ride their supports; controlled jumps do not inherit a platform's departure speed. Backspace restores platform phases to their initial positions. R preserves the moving room state.

## Training chase and baton

The player runs at 255 px/s and the dummy at 247 px/s. The 8 px/s difference is about 3.2% of the dummy's speed, creating a small normal-running advantage. Carrying reduces player speed and prevents attacks, so place the weight before chasing.

The dummy flees horizontally, predicts nearby moving-platform destinations, and samples ballistic paths before jumping. It avoids unreachable landings, platform undersides, and intervening collision surfaces. Short decision pauses, occasional floor hops, and bounded boundary retreats keep the chase varied. It stays west of the open pit. The dummy cannot attack or damage the player and is not an enemy.

Left mouse button swings the baton in the player's facing direction. One click deals at most one damage per target during a 140 ms swing, followed by a 300 ms cooldown. Reach is 66 px beyond the hand offset. Holding the button does not repeat attacks. The five-health dummy shows its remaining health, hit count, flash, and floating damage; at zero health it stops autonomous movement while remaining subject to gravity and platform support. T resets its health, hit count, spawn position, velocity, and planning state.

## Puzzle, health, and recovery rules

E picks up or drops the weight. When carrying near the moving high cradle, E places it and restores the relay. Loose weight falls against the same platform geometry and returns to its start if lost in the pit. The player and dummy pass through the weight and each other, keeping pickup and chase interactions predictable.

A 180+ px apex-to-landing drop removes one heart once per qualifying landing. A pit fall removes one heart and returns to the checkpoint with remaining health. At zero hearts, recovery restores five hearts. First checkpoint activation and R restart heal fully. R/death recover carried weight and cancel attacks while retaining relay and dummy progress. Backspace clears the room, puzzle, checkpoint, completion, dummy, health, and motion phases. No save persists between launches.

Godot's built-in `CharacterBody2D`, `AnimatableBody2D`, `StaticBody2D`, collision shapes, and `move_and_slide()` cover actors, moving supports, falling weight, bridge, and gate. Scripted acceleration, jump forgiveness, planning, and hit rules supply the desired behavior. No extra physics library or art application is needed.

See [health/melee rules](LOCAL_HEALTH_MELEE_REVISION.md), [moving-platform/chase revision](MOVING_CHASE_REVISION.md), and [setup/verification](SETUP.md). Audio, enemies, gamepad bindings, remapping, persistence, and a larger world remain outside this slice. Next decisions should come from playtest observations rather than adding systems preemptively.
