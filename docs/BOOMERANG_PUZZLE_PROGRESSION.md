# OBLIVION — The Stillwater Relay: six-encounter puzzle progression

Design proposal grounded in **TargetAimRevision**, inspected October 17, 2026.

## 1. Decision and scope

Build the progression around **an excursion that changes the world, followed by a return that leaves the body where it began**. Do not treat Boomerang as a teleport, a throwable duplicate, a grappling tool, or a way to recover spent jumps. The player progresses bodily only after returning and using an opened pedestrian route.

This document proposes six **new, separate graybox encounters**. It does not rebuild the first puzzle room, reinstate the old weight/cradle/enemy sequence, change the movement lab, or restore superseded controls. No encounters or puzzle systems described below have been implemented or playtested. The existing sandbox has no objective logic, doors, puzzle receivers, or encounter progression. Source observations, test evidence, calculations, and proposals are distinguished throughout.

**World frame — proposal:** Stillwater Relay is a quiet, abandoned water-management installation. Its mechanical interlocks were designed for a maintenance operator who could inspect inaccessible ducts and return to a safe service mark. Six stations restart a visible ribbon of maintenance lights toward an outlet gallery. Dry channels, inspection windows, amber outbound markings and teal return markings explain function without requiring quests, dialogue, enemies, water simulation, or a new narrative framework. Water and machinery remain noninteractive background imagery. Narrative supports mechanical readability, not the reverse.

**Ideation method:** SCAMPER, developed by Bob Eberle. Retain the same excursion/return interaction while modifying the route, combining receivers, reversing the meaning of outbound/return contact, and changing the useful launch position. The progression deliberately avoids a generic pressure plate, a carry-the-key fetch task, and a timed door sprint as its main ideas: each would obscure or underuse this form's fixed-origin rule.

## 2. Evidence and confidence

Paths below are relative to the project root. Code line references refer to the inspected, unchanged snapshot; gameplay paths begin `prototypes/quiet-relay/`.

### 2.1 Verified current rules

