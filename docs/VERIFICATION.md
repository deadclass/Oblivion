# Guarded chamber and cradle-boundary verification - 2026-10-07 UTC

The guarded chamber and placement-prompt follow-up passed final engine, source, export, and rendered checks. Owner requests for the chamber were recorded October 6, 2026 (America/Chicago). Automated controller/physics verification and staged image inspection are distinct from the human playtesting that remains.

The chamber is 2304 pixels wide, with ten moving supports, two upper galleries, floor/gallery blocks, and suspended obstacles. A five-health pursuing melee guard protects the actual weight in the far east, opposite the western entrance. Its orange windup precedes a one-heart strike. The western moving cradle rejects placement until guard defeat and retains the carried weight on rejection. Defeat unlocks placement, which restores the bridge and opens the eastern exit.

## Measured results

| Check | Result |
| --- | --- |
| Verified engine | 4.7.2.stable.official.ed1daf0bf |
| Canonical full suite | 167 checks, 0 failures, exit 0 |
| Canonical source headless smoke | 120 frames, exit 0 |
| Clean portable collaboration source suite | 167 checks, 0 failures, exit 0 |
| Clean portable source headless smoke | 120 frames, exit 0 |
| Focused combat and cradle-boundary fixture | 45 checks passed; included in the full suite |
| Canonical Windows release export with existing matching templates | Exit 0 |
| Exported release graphical capture run | Eight staged frames, OpenGL 3.3 / AMD Radeon RX 6700 XT, exit 0 |
| Exported release headless smoke | 120 frames, exit 0 |
| Local release size | 109,317,208 bytes |
| Local release SHA-256 | D1B3788510D6B7F792D463DFA29EAC67F803C1A691803D642B62F2EF21C24E93 |
| Release-frame inspection | All eight staged frames inspected; states and layout correct |
| Additional source-frame inspection | Two boundary frames inspected: 64.9 px shows E / PLACE; 65.1 px shows no prompt |
| Script/gameplay test failures | No remaining script errors or test failures |
| Known engine warning | Sandbox root-certificate-store warning recurred |
| Portable export preset | Not separately exported; verified release used canonical preset and existing local templates |
| Remote source synchronization | Run-specific remote proof is recorded locally after sync; final commit linked from draft PR #1 |

Both final source suites passed 167 checks with zero failures. The focused fixture now has 45 checks, comprising the original 32 combat checks and 13 placement-boundary regressions. The final release size/hash were read directly from the executable. Engine binaries, builds, logs, and captures remain local.

## Placement prompt and interaction

The prompt and E interaction now share cradle_in_reach(): player position must be strictly less than 65 px from socket_position() + Vector2(0,-5), a center 5 px above the moving cradle. Exactly 65 px is outside range. This replaces the mismatched prompt radius of 70 px around the unshifted cradle, which could show E / PLACE where E did not place the weight.

While carrying with the relay unsolved, an in-range prompt shows DEFEAT THE GUARD and retains the weight if the guard survives. After defeat it shows E / PLACE and permits placement. Zero guard health also permits the prompt and placement immediately, before the defeat flag updates. At or outside the strict boundary, no placement prompt appears and E uses ordinary drop behavior. Non-carrying and solved states hide the prompt; a solved relay ignores further placement.

The 13 added regressions compare the displayed prompt with the actual E outcome for locked and unlocked cradles at horizontal 64.9 px, 65.1 px, and exactly 65 px, plus vertical samples above and below the shifted center. They also cover no carried weight, zero guard health before the defeat flag updates, and the solved state. These precision fixtures temporarily stop player/platform motion so coordinates cannot drift between the prompt assertion and interaction.

## Coverage

The harness retains original movement/health/puzzle regressions, including variable jump height, coyote time, buffering, acceleration/braking, ceiling/gate collision, fall/pit recovery, checkpoints, pause, per-swing player hits, and resets. Focused fixtures can freeze motion and AI; separate active checks exercise all ten supports, rider transport through reversals, bob safety, loose weight, moving-cradle attachment, and western carrying jumps at phases 0, 7, and 14 seconds.

