extends Node

const GAME_ACTIONS := ["left", "right", "up", "down", "jump", "jump_alt", "attack", "special", "ranged", "swap_weapon", "target", "dash", "dodge", "heavy_attack", "block", "smash_left", "smash_right", "smash_up", "smash_down"]
var world: Node2D
var family: String = "keyboard"
var active_device: int = -1
var _capture_family: String = ""
var resume_guard: int = 0
var _ranged_sources: Dictionary = {}
var _ranged_reconnect_neutral: Dictionary = {}
var _target_sources: Dictionary = {}
var _target_reconnect_neutral: Dictionary = {}

static func setup() -> void:
	var keys := {"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN], "jump": [KEY_SPACE], "jump_alt": [], "attack": [KEY_J], "special": [], "ranged": [KEY_U, KEY_E], "swap_weapon": [KEY_F], "target": [KEY_TAB], "dash": [KEY_SHIFT], "dodge": [KEY_Q], "heavy_attack": [KEY_K], "block": [KEY_L], "restart": [KEY_R], "reset_dummy": [KEY_T], "reset_room": [KEY_BACKSPACE], "pause": [KEY_ESCAPE], "menu_resume": [], "menu_checkpoint": [], "menu_encounter": [], "menu_room": [], "smash_left": [], "smash_right": [], "smash_up": [], "smash_down": []}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for code in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mouse)
	var buttons := {"left": [JOY_BUTTON_DPAD_LEFT], "right": [JOY_BUTTON_DPAD_RIGHT], "up": [JOY_BUTTON_DPAD_UP], "down": [JOY_BUTTON_DPAD_DOWN], "jump": [JOY_BUTTON_A], "attack": [JOY_BUTTON_X], "dodge": [JOY_BUTTON_B], "swap_weapon": [JOY_BUTTON_Y], "block": [JOY_BUTTON_LEFT_SHOULDER], "dash": [JOY_BUTTON_RIGHT_SHOULDER], "pause": [JOY_BUTTON_START], "menu_resume": [JOY_BUTTON_A], "menu_checkpoint": [JOY_BUTTON_Y], "menu_encounter": [JOY_BUTTON_X], "menu_room": [JOY_BUTTON_B]}
	for action in buttons:
		for code in buttons[action]:
			var event := InputEventJoypadButton.new()
			event.device = -1
			event.button_index = code
			InputMap.action_add_event(action, event)
	var axes := {"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0], "up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0], "smash_left": [JOY_AXIS_RIGHT_X, -1.0], "smash_right": [JOY_AXIS_RIGHT_X, 1.0], "smash_up": [JOY_AXIS_RIGHT_Y, -1.0], "smash_down": [JOY_AXIS_RIGHT_Y, 1.0]}
	for action in axes:
		InputMap.action_set_deadzone(action, 0.65 if action.begins_with("smash_") else 0.20)
		var event := InputEventJoypadMotion.new()
		event.device = -1
		event.axis = axes[action][0]
		event.axis_value = axes[action][1]
		InputMap.action_add_event(action, event)
	for action in ["ranged", "target"]:
		InputMap.action_set_deadzone(action, 0.25)
		var event := InputEventJoypadMotion.new()
		event.device = -1
		event.axis = JOY_AXIS_TRIGGER_RIGHT if action == "ranged" else JOY_AXIS_TRIGGER_LEFT
		event.axis_value = 1.0
		InputMap.action_add_event(action, event)

static func family_for_name(controller_name: String) -> String:
	var name_lower := controller_name.to_lower()
	for term in ["playstation", "dualshock", "dualsense", "ps4", "ps5", "sony"]:
		if term in name_lower:
			return "playstation"
	return "gamepad"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.ignore_joypad_on_unfocused_application = true
	Input.joy_connection_changed.connect(on_connection_changed)