| Topic | Implemented behavior | Source evidence |
|---|---|---|
| Actual transformation | One active form owns travel. The normal 22×36 collision body disappears from queries; the player and attached camera follow the form. Gravity and normal actions are suspended. No concurrent jump, sword, dash, dodge or bomb activation. Weapon cycling does not remove the form. | `scripts/player.gd:78–85,98–119,313–336`; `scripts/world.gd:213–221`; `scripts/abilities.gd:248–265` |
| Plain launch | No held aim: launch heading is sampled once from selected target or facing. Flight does not home or steer. Speed 660 px/s; outbound duration up to 1.2 s. Maximum unobstructed path is 792 px, not a guaranteed displacement through walls. | `scripts/boomerang_form.gd:5–8,32–45,61–77`; `scripts/abilities.gd:248–257`; `scripts/aim_controller.gd:102–110` |
| Aimed launch | Aim must be held at activation to choose aimed form. Hold permits direct normalized steering at 660 px/s for up to 3 s. It uses **raw** aim, not assisted aim. Releasing aim, timing out, or striking a solid initiates return. No distance cap; no slow/hover control. Neutral aim remembers a heading. A plain launch cannot be upgraded by subsequently holding aim. | `scripts/boomerang_form.gd:40–44,61–99`; `scripts/aim_controller.gd:47–57`; `scripts/abilities.gd:255–257` |
| Solid collision | Radius-10 circle swept against collision layer 1, margin 0.001. Floor/walls block it. A blocked outbound move ends the excursion; it does not slide along or bounce off a wall for continued steering. | `scripts/boomerang_form.gd:92–99,130–149` |
| One-way platforms | Form queries ignore layer 2 entirely, so platform slabs are not form barriers, in either direction. The human body uses layers 1+2 and can jump upward through them/drop through them. Arrows, unlike form, treat them as full geometry. | `scripts/world.gd:101–114`; `scripts/player.gd:80,401–419`; `scripts/boomerang_form.gd:139`; `scripts/projectile.gd:183–198`; `tests/aim_form_checks.gd:292–299` |
| Return | Route positions are recorded and traversed in reverse at 760 px/s. No direct shortcut to origin. Return is still solid-collision checked. A newly inserted solid can stall return indefinitely; there is no automatic timeout rescue in that path. Completion restores the exact launch position, not the endpoint. | `scripts/boomerang_form.gd:95–128,174–187` |
| State restoration | Jump count/remaining jumps, dash and dodge availability, dash cooldown, facing and other saved movement state are restored. Velocity becomes zero; jump buffer is cleared. Form does not replenish air resources. Restored airborne body subsequently resumes normal physics. | `scripts/player.gd:313–365`; `tests/aim_form_checks.gd:187–214` |
| Contact | Current form can hit a training target once outbound and once returning, 5% each, using separate registries, a 17 px hit-sweep half-width, and solid-layer line of sight. Training targets receive knockback; they are not fixed puzzle switches. Hitstop pauses form stepping and its age advancement. | `scripts/boomerang_form.gd:12,59–60,151–169`; `scripts/abilities.gd:404–420` |
| Tap/hold aim | Tap LT/L2 or Tab before 180 ms cycles A, B, C, D, Free on release. Hold enters manual aim; pressing ranged while aim is down promotes immediately and consumes the tap. Manual aim overrides stored selection. | `scripts/world.gd:158–205`; `docs/TARGET_AIM_REVISION.md` |
| Assist and movement | Manual aim uses a 16° cone, 650 px range, 70% correction capped at 12°, only with unobstructed targets. Raw direction is kept separate. Running while aiming is allowed. Right stick has priority over movement-direction aiming; a neutral right stick lets movement inputs point. | `scripts/aim_controller.gd:7–11,38–94`; current revision notes; `tests/aim_form_checks.gd:67–144`; `tests/target_aim_checks.gd` |
| Walking/jumping | Ground speed 400, air speed 320 px/s; acceleration matters. Jump -620 with ascent gravity 1400; air jump -540. Fall gravity 1850. Ground jump leaves one air jump. Release cuts upward speed to -260. Coyote 0.09 s, buffer 0.12 s. Landing refreshes airtime resources. | `scripts/player.gd:5–19,141–219,388–419` |
| Dash/dodge | Ground dash 620×0.18 ≈111.6 px; air dash 560×0.18 ≈100.8 px, arbitrary normalized direction; 0.55 s dash cooldown and one air use until landing. Air dodge 480×0.20 ≈96 px, eight-way, separately consumed; ground roll 520×0.24 ≈124.8 px. These are nominal committed distances, not total jump reach. Crouch changes drawing/speed, not the collision box. | `scripts/player.gd:20–30,150,161–209,227–283,388–419,450–466` |
| Bow | Straight arbitrary heading at release, not homing. Charge up to 1 s gives 700–1180 px/s and 4–10% damage. Three arrows maximum; 1.5 s arrow lifetime. Radius-6 sweeps and safe muzzle placement block all platform sides, underside, tops and walls. | `scripts/abilities.gd:236–246,298–313`; `scripts/projectile.gd:46–61,139–198` |
| Bomb | One existing bomb; switch away without deleting it; select Bomb and freshly press ranged again to detonate. Blast radius 88, damage 14%, solid line of sight. Manual speed 650, default free lob (220,-230). Selected target uses validated ballistic search, not homing. Horizontal cap is half visible world width at launch (576 at tested default zoom, not a universal constant). Gravity 1100, terminal fall 700; preview/live share 120 Hz physics. | `scripts/abilities.gd:267–295,358–409`; `scripts/aim_controller.gd:12–14`; `scripts/projectile.gd:18–29,91–137`; `tests/aim_form_checks.gd:319–359`; `docs/VERIFICATION.md:39` |
| Safety/reset | Pause and disconnect cancel form back to origin; reset also cancels it. Player reset goes to sandbox START and retains target results/selection; target reset clears targets and cancels actions; full training reset also selects Bow and Free. Form bypasses the sandbox y-bound respawn check while active; ordinary body outside y>810 or y<-550 respawns. No hearts, lives or fall damage. Recovery-spin function exists in player source but is deliberately unbound/disabled in current abilities. | `scripts/world.gd:124–141,270–311`; `scripts/abilities.gd:223–234`; `docs/DESIGN.md`; `docs/AIM_FORM_REVISION.md` cancellation note; cancellation tests |

**Do not promote historical code to current behavior.** `projectile.gd:63–89` retains an old crescent projectile implementation (0.38 s outward), but current selected Boomerang creates `boomerang_form.gd`. Earlier notes about 330/380 speeds, 1.5 s aimed duration, immobilized aiming, no target cycling, recovery spin or old room objectives are superseded.

