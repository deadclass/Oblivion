# Verified GitHub publication

This wrapper is dormant until a job explicitly requests publication, the complete release gate passes, an independent reviewer approves exact public bytes, and the owner policy names the confirmed destination. Running it without `-ExecutePush` only validates receipts. This implementation has not performed a real push.

The only destination is the public `deadclass/Oblivion` repository, branch `prototype/quiet-relay-collaboration`, existing draft PR #1. It never changes PR state, merges, enables auto-merge, deletes tracked files or force-pushes. It uses existing Git credentials. It neither installs credentials nor initializes Git in the game project.

## Required inputs

- A fresh candidate from `scripts/release/New-Candidate.ps1`, with `Job.ReleaseIntent.GitHubPublication` set to the Boolean `true` in its original job. A local harness trial with `false` is refused even if publication receipts exist.
- Passing independent review and visual approvals accepted by `Test-ReleaseCandidate` without `EvidenceOnly`.
- Completed desktop delivery from `scripts/delivery/Deliver-Verified.ps1`. Publication rechecks the actual owner-selected `Play Oblivion.lnk`, its target/working folder/arguments, every delivered executable/sidecar byte, the receipt's exact candidate hashes, and the recoverable previous build and recovery shortcut. A text claim or `Status: Delivered` alone is insufficient. Both original job release intents must be true. This delivery check runs even in validate-only mode and again immediately before pushing.
- A reviewed mapping JSON and separate publication approval JSON. Both bind the exact candidate manifest, source, executable/sidecar set, original task and expected remote head. Missing, rejected, expired or mismatched evidence stops the operation.
- An existing checkout parent outside the original project. A fresh retained checkout is created there for each execution; previous files and builds are not removed.

Call `Publish-Verified.ps1` with `-RunDirectory`, `-MappingPath`, `-ApprovalPath`, and `-CheckoutParent`. `-ProjectRoot` defaults to the game project containing these scripts. Add `-ExecutePush` only after complete receipts exist; the default returns `ValidatedOnly-NoPush` and performs no Git network operation.

Before any combined desktop/GitHub release, run with `-Preflight`, or call shared `Test-PublicationPreflight` using those same five path inputs. It requires the complete independent release and public-content approvals, both original release intents, reviewed public bytes and a fresh expected remote head. It fetches into a separate local checkout outside the game project and desktop, stages only reviewed files and verifies the complete reconciled tree, remote-only preservation and effective push destination. It makes no commit or remote ref update. It returns readiness bound to the exact manifest/mapping/approval/head; it never fabricates desktop delivery. The desktop helper requires this readiness before any desktop write and again before switching the launcher. Normal publication independently requires actual verified desktop delivery afterward. `-Preflight` and `-ExecutePush` are mutually exclusive.

Preflight also exercises Git's receive-pack authentication using `push --dry-run --porcelain` of the already-current expected head to the fixed approved branch. It creates no commit and changes no ref. Every Git child receives `credential.interactive=never`, `GIT_TERMINAL_PROMPT=0` and `GCM_INTERACTIVE=never` without changing caller/global settings; missing existing credentials fail before desktop readiness, with no login UI or new account. A public fetch or another app's GitHub connection alone is not CLI push readiness. After that probe succeeds, only the new checkout receives owner attribution `deadclass` and the existing account's public privacy-preserving GitHub noreply identity. Local user, author and committer name/email values are set, and effective `GIT_AUTHOR_IDENT` and `GIT_COMMITTER_IDENT` are verified so inherited global author/committer settings cannot publish a private identity. No personal email or global identity is configured. A successful dry-run establishes current authentication/connectivity, not a guarantee against later revocation, branch policy changes or other external state changes.

Git is resolved as an existing application, ignoring function/alias shadows. When an unattended child omits Git from PATH, the wrapper checks the existing bundled Codex dependency runtime and standard Windows Git installation locations and invokes the discovered absolute executable. Existing-file and reparse-point checks apply; absence stops publication. It never installs Git, downloads a substitute or changes user/global PATH. The bundled runtime is the same existing Git used for the owner-authorized credential-manager sign-in.

## Mapping schema (version 1)

