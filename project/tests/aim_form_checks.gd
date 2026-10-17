extends "res://tests/combat_controls_checks.gd"

const PROJECTILE = preload("res://scripts/projectile.gd")

# These are observable physics/input regressions. Targets are frozen only for
# geometric isolation; production bodies, rays, sweeps and timers remain live.
func run(test_host) -> void:
	host = test_host
	world = load("res://main.tscn").instantiate()
	host.root.add_child(world)
	player = world.player
	dummy = world.dummy
	abilities = world.abilities
	player.test_control = true
	await host.tick(8)
	await test_hold_aim_mapping()
	await test_soft_assistance()
	await test_directional_bow()
	await test_plain_form()
	await test_steered_form()
	await test_form_collision_and_hits()
	await test_bomb_trajectory()
	await test_cancel_and_trigger_safety()
	reset_joy()
	release_inputs()
	host.paused = false
	world.queue_free()
	await host.tick(2)
	completed = true

func aim_fixture(point: Vector2 = Vector2(620,542)) -> void:
	reset_joy()
	await fixture(point)
	world.aim.cancel()
	world.camera.zoom = Vector2.ONE
	for target in world.targets:
		target.set_physics_process(false)
		target.hide()
		target.position = Vector2(-1000,-1000)
	await host.tick(2)

func direction_input(value: Vector2) -> void:
	for action in ["left","right","up","down"]:
		Input.action_release(action)
	if value.x < 0:
		Input.action_press("left",absf(value.x))
	elif value.x > 0:
		Input.action_press("right",value.x)
	if value.y < 0:
		Input.action_press("up",absf(value.y))
	elif value.y > 0:
		Input.action_press("down",value.y)

func hold_aim(value: Vector2) -> void:
	Input.action_press("target")
	direction_input(value)
	# Establish a held gesture for isolated ability fixtures. Gesture timing
	# itself is verified through real events/physics in target_aim_checks.gd.
	world.update_target_input(0.181)
	world.aim.update_aim(true,value)

func show_target(target, position: Vector2) -> void:
	target.show()
	target.position = position
	await host.tick(2)

func test_hold_aim_mapping() -> void:
	await aim_fixture()
	player.test_control = false
	joy_axis(JOY_AXIS_TRIGGER_LEFT,0.20)
	await host.tick(4)
	check(not world.aim.held, "LT/L2 pressure below threshold does not enter aim mode")
	joy_axis(JOY_AXIS_TRIGGER_LEFT,0.30)
	await host.tick(24)
	check(world.aim.held and not player.blocking and abilities.active_move.is_empty(), "LT/L2 above threshold holds aim independently of block and weapon use")
	joy_axis(JOY_AXIS_LEFT_X,0.3)
	joy_axis(JOY_AXIS_LEFT_Y,0.8)
	await host.tick(2)
	check(world.aim.raw_direction.is_equal_approx(Vector2(0.3,0.8).normalized()), "Partial left stick preserves its true analog aiming angle")
	joy_axis(JOY_AXIS_RIGHT_X,-0.8)
	joy_axis(JOY_AXIS_RIGHT_Y,-0.3)
	await host.tick(2)
	check(world.aim.raw_direction.is_equal_approx(Vector2(-0.8,-0.3).normalized()), "Right stick takes aiming priority without distorting its angle")
	check(not abilities.move_heavy and abilities.windup_time==0 and not player.recovery_used, "Right-stick aim cannot accidentally issue a heavy sword or recovery")
	joy_axis(JOY_AXIS_LEFT_X,0.0)
	joy_axis(JOY_AXIS_LEFT_Y,0.0)
	joy_axis(JOY_AXIS_RIGHT_X,0.0)
	joy_axis(JOY_AXIS_RIGHT_Y,0.0)
	var heading: Vector2 = world.aim.raw_direction
	await host.tick(10)
	check(world.aim.held and world.aim.raw_direction.is_equal_approx(heading), "Neutral sticks retain the last free aim heading while LT is held")
	joy_axis(JOY_AXIS_TRIGGER_LEFT,0.0)
	await host.tick(3)
	check(not world.aim.held and world.aim.assisted_target==null, "Releasing LT exits aim immediately and clears transient assistance")
	key(KEY_TAB,true)
	await host.tick(24)
	check(world.aim.held, "Keyboard Tab holds the same free aim mode")
	key(KEY_TAB,false)
	await host.tick(3)
	check(not world.aim.held and world.selected_target()==null, "Releasing a long-held Tab ends aim without cycling persistent selection")

