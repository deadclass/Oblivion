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
	print("RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
