extends Node2D

const Controls = preload("res://scripts/controls.gd")
const Player = preload("res://scripts/player.gd")
const TrainingDummy = preload("res://scripts/training_dummy.gd")
const Abilities = preload("res://scripts/abilities.gd")
const AimController = preload("res://scripts/aim_controller.gd")
const StatusDisplay = preload("res://scripts/status_display.gd")
const RoomLayout = preload("res://scripts/room_layout.gd")
const Minimap = preload("res://scripts/minimap.gd")
const START := Vector2(460, 542)
const DUMMY_START := Vector2(1100, 538)
var arena_width: float = 3200.0
var ground_y: float = 560.0
var platform_rects: Array[Rect2] = [Rect2(320,432,230,18), Rect2(690,330,220,18), Rect2(1060,432,230,18)]
var solid_rects: Array[Rect2] = []
var rooms: Array = RoomLayout.definitions()
var connections: Array = RoomLayout.LINKS
var current_room: int = 1
var discovered_rooms: Array[int] = [1]
var player
var dummy
var targets: Array = []
var target_index: int = -1
const TARGET_HOLD_TIME: float = 0.18
var _target_down: bool = false
var _target_hold_elapsed: float = 0.0
var _target_aim_consumed: bool = false
var _target_requires_neutral: bool = false
const CHORD_WINDOW: float = 0.08
var _last_attack_press: float = -1000.0
var _last_dash_press: float = -1000.0
var _pending_dash: bool = false
var _pending_upgrade: bool = false
var _pending_direction := Vector2.ZERO
var _pending_deadline: float = 0.0
var abilities
var aim
var controls
var camera: Camera2D
var hud: Label
var ui_canvas: CanvasLayer
var feedback: String = "Free practice. Move, jump, and try directional abilities on the dummy."
var feedback_time: float = 0.0
var time: float = 0.0
var respawn_count: int = 0

func _ready() -> void:
	Controls.setup()
	controls = Controls.new()
	controls.world = self
	add_child(controls)
	build_rooms()
	for rect in solid_rects:
		make_surface(rect, false)
	for rect in platform_rects:
		make_surface(rect, true)
	player = Player.new()
	player.position = START
	add_child(player)
	dummy = TrainingDummy.new()
	dummy.position = DUMMY_START
	dummy.spawn_position = DUMMY_START
	add_child(dummy)
	dummy.target_name = "Target D"
	var left_target = TrainingDummy.new()
	left_target.position = Vector2(435,410)
	left_target.target_name = "Target A"
	add_child(left_target)
	var upper_target = TrainingDummy.new()
	upper_target.position = Vector2(800,308)
	upper_target.target_name = "Target B"
	add_child(upper_target)
	var right_target = TrainingDummy.new()
	right_target.position = Vector2(1175,410)
	right_target.target_name = "Target C"
	add_child(right_target)
	targets.assign([left_target, upper_target, right_target, dummy])
	abilities = Abilities.new()
	abilities.world = self
	abilities.player = player
	add_child(abilities)
	aim = AimController.new()
	aim.world = self
	aim.player = player
	add_child(aim)
	camera = Camera2D.new()
	camera.position = Vector2(0, -90)
	camera.limit_left = 0
	camera.limit_right = int(arena_width)
	camera.limit_top = -2320
	camera.limit_bottom = 648
	camera.position_smoothing_enabled = false
	player.add_child(camera)
	ui_canvas = CanvasLayer.new()
	add_child(ui_canvas)
	hud = Label.new()
	hud.position = Vector2(28, 18)
	hud.add_theme_font_size_override("font_size", 16)
	var control_backdrop := ColorRect.new()
	control_backdrop.position = Vector2(-6,-4)
	control_backdrop.size = Vector2(900,102)
	control_backdrop.color = Color(0.025,0.044,0.063,0.96)
	control_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control_backdrop.show_behind_parent = true
	hud.add_child(control_backdrop)
	ui_canvas.add_child(hud)
	update_control_hud()
	var status := StatusDisplay.new()
	status.world = self
	ui_canvas.add_child(status)
	var minimap := Minimap.new()
	minimap.world = self
	ui_canvas.add_child(minimap)
	update_room_camera()
	if "--capture" in OS.get_cmdline_user_args():
		capture_frames()
	elif "--capture-rooms" in OS.get_cmdline_user_args():
		capture_rooms()

