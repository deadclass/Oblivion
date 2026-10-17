extends "res://tests/aim_form_checks.gd"

# Persistent selection is exercised separately from the inherited manual-aim
# suite. Actors can be frozen to isolate geometry, but arrows, bomb simulation,
# production collision queries, release dispatch and damage remain live.
func run(test_host) -> void:
	host = test_host
	world = load("res://main.tscn").instantiate()
	host.root.add_child(world)
	player = world.player
	dummy = world.dummy
	abilities = world.abilities
	player.test_control = true
	await host.tick(8)
	check(world.targets.size()==4, "Selected ranged regression fixture has all four production targets")
	if world.targets.size()==4:
		await test_selected_bow_heading()
		await test_arrow_solid_collisions()
		await test_targeted_bomb_platforms()
		await test_targeted_bomb_failure()
		await test_bomb_anchor_updates()
	reset_joy()
	release_inputs()
	host.paused = false
	world.queue_free()
	await host.tick(2)
	completed = true

func ranged_fixture(point: Vector2 = Vector2(620,220)) -> void:
	await aim_fixture(point)
	player.set_physics_process(false)
	player.position = point
	player.velocity = Vector2.ZERO
	world.target_index = -1
	world.aim.cancel()
	await host.tick(2)

func select_frozen(target, point: Vector2) -> void:
	await show_target(target,point)
	world.target_index = world.targets.find(target)
	world.aim.update_aim(false,Vector2.ZERO)

func first_arrow():
	for shot in abilities.projectiles:
		if is_instance_valid(shot) and not shot.is_queued_for_deletion() and shot.kind=="arrow":
			return shot
	return null

func release_bow() -> bool:
	return abilities.start_special(Vector2.ZERO) and abilities.release_special()

func verify_live_bomb_path(orb, points: PackedVector2Array, label: String) -> void:
	var matches: bool = not points.is_empty()
	var samples: int = 0
	for frame in range(720):
		if not is_instance_valid(orb) or orb.settled:
			break
		await host.tick(1)
		if not is_instance_valid(orb):
			matches = false
			break
		# Projectile age counts actual fixed physics steps rather than assuming
		# the number of process frames after the asynchronous test resumes.
		var step: int = roundi(orb.age * 120.0)
		matches = matches and step>=0 and step<points.size()
		if step>=0 and step<points.size():
			matches = matches and orb.position.distance_to(points[step])<0.1
		samples += 1
	check(matches and samples>2 and is_instance_valid(orb) and orb.settled, "Every live 120-Hz bomb position matches the predicted path to %s" % label)

func test_selected_bow_heading() -> void:
	await ranged_fixture()
	await select_frozen(dummy,Vector2(900,150))
	player.facing = -1
	var expected: Vector2 = world.aim.aim_origin().direction_to(dummy.global_position)
	check(world.selected_target()==dummy and not world.aim.held and world.aim.ranged_direction().is_equal_approx(expected), "A selected visible target gives Bow its full geometric heading without held aim or facing changes")
	check(release_bow(), "Selected Bow starts and releases through the ordinary ranged ability")
	var shot = first_arrow()
	check(is_instance_valid(shot) and shot.velocity.normalized().is_equal_approx(expected) and is_equal_approx(shot.velocity.length(),700), "Uncharged selected Bow keeps normal speed while pointing toward the selected target")
	await ranged_fixture()
	await select_frozen(dummy,Vector2(900,220))
	hold_aim(Vector2.UP)
	check(world.aim.ranged_direction().is_equal_approx(Vector2.UP) and world.selected_target()==dummy, "Manual held heading overrides the saved target without clearing its selection")
	check(release_bow(), "A saved target does not prevent a manual upward Bow release")
	shot = first_arrow()
	check(is_instance_valid(shot) and shot.velocity.normalized().is_equal_approx(Vector2.UP), "Manual upward arrow ignores the selected target to the right")
	await ranged_fixture()
	player.facing = -1
	world.aim.update_aim(false,Vector2.UP)
	check(world.selected_target()==null and world.aim.ranged_direction()==Vector2.LEFT, "Free mode without held aim uses facing rather than a stale manual or selected heading")
	check(release_bow(), "Free mode still permits a normal Bow release")
	shot = first_arrow()
	check(is_instance_valid(shot) and shot.velocity.y==0 and shot.velocity.x<0, "Unselected ordinary arrow travels horizontally toward current facing")
	await ranged_fixture()
	await select_frozen(dummy,Vector2(900,220))
	Input.action_press("ranged")
	check(abilities.start_special(Vector2.ZERO), "Selected Bow can keep charging while its target moves")
	await host.tick(12)
	dummy.position = Vector2(850,120)
	await host.tick(2)
	expected = world.aim.aim_origin().direction_to(dummy.global_position)
	Input.action_release("ranged")
	check(abilities.release_special(), "Moving selected target is resolved at Bow release")
	shot = first_arrow()
	check(is_instance_valid(shot) and shot.velocity.normalized().is_equal_approx(expected), "Released arrow uses the target's latest position rather than its charge-start position")
	if is_instance_valid(shot):
		var launched_velocity: Vector2 = shot.velocity
		dummy.position = Vector2(850,400)
		world.target_index = 0
		await host.tick(10)
		check(is_instance_valid(shot) and shot.velocity.is_equal_approx(launched_velocity), "An arrow in flight keeps its straight velocity after the target moves or selection changes")
	else:
		check(false, "Released selected arrow exists long enough to verify non-homing flight")
	await ranged_fixture(Vector2(620,220))
	await select_frozen(dummy,Vector2(620,120))
	check(release_bow(), "Selected Bow supports a vertically aligned target")
	await host.tick(30)
	check(dummy.hit_count==1 and dummy.percent==4 and dummy.last_impulse.y<0, "A real selected vertical arrow reaches and knocks back the target above it")

