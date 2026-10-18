extends Label

var world: Node2D
var reason: String = "PAUSED"
var room_hold: float = 0.0
var room_armed: bool = false

func _ready() -> void:
	room_armed = not Input.is_action_pressed("menu_room")
	refresh_text()

func refresh_text() -> void:
	var controls = world.controls
	text = "%s\n%s / %s resume\n%s reset player\n%s reset targets\nHold %s 1 sec: reset training" % [reason, controls.button("pause"), controls.button("menu_resume"), controls.button("menu_checkpoint"), controls.button("menu_encounter"), controls.button("menu_room")]
	if room_hold > 0.0:
		text += " (%.1f)" % maxf(0.0, 1.0 - room_hold)

func _process(delta: float) -> void:
	if not Input.is_action_pressed("menu_room"):
		room_hold = 0.0
		room_armed = true
	elif room_armed:
		room_hold += delta
		if room_hold >= 1.0:
			world.reset_room()
			resume()
			return
	refresh_text()

func resume() -> void:
	# Consume combat/jump/interaction presses used by the menu.
	world.controls.release_gameplay()
	get_tree().paused = false
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("menu_resume"):
		get_viewport().set_input_as_handled()
		resume()
	elif event.is_action_pressed("restart") or event.is_action_pressed("menu_checkpoint"):
		get_viewport().set_input_as_handled()
		world.respawn()
		resume()
	elif event.is_action_pressed("reset_dummy") or event.is_action_pressed("menu_encounter"):
		get_viewport().set_input_as_handled()
		world.reset_dummy()
		resume()
	elif event.is_action_pressed("reset_room"):
		get_viewport().set_input_as_handled()
		world.reset_room()
		resume()

