# Six-room release-preparation verification

This document describes automated evidence, not a release approval. The current prototype retains six rooms over three floors, bidirectional corridor/stair connections, the discovered-room minimap, safe respawn and the existing movement/ranged kit. Ability-gate and miniboss markings are reservations only.

The fresh release-preparation candidate runs the unchanged guarded release helper: two separate clean-source regression/smoke stages, a Windows release export using the existing matching local Godot 4.7.2 template, awaited executable startup, and 23 staged native ability/control captures. An additional exact-executable fixture supplies twelve room/stair/reservation/discovery/pause captures. Exact local process records, source/build hashes and review receipts remain outside the public source mapping.

Each clean regression run must report 788 checks, zero failures and COMPLETE. Review must inspect the actual logs and all rendered frames; filenames, process exit and workflow labels are not visual or release approval. Independent renewed review of the exact new candidate and the public-content mapping is pending at preparation time.

The room suite uses deterministic CharacterBody inputs for forward and reverse traversal of all five room links; separate placement fixtures cover seam hysteresis, boomerang restoration, camera/map state, resets and discovery. Capture-family tests cover fixture prompt pinning and restoration of ordinary hot-swap. Other movement/combat/aim/bomb/control suites remain enabled.

Synthetic input and staged captures do not establish physical Xbox/PlayStation/Steam Controller operation, USB/Bluetooth reconnect, actual Steam Input routing, human movement/assist feel, audio or timing quality. The portable public export preset has empty custom-template paths and has not separately been exported in this preparation. Prior local sources and builds are retained; none are included here. Licensing remains undecided.
