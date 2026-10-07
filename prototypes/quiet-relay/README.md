# The Quiet Relay - working prototype

A small original movement/puzzle slice for Oblivion. The name is provisional. Carry the warm weight onto three drifting platforms, place it in the listening cradle moving with the top platform, restore the bridge, and cross to the eastern door. A harmless fleeing dummy lets you test the player's one-damage signal baton.

Open `project.godot` in Godot 4.7.2 and press F5. See [setup](../../docs/SETUP.md), [design/tuning](../../docs/DESIGN.md), and [moving-platform/chase notes](../../docs/MOVING_CHASE_REVISION.md).

- A/D or left/right: move.
- Space, W, or up: jump; hold for height, release for a shorter jump.
- E: carry/drop, or place near the moving high cradle.
- Left mouse button: melee baton, one damage per target per swing; set down the weight first. Holding does not repeat attacks.
- T: restore the dummy's five health, zero hits, spawn position, velocity, and movement state.
- R: restart/heal at the last lit checkpoint; relay, dummy, and moving-platform state remain.
- Backspace: reset the whole room, puzzle, health, dummy, and platform phases.
- Esc: pause/resume. Close the window to quit.

The raised platforms move left/right with peak speeds of 42, 58, and 76 px/s and bob 5-8 px each way. The floor remains static. Time jumps between supports and approach the top cradle until its place prompt appears. The lower-floor checkpoint lights when crossed. Dropped weight can ride moving supports; lost weight returns to its start.

The player runs at 255 px/s and the dummy at 247 px/s, an 8 px/s advantage of about 3.2% relative to the dummy. The dummy runs away, predicts reachable moving-platform landings, occasionally hops on the floor, and turns near safe boundaries west of the pit. It cannot damage the player. Depletion stops its AI until reset, while gravity and platform support remain. Carrying reduces player speed to 84% and prevents attacks.

Five hearts and a tunable 180+ px large-fall threshold remain. Each qualifying landing costs one heart once. Pit recovery costs one heart and preserves the remainder. Zero hearts, R, and first checkpoint activation restore full health. R/death preserve relay and dummy progress; Backspace resets everything. See [health/melee rules](../../docs/LOCAL_HEALTH_MELEE_REVISION.md).

Visuals are original procedural geometry, with no external asset dependencies. Godot's built-in 2D physics supplies collision and moving support transport. Automated verification and rendered inspection are reported separately from human playtesting; no human playtest or native mouse/keyboard test has been recorded.

Completed, tested game updates are authorized for sync to `deadclass/Oblivion` on `prototype/quiet-relay-collaboration` and draft PR #1. Preserve collaborator work and keep the PR unmerged. Final verification and remote publication results are confirmed per update. Builds, engine binaries, caches, logs, and private paths remain outside Git. Licensing is undecided.