func test_soft_assistance() -> void:
	await aim_fixture(Vector2(620,480))
	player.set_physics_process(false)
	var origin: Vector2 = world.aim.aim_origin()
	await show_target(dummy,origin+Vector2.from_angle(deg_to_rad(10))*200)
	world.aim.update_aim(true,Vector2.RIGHT)
	var correction: float = rad_to_deg(Vector2.RIGHT.angle_to(world.aim.direction))
	check(world.aim.assisted_target==dummy and correction>0 and correction<12.01, "A nearby target inside the assist cone receives the doubled bounded angular correction")
	check(absf(correction-7.0)<0.05 and world.aim.raw_direction==Vector2.RIGHT, "Assistance blends 70 percent toward the target without rewriting raw input")
	world.aim.update_aim(true,Vector2.DOWN)
	check(world.aim.assisted_target==null and world.aim.direction.is_equal_approx(Vector2.DOWN), "A free turn away from the target is never locked to the previous assist")
	await show_target(dummy,origin+Vector2.from_angle(deg_to_rad(17))*200)
	world.aim.update_aim(true,Vector2.RIGHT)
	check(world.aim.assisted_target==null and world.aim.direction==Vector2.RIGHT, "Target just outside the sixteen-degree cone receives no aim correction")
	await show_target(dummy,origin+Vector2.from_angle(deg_to_rad(15.9))*200)
	world.aim.update_aim(true,Vector2.RIGHT)
	correction = absf(rad_to_deg(Vector2.RIGHT.angle_to(world.aim.direction)))
	check(world.aim.assisted_target==dummy and correction<=12.01 and correction<15.9, "Target near cone boundary stays a bounded correction rather than snapping to center")
	await show_target(dummy,origin+Vector2.from_angle(deg_to_rad(8))*651)
	world.aim.update_aim(true,Vector2.RIGHT)
	check(world.aim.assisted_target==null, "Assist range excludes targets beyond 650 world pixels")
	await show_target(dummy,origin+Vector2(200,20))
	var wall = world.make_surface(Rect2(715,430,14,130),false)
	await host.tick(2)
	world.aim.update_aim(true,Vector2.RIGHT)
	check(world.aim.assisted_target==null and world.aim.direction==Vector2.RIGHT, "A solid wall blocks aim assistance to an otherwise valid target")
	wall.queue_free()
	await host.tick(2)
	var nearer = world.targets[0]
	await show_target(dummy,origin+Vector2.from_angle(deg_to_rad(11))*120)
	await show_target(nearer,origin+Vector2.from_angle(deg_to_rad(3))*230)
	world.aim.update_aim(true,Vector2.RIGHT)
	check(world.aim.assisted_target==nearer, "Two targets choose the one nearest the free aim heading instead of the nearer off-axis body")
	world.aim.update_aim(true,Vector2.from_angle(deg_to_rad(11)))
	check(world.aim.assisted_target==dummy, "Steering toward another target changes the transient assist without cycling or locking")
	dummy.hide()
	nearer.hide()
	world.aim.update_aim(true,Vector2.LEFT)
	check(world.aim.assisted_target==null and world.aim.direction==Vector2.LEFT, "Aiming with no eligible targets stays safe and fully free")
	world.aim.update_aim(true,Vector2.ZERO)
	check(world.aim.raw_direction==Vector2.LEFT, "Neutral aim retains the remembered raw heading even without targets")
	world.aim.update_aim(false,Vector2.UP)
	check(not world.aim.held and world.aim.assisted_target==null, "Assistance disappears when hold-to-aim is released")