func blocked_arrow(point: Vector2, target_point: Vector2, heading: Vector2, label: String) -> void:
	await ranged_fixture(point)
	await show_target(dummy,target_point)
	hold_aim(heading)
	check(release_bow(), "%s permits an arrow release" % label)
	await host.tick(55)
	check(dummy.hit_count==0 and abilities._projectile_count("arrow")==0, "%s stops the real arrow before target damage" % label)

func test_arrow_solid_collisions() -> void:
	await blocked_arrow(Vector2(435,480),Vector2(435,380),Vector2.UP,"One-way platform underside")
	await blocked_arrow(Vector2(435,350),Vector2(435,500),Vector2.DOWN,"One-way platform top")
	await ranged_fixture(Vector2(620,220))
	var wall = world.make_surface(Rect2(720,120,2,250),false)
	await host.tick(2)
	await show_target(dummy,Vector2(900,170))
	world.target_index = world.targets.find(dummy)
	check(release_bow(), "Selected diagonal Bow may release toward a target behind a thin wall")
	await host.tick(60)
	check(dummy.hit_count==0 and abilities._projectile_count("arrow")==0, "A two-pixel solid wall blocks a diagonal selected arrow without tunneling or target damage")
	wall.queue_free()
	await host.tick(2)
	await ranged_fixture(Vector2(620,220))
	wall = world.make_surface(Rect2(680,120,1,200),false)
	await host.tick(2)
	await show_target(dummy,Vector2(900,211))
	hold_aim(Vector2.RIGHT)
	Input.action_press("ranged")
	abilities.start_special(Vector2.ZERO)
	abilities.charge_time = abilities.MAX_CHARGE
	Input.action_release("ranged")
	check(abilities.release_special(), "Fully charged Bow can release toward a one-pixel wall")
	await host.tick(40)
	check(dummy.hit_count==0 and abilities._projectile_count("arrow")==0, "The charged arrow sweep stops at a one-pixel wall at maximum projectile speed")
	wall.queue_free()
	await host.tick(2)
	await ranged_fixture(Vector2(435,470))
	await show_target(dummy,Vector2(435,400))
	hold_aim(Vector2.UP)
	check(release_bow(), "Bow can safely release immediately below a platform")
	var shot = first_arrow()
	check(is_instance_valid(shot) and shot.position.y>=456.0, "An upward muzzle is shortened to leave arrow clearance beneath the platform underside")
	await host.tick(30)
	check(dummy.hit_count==0 and abilities._projectile_count("arrow")==0, "Close underside launch never starts past the platform or damages a target above it")
	await ranged_fixture(Vector2(435,410))
	await show_target(dummy,Vector2(435,500))
	hold_aim(Vector2.DOWN)
	check(release_bow(), "Bow can safely release immediately above a platform")
	shot = first_arrow()
	check(is_instance_valid(shot) and shot.position.y<=426.0, "A downward muzzle retains full round-arrow clearance above the platform top")
	await host.tick(30)
	check(dummy.hit_count==0 and abilities._projectile_count("arrow")==0, "Close top launch cannot spawn beneath the platform to bypass its collision")
	await ranged_fixture(Vector2(970,542))
	wall = world.make_surface(Rect2(990,400,10,160),false)
	await host.tick(2)
	await select_frozen(dummy,Vector2(1040,533))
	check(release_bow(), "Selected Bow can release while its muzzle is near a wall")
	shot = first_arrow()
	check(is_instance_valid(shot) and shot.position.x<=983.6, "Close-wall arrow origin remains on the player's side with its collision radius clear")
	await host.tick(30)
	check(dummy.hit_count==0 and abilities._projectile_count("arrow")==0, "Close-wall selected release cannot place an arrow through the obstruction")
	wall.queue_free()
	await host.tick(2)
	await ranged_fixture(Vector2(305,440))
	await show_target(dummy,Vector2(620,431))
	hold_aim(Vector2.RIGHT)
	check(release_bow(), "An arrow may release next to the side of a practice platform")
	shot = first_arrow()
	check(is_instance_valid(shot) and shot.position.x<=314.0, "Platform edge is included in safe muzzle placement for horizontal fire")
	var clearance := CircleShape2D.new()
	clearance.radius = 6.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = clearance
	query.transform = Transform2D(0.0,shot.global_position if is_instance_valid(shot) else Vector2(330,431))
	query.collision_mask = 3
	query.collide_with_areas = false
	query.collide_with_bodies = true
	check(is_instance_valid(shot) and world.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(), "The complete arrow collision circle starts clear of a platform corner beside the muzzle")
	await host.tick(40)
	check(dummy.hit_count==0 and abilities._projectile_count("arrow")==0, "The round arrow sweep blocks platform side contact rather than treating the one-way body as empty")

