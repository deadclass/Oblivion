extends Node2D

var world: Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(world):
		return
	for i in range(world.max_hearts):
		var center := Vector2(42+i*25,144)
		var heart := PackedVector2Array([center+Vector2(-10,-3),center+Vector2(-7,-8),center+Vector2(-3,-8),center,center+Vector2(3,-8),center+Vector2(7,-8),center+Vector2(10,-3),center+Vector2(8,2),center+Vector2(0,10),center+Vector2(-8,2),center+Vector2(-10,-3)])
		draw_colored_polygon(heart,Color("dc817a") if i<world.health else Color("263d48"))
		draw_polyline(heart,Color("ffc2a3") if i<world.health else Color("617783"),1.0)
	draw_string(ThemeDB.fallback_font,Vector2(164,150),"%d/%d" % [world.health,world.max_hearts],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("dfc5a0"))
	var status: String = world.feedback if world.feedback_time>0 else "Guard %d/5 | %s | Falls 180+ px: -1 heart" % [world.dummy.health,"Cradle unlocked" if world.enemy_defeated or world.solved else "Cradle sealed"]
	draw_string(ThemeDB.fallback_font,Vector2(226,150),status,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("f0c88e"))
