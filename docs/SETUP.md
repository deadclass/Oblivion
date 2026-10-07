# Setup and verification

Use Godot **4.7.2 stable**, the version used to validate this prototype. Engine binaries and export templates are not stored in this repository. Use an existing local installation; if you need to obtain software, arrange that separately with the owner. The project uses the GL Compatibility renderer and has no plugins or external asset dependencies.

## Open and run

Open `prototypes/quiet-relay/project.godot` in Godot and press F5. From a terminal with Godot available as `godot`:

```sh
godot --path prototypes/quiet-relay
```

On Windows, you may use the full path to your existing Godot console executable. Do not commit that path to shared configuration.

## Automated checks

```sh
godot --headless --path prototypes/quiet-relay --fixed-fps 120 --script res://tests/run_tests.gd
godot --headless --path prototypes/quiet-relay --quit-after 120
```

Or use `scripts/Verify.ps1 -Godot <your-existing-godot-executable>` in PowerShell. The helper checks each exit code and creates only ignored local `.artifacts` logs.

## Windows release export

Use existing matching Windows export templates through Godot's Export interface and the `Windows Desktop` preset. Its template fields are intentionally blank so each collaborator uses their own standard Godot template installation. No code signing is configured and no third-party service is needed.

```sh
godot --headless --path prototypes/quiet-relay --export-release "Windows Desktop" .artifacts/QuietRelay.exe
```

Create the prototype's `.artifacts` directory first, or use `scripts/Export-Windows.ps1 -Godot <your-existing-godot-executable>`; the helper creates it. The preset embeds game data in the executable. Builds remain local and ignored.

## Rendered-frame inspection

Create an output folder and run the graphical engine with:

```sh
godot --path prototypes/quiet-relay -- --capture --capture-dir=.artifacts
```

Prefer an absolute capture directory to make the destination unambiguous. `--capture` saves initial and staged-restored PNGs and exits automatically. This verifies render layout and state visibility, not real keyboard interaction. Inspect both images; do not commit local logs or generated evidence by default.

## Baseline evidence and limits

The initial private slice passed 26 automated checks, source headless smoke, Windows release export, exported-build headless smoke, and GPU rendering. A separate clean-folder copy was validated before this collaboration publication; see `VERIFICATION.md` for its results. The suite traverses the carrying staircase and restored exit using the real controller. Focused checks also cover jump forgiveness, collisions, recovery, and pause/resume.

No human playtest or native UI keyboard test has been recorded. A tester should judge responsiveness, carrying speed, control discoverability, puzzle clues, and reset clarity. Some sandboxed environments may report a root-certificate-store warning; the game is offline, and such a warning did not prevent the recorded checks.
