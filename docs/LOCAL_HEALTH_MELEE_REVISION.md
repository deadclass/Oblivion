# Historical health/melee revision

The current [guarded chamber](GUARDED_CHAMBER_REVISION.md) supersedes this iteration's harmless-target behavior. The enemy now pursues and deals damage; placement requires its defeat. Current results are in [VERIFICATION.md](VERIFICATION.md). The history below describes the earlier training system.

This file retains its original filename for existing links. The health/melee system is part of the current collaboration source; earlier notes describing it as a permanently local or unpublished revision are superseded. Update publication follows the completed-and-tested workflow in [CONTRIBUTING.md](../CONTRIBUTING.md), with remote completion verified separately. The later [moving-platform/chase revision](MOVING_CHASE_REVISION.md) replaces the original stationary dummy and J/X attack controls.

The player has five hearts. `large_fall_threshold` in `player.gd` defaults to 180 pixels, measured from the airborne apex to the landing. A qualifying landing removes one heart once; standing on the floor does not repeat damage. Ordinary jumps remain below this threshold. Health is clamped at zero; exhaustion returns to the last checkpoint with five hearts.

A pit fall removes one heart and returns to the checkpoint while preserving remaining health. First checkpoint activation and manual R restart restore five hearts. R/death recover carried weight and cancel active attacks while retaining relay and dummy progress. Backspace restores the whole room, all hearts, the dummy, and platform phases. T resets the dummy's health/hit count/position/velocity/planning and cancels an in-flight swing.

Left mouse button swings the signal baton in the facing direction. `melee.gd` exports one damage, 66-pixel reach, 140 ms active time, and 300 ms cooldown. A forward rectangle physics query selects target areas; a per-swing target set prevents repeated hits across physics ticks. Holding attack does not repeat swings. Carrying the weight prevents starting attacks.

`dummy.gd` now provides a fleeing, jumping five-health training target, with hit count, damage flash, floating -1, and depletion/reset feedback. A `CharacterBody2D` collides with world surfaces, while a child target area forwards melee damage. The dummy cannot damage the player. At zero health, its AI stops; gravity and platform support remain. No enemies are present.

The player uses a separate collision layer so the falling weight collides with world geometry without being pushed through the floor by an overlapping player. The dummy also uses a separate world-only body layer, allowing the player and weight to pass through it.

The earlier health/melee revision passed 55 automated checks, source smoke, Windows export, graphical capture, and build smoke. Those are historical results. The current moving-platform/chase revision passed 83 checks in canonical and portable source; `VERIFICATION.md` records current source, Windows export, rendered inspection, and smoke evidence. No human playtest or native keyboard/mouse input test has been performed; InputMap injection and real physics queries provide automated coverage.
