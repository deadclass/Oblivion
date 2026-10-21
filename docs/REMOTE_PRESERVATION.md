# Preserved remote resources

Workflow reconciliation restored the ten previously absent files below, byte for
byte from public `deadclass/Oblivion` commit
[`d73a1f31dc416882f900b77e94f7206efdbebb7c`](https://github.com/deadclass/Oblivion/tree/d73a1f31dc416882f900b77e94f7206efdbebb7c),
the inspected head of `prototype/quiet-relay-collaboration` / draft PR #1.
Each copied file was checked against its Git blob ID before writing and after
readback. No existing local file was replaced; no Git repository was initialized
in this project and no remote change was made by this preservation step.

All paths below are relative to `prototypes/quiet-relay/`.

| Preserved path | Exact Git blob ID |
| --- | --- |
| `scripts/dummy.gd` | `499cb15afbae90fe1b34c5beb1da1bb26eeb994e` |
| `scripts/dummy.gd.uid` | `28b65a658c925d4f7b30e00830984a4080ea6ae8` |
| `scripts/enemy_melee.gd` | `d47e15b43d568c26d01dfbac47be713a257031b8` |
| `scripts/enemy_melee.gd.uid` | `fc4ce9e97804717c138a6d23144fe295a56eae32` |
| `scripts/melee.gd` | `c7a75c5bedc3fec086509ef887a8cbcdc10949b3` |
| `scripts/melee.gd.uid` | `3955b13fbadfc41deebe5367d81b29b3fd3675d6` |
| `scripts/moving_platform.gd` | `1bb5807f8ffeb4b30be4689b0d06f67a5c49d9a5` |
| `scripts/moving_platform.gd.uid` | `33b65d98e877ef469e19eb32ae22ef48ca8ecd3f` |
| `tests/combat_checks.gd` | `23e54c453bf3ffa783ec07d973ab15a943970906` |
| `tests/combat_checks.gd.uid` | `d8faa521c08d66b28b4d80ef815c714466828d65` |

These are dormant legacy resources from the older guard/weight/bridge prototype.
The current movement-lab scene, scripts and runner do not reference these five
script paths. Their resource UIDs are distinct from the current resources. They
remain at their original paths to preserve remote content during reconciliation;
they do not restore an enemy, moving-platform progression or a puzzle objective.

The old combat suite is deliberately inactive. It depends on the former harness,
health, guard, weight, cradle, bridge and gate APIs, which the current arena does
not implement. The current 455-check suite validates the movement lab; it does
not prove these legacy systems work. Do not add the old suite to the active
runner or instantiate these scripts without an authorized integration and new
tests. Historical playable behavior also requires the other files from the
original complete commit; these ten resources alone are not a runnable archive.

A fresh isolated source copy completed a cold Godot 4.7.2 headless editor import
(22 script registrations), followed by explicit `--check-only --script` parsing
of all five preserved `.gd` files. All six processes exited zero with no
script/parser errors, and the imported source files remained byte-identical.
This establishes import/parse compatibility only; the dormant legacy systems and
old combat suite were not executed.

Any candidate created before this preservation is stale. A fresh candidate must
cover the complete combined source and pass the existing release gate, including
export, executable smoke, exact-hash review and supported visual inspection.
