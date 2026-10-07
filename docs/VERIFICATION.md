# Collaboration baseline — 2026-10-07

The publication candidate was copied into a clean folder using only source, stable script IDs, tests, and portable configuration. No original `.godot` cache, engine binaries, logs, profile data, or exported build was copied.

- Godot queried version: `4.7.2.stable.official.ed1daf0bf`.
- Clean-folder test suite: **26 checks, 0 failures**, exit code 0.
- Clean-folder source smoke: 120 frames, exit code 0.
- The original private slice's Windows release exported successfully, rendered initial/restored frames, and passed a 120-frame exported headless smoke.
- Shared scripts and scene were copied unchanged from that tested slice. Export configuration now uses collaborators' standard template installations, with no machine-specific paths. The collaboration candidate was not separately exported using that portable preset.
- All visuals are procedural geometry; there are no missing external assets.
- The publication manifest was reviewed for private paths, credentials, generated logs, engine binaries, caches, and unrelated content.

The automated suite uses actual physics traversal through the carrying staircase and restored exit. Other checks isolate movement and recovery behavior using controlled placements. Pause/resume invokes the input handlers directly. Rendered-frame inspection is separate from gameplay testing: the solved screenshot is staged for visual QA.

No native keyboard UI test or human playtest has been recorded. Responsiveness, carrying speed, discoverability, and reset clarity remain human playtest tasks. A sandbox certificate-store warning appeared in recorded runs; this offline prototype does not use networking and all listed checks completed.