func test_targeted_bomb_platforms() -> void:
	var cases: Array = [
		{"index":0,"player":Vector2(230,542),"target":Vector2(435,410),"name":"left platform A"},
		{"index":1,"player":Vector2(610,542),"target":Vector2(800,308),"name":"upper platform B"},
		{"index":2,"player":Vector2(960,542),"target":Vector2(1175,410),"name":"right platform C"},
		{"index":3,"player":Vector2(800,542),"target":Vector2(1100,538),"name":"floor target D"}]
	for entry in cases:
		await ranged_fixture(entry.player)
		var target = world.targets[entry.index]
		await select_frozen(target,entry.target)
		abilities.selected_weapon = 2
		var launch: Dictionary = world.aim.targeted_bomb_launch(target)
		check(bool(launch.get("valid",false)) and launch.get("reason","")=="", "Physics solver finds a reachable targeted bomb arc to %s" % entry.name)
		world.aim.update_aim(false,Vector2.ZERO)
		check(world.aim.preview_points.size()>2 and world.aim.preview_settled and world.aim.preview_landing.distance_to(launch.get("landing",Vector2.INF))<0.1, "Selected %s shows its validated landing preview without held aim" % entry.name)
		check(abilities.fire_ranged() and is_instance_valid(abilities.orb), "Selected bomb spawns its solved arc to %s" % entry.name)
		var orb = abilities.orb
		if not is_instance_valid(orb) or not bool(launch.get("valid",false)):
			check(false, "Selected %s supplies a live bomb for landing and blast verification" % entry.name)
			continue
		check(orb.position.distance_to(launch.origin)<0.1 and orb.velocity.distance_to(launch.velocity)<0.1 and orb.launch_origin.is_equal_approx(launch.launch_origin), "Selected %s starts with the preview's exact origin, velocity and launch anchor" % entry.name)
		await verify_live_bomb_path(orb,launch.points,entry.name)
		check(is_instance_valid(orb) and orb.settled and orb.position.distance_to(launch.landing)<0.1 and orb.position.distance_to(target.position)<abilities.ORB_RADIUS, "Real bomb lands at preview and within blast reach of %s" % entry.name)
		check(abilities.detonate_orb() and target.hit_count==1 and target.percent==abilities.ORB_DAMAGE, "Landing bomb can actually damage %s through the production blast query" % entry.name)
	await ranged_fixture(Vector2(230,542))
	await select_frozen(world.targets[0],Vector2(435,410))
	abilities.selected_weapon = 2
	var launch: Dictionary = world.aim.targeted_bomb_launch(world.targets[0])
	check(is_equal_approx(float(launch.range_limit),576), "Selected bomb retains the half-visible-world-width cap at normal zoom")
	world.camera.zoom = Vector2(2,2)
	var zoomed: Dictionary = world.aim.targeted_bomb_launch(world.targets[0])
	check(is_equal_approx(float(zoomed.range_limit),288), "Selected bomb solver updates the same half-visible-world-width cap when zoom changes")

