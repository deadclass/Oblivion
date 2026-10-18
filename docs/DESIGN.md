# Current target and aim revision

See TARGET_AIM_REVISION.md. Tap selection and held free aim coexist, with movement available during aim. Targeted ranged launch headings use the selected target, while manual aim takes priority. Arrow collision includes every platform surface. Bomb targeting finds a collision-checked ballistic path within the half-screen horizontal cap. Four inert targets occupy the three platform homes and a ground home. This supersedes the previous target/aim descriptions below.

# Previous aiming and form revision

See AIM_FORM_REVISION.md. LT/L2 is now held aiming, with a transient assist hint and freely chosen direction. Bow supports arbitrary directions, Boomerang is a reversible character form, and Bomb previews the actual capped ballistic flight. This supersedes target cycling and the separate boomerang projectile described below.

# Previous combat-control revision

See COMBAT_CONTROLS_REVISION.md. Jump, sword, dodge, block, dash, ranged use, ranged swap and target cycle have separate buttons. Recovery spin is disabled. There are three practice targets and a highlighted selection. This supersedes the first-pass ability/control descriptions below.

# Movement sandbox design

This revision replaces the goal-driven encounter room with a free practice arena. It contains a continuous 1600px floor and exactly three static one-way platforms. The player has no hearts, fall damage, lives or completion condition. There is no weight, cradle, gate, enemy AI or enemy stage. Leaving the lower/upper safety bounds resets the player without a penalty.

The dummy never attacks or chases. Hits add a displayed percentage, hit count and move label, with stronger knockback as its percentage rises. It returns home after a short idle interval or leaving the arena while retaining results. T/reset-dummy clears its results; R/reset-player retains them; Backspace resets training.

The original maintenance-light visual style and procedural geometry remain. The first pass uses general sword, ranged, explosive and recovery mechanics inspired by the requested platform-fighter reference. No reference character art, models, music, names, animation assets or level layout are copied.

See MOVEMENT_SANDBOX.md for current input/timing parameters. Historical controller/encounter regression sources are under history/controller-prototype; the previous validated builds remain outside this revision. Tests for removed puzzle/enemy behavior are historical and do not validate the new sandbox. The new suite tests the actual new input, physics, abilities, dummy and reset/pause behavior.