### 2.2 Tests inspected and run for this design task

- Read current revision/setup/design notes and the runner plus applicable source/tests. The runner executes sandbox, combat-controls, aim-form, target-aim and target-ranged suites and rejects incomplete or script-error runs (`tests/run_tests.gd:3–30,46–73`).
- **Fresh execution:** copied the current prototype into `%TEMP%/OblivionPuzzleAudit-7a871fa0/quiet-relay`, excluding `.godot`, `.artifacts`, and `history`. Existing Godot 4.7.2 console executable ran:
  ```text
  <existing Godot console> --headless --path <temporary clean copy> --fixed-fps 120 --script res://tests/run_tests.gd --log-file <audit>/tests.log
  <existing Godot console> --headless --path <temporary clean copy> --quit-after 120 --log-file <audit>/smoke.log
  ```
  Result: **455 checks, 0 failures; COMPLETE**, exit 0. Source smoke: **120 frames, exit 0**, no script/parser errors. Tests/logs/caches were generated in the temporary audit folder, not over the project's preserved evidence/builds.
- Evidence caution: the working folder's old `.artifacts/automated-tests.log` ends at **453**, whereas `docs/VERIFICATION.md` reports a later clean 455-check run. The new independent clean-copy run above resolves this distinction; do not relabel the old log.
- These checks validate existing input/physics behavior, not the six proposed rooms. No new geometry was built, no Windows export was needed, and no new rendered-frame, physical-controller or human-feel testing occurred. Prior render claims in `docs/VERIFICATION.md` are historical evidence only.
- Independent read-only mechanics review confirmed the fixed-origin, raw-steering, collision-layer and resource rules. It specifically flagged occupied-origin restoration and inserted-solid return stalls as future integration risks; P2 below reserves both origin and route instead of claiming the current sandbox already handles dynamic gates.

## 3. Shared encounter specification — all proposed, not present

### 3.1 Reusable systems needed

**P1 — fixed form receiver.** A non-knockback sensor using a dedicated swept-contact adapter for active form, with outbound/return phase and excursion ID. It must not rely on ordinary player-area overlap: the normal body's collision layer is zero in form. For consistency, reuse the form's solid line-of-sight test and once-per-phase contact discipline. A receiver reports contact without damage or hitstop. Do not silently turn the training dummy into this system or add it to target cycling/assist groups. Bow, sword, dash, human overlap and bomb do not activate this crescent-marked sensor.

**P2 — transaction and safe exit latch.** Begin an encounter attempt at form launch; collect ordered/phase-specific contacts; commit completion only on a **normal finished return**. `boomerang_finished(form, cancelled)` is a starting integration point, not an existing puzzle event. Pause/disconnect, direct removal, explicit cancellation, R/T/Backspace, and failed/incomplete excursions roll back uncommitted progress. Wrong order marks only this attempt invalid; let the form safely return. Never force a new room teleport while form is active. Open a pedestrian exit only after the body has restored, keep it open until room restart, and never close a solid across an active route or launch body. Origin/route occupancy and safe reset ordering require new tests. No moving geometry is required in these six rooms.

**P3 — room presentation/reset.** Independent room checkpoints, completed-room flags, restart control, receiver feedback, entrance/exit triggers, collision-layer-aware spectator drawing, and room-specific camera framing. Existing R/T/Backspace semantics are sandbox semantics, not a room checkpoint system. Room restart must cancel first, clear projectiles/attempts, then place the human on a safe floor. Until this exists the designs are documents only. No lethal punishment: miss, return, retry.

**P4 — blast cradle (encounter 6 only).** A fixed bomb-specific receiver integrated with actual detonation events and solid line of sight; not a dummy, not an arrow target. It records a preparation latch for the current room attempt. An already placed bomb is not evidence of a detonation. Reject sword/bow/form hits. See encounter 6 for reset rules. This is an optional scope increment, separable from P1–P3.

### 3.2 Geometry, timing and bypass conventions

