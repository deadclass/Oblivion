# Oblivion Software workflow release policy

Owner decisions recorded October 17, 2026 (America/Chicago): maintain only `Play Oblivion.lnk` in the desktop OBLIVION folder. Leave `OBLIVION - Latest.lnk`, which targets Return Relay, untouched. Allow automatic verified source pushes only to public `deadclass/Oblivion`, branch `prototype/quiet-relay-collaboration`, existing draft PR #1. Never force-push, merge or enable auto-merge. On October 18 the owner separately authorized FULL POWER for the existing ENGINEER (`engineer`), REVIEWER (`reviewer-2`) and TESTER (`reviewer`), understanding that it grants whole-computer authority across sessions. The owner selected the built-in Full Power preset for those three; normal API readback confirms `full` approval and `this-computer` reach. No other agent, station-wide Full Power, service, credit, billing or credential change is authorized.

These decisions supersede older local-only instructions for the release workflow. They do not turn historical verification records into fresh approval. Historical gameplay revision documents remain accurate records of their own sessions.

## Saved integration

The local project has no `.git` directory. StarNet 0.13.5 Software inbox p138 uses this project as its Working folder. The existing six agents and models are preserved. Only the three explicitly authorized access presets changed; Researcher, Strategist, Overseer and global switches are unchanged. Native station tools saved the route below and read it back; this is configuration evidence, separate from runtime testing. The release helpers wrap the existing Godot setup, `scripts/Verify.ps1` and `scripts/Export-Windows.ps1`, and the saved build/delivery/publication briefs invoke them. A local validator does not restrict an agent with filesystem write access from changing the validator itself. See each job's actual evidence rather than assuming readiness from the layout.

Historical execution blocker: the initial ENGINEER, REVIEWER and TESTER used Trusted Project / ASK. StarNet line jobs run on its autonomous surface, whose execution lockout refuses shell and verification commands even with cached approvals or a trusted folder. This version does not expose a line-scoped unattended shell grant. The owner's saved Full Power changes resolve that execution posture blocker; authorization or an invisible pending card alone would not have sufficed. Never work around an actual denial through another agent, forge app consent or broaden other settings. A successful native release still requires its actual evidence, including existing noninteractive Git push authentication; the earlier local standalone harness tests and failure probe are separate historical results.

## Required route

Software INBOX p138 → RESEARCHER p153 → ENGINEER p139 → REVIEWER p155 → TESTER p140 → WINDOWS BUILD p160 → RELEASE REVIEW p162 → approval loop p141. Approval continues to DESKTOP DELIVERY p161 → GITHUB UPDATE p163 → original Outbox p142. Revisions return to ENGINEER p139, at most three times. Unapproved exhaustion goes to crewed FAILURE / ESCALATION p159 → separate Outbox p158. Software is bounded to 24 stages and the existing $2/job limit; existing Codex subscription runs reported $0 and consume subscription quota.

In this version, connecting escalation directly to an Outbox does not create a runnable escalation target. The intervening crewed failure Bay is required. The saved loop explicitly reports `escalatesTo: p159`. Native TIDY may rotate compass ports; destination IDs determine the route. The controlled failure-path probe exception in each brief applies only when the original owner task is explicitly tagged `CONTROLLED FAILURE-PATH PROBE`.

Review/test failures may return to ENGINEER within the bounded revision budget. Every failure, incomplete check, unavailable visual inspection, stale source/build, missing approval, gate error or exhausted revision budget must route to a separate FAILURE / ESCALATION endpoint with no delivery/publication successor. A loop's DONE status does not imply approval. A release stage must run the validator and require its successful exit before mutating a launcher or GitHub; text verdicts alone cannot unlock it.

## Shared handoff packet

Carry the original task verbatim, acceptance criteria, exact project root, task/run ID, current source manifest hash, changed-file list, each criterion's result, unresolved issues, revision count, commands actually run, exit statuses, fresh log hashes, build path/hash, review receipt and visual evidence through every handoff. Do not replace the task with a stage summary. Preserve previous source/builds and collaborator work. Record synthetic automation, rendered-image inspection, hardware tests and human playtesting separately. DONE, delivered, counters and remembered claims are not evidence.

## Bay briefs to apply in StarNet

