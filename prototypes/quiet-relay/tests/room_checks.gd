extends RefCounted

var completed: bool = false
var host
var world
var player

func check(condition: bool, description: String) -> void:
	host.check(condition, description)

func walk_to(x: float) -> void:
	for frame in range(1600):
		var distance: float = x-player.position.x
		player.test_axis = clampf(distance/40.0,-1.0,1.0)
		await host.tick(1)
		if absf(distance)<2.0 and absf(player.velocity.x)<8.0:
			break
	player.test_axis = 0.0
	await host.tick(8)
	check(absf(player.position.x-x)<3.0, "Actual controller reaches corridor waypoint %.0f" % x)

func ascend(floor_y: float) -> void:
	for step in range(1,10):
		var landing_y: float = floor_y-step*100.0-18.0
		player.test_jump_held = true
		player.test_jump_pressed = true
		var landed := false
		for frame in range(130):
			await host.tick(1)
			if player.is_on_floor() and absf(player.position.y-landing_y)<2.0:
				landed = true
				break
		check(landed, "Existing grounded jump reaches stair %d at floor %.0f" % [step,floor_y])
		await host.tick(3)
	player.test_jump_held = false

func descend(floor_y: float) -> void:
	for step in range(9):
		player.test_vertical = 0.0
		await host.tick(2)
		player.test_vertical = 1.0
		player.test_jump_pressed = true
		var landed := false
		for frame in range(130):
			await host.tick(1)
			if player.is_on_floor() and absf(player.position.y-(floor_y+(step+1)*100.0-18.0))<2.0:
				landed = true
				break
		check(landed, "Existing down+jump returns via stair %d" % (step+1))
	player.test_vertical = 0.0

func test_natural_form_return(origin: Vector2, heading: Vector2, launch_room: int, visited_room: int, aimed: bool = false) -> void:
	world.abilities.cancel_all()
	player.reset_at(origin)
	# Keep the real controller live so dummy-hit hitstop can expire during flight.
	player.set_physics_process(true)
	player.jumps_remaining = 1
	player.dodge_available = false
	player.dash_available = false
	world.current_room = launch_room
	world.discovered_rooms.assign([launch_room])
	world.update_room_state()
	world.abilities.handle_ranged(false,false)
	player.facing = int(heading.x) if heading.x != 0 else 1
	if aimed:
		Input.action_press("target")
		Input.action_press("up")
		world.update_target_input(world.TARGET_HOLD_TIME+0.01)
	world.abilities.selected_weapon = 1
	check(world.abilities.fire_ranged(), "Natural return fixture launches through ranged weapon in Room %d" % launch_room)
	await host.tick(35)
	check(player.boomerang_form and world.current_room==visited_room, "Live form physically crosses Room %d to %d before returning" % [launch_room,visited_room])
	check(world.camera.limit_left==int(world.rooms[visited_room-1].cell.x*1600) and world.camera.limit_bottom==int(world.rooms[visited_room-1].floor+88), "Excursion camera tracks the visited room")
	if aimed:
		Input.action_release("target")
		Input.action_release("up")
	var saw_return := false
	for frame in range(400):
		if world.abilities.boomerang_active():
			saw_return = saw_return or world.abilities.boomerang.returning
		else:
			break
		await host.tick(1)
	# Freeze only after the flight to inspect restoration before gravity/landing.
	player.set_physics_process(false)
	await host.tick(2)
	check(saw_return and not world.abilities.boomerang_active() and not player.boomerang_form, "Natural timer or aim-release flight completes its real return phase")
	check(player.position.distance_to(origin)<0.1 and world.abilities.active_move=="Boomerang returned", "Natural return restores the exact launch body without pause/reset cancellation")
	check(world.current_room==launch_room and world.camera.limit_left==int(world.rooms[launch_room-1].cell.x*1600) and world.camera.limit_bottom==int(world.rooms[launch_room-1].floor+88), "Natural return synchronizes launch-room minimap and camera on the next world tick")
	check(world.discovered_rooms==[launch_room,visited_room] and world.visible_connections().size()==1, "Natural return retains the newly discovered room and connection")
	check(player.jumps_remaining==1 and not player.dodge_available and not player.dash_available, "Cross-room return does not replenish spent movement resources")

