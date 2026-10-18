# Running and verifying the movement sandbox

October 17 workflow setup: [WORKFLOW_RELEASE.md](WORKFLOW_RELEASE.md) records the newly authorized launcher and verified-push policy, superseding older local-only restrictions for that specific workflow. The existing commands below remain available, but direct export overwrites the active artifact; use the isolated scripts/release candidate path for release work. A saved StarNet workflow must invoke the validator before either delivery or publication can be enabled.

Use the existing Godot 4.7.2 stable installation. No new plugin, asset, dependency or driver is needed for this source change. Open prototypes/quiet-relay/project.godot and run the main scene.

```sh
godot --path prototypes/quiet-relay
godot --headless --path prototypes/quiet-relay --fixed-fps 120 --script res://tests/run_tests.gd
godot --headless --path prototypes/quiet-relay --quit-after 120
godot --headless --path prototypes/quiet-relay --export-release "Windows Desktop" .artifacts/QuietRelay.exe
```

The PowerShell Verify.ps1 and Export-Windows.ps1 helpers accept an existing engine path. Verification requires a complete result and no script errors, not merely engine exit zero. Source must be tested from a clean folder excluding .godot/.artifacts/history caches or builds; history sources are archival.

Graphical evidence uses -- --capture --capture-dir=<absolute-local-folder>. Captures stage ability/movement states and exit; they do not constitute human input testing. Exported .exe smoke/graphical runs on Windows should use Start-Process -Wait -PassThru -WindowStyle Hidden so the GUI executable is actually awaited.

See TARGET_AIM_REVISION.md for current controls. Controller support uses Godot's normalized input. Steam Controllers should launch through an existing Steam installation with Gamepad emulation. USB/Bluetooth, physical controllers and actual Steam routing need hardware playtesting. No account settings or Steam library are modified by this task.

Builds, logs, .godot caches and machine paths remain local. VERIFICATION.md records exact results. Prior authorization for this task remains local only; no remote sync, PR, merge, deployment or ZIP update is part of this revision.

