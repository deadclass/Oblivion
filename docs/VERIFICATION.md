# Tested collaboration source - 2026-10-06

The current candidate contains moving raised platforms, the evasive jumping training dummy, left mouse melee, and the earlier five-heart/fall-damage revision. Gameplay scripts, scene, project settings, and stable script IDs were copied from the tested private slice; the collaboration folder keeps portable export configuration and setup helpers.

- Verified engine: `4.7.2.stable.official.ed1daf0bf`.
- Canonical source suite: **83 checks, 0 failures**, exit 0.
- Portable collaboration source suite: **83 checks, 0 failures**, exit 0.
- Both source headless smoke runs: 120 frames, exit 0.
- Canonical Windows release export using existing matching templates: exit 0.
- Exported Windows release rendered five captured frames on OpenGL 3.3; exit 0.
- Exported release headless smoke: 120 frames, exit 0.
- Local release SHA-256: `79AA707FD5C75C363789DC9D91F3118EF3D08A334F0FD959DEB7017DFD4F0AF0`.
- Initial, solved, and airborne-dummy render output was inspected for readable controls and aligned geometry. Capture mode stages selected states for visual inspection.

The original 55 regression checks isolate movement, puzzle, health, recovery, and melee with motion/AI disabled. Separate live checks exercise all three moving platforms, riding through reversals, vertical bob safety, loose-weight transport, actual carrying traversal at starting phases 0, 7, and 14 seconds, cradle attachment, restored exit traversal, real Godot left-mouse event injection, elevated dummy landings, and pursuit that catches and hits the live dummy. The player is 255 px/s versus the dummy's 247 px/s, approximately 3.24% faster while not carrying. The phase-14 test controller was corrected to approach a solid platform's flank instead of following underneath it.

Automated physics and input-event injection are separate from native operating-system interaction and human playtesting. No native mouse/keyboard UI test or human playtest is recorded. Moving-step timing, discoverability, and fair pursuit feel still need human feedback. The top platform can pass above the pit; checkpoint recovery remains available.

The sandbox root-certificate-store warning appeared in final engine runs. This offline prototype has no network features; all listed tests, export, rendering, and smoke runs succeeded. There were no remaining script errors. Godot's built-in 2D physics suffice and no new software was installed.

The portable export preset was not separately exported; the verified release used the existing local templates. Engine binaries, templates, builds, caches, logs, local profiles, credentials, and private paths are excluded from publication. Licensing remains undecided. The original 26-check baseline and intermediate 55-check health/melee suite are historical; the current suite is 83 checks.

Every completed tested game update is authorized for synchronization to the existing collaboration branch and draft PR, with collaborator work preserved and no force push or main merge. Read the remote head before updating and verify the resulting remote content before reporting it synchronized.
