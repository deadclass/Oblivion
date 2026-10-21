extends RefCounted

var completed: bool = false

func run(host) -> void:
	var world = load("res://main.tscn").instantiate()
	host.root.add_child(world)
	world.set_physics_process(false)
	world.player.test_control = true
	var controls = world.controls
	host.check(controls.has_method("set_capture_family"), "Capture family can be pinned independently of live input")
	if controls.has_method("set_capture_family"):
		controls.use_controller(1, "Sony DualSense")
		controls.set_capture_family("keyboard")
		var motion := InputEventJoypadMotion.new()
		motion.device = 1
		motion.axis = JOY_AXIS_LEFT_X
		motion.axis_value = 0.8
		controls._input(motion)
		host.check(controls.family == "keyboard" and "Space" in world.hud.text, "Keyboard capture explicitly replaces the previous PlayStation family")
		controls.set_capture_family("gamepad")
		controls.use_controller(1, "Sony DualSense")
		controls.on_connection_changed(controls.active_device, false)
		host.check(controls.family == "gamepad" and "Xbox / Steam" in world.hud.text and "RT" in world.hud.text, "Xbox capture survives live family selection and connection changes")
		controls.set_capture_family("playstation")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_J
		key.pressed = true
		controls._input(key)
		host.check(controls.family == "playstation" and "Cross" in world.hud.text, "PlayStation capture survives incidental keyboard input")
		controls.set_capture_family("")
		controls._input(key)
		host.check(controls.family == "keyboard", "Ordinary keyboard hot-swap resumes outside capture mode")
		controls.use_controller(0, "Xbox Controller")
		host.check(controls.family == "gamepad", "Ordinary controller selection remains enabled outside capture mode")
		controls.use_controller(1, "Sony DualSense")
		host.check(controls.family == "playstation", "Ordinary PlayStation selection remains enabled outside capture mode")
	host.paused = false
	world.queue_free()
	await host.tick(2)
	completed = true
