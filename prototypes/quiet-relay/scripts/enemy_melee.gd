extends Node2D

signal struck(target: Node)

enum Phase { IDLE, WINDUP, ACTIVE, RECOVERY }
@export var damage: int = 1
@export var reach: float = 60.0
@export var vertical_range: float = 38.0
@export var windup_duration: float = 0.30
@export var swing_duration: float = 0.14
@export var recovery_duration: float = 0.65
var phase: Phase = Phase.IDLE
var windup_time: float = 0.0
var active_time: float = 0.0
var recovery_time: float = 0.0
var swing_facing: float = 1.0
var attack_count: int = 0
var hit_count: int = 0
var hit_targets: Dictionary = {}

func is_committed() -> bool:
	return phase == Phase.WINDUP or phase == Phase.ACTIVE

func is_ready() -> bool:
	return phase == Phase.IDLE

func has_line_of_sight(target: Node2D) -> bool:
	var origin := global_position+Vector2(0,-8)
	var destination := target.global_position+Vector2(0,-8)
	if origin.distance_squared_to(destination) < 1.0:
		return true
	var query := PhysicsRayQueryParameters2D.create(origin,destination,1)
	query.collide_with_areas = false
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func try_attack() -> bool:
	var actor := get_parent()
	if phase != Phase.IDLE or not actor.ai_enabled or not actor.alerted or actor.health <= 0:
		return false
	if not is_instance_valid(actor.world) or not is_instance_valid(actor.world.player):
		return false
	var target: Node2D = actor.world.player
	var separation := target.global_position-global_position
	if absf(separation.x) > reach or absf(separation.y) > vertical_range or not has_line_of_sight(target):
		return false
	swing_facing = signf(separation.x) if absf(separation.x) > 1.0 else actor.facing
	actor.facing = swing_facing
	phase = Phase.WINDUP
	windup_time = windup_duration
	active_time = 0.0
	recovery_time = 0.0
	hit_targets.clear()
	attack_count += 1
	queue_redraw()
	return true

func cancel() -> void:
	phase = Phase.IDLE
	windup_time = 0.0
	active_time = 0.0
	recovery_time = 0.0
	hit_targets.clear()
	queue_redraw()

func reset() -> void:
	cancel()
	attack_count = 0
	hit_count = 0

func _physics_process(delta: float) -> void:
	var actor := get_parent()
	if not actor.ai_enabled or actor.health <= 0 or not is_instance_valid(actor.world):
		cancel()
		return
	match phase:
		Phase.WINDUP:
			windup_time = maxf(0.0,windup_time-delta)
			if windup_time <= 0.0:
				phase = Phase.ACTIVE
				active_time = swing_duration
		Phase.ACTIVE:
			_query_player_hits()
			# Damage callbacks can respawn the player and cancel this attack.
			# Preserve that cancellation instead of entering recovery afterward.
			if phase != Phase.ACTIVE:
				queue_redraw()
				return
			active_time = maxf(0.0,active_time-delta)
			if active_time <= 0.0:
				phase = Phase.RECOVERY
				recovery_time = recovery_duration
		Phase.RECOVERY:
			recovery_time = maxf(0.0,recovery_time-delta)
			if recovery_time <= 0.0:
				phase = Phase.IDLE
	queue_redraw()

func _query_player_hits() -> void:
	var actor := get_parent()
	var box := RectangleShape2D.new()
	box.size = Vector2(reach,44)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = box
	query.transform = Transform2D(0,global_position+Vector2(swing_facing*reach/2.0,-5))
	query.collision_mask = 8
	query.collide_with_areas = false
	query.collide_with_bodies = true
	for result in get_world_2d().direct_space_state.intersect_shape(query):
		var target: Node2D = result.collider
		var separation := target.global_position-global_position
		var id := target.get_instance_id()
		if hit_targets.has(id) or target != actor.world.player:
			continue
		if separation.x*swing_facing < -1.0 or absf(separation.x) > reach or absf(separation.y) > vertical_range:
			continue
		if not has_line_of_sight(target):
			continue
		# An invulnerable target also consumes this swing's attempt; it cannot
		# take a delayed second hit when invulnerability expires mid-swing.
		hit_targets[id] = true
		if actor.world.has_method("receive_enemy_hit") and actor.world.receive_enemy_hit(damage,global_position):
			hit_count += 1
			struck.emit(target)

func _draw() -> void:
	var actor := get_parent()
	if actor.health <= 0:
		return
	var direction: float = swing_facing if is_committed() else actor.facing
	var angle := 0.0 if direction > 0 else PI
	match phase:
		Phase.WINDUP:
			var progress := 1.0-windup_time/maxf(0.01,windup_duration)
			var orange := Color("ffab69")
			draw_line(Vector2(direction*9,-3),Vector2(direction*27,-28),orange,4)
			draw_arc(Vector2(0,-5),reach,angle-0.55,angle+0.55,18,Color(1.0,0.56,0.25,0.30+progress*0.55),2.0+progress)
			draw_circle(Vector2(direction*27,-28),3.0+progress*3.0,orange)
		Phase.ACTIVE:
			draw_arc(Vector2(0,-5),reach,angle-0.8,angle+0.8,20,Color("ffcc95"),4)
			draw_line(Vector2(direction*9,-3),Vector2(direction*55,-9),Color("ffe0ac"),5)
		_:
			draw_line(Vector2(direction*9,1),Vector2(direction*18,16),Color("c47a50"),4)
