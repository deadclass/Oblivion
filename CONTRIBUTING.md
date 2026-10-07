# Collaborating on Oblivion

The Quiet Relay is a working prototype. Keep changes focused on original movement, environmental interaction, and atmosphere. The project title and larger game direction remain open for discussion.

1. Start a descriptive branch from the current `main` branch. Keep unrelated experiments in separate branches or prototype folders.
2. Read `docs/SETUP.md` and run the baseline tests before editing.
3. Describe the concrete behavior you are changing. Record movement parameter changes and their reason in the PR.
4. Run the automated checks after gameplay changes, then play the room yourself. Record engine version, checks performed, and any remaining issues.
5. Open a draft PR while work is exploratory. Do not merge or enable auto-merge without the owner's approval.

Commit source, original assets, stable Godot `.uid` files, tests, and useful documentation. Keep engine binaries, export templates, generated `.godot` caches, local logs, credentials, private paths, and exported builds out of Git. Artwork currently comes entirely from procedural drawing in `world.gd`; there are no external asset dependencies.

Do not introduce copied characters, levels, signature artwork, or names from reference games. Licensing is undecided: do not add a license or external assets with new licensing obligations without discussing it with the owner. The current public repository does not grant an additional license.

Useful next contributions: human movement playtest feedback, more accessible/remappable controls, sound direction using original assets, and a second small interaction that deepens discovery. Keep each addition small enough to test. Do not expand scope into combat, procedural worlds, or a large content pipeline until the first room feels good.
