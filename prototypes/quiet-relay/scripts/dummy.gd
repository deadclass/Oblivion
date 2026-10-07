extends CharacterBody2D

# The body follows world collision; the separate target area keeps melee queries
# compatible and lets the player pass through this harmless training target.
class TargetArea extends Area2D:
	func receive_hit(amount: int) -> bool:
		return get_parent().receive_hit(amount)

@export var max_health: int = 5
@export var run_speed: float = 247.0
@export var acceleration: float = 1800.0
@export var air_acceleration: float = 1400.0
@export var gravity: float = 1450.0
@export var fall_gravity: float = 1850.0
@export var jump_speed: float = 550.0
@export var terminal_speed: float = 800.0
@export var decision_interval: float = 0.12
@export var jump_cooldown: float = 0.28
@export var floor_hop_interval: float = 1.25
@export var safe_min_x: float = 22.0
@export var safe_max_x: float = 810.0
@export var boundary_retreat_distance: float = 120.0
var ai_enabled: bool = true
var world: Node2D
var health: int = 5
var hit_count: int = 0
var feedback_time: float = 0.0
var jump_count: int = 0
var platform_landing_count: int = 0
var spawn_position: Vector2
var target_area: Area2D
var current_platform: Node2D
var _jump_target: Node2D
var _target_fraction: float = 0.5
var _air_time_remaining: float = 0.0
var _decision_timer: float = 0.0
var _jump_wait: float = 0.0
var _floor_hop_timer: float = 0.0
var _flee_direction: float = 1.0
var _jump_direction: float = 1.0
var _boundary_direction: float = 0.0
const HALF_WIDTH: float = 14.0
const HALF_HEIGHT: float = 22.0
const FLOOR_Y: float = 570.0

func _ready() -> void:
	collision_layer = 16
	collision_mask = 1
	floor_snap_length = 5.0
	floor_stop_on_slope = true
	# A leap's own speed is predictable; while standing, Godot still transports
	# the body with its AnimatableBody2D support automatically.
	platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING
	var collider := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(HALF_WIDTH * 2.0, HALF_HEIGHT * 2.0)
	collider.shape = box
	add_child(collider)
	target_area = TargetArea.new()
	target_area.name = "MeleeTarget"
	target_area.collision_layer = 4
	target_area.collision_mask = 0
	target_area.monitoring = false
	var hit_collider := CollisionShape2D.new()
	var hit_box := RectangleShape2D.new()
	hit_box.size = Vector2(28,44)
	hit_collider.shape = hit_box
	hit_collider.position.y = -5
	target_area.add_child(hit_collider)
	add_child(target_area)
	spawn_position = global_position
	reset()

func receive_hit(amount: int) -> bool:
	if health <= 0:
		return false
	health = maxi(0,health-amount)
	hit_count += 1
	feedback_time = 0.55
	if health == 0:
		velocity.x = 0.0
		_jump_target = null
	queue_redraw()
	return true

func reset() -> void:
	health = max_health
	hit_count = 0
	feedback_time = 0.0
	global_position = spawn_position
	velocity = Vector2.ZERO
	jump_count = 0
	platform_landing_count = 0
	current_platform = null
	_jump_target = null
	_air_time_remaining = 0.0
	_decision_timer = 0.0
	_jump_wait = 0.18
	_floor_hop_timer = 0.0
	_flee_direction = 1.0
	_jump_direction = 1.0
	_boundary_direction = 0.0
	queue_redraw()

