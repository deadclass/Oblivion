# Oblivion release evidence gate

These PowerShell 5.1 scripts wrap the existing `scripts/Verify.ps1` and
`scripts/Export-Windows.ps1`. They never update a desktop shortcut or push Git.
Every consumer that delivers or publishes must run `Test-Candidate.ps1`, require
exit zero and `Mode: ReleaseApproved`, and use only that candidate's exact files.
An app status such as DONE or delivered does not satisfy this gate.

## Create a candidate

Save a local job JSON outside committed source. Preserve the original task and
criteria verbatim; do not replace them with a later agent's summary.

```json
{
  "TaskId": "owner-task-id",
  "OriginalTask": "Original owner request",
  "AcceptanceCriteria": ["First original criterion", "Second original criterion"],
  "ChangedFiles": ["prototypes/quiet-relay/scripts/world.gd"],
  "ImplementerIdentity": "implementer identity"
}
```

Run in Windows PowerShell 5.1 with the existing Godot console engine:

```powershell
.\scripts\release\New-Candidate.ps1 -JobFile <local-job.json> -Godot <existing-Godot-console.exe>
```

This creates a fresh versioned `.artifacts/releases/<UTC-and-random-id>` folder.
It verifies two clean source snapshots using the existing Verify helper, exports
the second snapshot using the existing Export helper, then awaits executable
smoke and rendered capture processes. No prior executable or log is overwritten.
Every stage has a timeout. A failed run retains `failure.json` and cannot pass.

The current source, both snapshots, job, commands, process results, logs, matching
Godot launcher/engine and template, complete executable/sidecar set, and all 23
rendered frames are bound by SHA256. Candidate bytes must stay identical before
and after executable verification. Evidence expires within 24 hours of run start.
Changing any included source, script, documentation or root file requires a new
candidate. Generated/private artifact locations and binaries are excluded from
the source manifest; executable outputs have their own complete manifest.

## Independent approvals

Candidate creation ends at `AwaitingIndependentApproval`, never delivery approval.
After reviewing code and every original acceptance criterion, an independent
reviewer supplies a JSON file with these exact fields:

```text
SchemaVersion: 1
Kind: Review
Decision: Approved
Identity: independent reviewer identity (different from ImplementerIdentity)
Notes: substantive review findings and limits
RunId: candidate RunId
ManifestSha256: SHA256 of candidate.json
SourceSha256: candidate SourceSha256
ArtifactSetSha256: candidate ArtifactSetSha256
TaskSha256: candidate TaskSha256
ApprovedUtc: actual ISO 8601 UTC review time, after CompletedUtc
AcceptanceResults: one entry per original criterion, in original order
  Criterion: exact original criterion
  Passed: true (JSON boolean)
  Evidence: explanation referencing actual checks and review evidence
```

After actually inspecting every exported frame using supported image inspection
or human rendered inspection, supply a second JSON file with the same identity,
hash, time and notes fields, plus:

```text
Kind: Visual
Method: supported-image-inspection OR human-rendered-inspection
InspectedImages: all 23 candidate/captures/*.png entries
  Path: exact relative image path from EvidenceFiles
  Sha256: exact image hash from EvidenceFiles
  Passed: true (JSON boolean)
  Observation: substantive observation of this specific rendered frame
```

Do not generate approval from process exit status, filenames, old captures or a
workflow completion label. Capture fixtures exercise synthetic states; they do
not constitute physical-controller input or human playtesting.

Import each completed approval without replacing previous decisions:

```powershell
.\scripts\release\Add-Approval.ps1 -RunDirectory <run> -ApprovalFile <review.json>
.\scripts\release\Add-Approval.ps1 -RunDirectory <run> -ApprovalFile <visual.json>
.\scripts\release\Test-Candidate.ps1 -RunDirectory <run>
```

Missing, rejected, stale, expired, incomplete or mismatched evidence produces a
nonzero exit and `RELEASE REFUSED`. A changed candidate needs a new run and new
approvals. `EvidenceOnly-NOT-RELEASE-APPROVAL` is an internal pre-review result and
must never authorize delivery or publication.

## Boundaries

This is an executable safeguard against accidental and incomplete releases, not
an authentication system. Reviewer identities are recorded declarations; these
files do not prove who typed an identity. An actor with filesystem write access
can modify the gate itself. Independent oversight and routing must ensure the
implementer does not approve their own work or bypass the gate. No permissions,
credentials, paid services, engine installations or StarNet state are changed.

Public GitHub publication needs a separate reviewed source-only staging area,
sanitized machine-specific paths/instructions, reconciliation with remote work,
normal non-forced commits/pushes, and remote commit verification. This gate's
local source manifest intentionally covers local instructions and is not a
publication allowlist. Launcher selection, rollback and publication policy are
separate owner decisions.
