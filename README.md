# OBLIVION — mechanics prototype

Current mechanics-first Godot prototype: Return Relay puzzle plus a free-practice combat arena. This snapshot supersedes the earlier guarded-weight design as the current local development baseline, without deleting or merging the older draft PR.

## Run

Use **Godot 4.7.2 stable**, standard GDScript build. Import `project/project.godot` and press F5 for Return Relay. Open `project/main.tscn` and press F6 for the practice arena.

```text
godot --headless --editor --path project --quit
godot --path project
godot --path project res://main.tscn
godot --headless --path project --fixed-fps 120 --script res://tests/run_tests.gd
godot --headless --path project --quit-after 120
```

`godot` means your installed engine executable; no engine or export templates are bundled. Install matching export templates before exporting. The Windows preset uses standard installed templates and exports to `project/.artifacts/OBLIVION.exe`.

## Controls

| Action | Keyboard/mouse | Normalized gamepad |
|---|---|---|
| Move | A/D, arrows | Left stick/D-pad |
| Jump/air jump | Space | A/Cross |
| Sword | J / left click | X/Square |
| Ranged | U or E | RT/R2 |
| Cycle Bow/Boomerang/Bomb | F | Y/Triangle |
| Select target / manual aim | Tap / hold Tab + direction | Tap / hold LT/L2 + stick |
| Dash | Shift | RB/R1 |
| Dodge | Q | B/Circle |
| Block | L | LB/L1 |
| Heavy directional attack | K + direction | Right stick when not aiming |
| Drop through platform | Down + jump | Down + jump |
| Pause | Esc | Start/Options |
| Reset player / targets / room | R / T / Backspace | Pause menu |

Dash + sword within 80 ms produces sword dash. In aimed boomerang form, steer the transformed character for up to three seconds; releasing aim begins the return. Return retraces waypoints to the exact launch point rather than teleporting to the remote destination.

## Puzzle

Activate light 1, steer boomerang form through the enlarged slit to light 2, return home, walk through the opened gate, climb the platforms and reach the exit beacon. Player reset retains progress; full room reset clears it.

## Documentation

- [Source map](docs/SOURCE_MAP.md)
- [Asset checklist](docs/ASSET_CHECKLIST.md)
- [Verification and limitations](docs/VERIFICATION.md)
- [Publishing workflow](docs/PUBLISHING.md)
- `SOURCE_SHA256.txt`: hashes of the portable source files before cache generation.

## Rights

Licensing is undecided. No license granting additional reuse rights has been selected. Inherited code provenance and commercial rights have not been independently cleared. Procedural visuals avoid a separate sprite/audio dependency, but that is not a legal audit. Reference games inform atmosphere only; do not copy their characters, levels, names or signature assets.
