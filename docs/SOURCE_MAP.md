# Source map

`project/` preserves scene/script resource paths from the current verified local successor to the Commander's ChatGPT prototype. This is not a fresh authenticated export of the original ChatGPT attachment or its complete revision history.

| Path | Role |
|---|---|
| project/project.godot | Renderer, viewport, 120 Hz physics, default puzzle scene |
| project/puzzle_room.tscn | Return Relay puzzle |
| project/main.tscn | Free-practice arena |
| project/scripts/world.gd | Shared world, targets, camera and feedback |
| project/scripts/puzzle_room.gd | Lights, slit, gate, completion and resets |
| project/scripts/player.gd | Movement, jump, dash/dodge/block, body transitions |
| project/scripts/abilities.gd | Sword and ranged lifecycles |
| project/scripts/boomerang_form.gd | Steerable form, swept collision, path return |
| project/scripts/projectile.gd | Projectile flight and collision |
| project/scripts/bomb_solver.gd | Ballistic targeting |
| project/scripts/aim_controller.gd | Aim and previews |
| project/scripts/controls.gd | Input mapping and reconnect guards |
| project/scripts/training_dummy.gd | Practice targets and damage feedback |
| project/scripts/pause.gd | Pause/reset interface |
| project/scripts/status_display.gd | Status UI |
| project/tests/run_tests.gd | Full regression runner |
| project/tests/*_checks.gd | Movement, combat, aim, targeting and puzzle checks |
| project/**/*.uid | Preserve Godot resource UID metadata |
| project/export_presets.cfg | Portable Windows export preset |

Gameplay source is unchanged from the verified handoff. Public-copy changes are limited to documentation, exclusion of historical evidence/stale README/caches, and removal of machine-specific export-template paths. The portable preset has not been separately exported.
