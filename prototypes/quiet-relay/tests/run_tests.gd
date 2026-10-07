extends SceneTree

var world
var player
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func tick(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ",description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func place(point: Vector2) -> void:
	player.test_axis = 0
	player.test_jump_held = false
	player.reset_at(point)
	await tick(4)

func jump_to(x: float) -> void:
	player.test_jump_pressed = true
	player.test_jump_held = true
	for i in range(115):
		player.test_axis = clampf((x-player.position.x)/12.0,-1,1)
		await tick(1)
		if i > 10 and player.is_on_floor():
			break
	player.test_axis = 0
	player.test_jump_held = false
	await tick(8)

func jump_height(held_frames: int) -> float:
	await place(Vector2(100,548))
	var start_y: float = player.position.y
	var min_y := start_y
	player.test_jump_pressed = true
	player.test_jump_held = true
	for i in range(110):
		if i == held_frames:
			player.test_jump_held = false
		await tick(1)
		min_y = minf(min_y,player.position.y)
	return start_y-min_y

func run() -> void:
	world = load("res://main.tscn").instantiate()
	root.add_child(world)
	player = world.player
	player.test_control = true
	# Focused regressions isolate old behavior; test_motion_and_chase exercises live motion.
	world.set_platform_motion(false,true)
	world.dummy.ai_enabled = false
	await tick(10)
	check(player.is_on_floor(),"Spawn settles on floor")
	var full: float = await jump_height(110)
	var short: float = await jump_height(4)
	check(full > 95 and full < 110,"Full jump apex approximately 102 px: %.2f" % full)
	check(short < 45 and short > 15 and short < full*0.5,"Variable jump height: %.2f px" % short)
	await place(Vector2(100,548))
	player.test_axis = 1
	await tick(20)
	check(absf(player.velocity.x-255)<1,"Run reaches configured speed")
	player.test_axis = 0
	await tick(15)
	check(absf(player.velocity.x)<1,"Ground braking stops promptly")
	await place(Vector2(378,483))
	player.test_axis = 1
	while player.is_on_floor():
		await tick(1)
	await tick(5)
	var count: int = player.jump_count
	player.test_jump_pressed = true
	player.test_jump_held = true
	await tick(2)
	check(player.jump_count == count+1 and player.velocity.y < 0,"Coyote jump after stepping off edge")
	await place(Vector2(100,510))
	player.velocity.y = 330
	count = player.jump_count
	player.test_jump_pressed = true
	player.test_jump_held = true
	await tick(14)
	check(player.jump_count == count+1 and player.velocity.y < 0,"Buffered jump fires on landing")
	await place(Vector2(975,548))
	player.test_axis = 1
	await tick(40)
	check(player.position.x <= 984.1,"Closed gate blocks player")
	world.reset_room()
	await tick(8)
	await place(Vector2(185,548))
	world.interact()
	check(player.carrying,"Weight can be picked up")
	player.test_axis = 1
	await tick(27)
	player.test_axis = 0
	await tick(12)
	await jump_to(330)
	check(player.is_on_floor() and player.position.y < 490,"Carrying jump reaches first step")
	await jump_to(485)
	check(player.is_on_floor() and player.position.y < 425,"Carrying jump reaches second step")
	player.test_axis = 1
	await tick(40)
	player.test_axis = 0
	await tick(10)
	await jump_to(674)
	check(player.is_on_floor() and player.position.y < 355,"Carrying jump reaches cradle platform")
	player.test_axis = 1
	await tick(19)
	player.test_axis = 0
	await tick(12)
	world.interact()
	await tick(3)
	check(world.solved and not player.carrying,"Actual traversal places weight and restores relay")
	check(not world.bridge.get_child(0).disabled and world.gate.get_child(0).disabled,"Relay creates solid bridge and removes gate collision")
	player.test_axis = 1
	await tick(240)
	check(world.won,"Restored path leads to exit through actual movement")
	world.respawn()
	await tick(3)
	check(world.solved and not world.bridge.get_child(0).disabled,"Checkpoint restart preserves restored puzzle")
	world.reset_room()
	await tick(3)
	check(not world.solved and not world.won and world.stone.distance_to(world.STONE_START)<1,"Full reset clears puzzle and exit")
	await place(Vector2(580,548))
	check(world.checkpoint_active,"Crossing checkpoint activates it")
	player.position = Vector2(900,680)
	await tick(3)
	check(player.position.distance_to(Vector2(580,548))<5 and world.deaths==1,"Pit death respawns at checkpoint")
	player.carrying = true
	world.respawn()
	check(not player.carrying and world.stone == world.STONE_START,"Restart safely recovers carried weight")
	await place(Vector2(100,548))
	var ceiling = world.make_solid(Rect2(50,470,100,15))
	player.test_jump_pressed = true
	player.test_jump_held = true
	var highest: float = player.position.y
	for i in range(80):
		await tick(1)
		highest = minf(highest,player.position.y)
	check(highest >= 501 and player.is_on_floor(),"Ceiling collision stops upward travel and returns to floor")
	ceiling.queue_free()
	await tick(2)
	await place(Vector2(100,548))
	player.test_jump_pressed = true
	player.test_jump_held = true
	await tick(20)
	count = player.jump_count
	player.test_jump_pressed = true
	await tick(2)
	check(player.jump_count == count,"No unintended midair second jump")
	player.test_jump_held = false
	await tick(100)
	check(player.jump_count == count,"Expired buffer does not jump on much later landing")
	world.stone = Vector2(900,680)
	await tick(3)
	check(world.stone.distance_to(world.STONE_START)<1,"Loose weight falling into pit returns safely")
	var pause_event := InputEventAction.new()
	pause_event.action = "pause"
	pause_event.pressed = true
	world._unhandled_input(pause_event)
	check(paused,"Escape pause stops scene physics")
	world.get_node("Pause")._unhandled_input(pause_event)
	check(not paused,"Escape resumes scene physics")
	await test_health_and_melee()
	await test_motion_and_chase()
	print("RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func test_health_and_melee() -> void:
	world.reset_room()
	await tick(5)
	check(world.health == 5,"Five hearts after full reset")
	await place(Vector2(185,548))
	await tick(50)
	check(absf(world.stone.y-557)<1,"Loose weight stays on floor when player overlaps it")
	await place(Vector2(100,400))
	await tick(120)
	check(world.health == 5,"Landing below large-fall threshold causes no damage")
	await place(Vector2(100,200))
	await tick(160)
	check(world.health == 4,"Qualifying large fall removes exactly one heart")
	await tick(60)
	check(world.health == 4,"Standing after landing does not repeat fall damage")
	await place(Vector2(100,200))
	await tick(160)
	check(world.health == 3,"Separate qualifying landing causes one new damage")
	player.large_fall_threshold = 1000
	await place(Vector2(100,200))
	await tick(160)
	check(world.health == 3,"Large-fall threshold is tunable")
	player.large_fall_threshold = 180
	world.respawn()
	check(world.health == 5 and not player.fall_tracking,"Manual checkpoint restart heals and clears fall tracking")
	await tick(5)
	await place(Vector2(580,548))
	check(world.checkpoint_active and world.health == 5,"First checkpoint activation restores hearts")
	world.take_damage("Test damage")
	await tick(5)
	check(world.health == 4,"Standing at checkpoint does not heal repeatedly")
	player.reset_at(Vector2(900,680))
	await tick(4)
	check(world.health == 3 and player.position.distance_to(Vector2(580,548))<5,"Pit recovery costs one heart and preserves remaining health")
	world.health = 1
	var deaths_before: int = world.deaths
	await place(Vector2(100,200))
	await tick(160)
	check(world.health == 5 and world.deaths == deaths_before+1 and player.position.distance_to(Vector2(580,548))<8,"Zero-heart landing restores checkpoint and five hearts once")
	world.health = 1
	deaths_before = world.deaths
	player.reset_at(Vector2(900,680))
	await tick(4)
	check(world.health == 5 and world.deaths == deaths_before+1,"Zero-heart pit recovery counts once and restores five hearts")
	world.reset_room()
	await tick(5)
	await place(Vector2(185,548))
	player.facing = 1
	check(world.attack(),"Melee swing starts when ready")
	await tick(3)
	check(world.dummy.health == 4 and world.dummy.hit_count == 1,"Melee physics query deals one damage to dummy")
	await tick(10)
	check(world.dummy.health == 4 and world.dummy.hit_count == 1,"Overlapping active swing hits each target only once")
	check(not world.attack(),"Attack cooldown rejects rapid repeat")
	await tick(35)
	world.attack()
	await tick(4)
	check(world.dummy.health == 3 and world.dummy.hit_count == 2,"Next swing deals one new damage")
	await tick(40)
	player.facing = -1
	world.attack()
	await tick(40)
	check(world.dummy.health == 3,"Melee misses target behind player")
	await place(Vector2(100,548))
	player.facing = 1
	world.attack()
	await tick(40)
	check(world.dummy.health == 3,"Melee misses target outside reach")
	await place(Vector2(185,548))
	player.carrying = true
	check(not world.attack(),"Carrying weight prevents melee attack")
	player.carrying = false
	world.reset_dummy()
	Input.action_press("attack")
	await tick(80)
	Input.action_release("attack")
	check(world.dummy.health == 4 and world.dummy.hit_count == 1,"Holding attack creates one swing, not repeated hits")
	world.reset_dummy()
	await tick(3)
	for i in range(5):
		world.attack()
		await tick(40)
	check(world.dummy.health == 0 and world.dummy.hit_count == 5,"Five swings deplete five-health dummy")
	world.attack()
	await tick(40)
	check(world.dummy.health == 0 and world.dummy.hit_count == 5,"Depleted dummy stays at zero without extra hit count")
	Input.action_press("reset_dummy")
	await tick(3)
	Input.action_release("reset_dummy")
	check(world.dummy.health == 5 and world.dummy.hit_count == 0,"Dummy reset input restores health and hit count")
	world.attack()
	await tick(2)
	world.reset_dummy()
	await tick(20)
	check(world.dummy.health == 5 and world.weapon.active_time == 0,"Dummy reset cancels in-flight swing")
	world.attack()
	world.respawn()
	await tick(20)
	check(world.dummy.health == 5 and world.weapon.active_time == 0,"Checkpoint restart cancels in-flight melee")
	world.dummy.receive_hit(1)
	world.health = 2
	world.respawn()
	check(world.health == 5 and world.dummy.health == 4,"Checkpoint restart heals player while retaining dummy state")
	world.reset_room()
	await tick(5)
	check(world.health == 5 and world.dummy.health == 5 and world.dummy.hit_count == 0,"Full room reset restores hearts and dummy")

func mouse_button(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)

func land_on_moving_platform(platform, timeout_frames: int = 3600) -> bool:
	player.test_jump_held = true
	var air_remaining := 0.0
	var landing_fraction := 0.5
	var speed: float = player.run_speed*(0.84 if player.carrying else 1.0)
	for i in range(timeout_frames):
		var current: Rect2 = platform.surface_rect()
		if player.is_on_floor() and absf(player.position.y+16-current.position.y)<7 and player.position.x>current.position.x-6 and player.position.x<current.end.x+6:
			player.test_axis = 0
			return true
		var future: Rect2 = platform.predicted_surface_rect(maxf(0.07,air_remaining) if not player.is_on_floor() else 0.60)
		var landing_x: float = future.position.x+future.size.x*landing_fraction if not player.is_on_floor() else clampf(player.position.x,future.position.x+8,future.end.x-8)
		var delta_x: float = landing_x-player.position.x
		player.test_axis = clampf(delta_x/(maxf(0.07,air_remaining)*speed),-1,1) if not player.is_on_floor() else clampf(delta_x/12.0,-1,1)
		if player.is_on_floor():
			var plan: Dictionary = player_jump_plan(platform,speed)
			if not plan.is_empty():
				air_remaining = plan.flight
				landing_fraction = plan.fraction
				player.test_axis = clampf((plan.x-player.position.x)/(air_remaining*speed),-1,1)
				player.test_jump_pressed = true
			else:
				# A solid step cannot be jumped through from directly beneath it.
				# Approach its outside edge on the room floor, then retry the jump.
				if player.position.y+16 > current.position.y+32 and player.position.y>530:
					var outside_x: float = minf(current.position.x,future.position.x)-26
					player.test_axis = clampf((outside_x-player.position.x)/12.0,-1,1)
				# Wait near a safe takeoff edge rather than walking off while
				# the independently moving next step is too far away.
				for support in world.moving_platforms:
					var support_rect: Rect2 = support.surface_rect()
					if absf(player.position.y+16-support_rect.position.y)<7:
						if (delta_x>0 and player.position.x>support_rect.end.x-30) or (delta_x<0 and player.position.x<support_rect.position.x+30):
							player.test_axis = 0
		await tick(1)
		air_remaining = maxf(0.0,air_remaining-1.0/120.0)
	player.test_axis = 0
	print("TRAVERSAL TIMEOUT player=",player.position," target=",platform.surface_rect()," floor=",player.is_on_floor()," phase=",platform.elapsed)
	return false

func player_jump_plan(target, speed: float) -> Dictionary:
	var apex: float = player.position.y+16-player.jump_speed*player.jump_speed/(2*player.gravity)
	var flight := 0.6
	var destination: Rect2
	for iteration in range(3):
		destination = target.predicted_surface_rect(flight)
		if destination.position.y < apex+5:
			return {}
		flight = player.jump_speed/player.gravity+sqrt(2*(destination.position.y-apex)/player.fall_gravity)+0.025
	destination = target.predicted_surface_rect(flight)
	for fraction in [0.10,0.50,0.90]:
		var x: float = destination.position.x+destination.size.x*fraction
		if absf(x-player.position.x)>speed*flight:
			continue
		var point: Vector2 = player.position
		var motion := Vector2(player.velocity.x,-player.jump_speed)
		var elapsed := 0.0
		var blocked := false
		while elapsed < flight+0.08:
			var old_feet := point.y+16
			var desired := clampf((x-point.x)/maxf(0.07,flight-elapsed),-speed,speed)
			motion.x = move_toward(motion.x,desired,player.air_acceleration/120.0)
			point += motion/120.0
			elapsed += 1.0/120.0
			var body := Rect2(point-Vector2(11,16),Vector2(22,32))
			for platform in world.moving_platforms:
				var surface: Rect2 = platform.predicted_surface_rect(elapsed)
				if body.intersects(surface):
					if platform==target and motion.y>0 and old_feet<=surface.position.y+3:
						return {"flight":flight,"fraction":fraction,"x":x}
					blocked = true
					break
			if blocked:
				break
			motion.y += (player.fall_gravity if motion.y>0 else player.gravity)/120.0
	return {}

func test_motion_and_chase() -> void:
	world.reset_room()
	world.dummy.ai_enabled = false
	world.set_platform_motion(true,true)
	await place(Vector2(95,548))
	var initial: Array[Vector2] = []
	for platform in world.moving_platforms:
		initial.append(platform.position)
	await tick(180)
	for i in range(3):
		var platform = world.moving_platforms[i]
		check(absf(platform.position.x-initial[i].x)>30 and absf(platform.position.y-initial[i].y)>1,"Raised platform %d moves horizontally and bobs" % (i+1))
	check(world.moving_platforms[0].horizontal_speed != world.moving_platforms[1].horizontal_speed and world.moving_platforms[1].horizontal_speed != world.moving_platforms[2].horizontal_speed,"Each platform has a different speed")
	for platform in world.moving_platforms:
		platform.elapsed = 2.5
		platform.position = platform.base_rect.get_center()+platform.offset_at(platform.elapsed)
		await tick(3)
		var rect: Rect2 = platform.surface_rect()
		player.reset_at(Vector2(rect.get_center().x,rect.position.y-17))
		player.test_axis = 0
		player.test_jump_held = false
		await tick(30)
		var relative_x: float = player.position.x-platform.position.x
		var floor_frames: int = 0
		var hearts: int = world.health
		for i in range(750):
			await tick(1)
			if player.is_on_floor():
				floor_frames += 1
		check(absf(player.position.x-platform.position.x-relative_x)<5 and floor_frames>735,"Idle player rides platform through reversal without slipping")
		check(world.health==hearts,"Platform bob does not cause fall damage")
	world.reset_room()
	world.set_platform_motion(true,true)
	var low = world.moving_platforms[0]
	world.stone = Vector2(low.position.x,low.surface_rect().position.y-13)
	await tick(40)
	var weight_offset: float = world.stone.x-low.position.x
	await tick(240)
	check(absf(world.stone.x-low.position.x-weight_offset)<5 and absf(world.stone.y+13-low.surface_rect().position.y)<3,"Loose weight rides a moving platform")
	world.reset_room()
	world.set_platform_motion(true,true)
	await place(Vector2(185,548))
	world.interact()
	var traversed := true
	for platform in world.moving_platforms:
		var landed := await land_on_moving_platform(platform)
		check(landed,"Actual carrying jump lands on moving step")
		if not landed:
			traversed = false
			break
	if traversed:
		for i in range(160):
			player.test_axis = clampf((world.socket_position().x-player.position.x)/12.0,-1,1)
			await tick(1)
			if player.position.distance_to(world.socket_position())<40:
				break
		player.test_axis = 0
		world.interact()
		await tick(3)
	check(traversed and world.solved,"Moving staircase remains solvable using actual movement")
	if world.solved:
		await tick(180)
		check(world.stone.distance_to(world.socket_position())<1,"Placed weight follows moving cradle")
		player.test_axis = 1
		player.test_jump_held = false
		await tick(400)
		check(world.won,"Moving-puzzle completion still leads to exit")
	for starting_phase in [7.0,14.0]:
		world.reset_room()
		world.set_platform_motion(true,true)
		for platform in world.moving_platforms:
			platform.elapsed = starting_phase
			platform.position = platform.base_rect.get_center()+platform.offset_at(starting_phase)
		await tick(3)
		await place(Vector2(185,548))
		world.interact()
		var phase_traversed := true
		for platform in world.moving_platforms:
			if not await land_on_moving_platform(platform):
				phase_traversed = false
				break
		check(phase_traversed,"Live carrying staircase remains reachable at phase %.0f s" % starting_phase)
	world.reset_room()
	world.set_platform_motion(false,true)
	world.dummy.ai_enabled = false
	await place(Vector2(185,548))
	player.facing = 1
	var attack_events: Array = InputMap.action_get_events("attack")
	check(attack_events.size()==1 and attack_events[0] is InputEventMouseButton and attack_events[0].button_index==MOUSE_BUTTON_LEFT,"Melee is bound exclusively to left mouse button")
	mouse_button(true)
	await tick(80)
	mouse_button(false)
	await tick(2)
	check(world.dummy.hit_count==1 and world.dummy.health==4,"Real mouse event produces one swing while held")
	mouse_button(true)
	await tick(3)
	mouse_button(false)
	await tick(2)
	check(world.dummy.hit_count==2 and world.dummy.health==3,"Second mouse click produces a fresh one-damage swing")
	world.reset_room()
	world.set_platform_motion(true,true)
	world.dummy.ai_enabled = true
	check(player.run_speed > world.dummy.run_speed and player.run_speed/world.dummy.run_speed<1.05,"Player is slightly faster than evasive dummy")
	var jump_before: int = world.dummy.jump_count
	var high_landings: int = 0
	player.reset_at(Vector2(200,548))
	for i in range(1800):
		await tick(1)
		if world.dummy.is_on_floor() and world.dummy.position.y < 500:
			high_landings += 1
	check(world.dummy.jump_count>jump_before,"Live dummy runs and jumps to evade")
	check(high_landings>10,"Live dummy actually lands on elevated moving platforms")
	world.reset_dummy()
	await tick(3)
	check(world.dummy.health==5 and world.dummy.hit_count==0 and world.dummy.position.x<250,"T reset restores dummy health and starting location")
	world.dummy.ai_enabled = true
	player.reset_at(Vector2(180,548))
	player.test_jump_held = true
	var caught := false
	for i in range(3600):
		var delta: Vector2 = world.dummy.position-player.position
		player.test_axis = clampf(delta.x/12.0,-1,1)
		if player.is_on_floor() and (delta.y < -22 or (world.dummy.velocity.y < -100 and absf(delta.x)<180)):
			player.test_jump_pressed = true
		if absf(delta.x)<90 and absf(delta.y)<40:
			world.attack()
		await tick(1)
		if world.dummy.hit_count>0:
			caught = true
			break
	check(caught,"Player pursuing live jumping dummy can catch and hit it")
	world.dummy.health = 0
	player.test_axis = 0
	await tick(180)
	check(absf(world.dummy.velocity.x)<1,"Depleted dummy stops evading")
