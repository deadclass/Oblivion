# Setup and verification

Use Godot **4.7.2 stable**, the version used for this prototype. Engine binaries and export templates are not stored in this repository. Use an existing local installation; obtaining new software requires separate owner approval. The project uses the GL Compatibility renderer and has no plugins or external asset dependencies.

## Open and run

Open `prototypes/quiet-relay/project.godot` in Godot and press F5. From a terminal with Godot available as `godot`:

```sh
godot --path prototypes/quiet-relay
```

On Windows, you may use the full path to your existing Godot console executable. Do not commit that private path to shared configuration. The portable helpers accept an engine path argument.

Controls: A/D or arrows move; Space/W/Up jumps with hold-to-height; E carries/drops/places; left mouse button attacks; T resets the guard; R restarts/heals at the checkpoint; Backspace resets the whole room and platform phases; Esc pauses/resumes. The guard and weight begin in the far east. Defeat the guard before placing the weight at the moving high cradle in the west.

## Automated checks

```sh
godot --headless --path prototypes/quiet-relay --fixed-fps 120 --script res://tests/run_tests.gd
godot --headless --path prototypes/quiet-relay --quit-after 120
```

Or use `scripts/Verify.ps1 -Godot <your-existing-godot-executable>` in PowerShell. The helper checks exit codes and creates only ignored local `.artifacts` logs. The real-physics harness covers movement forgiveness and collisions, puzzle/recovery, player health and per-swing hits, mouse mapping, moving-support transport, and guard behavior. Focused checks can freeze platform motion and disable guard AI; active integration checks exercise motion and pursuit separately. New combat/expanded-room checks must validate attack timing, damage safety, obstacles, and the guard-defeat prerequisite.

Before publishing a completed update, run the source from a clean folder as well as the working project. Copy only source, original assets, tests, and required configuration; exclude caches, builds, logs, local profiles, engine binaries, templates, and credentials. A passing historical baseline is not sufficient evidence for changed gameplay.

## Windows release export

Use existing matching Windows export templates through Godot's Export interface and the `Windows Desktop` preset. Its template fields are intentionally blank so each collaborator uses their own standard Godot template installation. No code signing is configured and no third-party service is needed.

```sh
godot --headless --path prototypes/quiet-relay --export-release "Windows Desktop" .artifacts/QuietRelay.exe
```

Create the prototype's `.artifacts` directory first, or use `scripts/Export-Windows.ps1 -Godot <your-existing-godot-executable>`; the helper creates it. The preset embeds game data in the executable. Run the resulting build for smoke verification. Builds remain local and ignored.

## Rendered-frame inspection

Create an output folder and run the graphical engine with:

```sh
godot --path prototypes/quiet-relay -- --capture --capture-dir=.artifacts
```

Prefer an absolute capture directory to make the destination unambiguous. `--capture` saves staged game-state PNGs and exits automatically. Inspect readable controls/hearts, camera/HUD placement, the eastern guarded weight, upper-gallery obstacles, orange attack warning, health feedback, and the unlocked cradle/restored relay. This verifies render layout and state visibility; it does not test physical keyboard/mouse input. Do not commit local logs or generated evidence by default.

## Results and limits

[VERIFICATION.md](VERIFICATION.md) records the current update's engine, source, export, render, and remaining-issue evidence. See [guarded-chamber revision](GUARDED_CHAMBER_REVISION.md) for the current behavior. The prior 83-check moving/evasive-dummy suite, 55-check health/melee suite, and 26-check original baseline are historical. Do not infer that a new revision passes from those earlier totals, and confirm current export/publication results before reporting success.

No human playtest or native input test has been recorded. A tester should judge responsiveness, whether the small speed advantage makes pursuit fair, whether the orange attack warning allows an understandable dodge, obstacle/gallery routes, carrying speed, puzzle clues, and reset safety. Automated InputMap events exercise engine behavior rather than hardware/focus. Some sandboxed environments report a root-certificate-store warning; the offline game does not use networking.

## Collaboration sync

The owner has authorized syncing every completed, tested game update to `deadclass/Oblivion`, branch `prototype/quiet-relay-collaboration`, and draft PR #1. Inspect and preserve remote collaborator work, scan the clean candidate for private data, publish through existing authorized tooling, then verify the remote commit/content. Keep the PR unmerged and never force-push. Report a blocked write precisely rather than changing access or installing a workaround. Routine updates belong in the game chat; no watcher is needed.
