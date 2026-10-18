extends "res://tests/aim_form_checks.gd"

func run(test_host) -> void:
	host = test_host
	world = load("res://main.tscn").instantiate()
	host.root.add_child(world)
	player = world.player
	dummy = world.dummy
	abilities = world.abilities
	player.test_control = true
	await host.tick(10)
	await test_target_layout_and_cycle()
	await test_tap_hold_gesture()
	await test_moving_aim()
	await test_target_reset_and_pause()
	await test_target_disconnect()
	reset_joy()
	release_inputs()
	host.paused = false
	world.queue_free()
	await host.tick(2)
	completed = true

func gesture_fixture(point: Vector2 = Vector2(620,542)) -> void:
	reset_joy()
	key(KEY_TAB,false)
	await fixture(point)
	player.test_control = false
	await host.tick(3)

func tap_target(frames: int = 3) -> void:
	joy_axis(JOY_AXIS_TRIGGER_LEFT,1.0)
	await host.tick(frames)
	joy_axis(JOY_AXIS_TRIGGER_LEFT,0.0)
	await host.tick(3)

func test_target_layout_and_cycle() -> void:
	check(world.targets.size()==4 and world.target_index==-1 and world.selected_target()==null, "Four-target training starts in free-shot mode with no hidden persistent lock")
	var expected: Array[Vector2] = [Vector2(435,410),Vector2(800,308),Vector2(1175,410),Vector2(1100,538)]
	for index in range(4):
		var target = world.targets[index]
		check(target.is_on_floor() and target.position.distance_to(expected[index])<1 and target.spawn_position.is_equal_approx(expected[index]), "Target %s has a real stable support and the intended home" % target.target_name)
	check(world.targets[3]==dummy and world.targets[3].target_name=="Target D", "Ground Target D retains the original dummy alias for training statistics")
	await gesture_fixture()
	for index in range(5):
		await tap_target()
		var chosen = world.targets[index] if index<4 else null
		check(world.selected_target()==chosen and world.target_index==(index if index<4 else -1), "A distinct target tap selects %s" % (chosen.target_name if chosen!=null else "Free shots"))
	await host.tick(20)
	check(world.target_index==-1 and world.selected_target()==null, "Returning to free shots stays free across ordinary scene updates")
	for index in range(3):
		await gesture_fixture()
		var target = world.targets[index]
		target.accept_hit(5,Vector2(150,-200),"Platform home fixture")
		await host.tick(340)
		check(target.position.distance_to(expected[index])<1 and target.percent==5 and target.hit_count==1 and target.is_on_floor(), "Automatic return restores Target %s to its platform while retaining practice results" % target.target_name)
	await gesture_fixture()
	var saved: Array = world.targets.duplicate()
	world.targets = [null,dummy,null]
	world.target_index = -1
	world.clean_targets()
	check(world.targets.size()==1 and world.target_index==-1 and world.selected_target()==null, "Filtering invalid targets preserves explicit free-shot mode")
	check(world.cycle_target() and world.selected_target()==dummy, "A single surviving target can be selected without indexing errors")
	check(world.cycle_target() and world.selected_target()==null, "A single-target list still cycles back to free shots")
	world.targets = []
	check(not world.cycle_target() and world.selected_target()==null and world.target_index==-1, "Empty target lists safely retain free-shot mode")
	world.targets = saved
	world.target_index = -1

