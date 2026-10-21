# Six-room exploration revision

This revision supersedes the single-arena layout only. Existing controller/keyboard bindings, ability tuning, ranged targeting and four inert practice targets remain unchanged in safe Room 1. No enemy, boss, puzzle, ability lock or completion condition is implemented.

```
Top floor:       [5] --- [6]
                  |
Middle floor:    [4] --- [3]
                          |
Bottom floor:    [1] --- [2]
```

Each room spans 1600 world pixels. Floors lie at y=560, -340, -1240. Walk across each floor; climb the east stairwell between 2/3 and the west stairwell between 4/5. Each ascent uses nine 100px rises and wide overlapping one-way landings: ordinary held jump reaches each step without double jump or dash. Down+jump descends one landing at a time. All five links are freely bidirectional. Floor landings cover stairwell openings and safe lower floors catch falls. No transition teleports the body, cancels combat, resets targets or grants movement resources.

Room 1 preserves the original three-platform/four-target practice arrangement and safe spawn. Room 2 has a broad low gallery and east ascent; Room 3 has staggered balcony shelves; Room 4 has a broad sheltered platform and west ascent; Room 5 has upper approach shelves and a marked inactive miniboss staging area immediately before Room 6; Room 6 is an open destination gallery. Marked ability-gate sites near the 1/2 and 3/4 corridors are visual reservations only, with no collision or gating state.

The top-right viewport minimap reveals visited cells only and draws a connection only after both endpoints are discovered. The current cell has both a thick outline and dot (not color alone). Initial discovery is Room 1. A small seam deadband prevents boundary flicker. The camera clamps horizontally to the current room and vertically around its floor while keeping the player below the fixed HUD. Ordinary player/safety respawn always returns to safe Room 1, cancels abilities before resetting the body, and retains session discovery. Target-only reset retains discovery. Full training reset returns to Room 1 and clears discovery. Temporary boomerang excursions update the current cell; return or pause cancellation restores the launch-room map/camera.

Form launch saves its logical room as well as the physical launch point. Natural return, pause cancellation and direct form removal restore that saved room/camera immediately, bypassing movement hysteresis without discarding discovery or refreshing movement resources. This also applies when the launch point lies geometrically across a seam but still belongs to the prior logical room inside the deadband. A small camera-edge offset keeps the full body visible at the horizontal boundary; ordinary room hysteresis remains unchanged.

## Verification interfaces

`tests/room_checks.gd` traverses 1->2->3->4->5->6 and the entire reverse route using deterministic inputs through the unchanged CharacterBody controller. No position assignment occurs during this traversal. Separate explicit placement fixtures cover seam jitter, cross-room boomerang, every room's charge/dash/form/safety respawn, reset discovery and HUD prompt widths. Existing movement/combat/aim suites remain enabled; only obsolete arena geometry/outer-wall assertions move to the new outer edge.

Use existing `scripts/Verify.ps1` with Godot 4.7.2. Focused suite: `--headless --fixed-fps 120 --script res://tests/run_tests.gd -- --rooms-only`. Additional render fixture: `-- --capture-rooms --capture-dir=<existing absolute folder>` generates 12 images covering all six rooms, both stairs, miniboss reservation, respawn discovery, controller HUD and pause. These are staged states, not proof of traversal or human playtesting.

The existing mandatory 23 release captures and gate are unchanged. Windows Build must capture the extra room set from the same exact candidate into a separate supplemental folder, record process/executable/image hashes, and carry it to independent review. Release Review must inspect that supplemental coverage as acceptance evidence in addition to the mandatory 23, without weakening or modifying the gate. Engineer source renders or historical captures are not candidate approval. Any source edit invalidates old source/build evidence. All exports/promotions remain under docs/WORKFLOW_RELEASE.md and scripts/release/README.md; no direct live export, launcher mutation or push is part of Engineer implementation.

Physical controllers, hardware reconnect, audio/timing feel and human playtesting require separate checks; synthetic input and supported image inspection do not establish them.
