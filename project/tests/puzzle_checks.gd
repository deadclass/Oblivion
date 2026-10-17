extends "res://tests/aim_form_checks.gd"

func run(test_host) -> void:
	host = test_host
	world = load("res://puzzle_room.tscn").instantiate()
	host.root.add_child(world)
	player = world.player
	dummy = world.dummy
	abilities = world.abilities
	player.test_control = true
	await host.tick(8)
	check(not world.introduction_lit and not world.relay_lit, "Puzzle starts with both lights unlit and gate solid")
	check(world.gate.collision_layer == 1, "Gate blocks ordinary traversal initially")
	# Actual input/kit launch; only aim direction changes during flight.
	hold_aim(Vector2(0.872,-0.49))
	abilities.selected_weapon = 1
	check(abilities.fire_ranged(), "Existing ranged control launches the form in the room")
	var origin: Vector2 = abilities.boomerang.launch_origin
	await host.tick(25)
	check(world.introduction_lit, "Safe first light latches through real swept outward flight")
	Input.action_release("target")
	direction_input(Vector2.ZERO)
	await host.tick(80)
	check(not abilities.boomerang_active() and not player.boomerang_form, "Releasing aim completes return and restores the character")
	check(player.position.distance_to(origin) < 1, "Introduction returns to the launch body, not to the light")
	check(world.introduction_lit and not world.relay_lit, "First progress persists after return")
	await host.tick(60)
	# A direct aimed route at the second light strikes the wall below slit.
	hold_aim(Vector2.RIGHT)
	check(abilities.fire_ranged(), "A retry is available after return cooldown")
	await host.tick(140)
	check(not world.relay_lit and not abilities.boomerang_active(), "Solid obstacle rejects a straight flight and returns safely")
	check(player.position.distance_to(origin) < 1, "Wall collision restores the original launch position")
	# Solve by steering up to slit height, then right, all inside 3 seconds.
	await host.tick(60)
	hold_aim(Vector2.UP)
	check(abilities.fire_ranged(), "Steered puzzle attempt launches")
	await host.tick(38)
	hold_aim(Vector2.RIGHT)
	await host.tick(80)
	check(world.relay_lit, "Aimed form fits slit and reaches remote second light")
	check(world.gate.collision_layer == 0, "Remote light permanently opens the walking gate")
	Input.action_release("target")
	direction_input(Vector2.ZERO)
	await host.tick(160)
	check(not abilities.boomerang_active() and player.position.distance_to(origin) < 1, "Bent flight retraces slit and restores exact launch point")
	check(not world.completed_room, "Remote activation alone cannot complete final traversal")
	# Crossing the gate uses the unchanged player physics, not a teleport.
	player.test_axis = 1.0
	await host.tick(200)
	player.test_axis = 0.0
	check(player.position.x > 790, "Character can walk through the remotely opened gate")
	# Exercise real jumps on each platform with production gravity/collision.
	player.reset_at(Vector2(800,542))
	await host.tick(4)
	for destination in [Vector2(915,442), Vector2(1095,372), Vector2(1275,302), Vector2(1490,232)]:
		player.test_jump_pressed = true
		player.test_jump_held = true
		var landed := false
		for frame in range(150):
			var distance: float = destination.x - player.position.x
			player.test_axis = clampf(distance / 25.0, -1.0, 1.0)
			await host.tick(1)
			if frame > 12 and player.is_on_floor() and absf(player.position.y - destination.y) < 2 and absf(distance) < 50:
				landed = true
				break
		player.test_jump_held = false
		player.test_axis = 0.0
		check(landed, "Production jump reaches stair platform at x=%d" % int(destination.x))
		await host.tick(6)
	check(world.completed_room, "Room completes only after the returned character traverses to beacon")
	world.respawn()
	await host.tick(4)
	check(world.relay_lit and world.gate.collision_layer == 0, "Player reset preserves solved progress and safe gate state")
	world.reset_room()
	await host.tick(4)
	check(not world.introduction_lit and not world.relay_lit and not world.completed_room and world.gate.collision_layer == 1, "Full reset clears room and closes gate after restoring player")
	check(player.position.x < 750 and not player.boomerang_form, "Replay starts safely outside obstacle")
	# Real swept flight must tolerate off-center steering, not just one exact
	# recorded route. Both directions use production collision and return logic.
	for flight_y in [313.0, 335.0, 357.0, 285.0, 385.0]:
		world.reset_room()
		release_inputs()
		player.reset_at(Vector2(680, flight_y))
		player.set_physics_process(false)
		await host.tick(4)
		hold_aim(Vector2.RIGHT)
		abilities.selected_weapon = 1
		check(abilities.fire_ranged(), "Slit clearance trial launches at y=%d" % int(flight_y))
		var trial_origin: Vector2 = abilities.boomerang.launch_origin
		var furthest_x: float = trial_origin.x
		for frame in range(35):
			await host.tick(1)
			furthest_x = maxf(furthest_x, player.position.x)
		var should_pass: bool = flight_y >= 313.0 and flight_y <= 357.0
		check(furthest_x > 800 if should_pass else furthest_x < 750, "Slit admits forgiving flight heights but preserves wall collision at y=%d" % int(flight_y))
		Input.action_release("target")
		direction_input(Vector2.ZERO)
		await host.tick(100)
		check(not abilities.boomerang_active() and not player.boomerang_form and player.position.distance_to(trial_origin) < 1, "Slit trial safely restores launch body at y=%d" % int(flight_y))
		player.set_physics_process(true)
	world.reset_room()
	await host.tick(8)
	# Three-second timeout with stationary steering loop stays inside safe area.
	hold_aim(Vector2.UP)
	abilities.selected_weapon = 1
	check(abilities.fire_ranged(), "Timeout trial launches")
	for frame in range(365):
		if frame % 24 == 0:
			hold_aim(Vector2.RIGHT if int(frame / 24) % 2 == 0 else Vector2.LEFT)
		await host.tick(1)
	check(not abilities.boomerang_active() or abilities.boomerang.returning, "Aimed timeout begins return at three seconds without requiring release")
	Input.action_release("target")
	direction_input(Vector2.ZERO)
	await host.tick(360)
	check(not abilities.boomerang_active() and not player.boomerang_form, "Timeout eventually restores visible controllable character")
	await host.tick(60)
	hold_aim(Vector2.UP)
	check(abilities.fire_ranged(), "Form can be retried after timeout")
	await host.tick(15)
	world.reset_room()
	await host.tick(4)
	check(not abilities.boomerang_active() and not player.boomerang_form and player.position.x < 750, "Reset during flight cancels form before closing geometry")
	# A body cannot use the slit: grounded crossing before activation is blocked.
	player.test_axis = 1
	await host.tick(200)
	player.test_axis = 0
	check(player.position.x < 750, "Closed gate prevents ordinary character bypass")
	world.reset_room()
	await host.tick(8)
	Input.action_press("attack")
	world.process_combat_input()
	check(abilities.active_time > 0 or abilities.windup_time > 0, "Room retains live melee input dispatch")
	Input.action_release("attack")
	await host.tick(90)
	Input.action_press("dash")
	world.process_combat_input()
	check(player.is_dashing, "Room retains live dash input dispatch")
	Input.action_release("dash")
	await host.tick(80)
	world.respawn()
	await host.tick(60)
	abilities.selected_weapon = 0
	Input.action_press("ranged")
	world.process_combat_input()
	check(abilities.charging, "Room retains ranged bow charge input")
	Input.action_release("ranged")
	world.process_combat_input()
	check(abilities.projectiles.size() > 0, "Room retains bow release projectile")
	await host.tick(80)
	abilities.selected_weapon = 2
	Input.action_press("ranged")
	world.process_combat_input()
	check(is_instance_valid(abilities.orb), "Room retains bomb ranged input")
	Input.action_release("ranged")
	world.process_combat_input()
	world.reset_room()
	release_inputs()
	world.queue_free()
	await host.tick(3)
	completed = true