func make_surface(rect: Rect2, one_way: bool) -> StaticBody2D:
	var surface := StaticBody2D.new()
	surface.position = rect.get_center()
	surface.collision_layer = 2 if one_way else 1
	surface.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.one_way_collision = one_way
	shape.one_way_collision_margin = 4
	surface.add_child(shape)
	add_child(surface)
	return surface

func update_control_hud() -> void:
	if is_instance_valid(hud):
		hud.text = controls.hud_text()
	var overlay := ui_canvas.get_node_or_null("Pause") if is_instance_valid(ui_canvas) else null
	if is_instance_valid(overlay):
		overlay.refresh_text()
	queue_redraw()

func _physics_process(delta: float) -> void:
	time += delta
	feedback_time = maxf(0, feedback_time - delta)
	controls.advance_input_guard()
	if controls.gameplay_ready():
		if Input.is_action_just_pressed("restart"):
			respawn()
		elif Input.is_action_just_pressed("reset_room"):
			reset_room()
		elif Input.is_action_just_pressed("reset_dummy"):
			reset_dummy()
		else:
			update_target_input(delta)
			process_combat_input()
	if not abilities.boomerang_active() and (player.position.y > 810 or player.position.y < -2350 or player.position.x < -80 or player.position.x > arena_width + 80):
		respawn_count += 1
		respawn()
		set_feedback("Returned to practice. No fall damage or lives.")
	update_room_state()
	queue_redraw()

func build_rooms() -> void:
	solid_rects.assign([
		Rect2(0,560,3200,100), Rect2(-24,-2400,24,3060), Rect2(3200,-2400,24,3060),
		Rect2(0,-340,2720,40), Rect2(480,-1240,2720,40),
	])
	# The landings are one-way so both ascent and deliberate down+jump work.
	platform_rects.append_array(RoomLayout.stairs(2720,560))
	platform_rects.append(Rect2(2720,-340,480,18))
	platform_rects.append_array(RoomLayout.stairs(80,-340))
	platform_rects.append(Rect2(0,-1240,480,18))
	platform_rects.append_array([
		Rect2(1840,440,340,18), Rect2(2320,320,240,18),
		Rect2(2000,-470,280,18), Rect2(2420,-570,220,18),
		Rect2(720,-460,400,18), Rect2(1120,-600,240,18),
		Rect2(620,-1360,300,18), Rect2(1020,-1460,240,18),
		Rect2(1900,-1360,240,18), Rect2(2420,-1420,400,18),
	])

func room_at(point: Vector2) -> int:
	var east := point.x >= 1600.0
	if point.y < -1240.0:
		return 6 if east else 5
	if point.y < -340.0:
		return 3 if east else 4
	return 2 if east else 1

func update_room_state() -> void:
	var next := room_at(player.position)
	if next != current_room:
		# A small seam deadband prevents alternating cells while standing at an exit.
		var old: Dictionary = rooms[current_room-1]
		var candidate: Dictionary = rooms[next-1]
		if old.cell.x != candidate.cell.x and absf(player.position.x-1600.0) < 18.0:
			update_room_camera()
			return
		if old.cell.y != candidate.cell.y:
			var seam: float = maxf(old.floor, candidate.floor) - 900.0
			if absf(player.position.y-seam) < 8.0:
				update_room_camera()
				return
		current_room = next
		if not current_room in discovered_rooms:
			discovered_rooms.append(current_room)
		aim.invalidate_bomb_cache()
	update_room_camera()

func restore_form_room(launch_room: int) -> void:
	# Restoration is not movement across a seam. Keep the saved logical origin,
	# even when its physical launch point lies inside the ordinary deadband.
	current_room = launch_room
	aim.invalidate_bomb_cache()
	update_room_camera()

func update_room_camera() -> void:
	var room: Dictionary = rooms[current_room-1]
	camera.limit_left = int(room.cell.x*1600)
	camera.limit_right = camera.limit_left + 1600
	# The logical room may own a body within the seam band on either side.
	# Offset past the clamp just enough to keep its full 22px width visible.
	camera.offset.x = player.position.x-clampf(player.position.x,camera.limit_left+12,camera.limit_right-12) if absf(player.position.x-1600)<30 else 0.0
	camera.limit_top = int(room.floor-1080)
	camera.limit_bottom = int(room.floor+88)

