# Running and verifying Oblivion

Use Godot 4.7.2 stable. Open `prototypes/quiet-relay/project.godot` and run the main scene. No plugin or additional dependency is required for this prototype.

```sh
godot --path prototypes/quiet-relay
godot --headless --path prototypes/quiet-relay --fixed-fps 120 --script res://tests/run_tests.gd
godot --headless --path prototypes/quiet-relay --quit-after 120
```

The existing `scripts/Verify.ps1` accepts `-Godot` with an installed engine path. Successful verification requires a complete passing result, not just exit zero. Run clean-source checks without generated `.godot` or `.artifacts` directories. Focused room checks add `-- --rooms-only` to the test command; the fixture validates forward and reverse traversal independently of staged screenshots.

## Export

Install the matching Windows export templates through your existing Godot setup. The public preset leaves custom-template fields empty so Godot can resolve its installed templates. Export to a new local output folder, not over an active or previously verified executable:

```sh
godot --headless --path prototypes/quiet-relay --export-release "Windows Desktop" .artifacts/QuietRelay.exe
```

The output folder must exist. Local engine paths, templates, exported binaries, caches and logs are not public source. The portable empty-template preset has been checked as source but has not separately been exported in this release preparation; the local candidate uses the existing explicitly configured matching template.

## Render fixtures and limits

`-- --capture --capture-dir=<local-output-folder>` stages 23 ability/control images. `-- --capture-rooms --capture-dir=<local-output-folder>` stages twelve room, stair, reservation, discovery and pause images. Use a separate folder per fixture. These are synthetic staged states, not human playtesting or proof of physical input operation. Await exported executable processes and inspect their completed logs.

[Current controls](TARGET_AIM_REVISION.md) and [six-room layout/reset behavior](SIX_ROOM_REVISION.md) describe the current prototype. Xbox, PlayStation and Steam Input routes still need physical hardware and human feel testing. No account or controller-driver changes are made by the source.