The mapping object contains `SchemaVersion: 1`, `Destination`, `OwnerPolicy`, `ExpectedRemoteHead`, `RunId`, `ManifestSha256`, `SourceSha256`, `ArtifactSetSha256`, `TaskSha256`, `ExpiresUtc`, and `Files`.

`Destination` must contain these exact values:

```json
{
  "RepositoryUrl": "https://github.com/deadclass/Oblivion.git",
  "Branch": "prototype/quiet-relay-collaboration",
  "PullRequest": 1,
  "Visibility": "public"
}
```

`OwnerPolicy` contains `ConfirmedBy`, `ConfirmedUtc`, the Boolean `AutomaticVerifiedPush: true`, and the same exact `Destination`. Record the owner's actual existing authorization. The wrapper never creates this policy or a review receipt itself.

Every `Files` entry contains `CandidatePath`, `PublicPath`, `Mode`, `OriginalSha256`, and `PublicSha256`. Paths use forward slashes relative to the candidate source root. `ExactCandidate` copies the original bytes; both hashes must equal that file's candidate source hash. Every game source, asset, test and project file under `prototypes/quiet-relay/` must be mapped at its original path.

`ReviewedPublicVersion` additionally requires `PublicVersionPath` and `ReviewNotes`. The public-version path is relative to the mapping JSON's directory. Its actual bytes must match `PublicSha256`. This mode is restricted to documentation, `.gitignore` and the existing export preset; paths must stay unchanged. It is intended for explicitly reviewed removal of private paths or local export-template settings. It cannot rewrite gameplay, assets, tests, scenes or project configuration. No automatic sanitization occurs. The game folder's README and export preset still require mapping; source files elsewhere are published only when explicitly listed.

Local `AGENTS.md`, credentials, caches, logs, builds, archives and executables are refused. UTF-8 text is scanned for absolute machine paths, private keys, common credential formats and credential assignments. UNC detection requires an actual server/share delimiter shape, so escaped regular-expression source is not mistaken for a private network path; both ordinary server names and IP server/share paths remain refused. These checks supplement the required independent public content review; they cannot establish that arbitrary content contains no secret or personal information.

## Publication approval schema (version 1)

The separate approval object contains `SchemaVersion: 1`, `Decision: "ApprovedForPublicPush"`, `ReviewedBy`, `ReviewNotes`, `ApprovedUtc`, `ExpiresUtc`, `MappingSha256`, and the mapping's exact `Destination`, `ExpectedRemoteHead`, `RunId`, `ManifestSha256`, `SourceSha256`, `ArtifactSetSha256`, and `TaskSha256`. `MappingSha256` hashes the final mapping file bytes. The reviewer must differ from the implementer. Approval must follow candidate completion and expire no later than either the candidate or mapping.

Receipts are ordinary local review records. They are not signed attestations and cannot resist a malicious process using the same Windows account. They prevent accidental releases based on absent, failed, mismatched or old evidence; neither a prompt nor an OUTBOX status is an approval.

## Preservation and remote verification

Execution reads the live branch head and requires equality with the reviewed head, fetches it into a new checkout, and overlays only reviewed files. Remote-only files must retain exact blob hashes and modes. Remote-only game files absent from the approved candidate cause a refusal: reconcile them explicitly into a new candidate and verify it before obtaining new receipts. This prevents publishing an untested combination while preserving remote work. In particular, the current older PR #1 contains game files absent from Movement Lab, so direct publication of that candidate is expected to stop until reconciliation is done. PR #2 is separate and is never selected or modified.

Git hooks are disabled in the fresh checkout. Content filters are never executed.
All effective clean/smudge/process configuration values, including duplicates, are
inspected using NUL-delimited records. The only permitted values are the exact
standard defaults `filter.lfs.clean = git-lfs clean -- %f`,
`filter.lfs.smudge = git-lfs smudge -- %f` and
`filter.lfs.process = git-lfs filter-process`. Other drivers, near matches,
unknown commands and malformed records refuse publication. This exception is
only for **unused** inherited LFS defaults; it does not enable LFS publication.
No global configuration or caller environment is changed to bypass a refusal.

