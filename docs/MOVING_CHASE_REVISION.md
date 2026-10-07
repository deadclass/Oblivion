# Historical moving-platform and training-chase revision

This records the earlier three-platform/evasive-target iteration. The current [guarded chamber](GUARDED_CHAMBER_REVISION.md) replaces fleeing with armed pursuit, moves the weight and guard east, expands the room, and requires defeating the guard before placement. Current measured results are in [VERIFICATION.md](VERIFICATION.md).

Revision requested October 6, 2026 (America/Chicago). The room's three raised platforms now drift horizontally at different speeds and bob slightly vertically. The training dummy runs away and jumps between reachable supports, while the player keeps a small speed advantage. The attack control is the left mouse button. The Quiet Relay remains a provisional prototype name within Oblivion.

## Platforms and puzzle

`moving_platform.gd` uses Godot's `AnimatableBody2D`. Each raised platform follows smooth horizontal cycles, with distinct tuning assigned in `world.gd`:

| Platform | Horizontal amplitude | Peak speed | Vertical amplitude |
| --- | --- | --- | --- |
| Lower | 115 px | 42 px/s | 6 px |
| Middle | 150 px | 58 px/s | 8 px |
| Upper | 170 px | 76 px/s | 5 px |

Amplitudes are travel from the center in either direction. The floor sections remain static; pit, bridge, and gate locations are preserved. Grounded riders and dropped weight travel with platform collision bodies. The listening cradle and placed weight follow the upper platform. Backspace resets the platforms to their initial phases alongside the rest of the room. R retains current platform motion and restored puzzle progress.

## Harmless pursuit target

Normal player speed is 255 px/s; dummy speed is 247 px/s, an 8 px/s difference and about 3.2% advantage relative to the dummy. Carrying reduces player speed to 84% and prevents starting a baton swing.

The dummy is now a world-colliding `CharacterBody2D`, with a separate child `Area2D` for the existing melee query. It chooses a horizontal direction away from the player, predicts future moving-platform positions, and samples candidate ballistic paths. It rejects unreachable landings, underside collisions, and blocking surfaces. Air steering follows the predicted landing. Short planning pauses, occasional floor hops, and committed boundary retreats provide pursuit opportunities. Safe bounds keep it west of the pit.

The dummy is still a training target, with no attack or player-damage behavior. Health, hit counter, flash, floating damage, and reset prompt remain. Zero health stops autonomous running/jumping while gravity and moving-support transport remain. T restores five health, zero hits, spawn position, zero velocity, counters, and planning state; it also cancels an active swing. Backspace performs that reset with the full room reset. R/death preserve dummy progress.

Tuning lives in `dummy.gd`: run speed, ground/air acceleration, jump speed, ascent/descent gravity, terminal speed, decision interval, jump cooldown, floor-hop interval, safe horizontal bounds, and boundary-retreat distance. `ai_enabled` allows focused automated checks to freeze autonomy. `jump_count`, `platform_landing_count`, and `current_platform` support inspection; these are not player-facing mechanics.

## Mouse melee and unchanged health rules

Left mouse button replaces J/X as the attack binding. One press begins one swing; holding does not auto-repeat. The baton still deals one damage per target per swing, with a 140 ms active window, 300 ms cooldown, and 66 px reach beyond the hand offset. The facing direction determines the hit side. Set down the weight before attacking.

Player health remains five hearts. Large falls at or above 180 px cost one heart once per landing; pit recovery costs one heart while preserving the remainder. Exhaustion, first checkpoint activation, and R restore five hearts. Recovery cancels attacks and returns carried weight to its start while retaining the relay and dummy. Backspace resets all state and motion phases.

## Verification status and update workflow

Canonical and portable collaboration source both passed **83 automated checks, 0 failures**, and 120-frame source smoke runs. The expanded suite covers prior movement/puzzle/health/melee behavior plus moving-platform phases 0/7/14, rider/weight transport, active dummy chase/platform landings, catch-and-hit pursuit, speed bounds, actual Godot left-mouse events, and reset/depletion state. The canonical Windows release exported, rendered five captured frames, and passed its 120-frame exported headless smoke; initial, solved, and airborne-dummy frames were inspected. See `VERIFICATION.md` for evidence and limitations. No human playtest or physical keyboard/mouse input test has been recorded.

The owner has authorized syncing every completed, tested game update to `deadclass/Oblivion`, branch `prototype/quiet-relay-collaboration`, with draft PR #1 kept current. Inspect the destination before writes, preserve collaborator work, and verify the resulting remote commit/content. Keep the PR unmerged; do not force-push or enable auto-merge. Exclude credentials, private paths, logs, caches, engine binaries, export templates, and local builds. Routine progress belongs in the game chat; no watcher or scheduled monitor is part of this workflow. Licensing remains undecided.
