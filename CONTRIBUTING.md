# Collaborating on Oblivion

The Quiet Relay is a working prototype. Keep changes focused on original movement, environmental interaction, and atmosphere. The project title and larger game direction remain open for discussion. The current source includes five-heart recovery, a one-damage baton, drifting platforms, and a harmless jumping training dummy.

1. Read `docs/SETUP.md`, `docs/DESIGN.md`, and current revision notes, then run baseline checks before editing.
2. For this continuing prototype, work on `prototype/quiet-relay-collaboration` and inspect remote history/content before writing. Preserve collaborator changes and reconcile them through ordinary commits; never force-push. Separate unrelated experiments onto descriptive branches or prototype folders.
3. Describe the concrete behavior you are changing. Record movement parameters and their reason in the draft PR.
4. Complete relevant automated regression checks, a clean-folder source run, local export/smoke verification, and supported rendered inspection. Human playtesting is encouraged; report clearly when it has not occurred.
5. Sync every completed, tested game update to the existing branch and [draft PR #1](https://github.com/deadclass/Oblivion/pull/1), as authorized by the owner. Verify the resulting remote commit and content before reporting success. Keep the PR unmerged; merging or auto-merge requires separate approval.

Routine progress updates belong in the game chat. This workflow does not require a watcher or scheduled monitor. A blocked write should produce a clean reviewable source candidate and an exact blocker report, not an access workaround.

Commit source, original assets, stable Godot `.uid` files, tests, and useful documentation. Keep engine binaries, export templates, generated `.godot` caches, local logs, credentials, private paths, and exported builds out of Git. Artwork comes entirely from procedural drawing; there are no external asset dependencies.

Do not introduce copied characters, levels, signature artwork, or names from reference games. Licensing is undecided: do not add a license or external assets with new licensing obligations without discussing it with the owner. The current public repository does not grant an additional license. Software installation, spending, account changes, and publication of additional external resources require separate authorization.

Useful next contributions include human movement/chase feedback, accessible remappable controls, original sound direction, and a second small environmental interaction. Keep additions small enough to test. The baton and evasive dummy remain an approved training system; do not expand into enemies, broader combat, procedural worlds, or a large content pipeline without a new request.