Fetch disables submodule recursion. After validating the fetched head/tree,
`read-tree` populates only the index, without `-u`. Before checkout,
`check-attr -z --cached filter` audits the union of **all remote and mapped paths**.
Only genuinely unspecified attributes are accepted; set or named filter attributes refuse
even when no driver command is configured. Git's text protocol renders the
literal driver names `unset` and `unspecified` like inactive state labels.
A second `check-attr --all` query distinguishes a driver named `unspecified`
from an absent/reset attribute. Explicit `-filter` is conservatively refused
because its output is indistinguishable from `filter=unset`; use no filter
attribute or an explicitly reviewed `!filter` reset instead. The wrapper never
rewrites attributes automatically. Git resolves nested, global and
repository-info attributes. After checkout, every reviewed overlay (including
`.gitattributes`) is copied and hash-checked before any staging. Configuration is
rechecked and `check-attr -z filter` audits the same complete union against the
final worktree before the first `add`. Missing/ambiguous results refuse. Exact
staged blobs must still match reviewed bytes, and remote-only bytes/modes must
remain unchanged. These audits supplement, never replace, the complete release,
delivery, public-review, destination and remote-head guards.

Inherited repository-routing and injected-config Git environment variables are refused before every Git invocation; the wrapper does not change the caller's environment. Mapping paths must match the exact canonical manifest casing, and game-path protection covers case variants. Every effective Git push URL is checked after remote creation and again immediately before the push; there must be exactly one URL, matching the approved repository. This rejects inherited extra push URLs and destination rewrites. Public commit messages use fixed text, without task metadata. The complete release gate, receipts, public byte hashes, staged tree and remote head are checked again immediately before an ordinary explicit-refspec push. A concurrent branch advance that prevents a fast-forward stops the push. The wrapper does not retry or force it.

After a push, it verifies the remote ref, fetches that exact head afresh, compares the entire tree ID and every mapped blob, and writes a local verified-push receipt only if all match. An interruption or post-push mismatch is reported as unconfirmed; it may require read-only remote inspection before retrying. The retained checkout contains the local Git logs and receipt under `.publication-local/`, which are never staged.

## Deterministic checks

Run `Test-FilterGuards.ps1 -WorkDirectory <new-external-scratch-folder>` in
Windows PowerShell 5.1. The folder must be outside the project and desktop.
It exercises the production checkout and audit functions with real local Git;
only transport/head discovery is redirected to an isolated local seed. It
tests unused exact inherited LFS defaults, active remote-only/mapped/global
attributes, late overlay attributes, set/named/unset/unspecified states,
duplicate/unknown/near-match commands and clean/smudge/process execution markers.
Each case saves its actual operation sequence and refusal. The marker must stay
absent, actual user/global config hashes must remain unchanged and fixture
process environment changes must be restored. No network, filter execution,
approval, desktop operation or real publication is performed.

The guard suite includes a real PowerShell 5.1 child whose PATH excludes Git. It must invoke the exact same pre-existing Git binary and ignore a function shadow. A separate absent-installation fixture removes the known-path discovery candidates and requires refusal; no substitute is installed, and the parent PATH is unchanged.

Run `Test-PublicationGuards.ps1` using Windows PowerShell 5.1. It uses an isolated fixture release evaluator and shortcut readback. It tests missing/rejected approval, evidence-only release results, wrong destination, stale hashes, expiration, private paths, secret-shaped content, unsafe export presets, game rewrites, a local-only trial, moved heads, desktop delivery and preservation failures. A real local Git fixture verifies that an inherited second push URL is refused; all network verbs are denied and the caller's Git configuration is unchanged. These tests make no network calls and do not prove a real publication works. A real end-to-end push remains intentionally untested until an actual task, reconciled source and complete release/publication approvals are available.

`Test-ProductionEntryPoint.ps1 -RunDirectory <fresh-real-run> -WorkDirectory <new-local-test-folder>` separately launches the actual publisher in Windows PowerShell 5.1 with `ProjectRoot` omitted. Before importing a candidate's review approval, it demands the exact missing-review refusal. It validates genuine candidate evidence first, writes only local test logs and refuses if the source changes. This catches script-parameter/default-path failures that mocked function tests cannot exercise. It creates no approval, delivery or publication.