func test_tap_hold_gesture() -> void:
	await gesture_fixture()
	joy_axis(JOY_AXIS_TRIGGER_LEFT,0.20)
	await host.tick(25)
	joy_axis(JOY_AXIS_TRIGGER_LEFT,0.0)
	await host.tick(3)
	check(not world.aim.held and world.selected_target()==null, "Trigger pressure below threshold cannot aim or cycle even when held and released")
	joy_axis(JOY_AXIS_TRIGGER_LEFT,0.90)
	await host.tick(3)
	joy_axis(JOY_AXIS_TRIGGER_LEFT,0.95)
	await host.tick(3)
	joy_axis(JOY_AXIS_TRIGGER_LEFT,0.80)
	await host.tick(3)
	check(world.target_index==-1 and not world.aim.held, "High trigger jitter during one pending gesture does not select early or count repeated taps")
	joy_axis(JOY_AXIS_TRIGGER_LEFT,0.0)
	await host.tick(3)
	check(world.target_index==0, "A pending gesture release cycles exactly once despite multiple high trigger events")
	await host.tick(10)
	check(world.target_index==0, "Neutral frames cannot repeat a completed tap")
	joy_axis(JOY_AXIS_TRIGGER_LEFT,1.0)
	await host.tick(20)
	check(not world.aim.held and world.target_index==0, "A target gesture remains pending just before the 180 ms hold threshold")
	await host.tick(5)
	check(world.aim.held and world.target_index==0, "Passing the hold threshold enters aim while preserving the persistent target")
	joy_axis(JOY_AXIS_TRIGGER_LEFT,0.0)
	await host.tick(3)
	check(not world.aim.held and world.target_index==0, "Releasing a consumed aim hold cannot also cycle the selected target")
	await gesture_fixture(Vector2(620,220))
	joy_axis(JOY_AXIS_TRIGGER_LEFT,1.0)
	joy_axis(JOY_AXIS_RIGHT_Y,-1.0)
	await host.tick(3)
	check(not world.aim.held and abilities.windup_time==0 and not abilities.move_heavy, "Right-stick movement during a pending target gesture cannot leak a heavy sword attack")
	joy_axis(JOY_AXIS_TRIGGER_RIGHT,1.0)
	await host.tick(3)
	check(world.aim.held and abilities.charging and world.target_index==-1, "Ranged use during a pending target gesture immediately promotes manual aim instead of cycling")
	joy_axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
	await host.tick(2)
	joy_axis(JOY_AXIS_TRIGGER_LEFT,0.0)
	await host.tick(3)
	check(world.target_index==-1 and abilities.projectiles.size()==1, "Manual ranged gesture release produces one shot and consumes the target tap")
	await gesture_fixture()
	key(KEY_TAB,true)
	await host.tick(4)
	key(KEY_TAB,false)
	await host.tick(3)
	check(world.target_index==0 and not world.aim.held, "Keyboard Tab tap shares persistent target selection")
	key(KEY_TAB,true)
	await host.tick(25)
	check(world.aim.held and world.target_index==0, "Keyboard Tab hold shares manual aim without changing selection")
	key(KEY_TAB,false)
	await host.tick(3)
	check(world.target_index==0 and not world.aim.held, "Keyboard held-gesture release cannot create an extra target tap")
	await gesture_fixture()
	# Both real key events arrive before the next physics dispatch.
	key(KEY_TAB,true)
	key(KEY_TAB,false)
	await host.tick(3)
	check(world.target_index==0 and not world.aim.held, "A complete Tab tap between physics ticks still selects exactly one target")
	await host.tick(12)
	check(world.target_index==0 and not world.aim.held, "A completed between-tick tap cannot replay on subsequent physics frames")

func test_moving_aim() -> void:
	await gesture_fixture()
	joy_axis(JOY_AXIS_TRIGGER_LEFT,1.0)
	await host.tick(25)
	joy_axis(JOY_AXIS_RIGHT_X,0.3)
	joy_axis(JOY_AXIS_RIGHT_Y,-0.8)
	joy_axis(JOY_AXIS_LEFT_X,1.0)
	var start: Vector2 = player.position
	await host.tick(24)
	check(world.aim.held and player.position.x>start.x+50 and absf(player.velocity.x-400)<0.1, "Held aim allows normal full-speed horizontal movement through real physics")
	check(world.aim.raw_direction.is_equal_approx(Vector2(0.3,-0.8).normalized()) and not abilities.move_heavy, "Right stick preserves its analog aim while left stick independently moves the player")
	joy_axis(JOY_AXIS_LEFT_X,0.6)
	await host.tick(24)
	check(player.velocity.x>100 and player.velocity.x<300 and world.aim.held, "Partial movement stick retains proportional walking speed while aiming")
	joy_axis(JOY_AXIS_LEFT_X,0.0)
	joy_axis(JOY_AXIS_RIGHT_X,0.0)
	joy_axis(JOY_AXIS_RIGHT_Y,0.0)
	joy_axis(JOY_AXIS_LEFT_Y,1.0)
	await host.tick(4)
	check(player.crouching and world.aim.held and not player.blocking, "Held aim permits grounded crouch instead of suppressing ordinary movement states")
	joy_axis(JOY_AXIS_LEFT_Y,0.0)
	joy_button(JOY_BUTTON_A,true)
	await host.tick(3)
	check(player.jump_count==1 and not player.is_on_floor() and world.aim.held, "The independent jump button can jump while aim is held")
	joy_button(JOY_BUTTON_A,false)
	await gesture_fixture(Vector2(620,200))
	joy_axis(JOY_AXIS_TRIGGER_LEFT,1.0)
	await host.tick(25)
	player.velocity.y = 80
	joy_axis(JOY_AXIS_LEFT_Y,1.0)
	await host.tick(3)
	check(player.fastfall and player.velocity.y>1000 and world.aim.held, "Held aim no longer suppresses a fresh descending fast-fall input")
	await gesture_fixture(Vector2(430,414))
	joy_axis(JOY_AXIS_TRIGGER_LEFT,1.0)
	await host.tick(25)
	joy_axis(JOY_AXIS_LEFT_Y,1.0)
	joy_button(JOY_BUTTON_A,true)
	await host.tick(8)
	check(player.position.y>420 and not player.get_collision_mask_value(2) and world.aim.held, "Down plus jump can drop through a platform while manual aim is held")

