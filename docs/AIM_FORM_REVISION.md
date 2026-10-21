# Aiming and returning form

This previous revision is superseded by [TARGET_AIM_REVISION.md](TARGET_AIM_REVISION.md): tap targeting is restored, movement while aiming is enabled, assistance/speeds are doubled, and aimed form lasts three seconds. Use that guide for current controls.

Hold LT/L2 (Tab on keyboard) and point either stick, D-pad, or direction keys. Right stick takes priority when tilted. The character stops walking while aiming; ordinary jump, dodge, block, sword, and dash bindings remain available. The right stick aims while LT/L2 is held and performs directional heavy attacks otherwise.

Aim assistance considers visible, unobstructed dummies within 650px and a 16-degree cone. It applies 35% of the angular difference, capped at 6 degrees. The aiming ray remains under stick control, retains its heading at neutral, and releases assistance when you point away. No target cycling or persistent lock is used.

- Bow: hold RT/R2 (U/E) to charge, then release to fire. While holding aim, the shot follows the current full direction, including vertically, downward, and diagonally. Without aim it fires horizontally. Existing charge, damage, arrow count, and lifetime remain.
- Boomerang: RT/R2 transforms the character into a spinning form. A plain launch travels straight for up to 1.2s at 330px/s, compared with the previous 660px/s throw and 0.38s outbound duration. Holding LT/L2 on activation enables up to 1.5s of flight with direct stick steering. Releasing aim or reaching the timer starts the return at 380px/s. The form retraces its route to the exact launch point, then restores the character. Solid geometry constrains it; one-way platforms allow passage. It can hit each dummy once outward and once returning for 5% each. It preserves consumed air jumps, dashes, and dodges.
- Bomb: holding aim shows a dotted trajectory and a landing marker. RT/R2 launches along the aim direction; pressing it again with Bomb selected detonates the placed bomb. The simulation handles gravity, floor/platform landings, and wall bounces. Horizontal displacement from launch is capped at half the visible screen width in world units, captured at launch. At the limit the bomb loses horizontal motion and falls naturally. This applies to aimed and ordinary throws, including throws from high in the air. Damage and blast radius remain 14% and 88px.

Y/Triangle (F) cycles Bow, Boomerang, Bomb; X/Square (J/left click) always uses the sword. No recovery spin is enabled. There are three inert practice dummies and three one-way platforms, with no objective or enemy progression.

Pause, unplug, and reset cancel the form and restore the character at its origin. Existing stale-input guards remain. R resets the player, T resets target results, and Backspace resets training and loadout. Prior verified source/builds and the existing ZIP remain preserved. This is a local revision only; no remote publication is authorized.

Synthetic input, real physics, and render inspection are recorded separately from physical controller and human feel testing in VERIFICATION.md.