func test_directional_bow() -> void:
	for heading in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2(0.3,-0.8).normalized(),Vector2(-0.6,0.8).normalized()]:
		await aim_fixture(Vector2(620,220))
		hold_aim(heading)
		check(abilities.start_special(Vector2.ZERO) and abilities.release_special(), "Aimed bow can charge and release toward %s" % heading)
		var shot = abilities.projectiles[0] if not abilities.projectiles.is_empty() else null
		check(is_instance_valid(shot) and shot.velocity.normalized().is_equal_approx(heading) and is_equal_approx(shot.velocity.length(),700), "Arrow follows the full chosen angle at normalized uncharged speed: %s" % heading)
	await aim_fixture(Vector2(620,220))
	hold_aim(Vector2.RIGHT)
	Input.action_press("ranged")
	abilities.start_special(Vector2.ZERO)
	await host.tick(20)
	hold_aim(Vector2.UP)
	abilities.release_special()
	var changed = abilities.projectiles[0] if not abilities.projectiles.is_empty() else null
	check(is_instance_valid(changed) and changed.velocity.normalized().is_equal_approx(Vector2.UP), "Changing aim during bow charge directs the arrow along the heading at release")
	check(not abilities.release_special() and abilities.projectiles.size()==1, "Changing bow heading does not create more than one release projectile")
	await aim_fixture(Vector2(620,220))
	player.facing = -1
	world.aim.update_aim(false,Vector2.UP)
	abilities.start_special(Vector2.ZERO)
	abilities.release_special()
	check(abilities.projectiles[0].velocity.y==0 and abilities.projectiles[0].velocity.x<0, "Bow without held aim uses ordinary horizontal current-facing fire")
	await aim_fixture(Vector2(620,220))
	await show_target(dummy,Vector2(620,120))
	hold_aim(Vector2.UP)
	abilities.start_special(Vector2.ZERO)
	abilities.release_special()
	await host.tick(30)
	check(dummy.hit_count==1 and dummy.percent==4 and dummy.last_impulse.y<0, "A vertical aimed arrow strikes a real target above and applies directional knockback")

func start_plain_form() -> bool:
	abilities.selected_weapon = 1
	return abilities.fire_ranged()

func finish_form(frames: int = 400) -> void:
	for index in range(frames):
		if not abilities.boomerang_active():
			return
		await host.tick(1)

func test_plain_form() -> void:
	await aim_fixture()
	var origin: Vector2 = player.position
	check(start_plain_form() and abilities.boomerang_active() and player.boomerang_form, "Boomerang weapon transforms the character into a single active form")
	var form = abilities.boomerang
	check(form.launch_origin.is_equal_approx(origin) and not form.aimed and not player.can_act(), "Plain form records its exact launch body and excludes ordinary actions")
	check(not abilities.fire_ranged() and not abilities.start_attack(Vector2.RIGHT) and not player.request_dash(Vector2.RIGHT) and not player.request_dodge(Vector2.RIGHT), "Form cannot duplicate itself or simultaneously sword, dash or dodge")
	await host.tick(30)
	check(absf(form.position.x-origin.x-165.0)<1 and absf(form.position.y-origin.y)<0.1, "Plain form travels at 660 px/s with normal gravity suspended")
	check(player.position.is_equal_approx(form.position) and form.velocity.length()==660, "Character and following camera travel with the temporary body rather than a thrown copy")
	player.test_jump_pressed = true
	await host.tick(2)
	check(player.jump_count==0 and player.jumps_remaining==2, "Jump input during form does not spend or buffer an ordinary jump")
	await host.tick(115)
	check(form.returning and form.position.x-origin.x<=792.1 and form.position.x-origin.x>740, "Plain form turns back after its measured 1.2-second outward distance")
	check(absf(form.velocity.length()-760)<0.1, "Returning form uses its separate 760 px/s return speed")
	await host.tick(160)
	check(not abilities.boomerang_active() and not player.boomerang_form and player.position.distance_to(origin)<0.2, "Plain return restores the original character at the exact launch position")
	check(player.jumps_remaining==2 and player.dodge_available and player.dash_available and player.jump_count==0, "Plain return preserves movement resources and discards form-time jump presses")
	await aim_fixture(Vector2(620,180))
	player.jumps_remaining = 1
	player.dodge_available = false
	player.dash_available = false
	origin = player.position
	start_plain_form()
	await finish_form()
	check(not player.boomerang_form and player.position.distance_to(origin)<2, "Airborne form return restores the airborne launch body rather than dropping or teleporting it to the floor")
	check(player.jumps_remaining==1 and not player.dodge_available and not player.dash_available, "Air form return cannot replenish jumps or spent dodge/dash resources before landing")