- Coordinates use x right, y down, in world pixels. Each route lists **form-center waypoints relative to the launch center (0,0)**, not a demand to rebuild current arena coordinates. These specify centerline lengths, not complete scene geometry.
- Use 128 px-wide clear ducts with visible windows and broad turning bays (at least 160×160); radius-10 form leaves 54 px centerline clearance in straight sections. Turn guides are rounded visual cues, not walls the player should scrape. At 660 px/s, 54 px is only about 82 ms of lateral travel: no claim of comfortable human steering follows from geometric clearance. Widen after playtesting; never tighten into a barely fitting slit. Keep sensor centers on guide lines, with a proposed 28 px receiver radius; verify sweep/contact at speed.
- Separate human approach/exit walkways from maintenance ducts. Use complete solid housings, ceilings and endcaps with visible cutaway windows; **one-way slabs cannot seal a form route**. Duct access is not restricted by a tiny aperture. Even if a skilled human enters a duct, form-only receiver and normal-return completion prevent skipping the objective. Puzzles do not depend on proving a gap exceeds the entire jump+dash+dodge envelope.
- All route lengths below exclude deliberate circling. At 660 px/s, aimed outbound budget is **1980 px of path**, not radius. Return adds L/760; full maximum excursion is about 5.61 s before post-return cooldown/input handling. Return time does **not** consume the 3 s outbound budget. Proposed circuits use no expiry countdown outside this budget and no enemy hitstop. A 200 px detour consumes about 0.303 s.
- Jump sanity estimates (continuous, full hold): ground jump apex about 137 px at 0.443 s; a later full air jump can add about 104 px, before dash/dodge contributions. Discrete physics/acceleration/jump cut change exact results. These are not measured maximum reach bounds. Use 96 px step-ups and at most 120 px gaps in the proposed human approaches, with 192 px-wide landing surfaces. Pure-jump same-height flight is approximately 0.83 s; 120 px is well below the ideal 320 px/s airborne span but still needs graybox validation.
- No precision aerial launch is mandatory. Every designated origin is on a broad stationary floor/perch. Form return freezes/resets velocity, not air resources; give the player a true landing before another movement challenge. Never place a timed gate that demands moving while the body is still form.
- Exit gates are solid and latched; jumping, dash, roll or fastfall cannot replace their objective condition. Inspect wall-end, ceiling, corner and checkpoint-reset bypasses during grayboxing. A different launch location is allowed if it still satisfies the actual circuit; no invisible exact-position lock.
- Prompts pair glyph/word/shape with color. Show stored target vs held manual aim distinctly. Explain tap selects, hold steers; ranged while holding aim promotes immediately. Keyboard direction inputs can both move the human and point before launch; use broad safe footing. Do not require mouse precision or right-stick-only control.
- Keep practice dummies out of the puzzle aiming lanes. The current reticle uses assisted direction (`scripts/aim_controller.gd:228–245`), whereas form steering uses raw direction; a nearby assist candidate can therefore make the reticle diverge from the form's actual heading. Receiver exclusion from assist/target groups is deliberate, not a promise of a new auto-lock feature.
- After normal form completion, abilities impose at least 0.42 s cooldown and may require a fresh ranged-trigger release (`scripts/abilities.gd:79–85`). Retry cues must show this short recovery; none of these puzzles requires instant reactivation.

## 4. The six encounters

### 1 — Witness Bell: teach that contact is remote, progress is local

**Learning:** transform, strike something remotely, return to the original body, then walk through the result. This is a proposed new introductory encounter, not a rebuild of any historical first room.

**Layout:** an inspection booth with a 320 px straight horizontal centerline from launch mark to a crescent receiver. A solid stop sits beyond the receiver with its near face at x=460; contact center stops near x=450. The booth has a parallel human walkway ending at a latched exit. Keep duct/exit geometry separate and the origin stationary. The transparent inspection window is art, not an unmarked collision plane.

**Intended solution:** select Boomerang, face right and launch without held aim (Free selection avoids a stray stored heading). Cross the receiver; the end stop automatically begins return. After restoration, the bell's lamp stays on and the nearby pedestrian exit opens. Holding aim and deliberately returning is also valid. Only one receiver contact is required.

**Cues:** a hollow origin silhouette, already supported visually by form source, makes the return point visible. Receiver embossing shows crescent + one stroke; an amber trace lights on contact, teal lights only after successful return. Caption: “Send yourself. Come back. Then pass.” Add a clear Free indicator; do not force a target-cycle puzzle here.

**Failure/reset:** wrong heading or early release yields no completed attempt. Solid contact still safely returns. Pause/reset rolls back an uncommitted bell. No damage or loss; retry from the same booth. Completed bell persists until explicit room restart.