func _physics_process(delta: float) -> void:
	feedback_time = maxf(0.0,feedback_time-delta)
	_decision_timer = maxf(0.0,_decision_timer-delta)
	_jump_wait = maxf(0.0,_jump_wait-delta)
	_air_time_remaining = maxf(0.0,_air_time_remaining-delta)
	var was_grounded := is_on_floor()
	velocity.y = minf(velocity.y+(fall_gravity if velocity.y > 0 else gravity)*delta,terminal_speed)
	if ai_enabled and health > 0 and is_instance_valid(world):
		_update_flee_direction()
		if was_grounded:
			_floor_hop_timer += delta
			_jump_target = null
			if _jump_wait <= 0.0 and _decision_timer <= 0.0:
				_decision_timer = decision_interval
				_plan_escape_jump()
			var direction := _flee_direction
			# Pause at a raised edge while waiting for a safe jump. A brief wait
			# gives the pursuing player a fair opportunity to close the gap.
			if velocity.y >= 0 and is_instance_valid(current_platform) and _floor_hop_timer < 0.6:
				var support: Rect2 = current_platform.surface_rect()
				if (direction > 0 and global_position.x > support.end.x-HALF_WIDTH-6.0) or (direction < 0 and global_position.x < support.position.x+HALF_WIDTH+6.0):
					direction = 0.0
			velocity.x = move_toward(velocity.x,direction*run_speed,acceleration*delta)
		if velocity.y < 0 or not was_grounded:
			var target_speed := _jump_direction*run_speed
			if is_instance_valid(_jump_target) and _air_time_remaining > 0.02:
				var destination: Rect2 = _jump_target.predicted_surface_rect(_air_time_remaining)
				var landing_x := destination.position.x+destination.size.x*_target_fraction
				target_speed = clampf((landing_x-global_position.x)/maxf(0.07,_air_time_remaining),-run_speed,run_speed)
			velocity.x = move_toward(velocity.x,target_speed,air_acceleration*delta)
	else:
		velocity.x = 0.0
		_jump_target = null
	move_and_slide()
	current_platform = null
	if is_on_floor():
		for index in range(get_slide_collision_count()):
			var contact := get_slide_collision(index)
			var support_body := contact.get_collider()
			if contact.get_normal().y < -0.5 and support_body is Node2D and support_body.has_method("surface_rect"):
				current_platform = support_body
				break
		if not was_grounded:
			_floor_hop_timer = 0.0
			if is_instance_valid(current_platform):
				platform_landing_count += 1
	# Training stays west of the open pit even before the bridge is restored.
	global_position.x = clampf(global_position.x,safe_min_x,safe_max_x)
	if global_position.y > 675:
		# Recover a missed moving-platform leap without changing combat progress.
		global_position = spawn_position
		velocity = Vector2.ZERO
		_jump_target = null
	queue_redraw()

func _update_flee_direction() -> void:
	if is_instance_valid(world.player):
		var separation: float = global_position.x-world.player.global_position.x
		if absf(separation) > 10.0:
			_flee_direction = signf(separation)
	# Commit briefly to turning away from a room boundary. Recomputing the
	# player direction immediately would alternate sides at the same edge.
	if _boundary_direction < 0 and global_position.x > safe_max_x-boundary_retreat_distance:
		_flee_direction = -1.0
		return
	if _boundary_direction > 0 and global_position.x < safe_min_x+boundary_retreat_distance:
		_flee_direction = 1.0
		return
	_boundary_direction = 0.0
	if global_position.x >= safe_max_x-20.0:
		_flee_direction = -1.0
		_boundary_direction = -1.0
	elif global_position.x <= safe_min_x+20.0:
		_flee_direction = 1.0
		_boundary_direction = 1.0

func _flight_time(surface_y: float) -> float:
	var feet_y := global_position.y+HALF_HEIGHT
	var rise_time := jump_speed/gravity
	var apex_y := feet_y-jump_speed*jump_speed/(2.0*gravity)
	if surface_y < apex_y+5.0:
		return -1.0
	return rise_time+sqrt(maxf(0.0,2.0*(surface_y-apex_y)/fall_gravity))+0.025

