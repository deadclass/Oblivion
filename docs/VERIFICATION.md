# Verification — 17 October 2026

Engine: Godot 4.7.2 stable, standard Windows console build.

Both the completed local handoff and this staged portable public source were tested. Public-copy results:

| Check | Command after changing to repository root | Observed result |
|---|---|---|
| Clean import | `godot --headless --editor --path project --quit` | Exit 0, scripts registered without errors |
| Regression suite | `godot --headless --path project --fixed-fps 120 --script res://tests/run_tests.gd` | `RESULT: 505 checks, 0 failures; COMPLETE`, exit 0 |
| Default scene smoke | `godot --headless --path project --quit-after 120` | Exit 0 |

The regression suite covers movement, combat, input dispatch/reconnect guards, aim and ranged targeting, boomerang path return, bomb prediction, and Return Relay traversal/reset/slit clearance.

## Limits

- No human physical-controller or gameplay-feel acceptance pass is claimed.
- Headless smoke is not a visual rendering review.
- No new executable was exported. The portable export preset, with standard installed templates instead of personal paths, has not been separately export-tested.
- The enlarged slit is 72 px high versus an ordinary body around 36 px tall. Gate-blocking tests do not prove every jump/dash bypass is impossible.
- Passing tests do not establish legal provenance, complete ChatGPT revision history, production readiness or commercial license clearance.
- Local build, desktop executable and shortcut are unchanged.

`SOURCE_SHA256.txt` records staged source bytes. Generated import caches are excluded from publication.