func visible_connections() -> Array:
	return connections.filter(func(link): return link.x in discovered_rooms and link.y in discovered_rooms)

func selected_target():
	clean_targets()
	return targets[target_index] if target_index >= 0 and target_index < targets.size() else null

func clean_targets() -> void:
	var selected = targets[target_index] if target_index >= 0 and target_index < targets.size() else null
	targets = targets.filter(func(target): return is_instance_valid(target) and not target.is_queued_for_deletion())
	if targets.is_empty():
		target_index = -1
	elif is_instance_valid(selected) and selected in targets:
		target_index = targets.find(selected)
	else:
		target_index = -1

func cycle_target() -> bool:
	clean_targets()
	if targets.is_empty():
		set_feedback("No practice target available.")
		return false
	target_index += 1
	if target_index >= targets.size():
		target_index = -1
	var chosen = selected_target()
	aim.invalidate_bomb_cache()
	set_feedback("Selected %s" % chosen.target_name if is_instance_valid(chosen) else "Free shots. Hold aim to point.")
	queue_redraw()
	return true

func update_target_input(delta: float) -> void:
	var down: bool = Input.is_action_pressed("target")
	if _target_requires_neutral:
		if not down and not controls.target_is_physically_held():
			_target_requires_neutral = false
		aim.update_aim(false, Vector2.ZERO)
		return
	if down:
		if not _target_down:
			_target_hold_elapsed = 0.0
			_target_aim_consumed = false
		_target_down = true
		_target_hold_elapsed += delta
		if _target_hold_elapsed >= TARGET_HOLD_TIME or Input.is_action_pressed("ranged"):
			_target_aim_consumed = true
		aim.update_aim(_target_aim_consumed, controls.aim_direction())
	else:
		if _target_down and not _target_aim_consumed:
			cycle_target()
		elif not _target_down and Input.is_action_just_pressed("target") and Input.is_action_just_released("target"):
			# A complete quick tap can arrive between two physics samples.
			cycle_target()
		_target_down = false
		_target_hold_elapsed = 0.0
		_target_aim_consumed = false
		aim.update_aim(false, Vector2.ZERO)

func cancel_target_gesture() -> void:
	_target_requires_neutral = Input.is_action_pressed("target") or controls.target_is_physically_held()
	_target_down = false
	_target_hold_elapsed = 0.0
	_target_aim_consumed = false
	if is_instance_valid(aim):
		aim.update_aim(false, Vector2.ZERO)

func cancel_pending_actions() -> void:
	_last_attack_press = -1000.0
	_last_dash_press = -1000.0
	_pending_dash = false
	_pending_upgrade = false

func process_combat_input() -> void:
	var move_direction: Vector2 = controls.direction()
	var attack_pressed := Input.is_action_just_pressed("attack")
	var dash_pressed := Input.is_action_just_pressed("dash")
	if Input.is_action_just_pressed("swap_weapon"):
		abilities.cycle_ranged()
	if abilities.boomerang_active():
		# Aim remains live for steering/release; ordinary actions stay suspended.
		return
	if Input.is_action_pressed("block") or Input.is_action_just_pressed("dodge"):
		abilities.cancel_charge()
		_pending_dash = false
		_pending_upgrade = false
		return
	if attack_pressed:
		_last_attack_press = time
	if dash_pressed:
		_last_dash_press = time
		var normal_recent: bool = time - _last_attack_press <= CHORD_WINDOW and abilities.active_time > 0.0 and not abilities.move_heavy and not abilities.move_dash
		var wants_sword: bool = attack_pressed or normal_recent
		abilities.cancel_charge()
		if player.request_dash(move_direction, normal_recent):
			if wants_sword:
				abilities.start_sword_dash()
		elif normal_recent and player.hitstop_time > 0.0:
			# Preserve a near-simultaneous chord across the sword's brief hitstop.
			_pending_dash = true
			_pending_direction = move_direction
			_pending_deadline = time + CHORD_WINDOW
	if attack_pressed and player.is_dashing and time - _last_dash_press <= CHORD_WINDOW and not abilities.move_dash:
		if not abilities.start_sword_dash() and player.hitstop_time > 0.0:
			_pending_upgrade = true
			_pending_deadline = time + CHORD_WINDOW
	if time > _pending_deadline:
		_pending_dash = false
		_pending_upgrade = false
	if _pending_dash and player.hitstop_time <= 0.0:
		_pending_dash = false
		if player.request_dash(_pending_direction, true):
			abilities.start_sword_dash()
	if _pending_upgrade and player.hitstop_time <= 0.0:
		_pending_upgrade = false
		if player.is_dashing:
			abilities.start_sword_dash()
	if player.is_dashing or dash_pressed or _pending_dash or _pending_upgrade:
		return
	var heavy: Vector2 = controls.heavy_direction()
	if heavy.length() >= 0.35:
		abilities.start_attack(heavy, true)
	elif attack_pressed:
		abilities.start_attack(move_direction)
	abilities.handle_ranged(Input.is_action_just_pressed("ranged"), Input.is_action_pressed("ranged"))