func test_steered_form() -> void:
	await aim_fixture(Vector2(620,220))
	hold_aim(Vector2.RIGHT)
	check(start_plain_form() and abilities.boomerang.aimed, "Holding aim on launch selects the controllable form variant")
	var form = abilities.boomerang
	var origin: Vector2 = form.launch_origin
	await host.tick(20)
	var corner: Vector2 = form.position
	await show_target(dummy,corner+Vector2.from_angle(deg_to_rad(-82))*180)
	corner = form.position
	hold_aim(Vector2.UP)
	await host.tick(20)
	check(form.position.x>origin.x+50 and absf(form.position.x-corner.x)<0.2 and form.position.y<corner.y-50, "Aimed form responds to raw upward stick steering without target-assist drift")
	hold_aim(Vector2.LEFT)
	await host.tick(20)
	var top_left: Vector2 = form.position
	check(top_left.x<corner.x-50 and top_left.y<origin.y-50 and form.route.size()>40, "Aimed form records its curved excursion rather than a straight target route")
	Input.action_release("target")
	direction_input(Vector2.ZERO)
	await host.tick(3)
	check(form.returning and form.age<1.5, "Releasing LT/L2 starts return immediately before the aimed duration cap")
	var return_corner: Vector2 = form.position
	await host.tick(10)
	check(form.position.x>return_corner.x+20 and absf(form.position.y-return_corner.y)<1, "Return retraces the last curved segment instead of taking a straight shortcut to launch")
	await finish_form()
	check(not abilities.boomerang_active() and player.position.distance_to(origin)<2, "Curved aimed form returns to its exact recorded launch position")
	await aim_fixture(Vector2(150,180))
	hold_aim(Vector2.RIGHT)
	start_plain_form()
	form = abilities.boomerang
	await host.tick(110)
	check(not form.returning and form.position.x-form.launch_origin.x>576, "Aimed form can travel beyond half a screen with no bomb-style distance cap")
	hold_aim(Vector2.LEFT)
	await host.tick(80)
	check(not form.returning and form.age>1.5 and form.age<3.0, "Held aimed form remains steerable after the previous 1.5-second duration")
	hold_aim(Vector2.RIGHT)
	await host.tick(85)
	hold_aim(Vector2.LEFT)
	await host.tick(90)
	check(form.returning and form.age>=3.0, "A steered excursion within the walls returns at the full three-second timer")
	await finish_form(450)
	check(not abilities.boomerang_active() and not player.boomerang_form, "Automatically returning aimed form eventually restores the player")

