# Oblivion six-room prototype

Open `project.godot` using Godot 4.7.2. Six connected rooms span three floors, two rooms per floor. Room 1 retains three one-way practice platforms and four inert targets. Corridors and stairs connect all rooms without ability locks. The minimap shows discovered rooms, connections and the current room.

A/Cross jumps; X/Square uses the sword; B/Circle dodges; LB/L1 blocks; RB/R1 dashes; RT/R2 uses the selected ranged weapon; Y/Triangle cycles Bow, Boomerang and Bomb. Tap LT/L2 to cycle targets; hold it for directional aiming while moving. Dash plus melee within 80ms produces a sword dash. Rising-spin recovery is not enabled.

[Current controls](../../docs/TARGET_AIM_REVISION.md) | [Room layout](../../docs/SIX_ROOM_REVISION.md) | [Setup](../../docs/SETUP.md) | [Verification limits](../../docs/VERIFICATION.md)

Marked future gate/miniboss locations are nonblocking reservations only, not implemented puzzles or a boss. Synthetic tests and staged captures are separate from physical-controller and human playtesting.
