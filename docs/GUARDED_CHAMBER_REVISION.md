# Guarded-chamber revision

Revision requested October 6, 2026 (America/Chicago). The former fleeing training dummy becomes a pursuing melee guard. The chamber doubles to 2304 pixels wide, gains upper galleries and obstacles, and places both the guard and weight at the far eastern side, opposite the western player entrance. Defeating the guard is required before placing the weight in the western high cradle.

## Room and objective

The player starts at x=95. The guard starts at x=2090, beside the weight at x=2150. Ten moving platforms combine the original western cradle steps, a small pit-crossing support, and eastern steps toward two second-floor galleries at y=292. Fixed blocks and suspended ledges obstruct floor and gallery routes. The pit-crossing support permits reaching the guard before puzzle completion; placement later restores the safe bridge and opens the far eastern gate.

The bounded camera follows the player horizontally and vertically. A fixed `CanvasLayer` keeps controls, hearts/status, and the pause label visible as the room scrolls. Lower-floor checkpoints at x=580 and x=1840 heal on first activation.

Pick up the weight with E and return it west after defeating the guard. E near a sealed cradle reports the prerequisite and retains the carried weight; E elsewhere drops it. A solved weight follows the moving cradle. A weight lost to the pit returns to its eastern start.

## Pursuit and melee

The guard waits by the weight until the player approaches within 480 px horizontally and 330 px vertically. Once alerted, it chases and plans jumps across reachable moving/fixed supports and around obstacles. Normal player speed stays 255 px/s against guard speed 247 px/s, an 8 px/s advantage of about 3.2%. Carrying reduces player speed to 84% and prevents player attacks.

Left mouse button remains the player's attack: one damage per target per swing, 140 ms active time, and 300 ms cooldown. Holding the button does not repeat attacks. The guard has five health.

The guard's separate baton deals one player heart per successful strike. Its 300 ms orange windup gives warning, followed by a 140 ms active window and 650 ms recovery. Facing locks during windup/active phases, and the guard pauses its advance while committing. Its 60 px reach and 38 px vertical range limit attacks to nearby players. A collision ray blocks strikes through solid obstacles. Each swing can attempt damage only once against the player.

A combat hit gives 800 ms combat invulnerability, a short 165 px/s horizontal knockback with a small upward impulse, and damage feedback. A carried weight drops when struck. Killing the guard stops its movement/weapon and unlocks placement. The guard retains its procedural original visual identity, health/hit display, and damage flash.

## Recovery and reset rules

- Five player hearts, the 180+ px large-fall rule, and pit recovery remain. Each qualifying landing costs one heart once; a pit costs one heart while preserving remaining health.
- At zero hearts, return to the checkpoint with five hearts. R also restarts/heals; first activation of each checkpoint heals fully.
- R/death cancel both weapons, restore carried weight to its eastern start, and grant one second of combat grace. They preserve relay state, guard damage/defeat, and platform motion.
- T resets the guard at the eastern weight with five health, zero hits, unalerted state, and fresh movement/weapon planning. It cancels the player's swing and relocks an unsolved cradle. A restored relay stays open.
- Backspace resets the room, puzzle, checkpoints, guard, health, and platform phases. No progress persists between launches.

## Engine and verification

Godot's built-in 2D collision bodies, moving support transport, shape queries, rays, and `move_and_slide()` cover this slice. Scripts provide jump planning, attack phases, invulnerability, and the placement prerequisite. No new software, external assets, physics dependency, paid tool, or account change is needed.

See [VERIFICATION.md](VERIFICATION.md) for current measured checks, clean-source/build runs, rendered inspection, and remaining limitations. The prior 83-check moving/evasive-dummy revision is a historical baseline. Its passing result does not establish this revision's status. Automated engine input and rendered-frame inspection are reported separately from human playtesting; no human playtest or physical keyboard/mouse test has been recorded.

Every completed, tested update is authorized for sync to `deadclass/Oblivion`, branch `prototype/quiet-relay-collaboration`, and existing draft PR #1. Inspect and preserve collaborator work, verify the resulting remote commit/content, and keep the PR unmerged. No force-push, watcher, installation, or new publication destination is authorized. Builds, logs, caches, engine/template binaries, private paths, and credentials remain outside commits. Licensing is undecided.
