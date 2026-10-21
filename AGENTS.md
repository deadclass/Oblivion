# Repository guidance

Oblivion is an original Godot 2D platformer/puzzle project. `prototypes/quiet-relay` is a provisional working slice, not a final game name.

- Read README.md, CONTRIBUTING.md, docs/DESIGN.md, docs/SETUP.md, and the current revision notes before changes.
- Keep changes within the requested prototype and avoid unrelated projects. Preserve newly arrived collaborator work.
- The owner has authorized a larger chamber with upper galleries and obstacles, and one pursuing melee guard at the eastern weight. Preserve readable attack timing, recovery/reset rules, and the guard-defeat prerequisite for weight placement. Additional enemy systems or a larger game need a new request.
- Owner authorization recorded October 6, 2026 (America/Chicago): sync every completed, tested game update to `deadclass/Oblivion`, branch `prototype/quiet-relay-collaboration`, and keep draft PR #1 current. Inspect destination history and content before writes; reconcile collaborator changes. Never force-push, merge, or enable auto-merge without separate owner approval.
- Run existing and relevant new regression checks for gameplay changes. Verify the source from a clean folder, smoke-test the local build, and inspect supported rendered output. Report automation, rendered-frame inspection, and human playtesting separately.
- Verify the resulting remote commit and content before reporting publication complete. If access or write permission is blocked, prepare a clean source candidate and report the exact blocker; do not bypass denials.
- Give routine progress in the game chat. No watcher, scheduled monitor, or external messaging is part of this update workflow.
- Use Godot's built-in 2D physics unless a measured need justifies another dependency.
- Keep credentials, private paths, logs, caches, engine binaries, export templates, and builds out of commits.
- Do not select a license, spend money, install software, change account access, or publish additional external resources without authorization.
- Keep references atmospheric only; do not copy their characters, levels, names, or signature assets.
