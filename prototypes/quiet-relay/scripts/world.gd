extends Node2D

const Player = preload("res://scripts/player.gd")
const START := Vector2(95, 548)
const STONE_START := Vector2(185, 556.95)
const SOCKET := Vector2(724, 353)
var player: CharacterBody2D
var stone := STONE_START
var checkpoint := START
var checkpoint_active: bool = false
var solved: bool = false
var won: bool = false
var deaths: int = 0
var time: float = 0.0
var bridge: StaticBody2D
var gate: StaticBody2D
var weight_body: CharacterBody2D
var hud: Label
var notice: Label
var platforms: Array[Rect2] = [Rect2(0,570,840,78), Rect2(960,570,192,78), Rect2(280,505,105,22), Rect2(438,438,110,22), Rect2(610,370,165,25)]

func _ready() -> void:
	bind_key("left", [KEY_A, KEY_LEFT])
	bind_key("right", [KEY_D, KEY_RIGHT])
	bind_key("jump", [KEY_SPACE, KEY_W, KEY_UP])
	bind_key("interact", [KEY_E])
	bind_key("restart", [KEY_R])
	bind_key("reset_room", [KEY_BACKSPACE])
	bind_key("pause", [KEY_ESCAPE])
	for rect in platforms:
		make_solid(rect)
	make_solid(Rect2(-30,0,30,648))
	make_solid(Rect2(1152,0,30,648))
	bridge = make_solid(Rect2(840,570,120,20))
	gate = make_solid(Rect2(995,390,18,180))
	bridge.get_child(0).disabled = true
	player = Player.new()
	player.position = START
	add_child(player)
	weight_body = CharacterBody2D.new()
	weight_body.collision_layer = 2
	weight_body.collision_mask = 1
	var weight_shape := CollisionShape2D.new()
	var weight_box := RectangleShape2D.new()
	weight_box.size = Vector2(26,26)
	weight_shape.shape = weight_box
	weight_body.add_child(weight_shape)
	add_child(weight_body)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Label.new()
	hud.position = Vector2(30,22)
	hud.add_theme_font_size_override("font_size", 18)
	canvas.add_child(hud)
	hud.text = "THE QUIET RELAY    /    chamber 01\nA D / arrows move   •   Space / W / ↑ jump (hold for height)   •   E carry / place\nR checkpoint   •   Backspace reset room   •   Esc pause"
	notice = Label.new()
	notice.position = Vector2(30,105)
	notice.add_theme_color_override("font_color", Color("e5c791"))
	notice.add_theme_font_size_override("font_size", 19)
	canvas.add_child(notice)
	if "--capture" in OS.get_cmdline_user_args():
		capture_frames()

func bind_key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action,event)

