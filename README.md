# Oblivion prototype

An original Godot 2D platformer prototype with six connected rooms across three floors. Two rooms occupy each floor, joined by freely traversable corridors and stairwells. Room 1 is a safe movement and combat practice area with four inert targets. A compact top-right minimap shows discovered rooms, discovered connections and the current room; ordinary respawn retains discovery, while a full training reset clears it.

The marked ability-gate sites and miniboss staging area before Room 6 are reservations only. There is no implemented boss, puzzle, ability lock or completion objective.

## Run

Use the existing Godot 4.7.2 installation and open `prototypes/quiet-relay/project.godot`, or run:

```sh
godot --path prototypes/quiet-relay
godot --headless --path prototypes/quiet-relay --fixed-fps 120 --script res://tests/run_tests.gd
```

See [setup](docs/SETUP.md), [six-room layout and reset semantics](docs/SIX_ROOM_REVISION.md), [controls and ranged behavior](docs/TARGET_AIM_REVISION.md), and [design history](docs/DESIGN.md). Earlier arena and encounter notes describe previous revisions, not additional objectives in this prototype.

## Controls

A/Cross jumps; X/Square uses the sword; B/Circle dodges; LB/L1 blocks; RB/R1 dashes; RT/R2 uses the selected ranged weapon; Y/Triangle cycles Bow, Boomerang and Bomb. Tap LT/L2 to cycle targets A, B, C, D and Free; hold it to aim while moving. Right-stick aim is independent of left-stick movement. Keyboard/mouse mappings and Xbox, PlayStation and Steam Input gamepad prompts remain supported by the source.

## Verification scope

The release-preparation candidate completed two clean synthetic regression runs, each with 788 checks and zero failures, plus Windows export, awaited executable startup and staged rendered captures. Independent review of that new exact candidate and its public mapping is still pending; this text is not a release approval. Staged images do not establish physical-controller operation, human playtesting, audio or timing/feel. Existing local evidence, builds and machine-specific configuration are not part of the public mapping.

No third-party assets, engine binaries, export templates or local executables are included. Licensing remains undecided.