**Feasibility:** receiver reached in 320/660 ≈0.485 s. Stop at ≈450 gives outbound ≈0.682 s, return ≈0.592 s, total ≈1.274 s, comfortably inside the plain 1.2 s outbound duration. No jump or aerial action required; exit is on the same floor.

**Bypasses:** arrows can physically reach the bell but P1 rejects them; likewise sword/bomb. Jumping into the duct is not an objective bypass. Select-target launch is accepted if it actually follows the route; sensors themselves are not selectable targets. Opening the exit on contact rather than normal return would undermine the lesson and must be rejected by P2 tests.

**New dependencies:** P1–P3, single contact and normal-return commit. No new locomotion, carry system, weight or enemy.

### 2 — Bent Inspection: teach held steering and deliberate release

**Layout:** a windowed solid housing routes the form along (0,0) → (300,0) → (300,-240) → (520,-240), receiver at the final waypoint. The turns have broad bays; solid infill blocks the diagonal shortcut. A level pedestrian bypass opens only on completion; the human never has to land at the remote receiver.

**Intended solution:** hold aim before ranged activation, steer right/up/right following the duct, contact the receiver, release aim to start route-retracing return. A plain launch cannot turn around the infill. Continuing past the receiver into a safe end wall is an acceptable alternative return trigger.

**Cues:** two large arrow-shaped ribs at bends; display “Hold to steer — release to return.” The visible trail explains why the return also bends. No small timing window or secondary switch.

**Failure/reset:** clipping a solid begins return without completion unless the receiver was already contacted. No requirement to manually steer return. Incomplete/cancelled attempts reset their one provisional contact; completed attempts latch only after normal restoration.

**Feasibility:** centerline L=760 px; outbound ≈1.152 s, return 1.000 s, total 2.152 s. Aimed budget spare ≈1.848 s (1220 px path), generous for imperfect turns. Release after contact, not at an exact clock time. No human movement requirement.

**Bypasses:** full solid infill prevents straight diagonal flight; one-way surfaces are not substitutes for infill. Off-angle plain launches cannot negotiate both solid bends. Any ingenious curved path that contacts receiver and returns normally is valid. Whole-room perimeter and alternate-origin shortcuts need collision validation; do not add arbitrary launch locks merely to force one drawing of the route.

**New dependencies:** same P1–P3; no new gameplay system beyond encounter 1.

### 3 — Signal Manifold: teach an ordered excursion, not repeated throws

**Layout:** two visible branches off a spacious central junction. Intended route: (0,0) → (240,0) → (240,-180) [A] → (240,0) → (520,0) [B]. Place A in a capped upper bay, B in the right bay, with solid dividers preventing direct diagonal shortcuts. The wall arrangement must leave a clear return through the junction. A and B are fixed receivers, not knockback dummies.

**Intended solution:** hold aim, ascend to A, reverse down the same branch while still outbound, then turn right to B; release. A is recorded once despite being passed again. Both contacts must belong to the **same outbound phase of one excursion**, in A→B order. Return contacts do not rewrite the sequence.

**Cues:** pipes numbered I and II, matching stroke counts on receivers, and a small two-slot circuit diagram at launch. A lights provisionally; two separate throws visibly clear the provisional circuit between launches. Wrong order makes the diagram show “return and retry,” not a silent failure.

**Failure/reset:** B first invalidates this attempt but never traps/stops the form. Early release after A rolls back A at normal restoration. No stopwatch beyond aimed duration. Pausing cannot bank A. Completion persists only after a valid normal return.

**Feasibility:** L=240+180+180+280=880 px; outbound ≈1.333 s; return ≈1.158 s; total ≈2.491 s. Outbound slack ≈1.667 s/1100 px. Sharp reversal needs no turn-acceleration model because current raw steering changes direction immediately. No human jump needed.

**Bypasses:** one A touch repeated on branch exit must not count as B; sensor IDs and phase registries, not damage counts, determine sequence. Separate launches cannot accumulate A then B. Entering from another permitted launch and still doing A→B is a valid alternate solution. Outbound loops are valid if within the timer. Arrows and stored target selection cannot satisfy P1.

**New dependencies:** P2 ordered same-excursion evaluation and readable provisional/wrong-order UI. No new movement or collision behavior.

### 4 — Upper Service Mark: combine bodily positioning with remote work

