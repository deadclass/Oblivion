# Initial design and movement direction

The Quiet Relay is a provisional name for a single-room slice within Oblivion. A lone maintenance light explores a listening chamber that has stopped answering. Carry a resonant weight up broken steps, place it in a high cradle, and restore a bridge to an eastern doorway. A checkpoint provides recovery from the only lethal hazard: a dark pit.

The atmosphere comes from distance, silent architecture, dust, subdued teal masonry, and small warm lights. All visuals are original procedural geometry. The first room teaches its interaction clearly; later rooms could reveal older signals through incomplete architectural patterns while keeping their rules discoverable.

## Movement defaults

Parameters live in `prototypes/quiet-relay/scripts/player.gd` as `@export` defaults. The player is created programmatically in `world.gd`; edit defaults or assign properties after creation. There is currently no scene instance for inspector-based tuning.

| Parameter | Value |
| --- | --- |
| Run speed | 255 px/s |
| Ground acceleration | 2100 px/s² |
| Air acceleration | 1400 px/s² |
| Ground braking | 2600 px/s² |
| Jump impulse | 550 px/s upward |
| Ascent gravity | 1450 px/s² |
| Descent gravity | 1850 px/s² |
| Terminal fall speed | 800 px/s |
| Coyote time | 105 ms |
| Jump buffer | 120 ms |
| Release jump cut | Upward speed limited to 210 px/s |
| Carry speed | 84% of normal; jump height unchanged |
| Physics rate | 120 Hz |

The current automated harness measures a held-jump height of 106.61 px and a brief-jump height of 33.82 px. These are simulation results; feel still needs human assessment.

## Puzzle and recovery rules

E picks up or drops the weight. When carrying near the high cradle, E places it and restores the relay. Loose weight falls against the same platform geometry and returns to its start if it falls into the pit. The weight does not collide with the player's body, keeping carry/drop behavior predictable.

R returns to the last checkpoint and recovers a carried weight to its start. The restored relay survives that restart. Backspace clears the entire room, checkpoint, and completion state. The checkpoint lights when crossed on the lower floor. No save persists between launches.

Godot's `CharacterBody2D`, `StaticBody2D`, shape collisions, and `move_and_slide()` cover the player, falling weight, platforms, bridge, and gate. Scripted acceleration and jump forgiveness supply the desired feel. No extra physics library or art application is needed for this slice.

Out of scope so far: audio, combat, gamepad bindings, remapping, save persistence, and a larger world. Next decisions should come from playtest observations rather than adding systems preemptively.
