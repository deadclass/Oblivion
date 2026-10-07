extends Node2D

signal struck(target: Node)

@export var damage: int = 1
@export var reach: float = 66.0
@export var swing_duration: float = 0.14
@export var swing_cooldown: float = 0.30
var active_time: float = 0.0
var cooldown: float = 0.0
var swing_facing: float = 1.0
var hit_targets: Dictionary = {}

func try_attack() -> bool:
	if cooldown > 0 or get_parent().carrying:
		return false
	active_time = swing_duration
	cooldown = swing_cooldown
	swing_facing = get_parent().facing
	hit_targets.clear()
	return true

func cancel() -> void:
	active_time = 0.0
	cooldown = 0.0
	hit_targets.clear()
	queue_redraw()

func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0,cooldown-delta)
	if active_time > 0:
		var box := RectangleShape2D.new()
		box.size = Vector2(reach,40)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = box
		query.transform = Transform2D(0,global_position+Vector2(swing_facing*(16+reach/2),-5))
		query.collision_mask = 4
		query.collide_with_areas = true
		query.collide_with_bodies = false
		for result in get_world_2d().direct_space_state.intersect_shape(query):
			var target: Node = result.collider
			var id := target.get_instance_id()
			if not hit_targets.has(id) and target.has_method("receive_hit"):
				var ray := PhysicsRayQueryParameters2D.create(global_position+Vector2(0,-5),target.global_position+Vector2(0,-5),1)
				if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
					continue
				hit_targets[id] = true
				if target.receive_hit(damage):
					struck.emit(target)
		active_time = maxf(0.0,active_time-delta)
	queue_redraw()

func _draw() -> void:
	var facing: float = get_parent().facing
	if active_time > 0:
		facing = swing_facing
		var angle := 0.0 if facing > 0 else PI
		draw_arc(Vector2.ZERO,reach,angle-0.8,angle+0.8,18,Color("ffe0a2"),3)
		draw_line(Vector2(facing*9,-3),Vector2(facing*52,-10),Color("ffe0a2"),5)
	else:
		draw_line(Vector2(facing*9,1),Vector2(facing*18,15),Color("c4a77d"),4)