**Layout:** a dry lower walkway and two 192 px-wide human platforms, tops rising 96 px then another 96 px, horizontal gaps no more than 120 px. Use readable one-way platforms for this human approach. The upper service floor has a broad marked origin. Beyond it is a solid housing with a raised horizontal inlet and a receiver route (0,0) → (300,0) → (300,-180) → (600,-180). The lower origin's duct route must include an extra 800 px enclosed access dogleg before joining the 780 px upper route; total lower-route length 1580 px. A solid roof and endwalls prevent walking directly to the receiver/exit.

**Intended solution:** jump onto the first and second landings, allowing a full landing to refresh resources. Walk to the upper mark, hold aim, route to the receiver, return to the upper perch, then take the opened human catwalk. The lesson is “move the launch point,” not “stay where the form ends.” The lower 1580 px route is deliberately a harder valid alternative, not falsely advertised as impossible.

**Cues:** an inspection diagram shows the upper mark with a much shorter pipe route. The receiver can be seen from below, but the solid duct—not camera framing—explains the access route. Use platform arrows distinct from duct arrows. Returning to the perch lights a downward-facing footprint glyph before the exit opens.

**Failure/reset:** missed jump lands on a continuous safe floor; no pit deaths. Form wall contact returns to the actual chosen origin. Room restart returns to its lower entrance and clears provisional progress, not a suspended midair state. No auto-grant of spent air resources on return.

**Feasibility:** each 96 px rise is below the approximate 137 px full-held ground-jump apex; 120 px gaps have generous nominal same-height airborne range. Ceiling headroom must accommodate the 36 px body. Upper route L=780: outbound 1.182 s, return 1.026 s, total 2.208 s; slack 1.818 s. Lower route L=1580: outbound 2.394 s, return 2.079 s; it is within 3 s and therefore a valid challenge shortcut. Do not claim the raised route is mandatory without a separately tested restriction. No need to chain dash+dodge or restore removed recovery spin.

**Bypasses:** double-jump/air dash can skip the first landing; accept this expression of existing movement. An airborne launch still returns to that airborne origin and cannot become a permanent remote landing. Climbing the human approach can be skipped only by doing the harder full circuit, not by crossing the latched exit. Check diagonal/roof shortcuts when grayboxing the specified lower dogleg.

**New dependencies:** P1–P3 plus static room geometry only. This encounter deliberately introduces no additional receiver rule.

### 5 — Echo Governor: test the return path as an interaction

**Layout:** broad low alcoves carry A at (240,0) and B at (480,0); a visible governor C sits after a turn at (600,-180). Route: (0,0) → (240,0) [A] → (480,0) [B] → (600,0) → (600,-180) [C]. Solid dividers establish the bend; no doors move within the form route. A and B display amber outbound faces and teal return faces.

**Intended solution:** contact A then B then C outbound. C arms the governor. Release aim. As the form retraces automatically it must contact B then A **returning**, and complete normal restoration. This yields A→B→C outward / B→A return, all in one excursion. Return itself is automatic; the puzzle is arranging the outward path so it contains the needed return contacts.

**Cues:** twin strokes on A/B, single stroke on C; diagram traces amber toward C and teal back through B/A. C lights “path armed.” Return contacts make a different sound and fill the second face. Sign: “The governor closes the circuit on the way home.” Avoid text implying manual return steering.

**Failure/reset:** releasing before C or taking an outbound route that omits A/B cannot be repaired by return-only contacts. It rolls back after the body restores. Pause, disconnect, direct removal and reset cannot masquerade as a return crossing. Nothing inserts a solid into the saved route. Completion opens an off-route walkway after restoration.

**Feasibility:** L=780 px; outbound ≈1.182 s, return ≈1.026 s; ample slack. Return should cross B roughly 300/760≈0.395 s after leaving C and A roughly 540/760≈0.711 s after C, assuming the illustrated path. These are observational guides, not required timed windows. P1 sensors must not cause hitstop, and their fixed positions avoid dummy-knockback ambiguity. No human jump/dash requirement.

**Bypasses:** passing A/B twice while still outbound does not fill their teal faces. A completion callback alone does not count as return contacts. Cancellation returns position instantaneously but is marked cancelled and rejected. Direct-straight return/teleport must not be implemented as a convenience. An alternate route including all required phase contacts remains valid.

**New dependencies:** extend P2 with phase-specific sequence evaluation. Existing combat's separate outbound/return hit registries demonstrate the distinction but do not implement a puzzle event or a stable receiver.

