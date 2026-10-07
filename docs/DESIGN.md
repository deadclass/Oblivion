# Design and movement direction

The Quiet Relay is a provisional name for a single-room slice within Oblivion. A lone maintenance light explores a listening chamber that has stopped answering. The entrance is in the west; a pursuing guard protects a resonant weight at the far eastern end. Cross drifting platforms and architectural obstacles, defeat the guard, carry the weight back to the western high cradle, and restore a bridge and the eastern exit.

The atmosphere comes from distance, silent architecture, dust, subdued teal masonry, and small warm lights. All visuals are original procedural geometry. Rules remain visible through interaction labels, checkpoint lights, hearts, and the guard's orange attack warning. Reference games inform atmosphere only.

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

## Chamber and drifting platforms

The room is 2304 pixels wide, twice the original width. The player starts at x=95; the guard starts at x=2090 beside the weight at x=2150. The cradle remains on the high western moving support. Two eastern upper galleries at y=292 form a second floor, reached by steps near the center and a compact zigzag route at the far eastern end. Floor blocks, gallery blocks, and suspended ledges complicate the route without adding new movement abilities.

Ten supports use `AnimatableBody2D`, with smooth sinusoidal horizontal reversals and slight vertical bob. Main floors and architecture remain fixed. Motion is tunable in `scripts/moving_platform.gd`, with distinct assignments in `world.gd`.

| Moving support | Horizontal amplitude | Peak horizontal speed | Vertical amplitude |
| --- | --- | --- | --- |
| Western lower | 115 px | 42 px/s | 6 px |
| Western middle | 150 px | 58 px/s | 8 px |
| Western cradle | 170 px | 76 px/s | 5 px |
| Pit crossing | 12 px | 20 px/s | 3 px |
| Eastern lower | 35 px | 28 px/s | 4 px |
| Eastern middle | 35 px | 36 px/s | 5 px |
| Eastern upper | 28 px | 44 px/s | 4 px |
| Far eastern lower | 8 px | 25 px/s | 3 px |
| Far eastern middle | 8 px | 33 px/s | 3 px |
| Far eastern upper | 8 px | 40 px/s | 3 px |

Amplitude is distance from the original center in either direction. Speeds vary through each cycle and are highest near the center. The pit-crossing support is intentionally restrained so the central gap can be crossed before the bridge is restored. The listening cradle and placed weight follow the highest western support. Grounded actors and dropped weight ride supports; controlled jumps do not inherit a platform's departure speed. Backspace restores initial phases; R preserves room motion.

The bounded camera follows player movement horizontally and vertically. The controls, health, status, and pause label use a fixed `CanvasLayer` so scrolling does not move them.

## Pursuing guard and two batons

The player runs at 255 px/s and the guard at 247 px/s. The 8 px/s difference is about 3.2% of guard speed, retaining a small normal-running advantage. Carrying reduces player speed and prevents starting a player swing.

The former dummy is now the chamber's single enemy, still implemented in `dummy.gd`. It waits at the eastern weight until the player comes within 480 px horizontally and 330 px vertically, then remains alerted and pursues. Planning predicts moving support positions, samples ballistic paths, and chooses reachable jumps around intervening geometry. The guard and player collide with room geometry rather than each other.

Left mouse button swings the player's baton in the facing direction. One click deals at most one damage per target during a 140 ms swing, with a 300 ms cooldown. Reach is 66 px beyond the hand offset. Holding does not repeat attacks.

The guard's independent weapon lives in `enemy_melee.gd`. A 300 ms orange windup precedes a 140 ms active strike, then 650 ms recovery. Its reach is 60 px, its vertical attack range is 38 px, and it removes one player heart per successful swing. Facing is locked through windup and strike; the guard stops advancing during that commitment. A physics ray blocks attacks through solid room geometry. Per-swing target tracking prevents repeated damage during the active window.

A combat hit grants 800 ms combat invulnerability and applies 165 px/s horizontal knockback with a brief upward impulse. Player steering resumes after the short knockback interval. A hit while carrying drops the weight. The guard has five health, with health/hit feedback and damage flashes. At zero health its movement and weapon stop; gravity and platform support still apply.

## Puzzle, checkpoints, and resets

E picks up or drops the weight. When carrying near the moving western cradle, E places it only after guard defeat, restoring the bridge and opening the eastern gate. Attempting placement while the guard survives gives a sealed-cradle prompt and keeps the weight carried. E elsewhere still drops it. Loose weight falls against the same platform geometry and returns to its eastern start if lost in the pit.

The prompt and E interaction share `cradle_in_reach()`: player position must be strictly less than 65 px from `socket_position() + Vector2(0,-5)`. Exactly 65 px is outside placement range; while carrying with the relay unsolved, the prompt is hidden and E uses ordinary drop behavior there. While carrying in range, `E / PLACE` appears when the guard is defeated or already at zero health, including before the defeat flag updates; a living guard instead shows `DEFEAT THE GUARD`. Solved or non-carrying states hide the prompt.

Five hearts allow fall and combat mistakes. A 180+ px apex-to-landing drop removes one heart once per qualifying landing. A pit fall removes one heart and returns to the checkpoint with remaining health. At zero hearts, recovery restores five hearts. First activation of each lower-floor checkpoint, at x=580 and x=1840, heals fully.

R restarts and heals at the current checkpoint. R/death recover carried weight to the eastern start, cancel both weapons, and grant one second of combat grace while retaining relay and guard progress. Killing the guard remains effective across these recoveries. T restores the guard at its eastern spawn with five health, zero hits, and unalerted planning/weapon state, cancels the player's swing, and relocks an unsolved cradle. An already restored relay stays open. Backspace clears the room, puzzle, checkpoints, completion, guard, health, and platform phases. No save persists between launches.

Godot's built-in `CharacterBody2D`, `AnimatableBody2D`, `StaticBody2D`, collision shapes, shape queries, rays, and `move_and_slide()` cover actors, moving supports, weight, bridge, gate, and melee collision. Scripts supply the desired acceleration, jump forgiveness, planning, and combat/puzzle rules. No extra physics library or art application is needed.

See [guarded-chamber revision](GUARDED_CHAMBER_REVISION.md) and [setup/verification](SETUP.md). [Health/melee](LOCAL_HEALTH_MELEE_REVISION.md) and [moving/evasive-dummy](MOVING_CHASE_REVISION.md) notes document earlier iterations. Audio, gamepad bindings, remapping, persistence, and a larger world remain outside this slice. Next decisions should come from playtest observations rather than adding systems preemptively.