func make_solid(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	return body

func _physics_process(delta: float) -> void:
	time += delta
	if Input.is_action_just_pressed("restart"):
		respawn()
	if Input.is_action_just_pressed("reset_room"):
		reset_room()
	if Input.is_action_just_pressed("interact"):
		interact()
	if not checkpoint_active and player.position.x > 555 and player.position.x < 820 and player.position.y > 520:
		checkpoint_active = true
		checkpoint = Vector2(580,548)
	if player.position.y > 675:
		deaths += 1
		respawn()
	if solved and player.position.x > 1085:
		won = true
	if player.carrying:
		stone = player.position + Vector2(0,-34)
		weight_body.velocity = Vector2.ZERO
	elif not solved:
		weight_body.position = stone
		weight_body.velocity.y = minf(weight_body.velocity.y + 1450 * delta,800)
		weight_body.move_and_slide()
		stone = weight_body.position
		if stone.y > 675:
			stone = STONE_START
			weight_body.velocity = Vector2.ZERO
	notice.text = "Relay restored. The chamber remembers you.  •  Backspace to explore again" if won else ("Signal received. Cross the bridge to the eastern door." if solved else ("Checkpoint lit. Bring the weight to the high listening cradle." if checkpoint_active else "A quiet weight waits below. Carry it to the high listening cradle."))
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().paused = true
		var overlay := Label.new()
		overlay.name = "Pause"
		overlay.text = "PAUSED — Esc to resume"
		overlay.position = Vector2(430,270)
		overlay.add_theme_font_size_override("font_size",24)
		overlay.process_mode = Node.PROCESS_MODE_ALWAYS
		overlay.set_script(load("res://scripts/pause.gd"))
		add_child(overlay)
		get_viewport().set_input_as_handled()

func interact() -> void:
	if solved:
		return
	if player.carrying:
		if player.position.distance_to(SOCKET + Vector2(0,-5)) < 65:
			player.carrying = false
			stone = SOCKET
			solved = true
			bridge.get_child(0).set_deferred("disabled",false)
			gate.get_child(0).set_deferred("disabled",true)
		else:
			player.carrying = false
			stone = player.position
			weight_body.velocity = Vector2.ZERO
	elif player.position.distance_to(stone) < 58:
		player.carrying = true

func respawn() -> void:
	player.reset_at(checkpoint)
	if player.carrying:
		player.carrying = false
		stone = STONE_START
		weight_body.velocity = Vector2.ZERO

func reset_room() -> void:
	checkpoint_active = false
	checkpoint = START
	solved = false
	won = false
	deaths = 0
	player.carrying = false
	stone = STONE_START
	weight_body.velocity = Vector2.ZERO
	bridge.get_child(0).set_deferred("disabled",true)
	gate.get_child(0).set_deferred("disabled",false)
	respawn()

func _draw() -> void:
	# Original procedural chamber: distant ribs, dust, broken masonry and signal paths.
	for i in range(9):
		var x := 70 + i * 140
		draw_rect(Rect2(x,165,24,400), Color("101f2b"))
		draw_arc(Vector2(x+12,235),80,PI,TAU,24,Color("172c35"),2)
	for i in range(48):
		var p := Vector2(fmod(i*97.0+sin(time*0.2+i)*8,1152),160+fmod(i*71.0+time*3,380))
		draw_circle(p,1.3,Color(0.42,0.64,0.65,0.22))
	for rect in platforms:
		draw_rect(rect,Color("263b44"))
		draw_line(rect.position,rect.position+Vector2(rect.size.x,0),Color("728a83"),3)
		for x in range(int(rect.position.x)+16,int(rect.end.x),39):
			draw_line(Vector2(x,rect.position.y+8),Vector2(x+9,rect.end.y),Color("1c2e38"),1)
	draw_rect(Rect2(840,590,120,58),Color("09111d"))
	for i in range(7):
		draw_line(Vector2(846+i*17,633),Vector2(853+i*17,612),Color("577482"),2)
	if solved:
		draw_rect(Rect2(840,570,120,20),Color("947b57"))
		draw_line(Vector2(840,570),Vector2(960,570),Color("f6d48a"),3)
	else:
		draw_rect(Rect2(995,390,18,180),Color("4b666b"))
		for y in range(400,560,16):
			draw_line(Vector2(995,y),Vector2(1013,y+9),Color("a3b5a2"),2)
	draw_circle(Vector2(580,541),30,Color(0.8,0.7,0.4,0.10 if checkpoint_active else 0.025))
	draw_line(Vector2(580,570),Vector2(580,533),Color("d9c089") if checkpoint_active else Color("54656b"),4)
	draw_circle(Vector2(580,533),5,Color("f6d48a") if checkpoint_active else Color("54656b"))
	draw_arc(SOCKET+Vector2(0,-8),23,0,PI,20,Color("e2bc77") if solved else Color("6b8d93"),4)
	draw_line(SOCKET+Vector2(-25,17),SOCKET+Vector2(25,17),Color("93aaa0"),4)
	draw_circle(stone,22,Color(0.9,0.7,0.4,0.07))
	draw_colored_polygon(PackedVector2Array([stone+Vector2(0,-13),stone+Vector2(13,0),stone+Vector2(0,13),stone+Vector2(-13,0)]),Color("d2ac72"))
	draw_circle(stone,3,Color("fff0c4"))
	draw_rect(Rect2(1080,475,45,95),Color("152a33"))
	draw_arc(Vector2(1102,490),22,PI,TAU,24,Color("86a49c"),3)
	draw_line(Vector2(1102,502),Vector2(1102,550),Color("ebc78b") if solved else Color("344b55"),3)
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(145,608),"E  /  WEIGHT",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("b4bda8"))
	draw_string(font,Vector2(655,321),"LISTENING CRADLE",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("b4bda8"))
	draw_string(font,Vector2(535,608),"CHECKPOINT",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("b4bda8"))
	if player.carrying and player.position.distance_to(SOCKET) < 70 and not solved:
		draw_string(font,SOCKET+Vector2(-50,-55),"E  /  PLACE",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("ffe1a0"))

func capture_frames() -> void:
	var capture_dir := "res://evidence"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(capture_dir.path_join("chamber-start.png"))
	player.position = Vector2(724,348)
	player.carrying = true
	interact()
	player.position = Vector2(674,348)
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(capture_dir.path_join("chamber-solved.png"))
	get_tree().quit()