func test_form_collision_and_hits() -> void:
	await aim_fixture()
	await show_target(dummy,Vector2(710,538))
	var origin: Vector2 = player.position
	start_plain_form()
	var form = abilities.boomerang
	await host.tick(50)
	check(dummy.hit_count==1 and dummy.percent==5 and form.hit_targets.size()==1, "Boomerang form's outward sweep hits a real target once for five percent")
	await host.tick(100)
	check(dummy.hit_count==1, "Persistent outward contact cannot repeatedly damage the same target")
	await host.tick(160)
	check(dummy.hit_count==2 and dummy.percent==10 and not abilities.boomerang_active(), "Return phase owns a separate registry and may hit that target exactly once more")
	check(player.position.distance_to(origin)<0.2, "Hitstop on both form phases does not change the final launch position")
	await aim_fixture(Vector2(620,542))
	await show_target(dummy,Vector2(850,538))
	var wall = world.make_surface(Rect2(780,400,14,160),false)
	await host.tick(2)
	start_plain_form()
	form = abilities.boomerang
	await host.tick(30)
	check(form.returning and form.position.x<768.1 and dummy.hit_count==0, "Form's body sweep stops at solid walls and cannot hit a dummy behind them")
	await host.tick(100)
	check(not player.boomerang_form and player.position.distance_to(Vector2(620,542))<0.2, "Wall-blocked excursion retraces its safe path and restores the launch body")
	wall.queue_free()
	await host.tick(2)
	await aim_fixture(Vector2(620,460))
	hold_aim(Vector2.DOWN)
	start_plain_form()
	form = abilities.boomerang
	await host.tick(18)
	check(form.returning and form.position.y<=550.1, "Downward form body cannot cross the solid practice floor")
	await host.tick(90)
	check(not player.boomerang_form, "Floor-blocked form completes a safe return")
	await aim_fixture(Vector2(430,460))
	hold_aim(Vector2.UP)
	start_plain_form()
	form = abilities.boomerang
	await host.tick(20)
	check(not form.returning and form.position.y<420, "Form may travel through the one-way practice platforms")
	abilities.cancel_boomerang()
	check(not player.boomerang_form and not abilities.boomerang_active(), "Explicit form cancellation restores the character without leaving an invisible body")
	for edge in [Vector2(11.01,542),Vector2(1588.99,542)]:
		await aim_fixture(edge)
		player.facing = -1.0 if edge.x<800 else 1.0
		var launch: Vector2 = player.position
		check(start_plain_form(), "Boomerang may begin safely at a player-width gap beside the %s wall" % ("left" if edge.x<800 else "right"))
		var extreme_x: float = player.position.x
		for frame in range(18):
			await host.tick(1)
			extreme_x = minf(extreme_x,player.position.x) if edge.x<800 else maxf(extreme_x,player.position.x)
		check(extreme_x>=9.8 if edge.x<800 else extreme_x<=1590.2, "A form launched already adjacent to the arena wall cannot ignore initial overlap and cross the wall")
		await finish_form()
		check(not player.boomerang_form and player.position.distance_to(launch)<0.2, "An outward edge launch safely restores its exact original body position")

func settle_orb(orb, frames: int = 360) -> void:
	for index in range(frames):
		if not is_instance_valid(orb) or orb.settled:
			return
		await host.tick(1)

