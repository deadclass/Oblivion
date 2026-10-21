# Sequential encounter revision

The guarded weight is now protected by three successive enemies. Only one is active at a time. Every intermediate defeat cancels the player's current weapon and schedules the next enemy at the original eastern spawn after a 1.25-second HUD countdown. Repeated frames cannot create duplicate spawns. The western cradle unlocks only after the final tank dies; until then E retains carried weight at the sealed cradle.

## Tuning

| Enemy | Health | Run speed | Damage per hit | Warning | Active | Recovery |
| --- | --- | --- | --- | --- | --- | --- |
| Original guard | 5 | 247 px/s | 1 heart | 0.30 s | 0.14 s | 0.65 s |
| Runner | 2 | 510 px/s (twice player 255) | 0.5 heart | 0.30 s | 0.14 s | 0.65 s |
| Tank | 12 | 90 px/s | 1 heart | 0.55 s | 0.14 s | 1.10 s |

Runner acceleration is 3600 px/s² on ground and 2800 in air. It brakes to 247 px/s near the pit/support approach or obstacles and uses a 247 px/s navigation air limit to avoid overshooting landings. The tank keeps its 90 px/s ground pursuit and uses 180 px/s navigation hops to reach the unchanged support layout. Both pass live unsolved-pit crossing checks. One two-damage K heavy or two one-damage J/left-click hits defeat it. The tank has a 0.65-second delayed turn, shows a TURN countdown, and locks facing through warning, strike and recovery. Its front plate flashes on rejected hits; the yellow rear vent and REAR OPEN label expose the opening. A rear heavy deals two damage; twelve rear normal hits or six rear heavies defeat it. Center/purely vertical origins and the one-pixel center boundary are armored. Damage is checked against current facing at actual contact, not facing when the player began the attack. Unsourced damage cannot bypass armor.

Speed, health, stage delay and tank turn/warning/recovery values are exported in scripts/world.gd. Existing J/left-click/K/L controls and movement remain. Blocking halves player speed with normal jumps; it stops frontal enemy melee but not rear hits or full-heart fall/pit hazards.

Health uses integer half-heart units internally, with a heart-valued property for controller compatibility. The maximum remains five hearts. Runner hits remove one half unit; other enemy hits and hazards remove two. The HUD fills half of a heart and shows 4.5/5 accurately. Accepted-hit grace remains 0.8 s, recovery grace 1 s. L release/repress requirements remain.

R and death preserve encounter stage and surviving enemy health while canceling weapons and turning state, healing at the checkpoint and recovering carried weight. A pending arrival remains pending. T resets all enemy stages to the original guard and cancels pending arrivals; an already restored relay stays open. Backspace resets all stages, puzzle, health, checkpoints and platform phases. No persistent save is added.

## Verification strategy

The 217 existing controller, single-guard, moving-platform and puzzle regressions run with an explicitly isolated one-guard encounter configuration. New encounter checks instantiate the unmodified three-enemy configuration and verify ordering, transitions, no duplicates, actual runner speed/damage, fractional health/HUD, tank front/rear/facing geometry, reset/death, final unlock and a live movement/rear-heavy opening. This separates established mechanics from the new production sequence. The final verification report records engine/export/smoke/render results. Native OS input and human playtesting remain distinct and outstanding.

The earlier source and executable remain preserved. This revision is local; no GitHub publication or ZIP update is included.
