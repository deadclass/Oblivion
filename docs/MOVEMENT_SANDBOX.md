# Combat controls and dash revision

| Action | Xbox / Steam | PlayStation | Keyboard / mouse |
| --- | --- | --- | --- |
| Move / direction | Left stick / D-pad | Left stick / D-pad | A/D, W/S or arrows |
| Jump / double jump | A | Cross | Space |
| Sword | X | Square | J / left click |
| Dodge | B | Circle | Q |
| Block (hold) | LB | L1 | L |
| Dash | RB | R1 | Shift |
| Ranged weapon | RT | R2 | U / E |
| Swap ranged weapon | Y | Triangle | F |
| Cycle target | LT | L2 | Tab |
| Directional heavy sword | Right stick | Right stick | Direction + K |
| Pause | Start/Menu | Options | Esc |

Only A/Cross is a controller jump binding. Press it again for the existing double jump; tap for a short hop or hold for full height. Fast fall, down+jump platform drop-through and ordinary movement keep their previous tuning.

## Independent defence and movement

LB/L1 only raises the grounded block; directional input does not turn it into a roll. B/Circle performs a grounded directional roll or a neutral spot dodge, and the existing neutral/directional air dodge. One air dodge is available per airtime.

RB/R1 starts a dash. On the ground it goes left/right, using facing when the stick is neutral or only vertical. In the air it follows the normalized full stick direction, including arbitrary diagonal headings; a neutral press uses facing. Ground speed 620px/s, air 560px/s, duration 180ms, recovery 100ms, cooldown 550ms. There is one separate air-dash use per airtime, restored on landing. Dash is a movement burst, with no damage or added invulnerability by itself. Blocking, dodging and dashing are separate mutually exclusive states.

Dash plus melee within 80ms in either button order starts a swinging sword dash. It deals 8% per target once across the 180ms moving volume, with 400ms sword cooldown and solid-wall/floor line of sight. A normal slash already connecting before the upgrade is not applied again to that target; further targets can receive the dash hit. The chord crosses the normal slash's brief hitstop safely. Dash direction comes from the movement stick, not the selected target.

## Ranged loadout

Triangle/Y cycles Bow → Boomerang → Bomb → Bow, one step per press. The sword remains the same in all three loadouts, including directional normal/heavy attacks.

- Bow: hold RT/R2 to charge up to 1s, release to fire. Existing 4–10% damage and arrow speed/cap remain.
- Boomerang: press RT/R2 to launch the returning throw. It can hit once outward and once returning, 5% each.
- Bomb: press RT/R2 to deploy the remote explosive; press it again with Bomb selected to detonate. Existing 14% radius 88px blast and platform settling remain.

Stick direction does not change which ranged weapon is used. Switching preserves a live boomerang or placed bomb. Switching while holding a bow cancels the charge without firing; release RT/R2 before using the next weapon. Melee can put away a bow without shooting it. Player or target reset clears live abilities while retaining the selected weapon; full training reset returns to Bow.

Rising-spin recovery has no binding and its activation is disabled for this pass. LT/L2 is reserved for target cycling.

## Targets and reset safety

Three stationary named dummies are available: Target A on the left, Target B in the middle, Target C on the right. LT/L2 cycles the highlighted target once per trigger press, updates its damage/hit HUD, and turns the player toward it. Selection does not create homing projectiles or teleport attacks; normal hit volumes and intervening geometry still apply. Removed targets are skipped; zero/one-target cases are safe.

R resets the player, T resets all target results, and Backspace resets training/loadout/selection. Player and target resets retain selection; full reset selects Target B. Pause menus retain A/Cross resume, Y/Triangle reset player, X/Square reset targets and a fresh one-second B/Circle hold for full reset. Menu presses cannot trigger a jump, sword, dodge, weapon swap or target cycle on resume. Pause/unplug cancels dash/chord/bow transients and clears stale input without granting another consumed air use.

The native controller/Steam Input routing and movement feel still require hardware/human playtesting. The scene remains an original procedural training prototype with no objective, enemies, lives or self-damaging bomb behavior.