func test_seam_form_return(goal: float, launch_room: int, pause_cancel: bool) -> void:
	var seam_world = load("res://main.tscn").instantiate()
	host.root.add_child(seam_world)
	var body = seam_world.player
	seam_world.camera.make_current()
	body.test_control = true
	await host.tick(8)
	# Walk from the safe spawn; no position, room or physics overrides.
	var waypoints: Array = [1700.0,goal] if launch_room==2 else [goal]
	for waypoint in waypoints:
		for frame in range(1600):
			var distance: float = waypoint-body.position.x
			body.test_axis = clampf(distance/40.0,-1.0,1.0)
			await host.tick(1)
			if absf(distance)<0.1 and absf(body.velocity.x)<1.0:
				break
		body.test_axis = 0.0
		await host.tick(12)
	var origin: Vector2 = body.position
	check(absf(origin.x-goal)<0.2 and seam_world.current_room==launch_room, "Walked seam fixture reaches logical launch room")
	body.facing = 1 if launch_room==1 else -1
	seam_world.abilities.selected_weapon = 1
	check(seam_world.abilities.fire_ranged(), "Walked seam fixture launches real form")
	await host.tick(35)
	check(seam_world.current_room!=launch_room and body.boomerang_form, "Walked seam form crosses to excursion room")
	var saw_return := false
	if pause_cancel:
		seam_world.pause_game()
	else:
		for frame in range(600):
			if not seam_world.abilities.boomerang_active():
				break
			saw_return = saw_return or seam_world.abilities.boomerang.returning
			await host.tick(1)
		await host.tick(120)
	seam_world.camera.force_update_scroll()
	var screen: Vector2 = seam_world.get_viewport().get_canvas_transform()*body.position

	check((pause_cancel or saw_return) and not body.boomerang_form and body.position.distance_to(origin)<0.1, "Seam return restores exact body through natural completion or pause")
	check(seam_world.current_room==launch_room and seam_world.camera.limit_left==(0 if launch_room==1 else 1600), "Seam return restores logical launch room and minimap camera")
	check(screen.x>=11 and screen.x<=1141, "Seam return leaves the whole body inside the camera viewport")
	check(1 in seam_world.discovered_rooms and 2 in seam_world.discovered_rooms and seam_world.visible_connections().size()==1, "Seam return retains excursion discovery and connection")
	if pause_cancel:
		seam_world.ui_canvas.get_node("Pause").resume()
	seam_world.queue_free()
	await host.tick(3)
	world.camera.make_current()

func test_walked_seam_camera(launch_room: int) -> void:
	var seam_world = load("res://main.tscn").instantiate()
	host.root.add_child(seam_world)
	var body = seam_world.player
	seam_world.camera.make_current()
	body.test_control = true
	await host.tick(8)
	# Reach both geometric sides while retaining the logical room. No position,
	# room/discovery assignment or disabled controller may manufacture this state.
	var waypoints: Array = [1590.0,1610.0] if launch_room==1 else [1700.0,1610.0,1590.0]
	for goal in waypoints:
		for frame in range(1600):
			var distance: float = goal-body.position.x
			body.test_axis = clampf(distance/40.0,-1.0,1.0)
			await host.tick(1)
			if absf(distance)<0.1 and absf(body.velocity.x)<1.0:
				break
		body.test_axis = 0.0
		await host.tick(12)
		if goal==1700.0:
			continue
		check(absf(body.position.x-goal)<0.2 and body.is_on_floor() and seam_world.current_room==launch_room, "Walked ordinary seam fixture retains logical room on either geometric side")
		var discoveries: Array = seam_world.discovered_rooms.duplicate()
		var links: Array = seam_world.visible_connections().duplicate()
		for paused in [false,true]:
			if paused:
				seam_world.pause_game()
			seam_world.camera.force_update_scroll()
			var screen: Vector2 = seam_world.get_viewport().get_canvas_transform()*body.position
			check(screen.x>=11 and screen.x<=1141, "Ordinary seam keeps full body visible in Room %d at %.0f (paused=%s)" % [launch_room,goal,paused])
			check(seam_world.current_room==launch_room and seam_world.camera.limit_left==(0 if launch_room==1 else 1600) and seam_world.discovered_rooms==discoveries and seam_world.visible_connections()==links, "Camera upkeep does not change hysteresis, discovery or connections")
			if paused:
				seam_world.ui_canvas.get_node("Pause").resume()
	seam_world.queue_free()
	await host.tick(3)
	world.camera.make_current()