func test_target_reset_and_pause() -> void:
	await gesture_fixture()
	world.target_index = 2
	var chosen = world.targets[2]
	joy_axis(JOY_AXIS_TRIGGER_LEFT,1.0)
	await host.tick(3)
	world.respawn()
	joy_axis(JOY_AXIS_TRIGGER_LEFT,0.0)
	await host.tick(5)
	check(world.selected_target()==chosen and not world.aim.held, "Player reset preserves a persistent target and cancels a pending tap without cycling")
	joy_axis(JOY_AXIS_TRIGGER_LEFT,1.0)
	await host.tick(3)
	world.reset_dummy()
	joy_axis(JOY_AXIS_TRIGGER_LEFT,0.0)
	await host.tick(5)
	check(world.selected_target()==chosen and not world.aim.held, "Target reset retains persistent selection and consumes the interrupted target gesture")
	world.reset_room()
	await host.tick(5)
	check(world.target_index==-1 and world.selected_target()==null, "Full training reset explicitly clears persistent target selection")
	await gesture_fixture()
	world.target_index = 1
	joy_axis(JOY_AXIS_TRIGGER_LEFT,1.0)
	await host.tick(3)
	world.pause_game()
	world.ui_canvas.get_node("Pause").resume()
	await host.tick(5)
	joy_axis(JOY_AXIS_TRIGGER_LEFT,0.95)
	await host.tick(25)
	check(world.target_index==1 and not world.aim.held, "Canceled trigger jitter after pause cannot resume aim or turn the pending gesture into a tap")
	joy_axis(JOY_AXIS_TRIGGER_LEFT,0.0)
	await host.tick(3)
	check(world.target_index==1, "First physical neutral after canceled aim merely rearms the gesture without cycling")
	await tap_target()
	check(world.target_index==2, "A real neutral and fresh short tap safely rearm target cycling after pause")

func test_target_disconnect() -> void:
	await gesture_fixture()
	world.target_index = 1
	joy_axis(JOY_AXIS_TRIGGER_LEFT,1.0)
	await host.tick(3)
	world.controls.use_controller(31,"Xbox Controller")
	world.controls.on_connection_changed(31,false)
	check(host.paused and not world.aim.held and world.target_index==1, "Unplug cancels a pending aim gesture without changing the persistent lock")
	world.ui_canvas.get_node("Pause").resume()
	await host.tick(4)
	world.controls.on_connection_changed(31,true)
	joy_axis(JOY_AXIS_TRIGGER_LEFT,0.95)
	await host.tick(25)
	check(not world.aim.held and world.target_index==1, "A delayed high LT event on reconnect cannot aim or manufacture a target tap")
	joy_axis(JOY_AXIS_TRIGGER_LEFT,0.0)
	await host.tick(4)
	check(world.target_index==1, "Reconnect neutral alone cannot cycle a canceled gesture")
	await tap_target()
	check(world.target_index==2, "Fresh reconnect tap cycles exactly once after device-specific neutral rearm")