func set_feedback(message: String) -> void:
	feedback = message
	feedback_time = 2.5

func respawn() -> void:
	abilities.cancel_all()
	player.reset_at(START)
	current_room = 1
	update_room_camera()
	aim.invalidate_bomb_cache()
	controls.release_gameplay()
	set_feedback("Player reset. Dummy results retained.")

func reset_dummy() -> void:
	abilities.cancel_all()
	cancel_target_gesture()
	player.cancel_transients()
	cancel_pending_actions()
	for target in targets:
		if is_instance_valid(target):
			target.reset_dummy()
	aim.invalidate_bomb_cache()
	set_feedback("Targets reset. Try another movement or ability sequence.")

func reset_room() -> void:
	respawn()
	discovered_rooms.assign([1])
	abilities.reset_loadout()
	for target in targets:
		if is_instance_valid(target):
			target.reset_dummy()
	target_index = -1
	set_feedback("Training reset. Free practice continues.")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		pause_game()
		get_viewport().set_input_as_handled()

func pause_game(reason: String = "PAUSED") -> void:
	if get_tree().paused:
		return
	abilities.cancel_charge()
	abilities.cancel_sword_dash()
	abilities.cancel_boomerang()
	update_room_state()
	cancel_target_gesture()
	player.cancel_transients()
	cancel_pending_actions()
	get_tree().paused = true
	var overlay := Label.new()
	overlay.name = "Pause"
	overlay.position = Vector2(325, 245)
	overlay.add_theme_font_size_override("font_size", 23)
	overlay.add_theme_color_override("font_color", Color("ffe1a0"))
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_script(load("res://scripts/pause.gd"))
	overlay.world = self
	overlay.reason = reason
	var backdrop := ColorRect.new()
	backdrop.position = Vector2(-22, -15)
	backdrop.size = Vector2(535, 205)
	backdrop.color = Color(0.025, 0.044, 0.063, 0.94)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.show_behind_parent = true
	overlay.add_child(backdrop)
	ui_canvas.add_child(overlay)
	# Status processing pauses too; refresh its canceled action state once.
	for item in ui_canvas.get_children():
		if item is CanvasItem:
			item.queue_redraw()