func test_vertical_seam_return(seam: float, lower_room: int, upper_room: int, pause_cancel: bool, from_upper: bool) -> void:
	world.abilities.cancel_all()
	var launch_room: int = upper_room if from_upper else lower_room
	var visited_room: int = lower_room if from_upper else upper_room
	# Explicit boundary fixture: logical origin can differ from geometric cell
	# inside hysteresis. Use the real live controller/form, not a fake return.
	var origin := Vector2(2920 if lower_room==2 else 280, seam+(4 if from_upper else -4))
	player.reset_at(origin)
	player.set_physics_process(true)
	player.jumps_remaining = 1
	player.dodge_available = false
	player.dash_available = false
	world.current_room = launch_room
	world.discovered_rooms.assign([launch_room])
	world.update_room_state()
	check(world.current_room==launch_room and world.room_at(origin)!=launch_room, "Vertical seam fixture retains logical origin inside deadband")
	world.abilities.handle_ranged(false,false)
	Input.action_press("target")
	Input.action_press("down" if from_upper else "up")
	world.update_target_input(world.TARGET_HOLD_TIME+0.01)
	world.abilities.selected_weapon = 1
	check(world.abilities.fire_ranged(), "Vertical seam fixture launches aimed form")
	await host.tick(35)
	check(world.current_room==visited_room and player.boomerang_form, "Vertical form crosses beyond launch deadband")
	Input.action_release("target")
	Input.action_release("down" if from_upper else "up")
	var saw_return := false
	if pause_cancel:
		world.pause_game()
	else:
		for frame in range(400):
			if not world.abilities.boomerang_active():
				break
			saw_return = saw_return or world.abilities.boomerang.returning
			await host.tick(1)
	player.set_physics_process(false)
	world.camera.force_update_scroll()
	var screen: Vector2 = world.get_viewport().get_canvas_transform()*player.position
	check((pause_cancel or saw_return) and not player.boomerang_form and player.position.distance_to(origin)<0.1, "Vertical seam restores exact body on natural return or pause")
	check(world.current_room==launch_room and world.camera.limit_bottom==int(world.rooms[launch_room-1].floor+88), "Vertical restoration preserves logical origin rather than recomputing geometric cell")
	check(screen.y>=18 and screen.y<=630, "Vertical restoration keeps body inside viewport")
	check(world.discovered_rooms==[launch_room,visited_room] and world.visible_connections().size()==1, "Vertical restoration retains discovery and connection")
	check(player.jumps_remaining==1 and not player.dodge_available and not player.dash_available, "Vertical restoration does not replenish movement resources")
	if pause_cancel:
		world.ui_canvas.get_node("Pause").resume()