func test_bomb_trajectory() -> void:
	await aim_fixture(Vector2(620,50))
	abilities.selected_weapon = 2
	hold_aim(Vector2(1,-0.7).normalized())
	var launch: Dictionary = world.aim.bomb_launch()
	var preview: Dictionary = world.aim.preview_bomb(launch)
	check(is_equal_approx(launch.range_limit,576), "Bomb maximum horizontal displacement is half the visible world width at normal zoom")
	check(preview.settled and preview.points.size()>20 and preview.position.x<=launch.launch_origin.x+launch.range_limit+0.01, "Bomb preview includes a complete colliding trajectory and obeys the horizontal cap")
	check(absf(preview.position.x-launch.launch_origin.x-launch.range_limit)<1, "High aimed bomb reaches the half-screen cap and then falls vertically")
	check(abilities.fire_ranged() and is_instance_valid(abilities.orb), "Aimed Bomb uses ranged fire without spawning a boomerang or sword")
	var orb = abilities.orb
	check(orb.launch_origin.is_equal_approx(launch.launch_origin) and is_equal_approx(orb.range_limit,launch.range_limit), "Live bomb captures its launch anchor and range independently of later player movement")
	await settle_orb(orb)
	check(is_instance_valid(orb) and orb.settled and orb.position.distance_to(preview.position)<0.1, "Live bomb's first landing exactly matches its 120-Hz trajectory preview")
	await aim_fixture(Vector2(620,50))
	world.camera.zoom = Vector2(2,2)
	abilities.selected_weapon = 2
	hold_aim(Vector2(1,-0.7).normalized())
	launch = world.aim.bomb_launch()
	preview = world.aim.preview_bomb(launch)
	check(is_equal_approx(launch.range_limit,288), "Bomb range scales with camera zoom rather than fixed screen pixels")
	abilities.fire_ranged()
	orb = abilities.orb
	world.camera.zoom = Vector2.ONE
	await settle_orb(orb)
	check(is_instance_valid(orb) and orb.settled and orb.position.x<=launch.launch_origin.x+288.01 and orb.position.distance_to(preview.position)<0.1, "Changing camera zoom after launch cannot enlarge the captured bomb range or invalidate its preview")
	await aim_fixture(Vector2(430,350))
	abilities.selected_weapon = 2
	hold_aim(Vector2.DOWN)
	launch = world.aim.bomb_launch()
	preview = world.aim.preview_bomb(launch)
	abilities.fire_ranged()
	orb = abilities.orb
	await settle_orb(orb)
	check(preview.settled and absf(preview.position.y-423)<1 and orb.position.distance_to(preview.position)<0.1, "Downward bomb preview and actual body agree on a one-way platform landing")
	await aim_fixture(Vector2(430,480))
	abilities.selected_weapon = 2
	hold_aim(Vector2.UP)
	launch = world.aim.bomb_launch()
	preview = world.aim.preview_bomb(launch)
	abilities.fire_ranged()
	orb = abilities.orb
	await settle_orb(orb)
	var passed_above: bool = false
	for point in preview.points:
		passed_above = passed_above or point.y<432
	check(passed_above and absf(preview.position.y-423)<1 and orb.position.distance_to(preview.position)<0.1, "Bomb passes upward through a platform before both preview and flight land on its top")
	await aim_fixture(Vector2(150,200))
	var wall = world.make_surface(Rect2(350,-100,14,660),false)
	await host.tick(2)
	abilities.selected_weapon = 2
	hold_aim(Vector2(1,-0.3).normalized())
	launch = world.aim.bomb_launch()
	preview = world.aim.preview_bomb(launch)
	abilities.fire_ranged()
	orb = abilities.orb
	await settle_orb(orb)
	check(preview.position.x<350 and orb.position.distance_to(preview.position)<0.1, "Bomb preview and actual flight use the same wall collision and bounce")
	wall.queue_free()
	await host.tick(2)
	await aim_fixture(Vector2(970,542))
	wall = world.make_surface(Rect2(990,400,10,160),false)
	await host.tick(2)
	abilities.selected_weapon = 2
	hold_aim(Vector2.RIGHT)
	launch = world.aim.bomb_launch()
	preview = world.aim.preview_bomb(launch)
	check(launch.origin.x<=980.51, "A bomb near a wall starts with body clearance rather than spawning through the wall")
	abilities.fire_ranged()
	orb = abilities.orb
	await settle_orb(orb)
	check(is_instance_valid(orb) and orb.position.x<990 and orb.position.distance_to(preview.position)<0.1, "Close-wall launch uses the same safe origin in preview and live projectile")
	wall.queue_free()
	await host.tick(2)
	await aim_fixture(Vector2(620,50))
	abilities.selected_weapon = 2
	hold_aim(Vector2(-1,-0.7).normalized())
	launch = world.aim.bomb_launch()
	preview = world.aim.preview_bomb(launch)
	check(preview.position.x>=launch.launch_origin.x-launch.range_limit-0.01, "Half-screen bomb displacement cap also protects leftward throws")
	var state: Dictionary = PROJECTILE.simulate_orb_step(Vector2(620+576,100),Vector2(650,100),1.0/120.0,Vector2(620,50),576,world.get_world_2d().direct_space_state)
	check(is_equal_approx(state.position.x,1196) and state.velocity.x==0 and state.velocity.y>100, "At the hard range boundary horizontal travel stops while gravity continues")

