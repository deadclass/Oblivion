# The Quiet Relay - working prototype

An original movement/puzzle slice for Oblivion. The name is provisional. Travel from the western entrance across a larger chamber of drifting supports, blocks, hanging obstacles, and upper galleries. A melee guard protects the weight on the opposite eastern side. Defeat it, return the weight to the moving western high cradle, restore the bridge, and reach the eastern exit.

Open `project.godot` in Godot 4.7.2 and press F5. See [setup](../../docs/SETUP.md), [design/tuning](../../docs/DESIGN.md), [guarded-chamber notes](../../docs/GUARDED_CHAMBER_REVISION.md), and [verification](../../docs/VERIFICATION.md).

- A/D or left/right: move.
- Space, W, or up: jump; hold for height, release for a shorter jump.
- E: carry/drop, or place near the moving high cradle after defeating the guard. A locked cradle retains your carried weight.
- Left mouse button: player baton, one damage per target per swing; set down the weight first. Holding does not repeat attacks.
- T: reset the guard's five health, hits, eastern spawn, velocity, and unalerted state. Relock an unsolved cradle; keep an already restored relay open.
- R: restart/heal at the last lit checkpoint; relay, guard progress, and platform motion remain. Recover carried weight to the east.
- Backspace: reset the whole room, puzzle, checkpoints, health, guard, and platform phases.
- Esc: pause/resume. Close the window to quit.

The 2304-pixel room is twice its original width. Ten platforms move left/right at different speeds and bob slightly. The main floors and architecture stay fixed. A moving pit ledge permits crossing before puzzle completion; eastern steps reach two upper galleries. The camera follows within room bounds, while the HUD and pause label stay fixed on screen. Lower-floor checkpoints lie near the western cradle route and before the eastern guard.

The guard waits by the weight until the player enters its detection range, then chases and jumps across reachable supports. Its orange 300 ms windup precedes a one-heart, 140 ms strike and 650 ms recovery. Facing locks during the warning and strike, and solid obstacles block its attacks. The player runs at 255 px/s and the guard at 247 px/s, an 8 px/s advantage of about 3.2%. The guard has five health. Defeating it stops its attacks and unlocks weight placement; defeat persists across R/death.

Carrying reduces player speed to 84% and prevents attacks. Enemy strikes drop carried weight, grant 800 ms combat invulnerability, and apply short knockback. R/death cancel both weapons and give one second of combat grace. Dropped weight can ride moving supports; lost or recovered carried weight returns to its eastern start.

Player health remains five hearts. A tunable 180+ px apex-to-landing drop costs one heart once. Pit recovery costs one heart and preserves the remainder. Zero hearts, R, and first checkpoint activations restore full health. Backspace resets everything.

Visuals are original procedural geometry, with no external asset dependencies. Godot's built-in 2D physics supplies collision, moving support transport, and combat queries. The guarded-chamber revision passed **154 checks with 0 failures** in both canonical and clean portable source, plus source smoke runs. Its Windows release exported, generated eight inspected staged frames, and passed exported headless smoke. See [verification](../../docs/VERIFICATION.md) for measured evidence and the remaining sandbox certificate-store warning. Earlier 83-check results are historical. Automated verification and rendered inspection are distinct from human playtesting; no human playtest or native mouse/keyboard test has been recorded.

Completed, tested game updates are authorized for sync to `deadclass/Oblivion` on `prototype/quiet-relay-collaboration` and draft PR #1. Preserve collaborator work and keep the PR unmerged. Final verification and remote publication results are confirmed per update. Builds, engine binaries, caches, logs, and private paths remain outside Git. Licensing is undecided.