| Bay | DOES | HANDS OFF |
| --- | --- | --- |
| RESEARCHER / Planning | Read AGENTS, README, CONTRIBUTING, DESIGN, SETUP and current revision notes in the inbox Working folder. Inspect existing code/scripts. Translate the unchanged task into acceptance criteria, focused plan and regression risks. Use existing providers/dependencies; check costs before a bounded model trial. | Shared packet plus concrete plan, touched areas, test/visual plan and blockers. No implementation or delivery claims. |
| ENGINEER | Implement only the authorized Oblivion change in that same folder with existing Godot physics. Preserve previous verified work. Add meaningful regressions for gameplay changes and run existing Verify.ps1. Never update the live executable/shortcut or publish directly. | Shared packet plus exact changed files, implementation decisions, actual checks and failures. Changes after review invalidate approval. |
| REVIEWER | Independently compare the original task/criteria with exact changed source, project rules and regression risks. Inspect implementation, release scripts and evidence; return revisions for gaps. An empty brief or loop completion cannot count as approval. | Shared packet plus explicit pass/fail findings tied to exact source and candidate executable when available. Unresolved findings route to revision/escalation. |
| TESTER | Independently run regression and clean-source checks. Require completed counts and inspect logs, not exit code alone. Verify task criteria and supported rendered output. Keep physical-controller/human testing limits explicit. | Shared packet plus fresh command/log evidence and verdict. Failure/incomplete/unsupported inspection routes to revision/escalation. |
| WINDOWS BUILD | Use scripts/release to snapshot the source into unique staging folders, invoke existing Verify.ps1 and Export-Windows.ps1, await export/executable smoke/capture, and hash source/build/sidecars/evidence. Do not overwrite .artifacts/QuietRelay.exe. | Candidate manifest and all fresh evidence. No promotion until independent exact-hash review and supported visual inspection pass the validator. |
| RELEASE REVIEW | Independently inspect the exact candidate, original criteria, all fresh verification logs and all 23 supported rendered frames. Write substantive Review and Visual receipts only for passed evidence, import using Add-Approval.ps1 and require full Test-Candidate.ps1 success. Reconcile public source before approving a publication task. | Shared packet plus exact-hash review/visual receipts and full validator result. Only full success permits approved; otherwise revise/escalate. |
| DESKTOP DELIVERY | Rerun the executable release validator immediately before mutation. Install in a new versioned build folder, hash-check it, preserve previous launcher/build, update only Play Oblivion.lnk and read back target/working directory. On any error retain or restore the previous launcher. | Shared packet plus verified delivery path/hash, backup location and shortcut readback. Never claim success merely because the bay completed. |
| GITHUB UPDATE | Rerun the same release validator. Reconcile the no-.git project with a separate checkout of the confirmed remote branch. Review a source-only allowlist and sanitized candidate, preserve all remote files/changes and require an ordinary fast-forward push. Never copy local instructions/private paths, credentials, caches, logs or builds. | Actual commit ID, pushed ref and independently read-back remote commit/content. A moved remote head requires reconciliation/revalidation. No push on missing/stale/failed evidence. |
| FAILURE / ESCALATION | Stop the job before delivery/publication, retain task/evidence/candidate and previous working build, report exact reason and remaining work. No automatic successor to success. | Blocked/failed packet for the owner, never a release approval. |

## Release requirements

The validator must reject missing, failed, stale, edited, expired or previous-run evidence; compare current and staged source, executable/sidecars, logs and rendered image hashes; and require independent review/visual approval of that exact candidate. A source edit, rebuilt executable, changed evidence or changed acceptance criteria requires a new candidate and approval. Do not mark visual approval by generating files or seeing a capture exit code: inspect the supported images and record findings.

Keep the existing verification/export helpers intact. Their direct invocation alone is not a release check. Run candidates in separate fresh directories so fixed artifact names cannot overwrite a working version. Preserve failed candidates for diagnosis.

The desktop wrapper also requires an explicit Boolean GitHub publication intent. If true, supply `-MappingPath`, `-PublicationApprovalPath` and `-CheckoutParent`. Its shared publication preflight validates the independent public review, exact candidate and public bytes, current remote head and remote preservation before any desktop mutation, then repeats before the launcher switch. Missing or stale publication readiness blocks desktop delivery. The final publisher still requires actual desktop delivery and rechecks everything before an ordinary push. A later network outage or external branch change can still interrupt publication; report that actual failure without claiming the entire release succeeded.

## Git reconciliation

Publication may inherit only the exact standard unused Git LFS clean, smudge and
process defaults; this is not permission to run LFS or any other content filter.
Unknown/near-match commands and every active filter attribute block promotion.
The shared checkout helper fetches without submodule recursion, uses `read-tree`
without `-u`, and audits effective filter attributes for all fetched remote plus
mapped paths from the index before checkout. It copies all overlays before
rechecking configuration and auditing final-worktree attributes, before any
`add`. Exact staged-byte, remote-preservation, review, delivery and push guards
remain mandatory. Run the real local PS5 filter fixtures as well as the existing
guard suite. A failed audit is not fixed by changing global Git configuration,
credentials, PATH, permissions or policy. See `scripts/publication/README.md`.

Read-only remote audit found PR #1 open and draft on the confirmed branch. A separate PR #2 is Return Relay work on a different branch and layout; do not copy or overwrite it. Do not initialize the requested local folder against an arbitrary remote or bulk-copy the folder into GitHub. Use the remote branch as the base in a separate checkout, compare each intended file, sanitize export presets and documentation, and preserve collaborator changes. A `.gitignore` is an additional exclusion rule, not a public-source review. Only after the candidate and reconciled source pass the gate may the approved ordinary push occur; verify remote commit and file content afterward.

## Submitting work

Open Software → INBOX → Send a job. Enter the requested change and observable acceptance criteria. The inbox Working folder must resolve to this TargetAimRevision project. Submit one bounded task; inspect its per-stage evidence and final verified delivery/commit references. An Outbox message alone is insufficient. Real release job JSON must contain original task/criteria and explicit boolean `ReleaseIntent.DesktopDelivery` and `ReleaseIntent.GitHubPublication`; qualification probes never grant those intents. If a required tool, supported image inspection, existing connection or evidence is unavailable, report the exact blocker and preserve the current launcher/remote rather than inventing a pass.

StarNet 0.13.5's inbox backend limits direct job text to 2,000 characters. Keep a direct task within that limit. For a longer task, save its complete original text and criteria in a project file and send a short instruction naming that file; planning must read the complete file and bind its content to the immutable job before implementation. Never silently approve a truncated or summarized task.