func _draw() -> void:
	for room in rooms:
		var origin := Vector2(room.cell.x*1600,room.floor)
		for i in range(10):
			var point: Vector2 = origin+Vector2(55+i*160,-340)
			draw_rect(Rect2(point,Vector2(18,340)),room.color.darkened(0.88))
			draw_arc(point+Vector2(9,52),76,PI,TAU,20,room.color.darkened(0.77),2)
		var title_offset := Vector2(80,-270) if room.id==1 else Vector2(620,-270)
		draw_string(ThemeDB.fallback_font,origin+title_offset,"%d / %s" % [room.id,room.title],HORIZONTAL_ALIGNMENT_LEFT,-1,25,room.color)
	for rect in solid_rects:
		draw_rect(rect,Color("263b44"))
		draw_line(rect.position,Vector2(rect.end.x,rect.position.y),Color("809991"),3)
	for rect in platform_rects:
		draw_rect(rect, Color("304b56"))
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color("a5c3af"), 3)
		draw_line(rect.position+Vector2(20,10), Vector2(rect.end.x-20, rect.position.y+10), Color("1d333d"), 2)
	draw_string(ThemeDB.fallback_font, Vector2(640, 605), "FOUR TARGETS / TAP TO SELECT, HOLD TO AIM", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("92b0ac"))
	for site in [Vector2(1730,560),Vector2(1400,-340)]:
		draw_rect(Rect2(site+Vector2(-35,-120),Vector2(70,120)),Color(0.7,0.8,0.7,0.12),false,2)
		draw_string(ThemeDB.fallback_font,site+Vector2(-110,-140),"FUTURE ABILITY GATE / OPEN",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("b6c8aa"))
	draw_rect(Rect2(1170,-1240,360,18),Color("c69b86"),false,3)
	draw_string(ThemeDB.fallback_font,Vector2(1160,-1410),"MINIBOSS SITE / INACTIVE",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("d5ae94"))
	draw_string(ThemeDB.fallback_font,Vector2(1170,-1385),"Room 6 entry remains open",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("b6c8aa"))
	for site in [Vector2(2920,560),Vector2(280,-340)]:
		for step in range(9):
			var point: Vector2 = site+Vector2(0,-step*100-45)
			draw_line(point+Vector2(-12,12),point+Vector2(0,0),Color("ffe1a0"),3)
			draw_line(point,point+Vector2(12,12),Color("ffe1a0"),3)
	var chosen = selected_target()
	if is_instance_valid(chosen) and not aim.held:
		draw_arc(chosen.position + Vector2(0,-5), 38, 0, TAU, 40, Color("e8cc7e"), 2.0)


func capture_image(directory: String, filename: String) -> void:
	queue_redraw()
	player.queue_redraw()
	for target in targets:
		if is_instance_valid(target):
			target.queue_redraw()
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(directory.path_join(filename))
	if result != OK:
		push_error("Capture failed: " + filename)