### 6 — Outlet Commissioning: combine preparation, positioning and a complete circuit

**Layout:** a safe entrance walkway has a raised service landing 96 px up (192 px wide; approach gap ≤120). From its marked launch area, a wide open bomb lob reaches a blast cradle centered about 300 px horizontally away, on a fixed shelf of similar height. No roof, platform or wall may cross the chosen arc or the short blast line to the cradle. Behind a **permanent** partition, a windowed form duct follows (0,0) → (300,0) [A] → (300,-240) → (700,-240) [B] → (700,0) [C] → (760,0) release bay. Straight legs total 1240 px. Solid dividers prevent corner cutting through the partition. Bomb cradle, form duct and pedestrian exit are separate readable mechanisms, not a hidden remote gate hazard.

**Intended solution:** reach the landing. Select Bomb, hold aim and use its preview to land beside the cradle, release aim as needed, then press ranged again with Bomb selected to detonate and set the preparation latch. Select Boomerang. In one aimed excursion contact A→B→C outbound, release in the broad bay, then cross B→A on the recorded return and restore normally. C is an outbound-only arm receiver; passing it again during return is ignored. Successful return commits the outlet and opens the human exit permanently until room restart.

The bomb prepares an electrical latch only; it does not open/close any form-route wall. The latch has no short countdown. Weapon changes happen before launch or after restoration, never as a demand to use Bomb while transformed. Allow the player to detonate a valid cradle bomb from any safe human position; this is a valid alternate order, not a failure.

**Cues:** a blast-ring glyph on the cradle, crescent glyphs on duct receivers, and one circuit diagram with a separate preparation box and amber/teal path. The bomb preview landing marker confirms placement; no target-selection dependency is required. At launch the UI shows “Cradle ready / route incomplete,” so players do not confuse preparation with completion. Repeat earlier cues without adding a new control.

**Failure/reset:** failed lob can be detonated harmlessly and retried; one-bomb rule remains. Wrong route or early return clears provisional A/B/C but keeps the prepared cradle for retries. Pause/disconnect cancels only the in-flight circuit; does not grant completion. Explicit room restart cancels all actions, removes the bomb and clears cradle and circuit together. This persistence policy is **new**, not inferred from sandbox target retention. No punishment clock or inserted route obstruction.

**Feasibility:** form L=1240, outbound ≈1.879 s, return ≈1.632 s, total ≈3.511 s; outbound spare ≈1.121 s/740 px. Return crossing of C is harmless; B then A are checked in order. A 300 px bomb displacement is below the tested default 576 px cap, but being within the cap alone is not proof of reachability. A continuous same-height manual lob at 650 px/s and gravity 1100 needs sin(2θ)≈300×1100/650²≈0.781 (low-angle seed ≈25.7° upward); actual muzzle offset, shelf height and 120 Hz integration change landing. Use this only as a seed and accept the live preview's clear settled landing within the 88 px blast radius and unobstructed blast line. Do not depend on the finite selected-target solver recognizing a new cradle. At a zoom making half-view width less than 300, reframe/shorten the throw; current zoom-dependent cap must remain intact. Human rise/gap checks are the same conservative ones as encounter 4.

**Bypasses:** arrows cannot charge the blast cradle; bomb blast cannot activate crescent sensors; sword cannot substitute for either. A previously planted bomb may legitimately prepare the latch later, but cannot satisfy route contacts by itself. Repeated form launches cannot accumulate circuit steps. Body entry into the duct, overshooting C and cancelling, platform drop-through, and a skipped approach landing cannot satisfy normal-return transaction completion. Enclose wall/roof endpoints and audit alternate origins. Keep route and origin free of all gate collision throughout attempts.

**New dependencies:** P4 blast cradle plus the already taught P1–P3 and phase ordering. If P4 is outside the next implementation budget, replace the cradle with a clearly labelled manual preparation console and describe that as a different proposed interaction; do not pretend bomb placement currently powers scenery. Recommended first implementation ends at encounter 5 before adding this bomb-specific adapter.

## 5. Implementation and validation contract

**Recommended sequence:** first create P1–P3 in a separate, user-authorized graybox branch/folder and validate encounters 1–2; add ordered and phase evaluation for 3/5; block out the human approach for 4; only then add P4 and encounter 6. This document is not authorization to perform those changes. Preserve this movement lab and previous builds as baselines.