func run(test_host) -> void:
	host = test_host
	world = load("res://main.tscn").instantiate()
	host.root.add_child(world)
	player = world.player
	player.test_control = true
	await host.tick(8)
	check(world.get("rooms") != null, "Six-room world exposes explicit room definitions")
	if world.get("rooms") == null:
		world.queue_free()
		await host.tick(2)
		completed = true
		return
	check(world.rooms.size()==6 and world.connections.size()==5, "Six rooms share exactly five bidirectional chain links")
	for floor_index in range(3):
		check(world.rooms.filter(func(room): return room.cell.y==floor_index).size()==2, "Floor %d contains two rooms" % floor_index)
	check(world.current_room==1 and world.discovered_rooms==[1] and world.visible_connections().is_empty(), "Fresh world reveals only safe Room 1 and no unexplored connections")
	check(world.ui_canvas.get_node_or_null("Minimap") != null, "Viewport-anchored minimap has its reserved HUD node")
	for family in ["keyboard","xbox","playstation"]:
		world.controls.family = family
		world.update_control_hud()
		for line in world.hud.text.split("\n"):
			check(world.hud.get_theme_font("font").get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,world.hud.get_theme_font_size("font_size")).x < 900, "Control prompt fits left of minimap: %s" % family)
	world.controls.family = "keyboard"
	world.update_control_hud()
	await walk_to(2920)
	check(world.current_room==2 and world.visible_connections().size()==1, "Walking 1 to 2 discovers corridor and current room")
	await ascend(560)
	check(world.current_room==3, "East stairwell physically connects Room 2 to Room 3")
	await walk_to(280)
	check(world.current_room==4, "Walking middle gallery connects Room 3 to Room 4")
	await ascend(-340)
	check(world.current_room==5, "West stairwell physically connects Room 4 to Room 5")
	await walk_to(2200)
	check(world.current_room==6 and world.discovered_rooms.size()==6 and world.visible_connections().size()==5, "All six rooms and five map connections reveal through actual traversal")
	await walk_to(280)
	check(world.current_room==5, "Room 6 returns freely to Room 5 past inactive miniboss site")
	await descend(-1240)
	check(world.current_room==4, "West stairwell returns from Room 5 to Room 4")
	await walk_to(2920)
	check(world.current_room==3, "Middle corridor returns from Room 4 to Room 3")
	await descend(-340)
	check(world.current_room==2, "East stairwell returns from Room 3 to Room 2")
	await walk_to(1450)
	check(world.current_room==1 and world.discovered_rooms.size()==6, "Room 2 returns to Room 1 without forgetting discovery")
	# State/reset fixtures are deliberately separate from the traversal proof above.
	player.set_physics_process(false)
	for x in [1599.0,1601.0,1598.0,1602.0]:
		player.position = Vector2(x,542)
		world.update_room_state()
		check(world.current_room==1, "Horizontal seam deadband prevents current-room oscillation")
	player.position = Vector2(1700,542)
	world.update_room_state()
	check(world.current_room==2, "Leaving seam deadband updates current room")
	player.position = Vector2(2920,-360)
	world.update_room_state()
	for y in [-339.0,-341.0,-338.0,-342.0]:
		player.position.y = y
		world.update_room_state()
		check(world.current_room==3, "Vertical seam deadband prevents current-room oscillation")
	# A real form excursion crosses a room seam and restores its launch room.
	world.abilities.cancel_all()
	player.reset_at(Vector2(1500,542))
	world.update_room_state()
	world.abilities.handle_ranged(false,false)
	check(world.abilities.start_special(Vector2.RIGHT), "Room-boundary boomerang launches through production ability")
	await host.tick(35)
	check(world.current_room==2 and player.boomerang_form, "Temporary form updates minimap during physical cross-room excursion")
	world.pause_game()
	check(not player.boomerang_form and world.current_room==1, "Pause cancels cross-room form and immediately restores launch-room minimap")
	world.ui_canvas.get_node("Pause").resume()
	await host.tick(3)
	check(world.current_room==1 and player.position.distance_to(Vector2(1500,542))<1, "Form cancellation restores launch room and body together")
	# No reposition, manual return, pause or reset occurs between launch and finish.
	await test_natural_form_return(Vector2(1500,542),Vector2.RIGHT,1,2)
	await test_natural_form_return(Vector2(1700,542),Vector2.LEFT,2,1)
	await test_natural_form_return(Vector2(2920,-250),Vector2.UP,2,3,true)
	await test_walked_seam_camera(1)
	await test_walked_seam_camera(2)
	for pause_cancel in [false,true]:
		await test_seam_form_return(1500,1,pause_cancel)
		await test_seam_form_return(1700,2,pause_cancel)
		await test_seam_form_return(1590,1,pause_cancel)
		await test_seam_form_return(1610,2,pause_cancel)
		for from_upper in [false,true]:
			await test_vertical_seam_return(-340,2,3,pause_cancel,from_upper)
			await test_vertical_seam_return(-1240,4,5,pause_cancel,from_upper)
	world.discovered_rooms.assign([1,2,3,4,5,6])
	for room in world.rooms:
		for mode in ["charge","dash","form","safety"]:
			world.abilities.cancel_all()
			player.reset_at(Vector2(room.cell.x*1600+800,room.floor-18))
			world.update_room_state()
			world.abilities.handle_ranged(false,false)
			if mode=="charge":
				world.abilities.start_special(Vector2.ZERO)
			elif mode=="dash":
				player.request_dash(Vector2.RIGHT)
			elif mode=="form":
				world.abilities.start_special(Vector2.RIGHT)
			if mode=="safety":
				player.position.y = 900
				world._physics_process(1.0/120.0)
			else:
				world.respawn()
			check(player.position==world.START and world.current_room==1 and world.discovered_rooms.size()==6, "Room %d %s respawn synchronizes body/current room and retains discovery" % [room.id,mode])
			check(not player.boomerang_form and not player.is_dashing and not world.abilities.charging and world.camera.limit_left==0 and world.camera.limit_bottom==648, "Reset cancels transient state before applying safe camera/spawn")
	world.reset_dummy()
	check(world.discovered_rooms.size()==6, "Target-only reset retains discovered map")
	world.reset_room()
	check(world.discovered_rooms==[1] and world.current_room==1, "Full training reset begins a fresh exploration map")
	world.queue_free()
	await host.tick(2)
	completed = true
