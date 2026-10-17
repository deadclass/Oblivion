extends "res://scripts/world.gd"

# Room-only logic. The original controller, ability kit and form are unchanged.
const INTRO := Vector2(580, 475)
const RELAY := Vector2(900, 335)
const EXIT := Rect2(1430, 195, 125, 55)
const SLIT_TOP := 299.0
const SLIT_BOTTOM := 371.0
var introduction_lit: bool = false
var relay_lit: bool = false
var completed_room: bool = false
var gate: StaticBody2D
var previous_form_position := Vector2.ZERO
var tracked_form_id: int = 0
var room_label: Label
var capture_requested: bool = false

func _ready() -> void:
	# Give the 20px collision body and its spinning outline generous clearance.
	# The elevated opening still requires remote flight from the starting side.
	platform_rects = [Rect2(845,460,145,18), Rect2(1025,390,145,18), Rect2(1205,320,145,18), Rect2(1385,250,180,18)]
	super._ready()
	make_surface(Rect2(750,-500,28,SLIT_TOP + 500), false)
	make_surface(Rect2(750,SLIT_BOTTOM,28,500 - SLIT_BOTTOM), false)
	gate = make_surface(Rect2(750,500,28,60), false)
	# Retain a real practice dummy before the obstacle; do not use dummy hit
	# callbacks for puzzle state, so arrows, bombs and sword cannot solve it.
	for index in range(targets.size()):
		targets[index].position = Vector2(130 + index * 80, 538)
		targets[index].spawn_position = targets[index].position
	room_label = Label.new()
	room_label.position = Vector2(28, 224)
	room_label.add_theme_font_size_override("font_size", 17)
	room_label.add_theme_color_override("font_color", Color("ffe1a0"))
	var panel := ColorRect.new()
	panel.position = Vector2(-10, -8)
	panel.size = Vector2(1090, 65)
	panel.color = Color(0.025, 0.044, 0.063, 0.96)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.show_behind_parent = true
	room_label.add_child(panel)
	ui_canvas.add_child(room_label)
	refresh_room_text()
	capture_requested = "--puzzle-capture" in OS.get_cmdline_user_args()
	if capture_requested:
		capture_room()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if abilities.boomerang_active():
		var form = abilities.boomerang
		if tracked_form_id != form.get_instance_id():
			tracked_form_id = form.get_instance_id()
			previous_form_position = form.launch_origin
		# Sweep between samples, rather than relying on a narrow overlap at
		# 660px/s. Returning flight cannot accidentally arm a fresh relay.
		if not form.returning:
			if not introduction_lit and touches_switch(INTRO, previous_form_position, form.global_position):
				introduction_lit = true
				set_feedback("First light latched. Release aim to return home.")
			if introduction_lit and not relay_lit and touches_switch(RELAY, previous_form_position, form.global_position):
				relay_lit = true
				# Only remove geometry; never insert a solid into a return route.
				gate.set_collision_layer_value(1, false)
				set_feedback("Gate latched open. Return, walk through, then climb to the beacon.")
		previous_form_position = form.global_position
	else:
		tracked_form_id = 0
		if relay_lit and EXIT.has_point(player.position) and player.is_on_floor():
			completed_room = true
	refresh_room_text()

func touches_switch(point: Vector2, start: Vector2, finish: Vector2) -> bool:
	var nearest := Geometry2D.get_closest_point_to_segment(point, start, finish)
	return nearest.distance_to(point) <= 26.0 and abilities.has_line_of_sight(nearest, point)

func refresh_room_text() -> void:
	if not is_instance_valid(room_label):
		return
	if completed_room:
		room_label.text = "ROOM COMPLETE — remote reach, return home, then traverse.\nBackspace: replay room. R: safe return; progress retained."
	elif relay_lit:
		room_label.text = "3 / TRAVERSE — return home, walk under the open gate, jump up to the beacon.\nLights stay latched. Falls are safe. R retains progress; Backspace restarts."
	elif introduction_lit:
		room_label.text = "2 / REMOTE RELAY — aim up, then steer right through the glowing opening to light 2.\nFly through as Boomerang. The gate stays open after you return. No carrying or teleporting."
	else:
		room_label.text = "1 / SAFE INTRO — cycle to Boomerang, hold aim, launch, steer into the first light.\nRelease aim or wait 3 seconds: you retrace your route and reform at the launch point."

func reset_room() -> void:
	# The inherited reset cancels flight and moves the body to START before
	# closing the gate; resetting can never seal the character inside it.
	super.reset_room()
	introduction_lit = false
	relay_lit = false
	completed_room = false
	tracked_form_id = 0
	gate.set_collision_layer_value(1, true)
	refresh_room_text()

func _draw() -> void:
	super._draw()
	draw_rect(Rect2(750,-500,28,SLIT_TOP + 500), Color("39545d"))
	draw_rect(Rect2(750,SLIT_BOTTOM,28,500 - SLIT_BOTTOM), Color("39545d"))
	draw_line(Vector2(740,SLIT_TOP), Vector2(788,SLIT_TOP), Color("a7ebdf"), 3)
	draw_line(Vector2(740,SLIT_BOTTOM), Vector2(788,SLIT_BOTTOM), Color("a7ebdf"), 3)
	if not relay_lit:
		draw_rect(Rect2(750,500,28,60), Color("ce9868"))
	for index in range(2):
		var point: Vector2 = INTRO if index == 0 else RELAY
		var lit: bool = introduction_lit if index == 0 else relay_lit
		draw_circle(point, 26, Color("254b51"))
		draw_arc(point, 22, 0, TAU, 32, Color("a7ebdf") if lit else Color("e7b477"), 4)
		draw_string(ThemeDB.fallback_font, point + Vector2(-6,6), str(index+1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_circle(Vector2(1490,220), 22, Color("a7ebdf") if completed_room else Color("cbb77b"))
	draw_string(ThemeDB.fallback_font, Vector2(1350,190), "RETURN, THEN CLIMB", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("a7ebdf"))

func capture_room() -> void:
	await get_tree().create_timer(0.4).timeout
	camera.zoom = Vector2(0.68,0.68)
	camera.position = Vector2(340,-170)
	await get_tree().process_frame
	await get_tree().process_frame
	await capture_image("res://evidence", "puzzle-room.png")
	get_tree().quit()