| Encounter | Concept taught/tested | Outbound centerline | Outbound / return estimate | Genuinely new rule beyond shared foundation |
|---|---|---:|---:|---|
| 1 Witness Bell | Contact, exact-origin restoration, bodily exit | 450 px to stop | 0.682 / 0.592 s | Single receiver normal-return commit |
| 2 Bent Inspection | Hold steering; curved return | 760 px | 1.152 / 1.000 s | None |
| 3 Signal Manifold | Ordered contacts in one outbound excursion | 880 px | 1.333 / 1.158 s | Same-excursion order |
| 4 Upper Service Mark | Choose a better grounded launch position | 780 px upper; 1580 lower | 1.182 / 1.026 s upper | None; geometry changes usefulness |
| 5 Echo Governor | Outbound arms, return completes | 780 px | 1.182 / 1.026 s | Phase-specific order |
| 6 Outlet Commissioning | Bomb preparation + full route + safe return | 1240 px | 1.879 / 1.632 s | Bomb-specific preparation latch |

### Required automated acceptance checks for a future implementation

1. Keep all 455 existing checks passing; do not change their expected current mechanics to make a puzzle work.
2. Receiver contact uses swept form geometry at 660/760 px/s, once per ID/phase/excursion; does not miss a sensor between ticks or trigger through solid walls. Normal-body layer zero must not disable contact reporting. Test both maximum-speed directions and corner cases.
3. Only normal completion commits a valid transaction. Test aim release, timeout, wall-blocked return, reset, pause, disconnect, direct node deletion and stale held inputs. Invalid/cancelled attempts never bank partial ordered progress.
4. Outward solid collision initiates return; return path remains clear. Assert no gate/receiver-created solid can overlap the origin or any recorded segment. Do not rely on reset as the ordinary solution for a blocked return.
5. One-way behavior stays asymmetric: human jump/drop, form ignores, arrows fully collide, bomb upward pass/downward landing. Never silently convert platform layers to solve a layout.
6. Phase logic: A twice outward is not A outward plus A return; separate launches cannot accumulate ordered contacts; repeated return contacts cannot double-commit. Contact-only listeners do not award cancellation completion.
7. Run generated human-body trajectories through each 96 px rise/120 px gap using actual physics, collision headroom and input durations. Include variable jump release, double jump, analog dash, dodge, fastfall, missed landing and no-refresh airborne form return.
8. Replay each waypoint route at fixed physics rate; verify timing and solid clearance; then perturb turns/launch positions. The table is analytical budgeting, not an implemented trajectory proof. Test roof/diagonal/perimeter shortcuts and accept legitimate alternate circuits.
9. Bomb cradle uses actual detonation, 88 px radius and solid visibility. Compare preview/live landing at intended shelf, verify zoom-dependent range captured at launch, wrong-weapon rejection, one-bomb behavior, existing-bomb detonation, and restart cleanup.
10. Room restart is atomic: cancel form/actions before relocating; clear temporary state and projectiles; restore safe human collision and resources at the checkpoint; never leave an invisible or trapped body.

### Required rendered and human checks — not yet performed

- Inspect all six at ordinary camera framing: origin, next turn, receiver identity and exit state must remain readable. Camera follows form and can leave origin off-screen; use a small circuit diagram rather than promising both are always visible. Do not shrink the camera until a 300 px bomb throw violates the cap.
- Test keyboard directional steering and real Xbox/PlayStation/Steam Input separately. Validate tap/hold discovery, neutral-heading retention, high-speed turn comfort, correct release, and the player's understanding that return is automatic. No physical-device claim is supported by the present tests.
- Confirm first-time players can describe where they will reform, why an attempt failed, and why the exit did/did not open. If not, revise cues/space before adding mechanics.
- Prefer untimed retries, wide corridors and persistent completed exits over tighter clocks. Geometry timing has arithmetic support here; puzzle fun, accessibility and readability still require graybox playtesting.

## 6. Deliverable boundary

This task adds only `docs/BOOMERANG_PUZZLE_PROGRESSION.md`. It does not implement receivers, doors, checkpoints, room geometry, objectives, narrative quests or new input. Gameplay source, tests, scenes, project configuration and all existing artifacts/builds are to remain unchanged. No remote publication, ZIP update, installation or unrelated-project action is part of this work.