func capture_pose(point: Vector2) -> void:
	player.reset_at(point)
	player.set_physics_process(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.set_physics_process(false)
	update_room_state()
	camera.force_update_scroll()

func capture_rooms() -> void:
	controls.set_capture_family("keyboard")
	var directory := "res://evidence"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			directory = argument.trim_prefix("--capture-dir=")
	await get_tree().create_timer(0.3).timeout
	set_physics_process(false)
	player.test_control = true
	await capture_kit(START)
	await capture_image(directory,"room-01-safe-start.png")
	for room in rooms.slice(1):
		await capture_kit(Vector2(room.cell.x*1600+800,room.floor-18))
		await capture_image(directory,"room-%02d-layout.png" % room.id)
	await capture_kit(Vector2(2920,42))
	await capture_image(directory,"room-east-stairwell.png")
	await capture_kit(Vector2(280,-858))
	await capture_image(directory,"room-west-stairwell.png")
	await capture_kit(Vector2(1380,-1258))
	await capture_image(directory,"room-miniboss-reservation.png")
	respawn()
	await capture_pose(START)
	await capture_image(directory,"room-respawn-complete-map.png")
	controls.set_capture_family("gamepad")
	await capture_image(directory,"room-controller-complete-map.png")
	pause_game()
	await capture_image(directory,"room-pause-complete-map.png")
	get_tree().quit()

func capture_kit(point: Vector2, weapon: int = 0, selection: int = -1) -> void:
	abilities.cancel_all()
	abilities.handle_ranged(false,false)
	await capture_pose(point)
	abilities.set_physics_process(true)
	abilities.selected_weapon = weapon
	target_index = selection
	aim.invalidate_bomb_cache()
	aim.update_aim(false, Vector2.ZERO)

func capture_frames() -> void:
	controls.set_capture_family("keyboard")
	var directory := "res://evidence"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			directory = argument.trim_prefix("--capture-dir=")
	await get_tree().create_timer(0.3).timeout
	set_physics_process(false)
	player.test_control = true
	await capture_kit(Vector2(850,542))
	print("GRAPHICAL CONTROLLER HARDWARE: ", Input.get_connected_joypads())
	set_feedback("Three platform targets and one ground target. Tap to select, hold to aim.")
	await capture_image(directory, "01-four-targets-keyboard.png")
	controls.set_capture_family("gamepad")
	await capture_image(directory, "02-controls-xbox.png")
	controls.set_capture_family("playstation")
	await capture_image(directory, "03-controls-playstation.png")
	cycle_target()
	await capture_image(directory, "04-tap-target-a.png")
	cycle_target()
	await capture_image(directory, "05-tap-target-b.png")
	await capture_pose(Vector2(850,375))
	aim.update_aim(true, (targets[2].global_position - aim.aim_origin()).rotated(0.12))
	set_feedback("Holding aim overrides Target B; stronger assistance follows the pointed direction.")
	await capture_image(directory, "06-aim-overrides-selection.png")
	player.set_physics_process(true)
	player.test_axis = -1.0
	await get_tree().create_timer(0.18).timeout
	player.test_axis = 0.0
	player.set_physics_process(false)
	aim.update_aim(true, Vector2(0.6,-0.8))
	await capture_image(directory, "07-move-while-aiming.png")
	await capture_kit(Vector2(620,250),0,1)
	abilities.fire_ranged()
	abilities.charge_time = 0.8
	abilities.set_physics_process(false)
	await capture_image(directory, "08-bow-selected-target.png")
	aim.update_aim(true, Vector2(0.65,-0.76))
	abilities.release_special()
	for shot in abilities.projectiles:
		shot.set_physics_process(false)
		shot.global_position += shot.velocity.normalized()*110
	await capture_image(directory, "09-manual-arrow-heading.png")
	await capture_kit(Vector2(620,490),1)
	player.set_physics_process(true)
	abilities.fire_ranged()
	await get_tree().create_timer(0.42).timeout
	await capture_image(directory, "10-faster-plain-boomerang.png")
	await capture_kit(Vector2(620,490),1)
	aim.update_aim(true, Vector2.RIGHT)
	player.set_physics_process(true)
	abilities.fire_ranged()
	await get_tree().create_timer(0.8).timeout
	aim.update_aim(true, Vector2.LEFT)
	await get_tree().create_timer(0.8).timeout
	aim.update_aim(true, Vector2.RIGHT)
	await get_tree().create_timer(0.2).timeout
	await capture_image(directory, "11-three-second-steered-form.png")
	aim.update_aim(false, Vector2.ZERO)
	await get_tree().create_timer(0.09).timeout
	await capture_image(directory, "12-returning-to-origin.png")
	await capture_kit(Vector2(650,542),2,0)
	set_feedback("Target A: automatic collision-checked bomb arc within half-screen range.")
	await capture_image(directory, "13-targeted-bomb-platform-a.png")
	camera.position = Vector2(0,-220)
	await capture_kit(Vector2(950,420),2,1)
	set_feedback("Target B: a ballistic path to the upper platform.")
	await capture_image(directory, "14-targeted-bomb-upper-platform.png")
	camera.position = Vector2(0,-90)
	await capture_kit(Vector2(650,542),2,3)
	aim.update_aim(true, Vector2(0.92,-0.39))
	set_feedback("Manual aim overrides Target D's automatic throw.")
	await capture_image(directory, "15-manual-bomb-override.png")
	await capture_kit(Vector2(450,542),2,2)
	set_feedback("Target C is beyond the half-screen bomb range; no throw is created.")
	abilities.fire_ranged()
	await capture_image(directory, "16-targeted-bomb-out-of-range.png")
	await capture_kit(Vector2(650,542),2,0)
	abilities.fire_ranged()
	await get_tree().create_timer(1.1).timeout
	await capture_image(directory, "17-targeted-bomb-landing.png")
	abilities.detonate_orb()
	abilities.effect_time = 0.12
	abilities.set_physics_process(false)
	await capture_image(directory, "18-targeted-bomb-burst.png")
	await capture_kit(Vector2(900,542))
	player.set_physics_process(true)
	player.request_dash(Vector2.RIGHT)
	await get_tree().create_timer(0.055).timeout
	await capture_image(directory, "19-ground-dash.png")
	await capture_kit(Vector2(1010,542))
	player.set_physics_process(true)
	player.request_dash(Vector2.RIGHT)
	abilities.start_sword_dash()
	await get_tree().create_timer(0.055).timeout
	await capture_image(directory, "20-sword-dash.png")
	await capture_kit(Vector2(900,542))
	player.set_physics_process(true)
	player.test_dodge_pressed = true
	await get_tree().create_timer(0.06).timeout
	await capture_image(directory, "21-circle-dodge.png")
	await capture_kit(Vector2(900,542))
	player.blocking = true
	await capture_image(directory, "22-l1-block.png")
	pause_game()
	await capture_image(directory, "23-controls-pause.png")
	get_tree().quit()