func test_cancel_and_trigger_safety() -> void:
	await aim_fixture(Vector2(620,180))
	player.jumps_remaining = 1
	player.dodge_available = false
	player.dash_available = false
	hold_aim(Vector2.RIGHT)
	start_plain_form()
	var origin: Vector2 = abilities.boomerang.launch_origin
	await host.tick(15)
	world.pause_game()
	check(host.paused and not player.boomerang_form and not abilities.boomerang_active() and player.position.distance_to(origin)<0.1 and not world.aim.held, "Pause cancels form and aim by safely restoring the launch body")
	check(player.jumps_remaining==1 and not player.dodge_available and not player.dash_available, "Pause cancellation cannot refill movement resources captured by form")
	world.ui_canvas.get_node("Pause").resume()
	await host.tick(3)
	check(not player.boomerang_form and not abilities.charging and abilities.projectiles.is_empty(), "Form resume cannot replay stale ranged, sword or movement inputs")
	await aim_fixture()
	start_plain_form()
	await host.tick(10)
	world.respawn()
	check(not player.boomerang_form and not abilities.boomerang_active() and player.position==world.START, "Player reset clears the form before applying the ordinary player spawn")
	await aim_fixture()
	start_plain_form()
	await host.tick(10)
	world.reset_dummy()
	check(not player.boomerang_form and not abilities.boomerang_active() and dummy.percent==0, "Target reset cancels an in-flight form before it can hit newly reset targets")
	await aim_fixture()
	start_plain_form()
	await host.tick(10)
	world.reset_room()
	check(not player.boomerang_form and abilities.selected_weapon==0 and not world.aim.held, "Full reset restores the base character and Bow loadout without an aim lock")
	await aim_fixture()
	player.test_control = false
	joy_axis(JOY_AXIS_TRIGGER_RIGHT,1.0)
	await host.tick(8)
	world.pause_game()
	world.ui_canvas.get_node("Pause").resume()
	await host.tick(5)
	joy_axis(JOY_AXIS_TRIGGER_RIGHT,0.95)
	await host.tick(6)
	check(not abilities.charging and abilities.projectiles.is_empty(), "Trigger jitter after pause cannot rearm a ranged press without a physical neutral release")
	joy_axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
	await host.tick(3)
	joy_axis(JOY_AXIS_TRIGGER_RIGHT,1.0)
	await host.tick(5)
	check(abilities.charging, "A real trigger release and fresh press safely rearms ranged input after pause")
	world.respawn()
	await host.tick(5)
	joy_axis(JOY_AXIS_TRIGGER_RIGHT,0.90)
	await host.tick(6)
	check(not abilities.charging and abilities.projectiles.is_empty(), "Trigger jitter after player reset cannot restart a held Bow charge")
	joy_axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
	await host.tick(3)
	joy_axis(JOY_AXIS_TRIGGER_RIGHT,1.0)
	await host.tick(5)
	check(abilities.charging, "Physical trigger neutral rearms ranged input after player reset")
	world.controls.use_controller(31,"Xbox Controller")
	world.controls.on_connection_changed(31,false)
	check(host.paused and not abilities.charging and not world.aim.held, "Active controller unplug cancels aiming and charged ranged state")
	world.ui_canvas.get_node("Pause").resume()
	await host.tick(3)
	check(not player.boomerang_form and abilities.projectiles.is_empty(), "Controller unplug recovery leaves a visible base body and no phantom projectile")
	abilities.handle_ranged(false,false)
	check(not abilities.ranged_requires_release and not abilities.charging, "Keyboard recovery after unplug can clear the ordinary ranged latch without inheriting a disconnected trigger")
	world.controls.on_connection_changed(31,true)
	joy_axis(JOY_AXIS_TRIGGER_RIGHT,0.95)
	await host.tick(6)
	check(not abilities.charging and abilities.projectiles.is_empty(), "Reconnected controller's delayed high trigger cannot fire before that device physically returns to neutral")
	joy_axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
	await host.tick(3)
	joy_axis(JOY_AXIS_TRIGGER_RIGHT,1.0)
	await host.tick(5)
	check(abilities.charging, "A neutral event and fresh trigger press safely rearm the reconnected controller")