func _plan_escape_jump() -> void:
	var best_platform: Node2D
	var best_x: float = 0.0
	var best_time: float = 0.0
	var best_score: float = -INF
	for platform in world.moving_platforms:
		if platform == current_platform:
			continue
		var destination: Rect2 = platform.surface_rect()
		var flight := _flight_time(destination.position.y)
		if flight < 0:
			continue
		for iteration in range(3):
			destination = platform.predicted_surface_rect(flight)
			flight = _flight_time(destination.position.y)
			if flight < 0:
				break
		if flight < 0:
			continue
		var left := maxf(safe_min_x,destination.position.x+HALF_WIDTH+6.0)
		var right := minf(safe_max_x,destination.end.x-HALF_WIDTH-6.0)
		if right < left:
			continue
		var landing_x := clampf(global_position.x+_flee_direction*run_speed*flight*0.88,left,right)
		var travel := landing_x-global_position.x
		if absf(travel) > run_speed*flight-8.0:
			continue
		if not _jump_path_clear(platform,landing_x,flight):
			continue
		var climb := global_position.y+HALF_HEIGHT-destination.position.y
		var score := _flee_direction*travel*0.5+climb*0.9+35.0
		if travel*_flee_direction < -15.0:
			score -= 130.0
		if score > best_score:
			best_score = score
			best_platform = platform
			best_x = landing_x
			best_time = flight
	if is_instance_valid(best_platform):
		var destination: Rect2 = best_platform.predicted_surface_rect(best_time)
		_target_fraction = (best_x-destination.position.x)/destination.size.x
		_start_jump(best_platform,best_time)
	elif _floor_hop_timer >= floor_hop_interval:
		var flight := _flight_time(FLOOR_Y)
		var landing_x := clampf(global_position.x+_flee_direction*run_speed*flight*0.85,safe_min_x,safe_max_x)
		if _jump_path_clear(null,landing_x,flight):
			_start_jump(null,flight)

func _start_jump(platform: Node2D, flight: float) -> void:
	_jump_target = platform
	_air_time_remaining = flight
	_jump_direction = _flee_direction
	velocity.y = -jump_speed
	_jump_wait = jump_cooldown
	_floor_hop_timer = 0.0
	jump_count += 1

func _jump_path_clear(target: Node2D, landing_x: float, duration: float) -> bool:
	# Sample the same ballistic path against future moving surfaces. In
	# particular, do not leap into a platform's underside from directly below.
	var point := global_position
	var motion := Vector2(velocity.x,-jump_speed)
	var step := 1.0/120.0
	var elapsed := 0.0
	while elapsed < duration+0.08:
		var previous_feet := point.y+HALF_HEIGHT
		var remaining := maxf(0.07,duration-elapsed)
		var desired := clampf((landing_x-point.x)/remaining,-run_speed,run_speed)
		motion.x = move_toward(motion.x,desired,air_acceleration*step)
		point += motion*step
		elapsed += step
		var feet := point.y+HALF_HEIGHT
		var body := Rect2(point-Vector2(HALF_WIDTH,HALF_HEIGHT),Vector2(HALF_WIDTH*2.0,HALF_HEIGHT*2.0))
		for platform in world.moving_platforms:
			var surface: Rect2 = platform.predicted_surface_rect(elapsed)
			if body.intersects(surface):
				if platform == target and motion.y > 0 and previous_feet <= surface.position.y+3.0:
					return true
				return false
		if target == null and motion.y > 0 and previous_feet <= FLOOR_Y and feet >= FLOOR_Y:
			return point.x >= safe_min_x and point.x <= safe_max_x
		motion.y = minf(motion.y+(fall_gravity if motion.y > 0 else gravity)*step,terminal_speed)
	return false

func _draw() -> void:
	var color := Color("526e73") if health > 0 else Color("303c42")
	if feedback_time > 0:
		color = Color("ffe0a2")
	draw_line(Vector2(0,14),Vector2(0,22),color,5)
	draw_line(Vector2(-17,22),Vector2(17,22),color,4)
	draw_rect(Rect2(-13,-27,26,41),color)
	draw_circle(Vector2(0,-11),10,Color("172b33"))
	draw_arc(Vector2(0,-11),7,0,TAU,20,Color("d9b37e") if health > 0 else Color("596064"),2)
	for i in range(max_health):
		draw_rect(Rect2(-23+i*10,-42,7,5),Color("ebc78b") if i < health else Color("3c5058"))
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(-25,79),"DUMMY",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("b4bda8"))
	if feedback_time > 0:
		draw_string(font,Vector2(-11,-55),"-1",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("ffde98"))
	if health == 0:
		draw_string(font,Vector2(-53,-57),"T / RESET",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("b4bda8"))