Expanded-route checks drive the real player controller from its western start across the unsolved pit and eastern obstacles to the actual guarded weight. Five physical swings defeat a stationary guard fixture, then the player picks up the eastern weight, carries it back through obstacles and the pit, climbs to the western cradle, places it, and travels to the far eastern exit. Route movement uses test axis/jump inputs through the normal controller and real collision. It does not teleport across route obstacles. Stationary guard locomotion isolates delivery/puzzle continuity; separate live combat checks exercise the armed encounter.

Other passing checks cover the second-floor route, upper-floor obstacles/gallery gap, bounded follow camera and fixed CanvasLayer HUD, guard awareness/pursuit, the central step route to the galleries, far-eastern ascent and attack beyond an upper-gallery blocker from the guard's actual spawn at platform phases 0, 7, and 14 seconds, and unsolved-pit crossing. Navigation-only fixtures may protect or reposition the player to observe a particular guard route.

Real Godot left-mouse event injection verifies exclusive button mapping, one swing while held, and a new swing after release/click. A separate live duel passed while exercising pursuit, both real weapons, and damage queries: it defeated the guard without player death and included at least one enemy hit. Player speed is 255 px/s versus guard speed 247 px/s, about 3.24% faster when not carrying.

The original 32 combat checks cover distant guarding and detection; cradle prerequisite/retained weight; dropping away from the cradle; warning, active damage, per-swing tracking and recovery; movement retreat during windup; solid walls blocking both weapons; a wall appearing during windup; invulnerability during an active swing and later expiration; knockback/weight drop; lethal and restart safety; defeat persistence; T and full-room reset rules. A lethal carrying hit returns the weight to its eastern start through respawn, while a surviving hit drops it at the hit position. Respawn cancels both weapons and grants one second of combat grace.

## Rendered inspection and remaining limits

The final Windows executable generated eight staged captures, all inspected: initial chamber, eastern guarded weight, orange windup, player damage at 4/5 health, locked cradle retaining the carried weight, defeated-guard/restored relay, upper gallery, and eastern exit. The images confirmed grounded actors, a readable fixed HUD, visible weapon warning and damage feedback, correct obstacles and cradle state, restored bridge, and clear progression/exit status.

Two additional staged source-engine frames, cradle-boundary-inside.png and cradle-boundary-outside.png, were inspected separately. The inside frame at 64.9 px shows E / PLACE; the outside frame at 65.1 px has no placement prompt. These are source captures, additional to the eight release-executable frames. The exact 65 px exclusion is verified by the automated boundary fixture.

Automated controller inputs and engine mouse events are distinct from native operating-system interaction and human playtesting. Staged rendered frames check visible state/layout rather than a complete gameplay route. No human playtest or native keyboard/mouse test has been recorded. Attack warning readability, dodge timing, chase fairness, obstacle routes, carrying speed, and puzzle clarity still need human feedback.

The sandbox root-certificate-store warning recurred in final engine runs and is the sole known engine warning. This offline game has no network features; the warning did not prevent the listed tests, export, rendering, or smoke runs. No remaining script errors or gameplay test failures were found. Godot's built-in 2D bodies, moving support transport, shape queries, rays, and move_and_slide() suffice. No new software, external assets, physics dependency, spending, or account change was needed. The portable export preset was not separately exported; the verified Windows release used the canonical preset and existing local templates.

## Collaboration

The owner authorizes syncing every completed, tested game update to deadclass/Oblivion on prototype/quiet-relay-collaboration and [draft PR #1](https://github.com/deadclass/Oblivion/pull/1). Run-specific remote proof is recorded locally after sync; the final source commit is linked from the draft PR. This engine/build report does not itself establish that a remote write succeeded. Verify the remote head and content before reporting this update synchronized.

Preserve collaborator work; never force-push, merge main, or enable auto-merge without separate approval. Routine updates belong in the game chat, without a watcher. Engine binaries, templates, builds, caches, logs, local profiles, credentials, and private paths are excluded from publication. Licensing remains undecided. Historical 26-, 55-, 83-, and 154-check reports describe earlier revisions.