func test_targeted_bomb_failure() -> void:
	await ranged_fixture(Vector2(230,542))
	await select_frozen(dummy,Vector2(1100,538))
	abilities.selected_weapon = 2
	var invalid: Dictionary = world.aim.targeted_bomb_launch(dummy)
	check(not bool(invalid.get("valid",true)) and not str(invalid.get("reason","")).is_empty() and invalid.get("points",PackedVector2Array()).is_empty(), "A target beyond half-screen range returns an explicit invalid result with no fake flight path")
	world.aim.update_aim(false,Vector2.ZERO)
	check(world.aim.preview_points.is_empty() and not world.aim.preview_settled, "Out-of-range selected bomb shows no successful trajectory or landing preview")
	check(not abilities.fire_ranged() and not is_instance_valid(abilities.orb) and abilities.projectiles.is_empty() and abilities.cooldown==0, "Out-of-range selected bomb fails safely without a fallback throw or cooldown consumption")
	hold_aim(Vector2.UP)
	check(abilities.fire_ranged() and is_instance_valid(abilities.orb) and abilities.orb.velocity.normalized().is_equal_approx(Vector2.UP), "Held manual aim can explicitly override an out-of-range saved target for Bomb")
	await ranged_fixture(Vector2(610,542))
	await select_frozen(world.targets[1],Vector2(800,308))
	abilities.selected_weapon = 2
	var wall = world.make_surface(Rect2(700,-500,20,1060),false)
	await host.tick(2)
	world.aim.cancel()
	invalid = world.aim.targeted_bomb_launch(world.targets[1])
	check(not bool(invalid.get("valid",true)) and not str(invalid.get("reason","")).is_empty(), "An in-range target beyond a full-height solid wall is rejected as physically unreachable")
	world.aim.update_aim(false,Vector2.ZERO)
	check(world.aim.preview_points.is_empty() and not world.aim.preview_settled, "Unreachable selected bomb cannot display a misleading solved arc through the wall")
	check(not abilities.fire_ranged() and not is_instance_valid(abilities.orb) and abilities.projectiles.is_empty(), "Unreachable selected bomb never substitutes an ordinary facing throw")
	wall.queue_free()
	await host.tick(2)
	await ranged_fixture(Vector2(800,542))
	await select_frozen(dummy,Vector2(1100,538))
	abilities.selected_weapon = 2
	world.camera.zoom = Vector2(2,2)
	invalid = world.aim.targeted_bomb_launch(dummy)
	check(not bool(invalid.get("valid",true)) and is_equal_approx(float(invalid.range_limit),288) and not abilities.fire_ranged(), "Zoom-reduced range rejects a selected target that was reachable at the ordinary view width")

func test_bomb_anchor_updates() -> void:
	await ranged_fixture(Vector2(800,542))
	await select_frozen(dummy,Vector2(1100,538))
	abilities.selected_weapon = 2
	var first: Dictionary = world.aim.targeted_bomb_launch(dummy)
	dummy.position = Vector2(1060,538)
	await host.tick(2)
	var moved: Dictionary = world.aim.targeted_bomb_launch(dummy)
	check(bool(moved.get("valid",false)) and moved.landing.distance_to(dummy.position)<55 and moved.velocity.distance_to(first.velocity)>1, "Moving the selected target before launch invalidates the cached arc and solves its new landing")
	player.position = Vector2(830,542)
	await host.tick(2)
	var shifted: Dictionary = world.aim.targeted_bomb_launch(dummy)
	check(bool(shifted.get("valid",false)) and shifted.launch_origin.is_equal_approx(player.position) and shifted.origin.distance_to(moved.origin)>3, "Moving the player before launch refreshes the solver origin and range anchor")
	world.aim.update_aim(false,Vector2.ZERO)
	check(world.aim.preview_landing.distance_to(shifted.landing)<0.1, "The automatic selected preview uses the refreshed player and target anchors")
	check(abilities.fire_ranged() and is_instance_valid(abilities.orb), "Refreshed selected bomb can launch its current solved trajectory")
	var orb = abilities.orb
	if not is_instance_valid(orb):
		check(false, "Anchor regression has a live bomb")
		return
	var captured_anchor: Vector2 = orb.launch_origin
	var captured_cap: float = orb.range_limit
	player.position = Vector2(700,542)
	dummy.position = Vector2(1250,538)
	world.camera.zoom = Vector2(2,2)
	world.target_index = -1
	await host.tick(6)
	check(orb.launch_origin.is_equal_approx(captured_anchor) and is_equal_approx(orb.range_limit,captured_cap), "Player, target, selection and zoom changes cannot rewrite an in-flight bomb's launch anchor or cap")
	check(is_equal_approx(orb.velocity.x,float(shifted.velocity.x)), "Moving a selected target after launch does not steer the live bomb horizontally")
	await settle_orb(orb,720)
	check(is_instance_valid(orb) and orb.settled and orb.position.distance_to(shifted.landing)<0.1, "An in-flight selected bomb still lands at its original validated preview after later target movement")

