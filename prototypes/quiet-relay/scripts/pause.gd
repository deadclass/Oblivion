extends Label

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().paused = false
		get_viewport().set_input_as_handled()
		queue_free()
