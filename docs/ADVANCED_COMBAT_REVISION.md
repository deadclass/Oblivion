# Advanced combat — 2026-10-09

This revision restores J alongside left click, adds K heavy attacks and held L frontal blocking, and corrects guard damage admission. It extends baseline d73a1f31dc416882f900b77e94f7206efdbebb7c and passed 217 engine assertions with zero failures. See [verification](VERIFICATION.md).

## Controls and behavior

| Input | Damage | Windup | Active | Cooldown from input | Reach |
| --- | --- | --- | --- | --- | --- |
| J / left click | 1 | None | 140 ms | 300 ms | 66 px |
| K | 2 | 320 ms | 180 ms | 900 ms | 78 px |

Each attack requires a fresh press. Both use per-swing target tracking and solid-wall line of sight. Carrying or blocking prevents attack initiation. Amber feedback and a HUD countdown expose the heavy windup; floating damage shows the actual amount.

Hold L to block guard melee from the facing side. A successful front block prevents damage, knockback and weight-drop effects without granting invulnerability or stamina. Rear strikes, falls and pits remain dangerous. Blocking halves walking speed and retains normal jump physics. Carrying, attacking/recovery and knockback suppress it. Release L to stop immediately. L held through death, R, T or full reset requires release and a fresh press before shielding resumes. A cyan shield and HUD label expose the state.

## Guard damage correction

The old damage handler rejected hits when the completed-room won flag was set. R/T preserve progress, leaving a reset guard unable to hurt the player. The revision removes that exemption while retaining 800 ms accepted-hit protection and one-second recovery grace. Engine checks confirm a fresh eastern encounter damages the player and a completed-room T/R sequence damages again after grace expires. The user's exact earlier played build/state remains unknown.

Windup still requires a center within 60 px horizontally and +/-38 px vertically. Active damage tests overlap with a 60 px frontal rectangle and a centered 76 px-high query. The player's body edge can overlap with center distances 64–70 px; 72 px misses. Locked facing, rear exclusion, vertical clipping and solid-wall obstruction remain. Tests cover +/-37.9 and +/-38.1 px and front-body-edge contacts.

The five-heart recovery, moving platforms, galleries, strict cradle boundary, guard-defeat prerequisite and weight-delivery/exit route remain intact. Built-in Godot 2D physics and original procedural artwork suffice; no new dependency or asset was added.

## Verification limits

The suite includes 50 advanced-combat assertions and 167 retained regressions. Engine event injection verifies J/K/L and mouse behavior, movement, jump height, timing, walls, front/rear blocking, carrying/knockback exclusions and reset/death cancellation. Source and release smoke checks, Windows export and 11 inspected staged release frames passed. Native OS input and human playtesting remain outstanding. Builds, logs and captures stay local.