func _input(event: InputEvent) -> void:
	if not _capture_family.is_empty():
		return
	# Releasing logical actions on pause does not release the physical trigger.
	# Keep actual event state so trigger jitter cannot rearm a canceled shot.
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_TRIGGER_LEFT:
		var source: String = "pad:%d" % event.device
		if event.axis_value > 0.25:
			_target_sources[source] = true
			if _target_reconnect_neutral.has(event.device):
				world.cancel_target_gesture()
		else:
			_target_sources.erase(source)
			_target_reconnect_neutral.erase(event.device)
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_TRIGGER_RIGHT:
		var source: String = "pad:%d" % event.device
		if event.axis_value > 0.25:
			_ranged_sources[source] = true
			if _ranged_reconnect_neutral.has(event.device) and is_instance_valid(world.abilities):
				world.abilities.ranged_requires_release = true
		else:
			_ranged_sources.erase(source)
			_ranged_reconnect_neutral.erase(event.device)
	elif event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code == KEY_TAB:
			if event.pressed:
				_target_sources["keyboard"] = true
			else:
				_target_sources.erase("keyboard")
		if code == KEY_U or code == KEY_E:
			var source: String = "key:%d" % code
			if event.pressed:
				_ranged_sources[source] = true
			else:
				_ranged_sources.erase(source)
	if event is InputEventJoypadButton and event.pressed:
		use_controller(event.device, Input.get_joy_name(event.device))
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.25:
		use_controller(event.device, Input.get_joy_name(event.device))
	elif (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
		family = "keyboard"
		active_device = -1
		world.update_control_hud()

func use_controller(device: int, controller_name: String) -> void:
	if not _capture_family.is_empty():
		return
	family = family_for_name(controller_name)
	active_device = device
	world.update_control_hud()

func set_capture_family(value: String) -> void:
	# Render fixtures pin prompts through awaited draws; live hot-swap is unchanged.
	_capture_family = value
	if not value.is_empty():
		family = value
		active_device = -1
		world.update_control_hud()

func direction() -> Vector2:
	return Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down"))

func ranged_is_physically_held() -> bool:
	return not _ranged_sources.is_empty()

func target_is_physically_held() -> bool:
	return not _target_sources.is_empty()

func aim_direction() -> Vector2:
	# Both sticks can point while holding aim. Right stick takes priority and
	# becomes analog aim rather than issuing directional heavy attacks.
	var right_stick := Vector2(Input.get_action_raw_strength("smash_right") - Input.get_action_raw_strength("smash_left"), Input.get_action_raw_strength("smash_down") - Input.get_action_raw_strength("smash_up"))
	var left_stick := Vector2(Input.get_action_raw_strength("right") - Input.get_action_raw_strength("left"), Input.get_action_raw_strength("down") - Input.get_action_raw_strength("up"))
	return right_stick if right_stick.length() > 0.20 else left_stick

func heavy_direction() -> Vector2:
	if Input.is_action_pressed("target"):
		return Vector2.ZERO
	if Input.is_action_just_pressed("heavy_attack"):
		var aim := direction()
		return aim if aim.length() > 0.20 else Vector2(world.player.facing, 0)
	for action in ["smash_left", "smash_right", "smash_up", "smash_down"]:
		if Input.is_action_just_pressed(action):
			return Vector2(Input.get_action_raw_strength("smash_right") - Input.get_action_raw_strength("smash_left"), Input.get_action_raw_strength("smash_down") - Input.get_action_raw_strength("smash_up"))
	return Vector2.ZERO

func button(action: String) -> String:
	if family == "keyboard":
		return {"jump": "Space", "attack": "J / Click", "ranged": "U / E", "swap_weapon": "F", "target": "Tab", "dash": "Shift", "dodge": "Q", "heavy_attack": "K", "block": "L", "pause": "Esc", "menu_resume": "Esc", "menu_checkpoint": "R", "menu_encounter": "T", "menu_room": "Backspace"}.get(action, action)
	if family == "playstation":
		return {"jump": "Cross", "attack": "Square", "ranged": "R2", "swap_weapon": "Triangle", "target": "L2", "dash": "R1", "dodge": "Circle", "heavy_attack": "Right stick", "block": "L1", "pause": "Options", "menu_resume": "Cross", "menu_checkpoint": "Triangle", "menu_encounter": "Square", "menu_room": "Circle"}.get(action, action)
	return {"jump": "A", "attack": "X", "ranged": "RT", "swap_weapon": "Y", "target": "LT", "dash": "RB", "dodge": "B", "heavy_attack": "Right stick", "block": "LB", "pause": "Start", "menu_resume": "A", "menu_checkpoint": "Y", "menu_encounter": "X", "menu_room": "B"}.get(action, action)

func hud_text() -> String:
	if family == "keyboard":
		return "OBLIVION / MOVEMENT LAB\nA D / arrows move | Space jump x2 | Q dodge | L block | Shift dash (+ J = sword dash)\nJ / Click sword | U / E ranged | F swap | Tap Tab: target / Hold + direction: aim\nK heavy | Down + jump: drop | T targets | R player | Backspace all | Esc pause"
	return "OBLIVION / MOVEMENT LAB / %s\nLeft stick move | %s jump x2 | %s dodge | %s block\n%s sword | %s dash (+ %s) | %s ranged | %s weapon swap\nTap %s: target / Hold: aim with right stick | Right stick heavy | %s pause" % ["PlayStation" if family == "playstation" else "Xbox / Steam", button("jump"), button("dodge"), button("block"), button("attack"), button("dash"), button("attack"), button("ranged"), button("swap_weapon"), button("target"), button("pause")]

func release_gameplay() -> void:
	if is_instance_valid(world.abilities):
		world.abilities.cancel_charge()
		world.abilities.cancel_sword_dash()
		world.abilities.cancel_boomerang()
	world.cancel_target_gesture()
	for action in GAME_ACTIONS:
		Input.action_release(action)
	world.cancel_pending_actions()
	if is_instance_valid(world.player):
		world.player.cancel_transients()
		world.player.jump_buffer = 0.0
		world.player.velocity.x = 0.0
		world.player.blocking = false
	resume_guard = 2

func advance_input_guard() -> void:
	resume_guard = maxi(0, resume_guard - 1)

func gameplay_ready() -> bool:
	return resume_guard == 0

func on_connection_changed(device: int, connected: bool) -> void:
	if not _capture_family.is_empty():
		return
	if not connected:
		if _target_sources.has("pad:%d" % device):
			_target_reconnect_neutral[device] = true
		_target_sources.erase("pad:%d" % device)
		if _ranged_sources.has("pad:%d" % device):
			_ranged_reconnect_neutral[device] = true
		_ranged_sources.erase("pad:%d" % device)
	if connected or device != active_device:
		return
	release_gameplay()
	for action in ["pause", "menu_resume", "menu_checkpoint", "menu_encounter", "menu_room"]:
		Input.action_release(action)
	family = "keyboard"
	active_device = -1
	world.update_control_hud()
	world.pause_game("Controller disconnected")
