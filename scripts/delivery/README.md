# Verified desktop delivery

`Deliver-Verified.ps1 -RunDirectory <candidate>` previews delivery only after the
complete release validator passes. `-Deliver` installs and switches the launcher.
The original task must contain explicit Boolean release intents. Desktop delivery
requires `DesktopDelivery: true`; `GitHubPublication` must be either `true` or
`false`. A local harness-only trial cannot deliver.

For a combined delivery-and-publication job (`GitHubPublication: true`), pass
`-MappingPath <reviewedmapping.json>`,
`-PublicationApprovalPath <publicreview.json>` and
`-CheckoutParent <existing-directory-outside-project>`. The shared publication
preflight validates the exact release, reviewed public bytes and mapping, owner
policy, preserved remote source and current approved branch head before any
desktop write. This preflight deliberately does not require a desktop receipt:
the desktop has not been delivered yet. Missing, stale, invalid or unreconciled
publication prerequisites refuse delivery. It runs again before the launcher
switch and must retain the same release, mapping, review and expected remote head.
An explicitly desktop-only job (`GitHubPublication: false`) does not run this
publication preflight.

Only the owner-selected existing Desktop/OBLIVION/Play Oblivion.lnk is accepted.
The other launcher is never touched. The script preserves the old shortcut bytes,
executable and Godot export sidecars with hashes and a separate recovery shortcut
in the run's delivery/previous-build folder. It installs the candidate in a new
desktop OBLIVION/builds/<run-id> folder, compares every artifact hash, reruns the
full gate immediately before the atomic shortcut replacement, and reads back
the target and working directory. It revalidates afterward and restores the
previous shortcut on a detected post-switch failure. Failed candidates and
recovery files are retained.

On a system whose PowerShell execution policy disables local script files, the
existing verification harness uses a process-scoped invocation:

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\delivery\Deliver-Verified.ps1 -RunDirectory <candidate> -Deliver
```

Add the three publication input arguments above for a combined release. The
preflight performs bounded read-only remote checks and retains its separate
workspace checkout; it never pushes or creates a fake delivery receipt. It cannot
guarantee a future network operation will succeed. If a later publication fails
or is unconfirmed, stop and report the partial outcome with the preserved desktop
recovery evidence; do not claim full workflow success or attempt a force-push.

This flag applies to that process; do not change the machine/user execution policy
or StarNet agent permissions. Validation/rollback does not authenticate a declared
reviewer identity or defend against an actor rewriting its own gate. The saved
workflow must use this command for launcher delivery and route any nonzero exit
to failure/escalation. Never run the legacy export helper over the active target.
