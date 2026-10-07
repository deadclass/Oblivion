extends CharacterBody2D

const EnemyMelee = preload("res://scripts/enemy_melee.gd")
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
@export var safe_min_x: float = 22.0
@export var safe_max_x: float = 2280.0
@export var aggro_range: float = 480.0
@export var aggro_vertical_range: float = 330.0
@export var attack_stop_distance: float = 44.0
var ai_enabled: bool = true
var alerted: bool = false
var world: Node2D
var health: int = 5
var hit_count: int = 0
var feedback_time: float = 0.0
var jump_count: int = 0
var platform_landing_count: int = 0
var spawn_position: Vector2
var target_area: Area2D
var weapon: Node2D
var current_platform: Node2D
var facing: float = -1.0
var _jump_target: Node2D
var _jump_landing_x: float = INF
var _target_fraction: float = 0.5
var _air_time_remaining: float = 0.0
var _decision_timer: float = 0.0
var _jump_wait: float = 0.0
var _chase_direction: float = -1.0
var _jump_direction: float = -1.0
var _retreat_time: float = 0.0
var _retreat_direction: float = 0.0
var _route_timer: float = 0.0
var _steering_goal: Vector2
var _route_target: Node2D
const HALF_WIDTH: float = 14.0
const HALF_HEIGHT: float = 22.0
const FLOOR_Y: float = 570.0

func _ready() -> void:
	collision_layer = 16
	collision_mask = 1
	floor_snap_length = 5.0
	floor_stop_on_slope = true
	platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING
	var collider := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(HALF_WIDTH*2.0,HALF_HEIGHT*2.0)
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
	weapon = EnemyMelee.new()
	weapon.name = "EnemyMelee"
	add_child(weapon)
	spawn_position = global_position
	reset()

func receive_hit(amount: int) -> bool:
	if health <= 0:
		return false
	health = maxi(0,health-amount)
	hit_count += 1
	feedback_time = 0.55
	alerted = true
	if health == 0:
		velocity.x = 0.0
		_jump_target = null
		weapon.cancel()
	queue_redraw()
	return true

func reset() -> void:
	health = max_health
	hit_count = 0
	feedback_time = 0.0
	alerted = false
	global_position = spawn_position
	velocity = Vector2.ZERO
	jump_count = 0
	platform_landing_count = 0
	current_platform = null
	_jump_target = null
	_air_time_remaining = 0.0
	_jump_landing_x = INF
	_decision_timer = 0.0
	_jump_wait = 0.06
	_chase_direction = -1.0
	_jump_direction = -1.0
	_retreat_time = 0.0
	_retreat_direction = 0.0
	_route_timer = 0.0
	_steering_goal = spawn_position
	_route_target = null
	facing = -1.0
	if is_instance_valid(weapon):
		weapon.reset()
	queue_redraw()

func _physics_process(delta: float) -> void:
	feedback_time = maxf(0.0,feedback_time-delta)
	_decision_timer = maxf(0.0,_decision_timer-delta)
	_jump_wait = maxf(0.0,_jump_wait-delta)
	_air_time_remaining = maxf(0.0,_air_time_remaining-delta)
	_retreat_time = maxf(0.0,_retreat_time-delta)
	_route_timer = maxf(0.0,_route_timer-delta)
	var was_grounded := is_on_floor()
	velocity.y = minf(velocity.y+(fall_gravity if velocity.y > 0 else gravity)*delta,terminal_speed)
	var pursuing := ai_enabled and health > 0 and is_instance_valid(world) and is_instance_valid(world.player)
	if pursuing and not alerted:
		var distance: Vector2 = world.player.global_position-global_position
		alerted = absf(distance.x) <= aggro_range and absf(distance.y) <= aggro_vertical_range
	pursuing = pursuing and alerted
	if pursuing:
		var actual_goal: Vector2 = world.player.global_position
		var goal := actual_goal
		if actual_goal.y < global_position.y-38.0:
			if was_grounded and _route_timer <= 0.0:
				_steering_goal = _route_waypoint(actual_goal)
				_route_timer = 0.35
			goal = _steering_goal
		else:
			_steering_goal = actual_goal
			_route_target = null
		var separation := actual_goal-global_position
		_chase_direction = signf(goal.x-global_position.x) if absf(goal.x-global_position.x) > 8.0 else 0.0
		if not weapon.is_committed() and _chase_direction != 0.0:
			facing = _chase_direction
		if weapon.is_committed():
			facing = weapon.swing_facing
			velocity.x = move_toward(velocity.x,0.0,acceleration*delta)
		else:
			if was_grounded:
				_jump_target = null
				var obstacle_ahead := _obstacle_ahead(_chase_direction)
				var wall_ahead := _wall_blocks(_chase_direction)
				var needs_jump := goal.y < global_position.y-38.0 or obstacle_ahead or wall_ahead
				if _retreat_time <= 0.0 and needs_jump and _jump_wait <= 0.0 and _decision_timer <= 0.0:
					_decision_timer = decision_interval
					var close_step := false
					if is_instance_valid(_route_target):
						var target_rect: Rect2 = _route_target.surface_rect()
						close_step = absf(target_rect.get_center().x-global_position.x) < 180.0 and target_rect.position.y < global_position.y+HALF_HEIGHT-15.0
					if not _plan_chase_jump(goal,obstacle_ahead or wall_ahead) and (wall_ahead or obstacle_ahead or close_step):
						# Back away from an underside before retrying a jump. There
						# is no random escape hopping during direct pursuit.
						# A nearby higher step can be reachable from the leading
						# edge of this support, outside an overhead platform.
						# Continue toward that edge rather than retreating under it.
						var raised_support: bool = is_instance_valid(current_platform) and current_platform.surface_rect().position.y < FLOOR_Y-1.0
						var separated_step := false
						if raised_support and is_instance_valid(_route_target):
							var support: Rect2 = current_platform.surface_rect()
							var step: Rect2 = _route_target.surface_rect()
							separated_step = step.position.x-support.end.x > HALF_WIDTH if _chase_direction > 0.0 else support.position.x-step.end.x > HALF_WIDTH
						_retreat_direction = _chase_direction if close_step and separated_step and not wall_ahead and not obstacle_ahead else (-_chase_direction if _chase_direction != 0.0 else -facing)
						_retreat_time = 0.24
						# Turn and brake after the retreat before sampling the next
						# launch, rather than jumping with velocity away from it.
						_decision_timer = 0.42
				var direction := _retreat_direction if _retreat_time > 0.0 else _chase_direction
				if absf(separation.x) <= attack_stop_distance and absf(separation.y) <= weapon.vertical_range:
					direction = 0.0
				if not _position_safe(global_position+Vector2(direction*(HALF_WIDTH+8.0),0.0)):
					direction = 0.0
				velocity.x = move_toward(velocity.x,direction*run_speed,acceleration*delta)
			if velocity.y < 0 or not was_grounded:
				var target_speed := _chase_direction*run_speed
				if is_instance_valid(_jump_target) and _air_time_remaining > 0.02:
					var destination: Rect2 = _jump_target.predicted_surface_rect(_air_time_remaining)
					var landing_x := destination.position.x+destination.size.x*_target_fraction
					target_speed = clampf((landing_x-global_position.x)/maxf(0.07,_air_time_remaining),-run_speed,run_speed)
				elif is_finite(_jump_landing_x) and _air_time_remaining > 0.02:
					target_speed = clampf((_jump_landing_x-global_position.x)/maxf(0.07,_air_time_remaining),-run_speed,run_speed)
				velocity.x = move_toward(velocity.x,target_speed,air_acceleration*delta)
			weapon.try_attack()
	else:
		velocity.x = 0.0
		_jump_target = null
		weapon.cancel()
	move_and_slide()
	current_platform = null
	if is_on_floor():
		for index in range(get_slide_collision_count()):
			var contact := get_slide_collision(index)
			var support_body := contact.get_collider()
			if contact.get_normal().y < -0.5 and support_body is Node2D and support_body.has_method("surface_rect"):
				current_platform = support_body
		if not was_grounded and is_instance_valid(current_platform) and current_platform.surface_rect().position.y < FLOOR_Y-1.0:
			platform_landing_count += 1
		if not was_grounded:
			_route_timer = 0.0
	global_position.x = clampf(global_position.x,safe_min_x,safe_max_x)
	if global_position.y > 675:
		# A missed route returns to the guard without healing combat damage.
		global_position = spawn_position
		velocity = Vector2.ZERO
		_jump_target = null
		weapon.cancel()
	queue_redraw()

func _navigation_surfaces() -> Array:
	if world.has_method("navigation_surfaces"):
		return world.navigation_surfaces()
	return world.moving_platforms

func _navigation_blockers() -> Array:
	if world.has_method("navigation_blockers"):
		return world.navigation_blockers()
	return []

func _position_safe(point: Vector2) -> bool:
	if point.x < safe_min_x or point.x > safe_max_x:
		return false
	if world.has_method("dummy_position_is_safe"):
		return world.dummy_position_is_safe(point)
	return not (not world.solved and point.x >= 840.0 and point.x <= 960.0 and point.y+HALF_HEIGHT >= 568.0)

func _floor_y_at(x: float) -> float:
	if world.has_method("floor_y_at"):
		return world.floor_y_at(x)
	return INF if not world.solved and x >= 840.0 and x <= 960.0 else FLOOR_Y

func _wall_blocks(direction: float) -> bool:
	if direction == 0.0 or not is_on_wall():
		return false
	for index in range(get_slide_collision_count()):
		if get_slide_collision(index).get_normal().x*direction < -0.5:
			return true
	return false

func _obstacle_ahead(direction: float) -> bool:
	if direction == 0.0:
		return false
	var ahead_x := global_position.x+direction*(HALF_WIDTH+40.0)
	if global_position.y+HALF_HEIGHT > FLOOR_Y-8.0 and not is_finite(_floor_y_at(ahead_x)):
		return true
	for height in [-8.0,-22.0]:
		var ray := PhysicsRayQueryParameters2D.create(global_position+Vector2(direction*(HALF_WIDTH+1.0),height),global_position+Vector2(direction*65.0,height),1)
		ray.collide_with_areas = false
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			return true
	return false

func _flight_time(surface_y: float,impulse: float = 0.0) -> float:
	return _flight_time_from(global_position.y+HALF_HEIGHT,surface_y,impulse)

func _flight_time_from(feet_y: float,surface_y: float,impulse: float = 0.0) -> float:
	impulse = jump_speed if impulse <= 0 else impulse
	var rise_time := impulse/gravity
	var apex_y := feet_y-impulse*impulse/(2.0*gravity)
	if not is_finite(surface_y) or surface_y < apex_y+5.0:
		return -1.0
	return rise_time+sqrt(maxf(0.0,2.0*(surface_y-apex_y)/fall_gravity))+0.025

func _plan_chase_jump(goal: Vector2,allow_floor_jump: bool = false) -> bool:
	var best: Dictionary = {}
	for platform in _navigation_surfaces():
		if platform == current_platform and not allow_floor_jump:
			continue
		var destination: Rect2 = platform.surface_rect()
		# If the route's next support is above us, prepare its takeoff on
		# this support instead of taking an available jump back downward.
		# That preserves the climb while horizontal velocity turns around.
		if is_instance_valid(_route_target) and _route_target.surface_rect().position.y < global_position.y+HALF_HEIGHT-15.0 and destination.position.y >= global_position.y+HALF_HEIGHT-15.0 and not (platform == current_platform and allow_floor_jump):
			continue
		var required_height := maxf(35.0,global_position.y+HALF_HEIGHT-destination.position.y+16.0)
		var low_impulse := minf(jump_speed,sqrt(2.0*gravity*required_height))
		var shallow_height := maxf(35.0,global_position.y+HALF_HEIGHT-destination.position.y+7.0)
		var shallow_impulse := minf(jump_speed,sqrt(2.0*gravity*shallow_height))
		for impulse in [jump_speed,low_impulse,shallow_impulse]:
			var candidate := _platform_jump_candidate(platform,goal,impulse)
			if not candidate.is_empty():
				if best.is_empty() or candidate.score > best.score:
					best = candidate
				break
	if not best.is_empty():
		var destination: Rect2 = best.platform.predicted_surface_rect(best.flight)
		_target_fraction = (best.x-destination.position.x)/destination.size.x
		_start_jump(best.platform,best.flight,best.x,best.impulse)
		return true
	if not allow_floor_jump:
		return false
	# Try clear ground landings and a lower obstacle-clearing arc before
	# backing away. Small pillars under a ceiling do not need a full jump.
	for distance in [120.0,145.0,170.0,95.0]:
		var landing_x := clampf(global_position.x+_chase_direction*distance,safe_min_x,safe_max_x)
		var floor_y := _floor_y_at(landing_x)
		if not is_finite(floor_y):
			continue
		var required_height := 35.0
		for surface in _navigation_surfaces():
			var rect: Rect2 = surface.surface_rect()
			if rect.end.y >= FLOOR_Y-2.0 and rect.position.x <= maxf(global_position.x,landing_x)+HALF_WIDTH and rect.end.x >= minf(global_position.x,landing_x)-HALF_WIDTH:
				required_height = maxf(required_height,FLOOR_Y-rect.position.y+16.0)
		var low_impulse := minf(jump_speed,sqrt(2.0*gravity*required_height))
		for impulse in [jump_speed,low_impulse]:
			var flight := _flight_time(floor_y,impulse)
			if flight > 0 and absf(landing_x-global_position.x) <= run_speed*flight-8.0 and _position_safe(Vector2(landing_x,floor_y-HALF_HEIGHT)) and _jump_path_clear(null,landing_x,flight,impulse):
				_start_jump(null,flight,landing_x,impulse)
				return true
	return false

func _platform_jump_candidate(platform: Node2D,goal: Vector2,impulse: float) -> Dictionary:
	var destination: Rect2 = platform.surface_rect()
	var flight := _flight_time(destination.position.y,impulse)
	if flight < 0:
		return {}
	for iteration in range(3):
		destination = platform.predicted_surface_rect(flight)
		flight = _flight_time(destination.position.y,impulse)
		if flight < 0:
			return {}
	var left := maxf(safe_min_x,destination.position.x+HALF_WIDTH+3.0)
	var right := minf(safe_max_x,destination.end.x-HALF_WIDTH-3.0)
	if right < left:
		return {}
	# Clear a nearby pillar before descending onto the same support; merely
	# aiming at the player's center can leave the larger guard's trailing
	# edge overlapping that pillar by a pixel on the descent.
	var goal_x := goal.x+_chase_direction*16.0 if platform == current_platform else goal.x
	var landing_x := clampf(goal_x,left,right)
	landing_x = clampf(landing_x,global_position.x-run_speed*flight+8.0,global_position.x+run_speed*flight-8.0)
	if landing_x < left or landing_x > right or not _position_safe(Vector2(landing_x,destination.position.y-HALF_HEIGHT)) or not _jump_path_clear(platform,landing_x,flight,impulse):
		return {}
	var travel := landing_x-global_position.x
	var landing_y := destination.position.y-HALF_HEIGHT
	var initial_distance := absf(goal.x-global_position.x)+absf(goal.y-global_position.y)*1.2
	var score := initial_distance-absf(goal.x-landing_x)-absf(goal.y-landing_y)*1.2
	if goal.y < global_position.y-38.0 and landing_y < global_position.y-15.0:
		score += 75.0
	if travel*_chase_direction < -15.0:
		score -= 25.0
	if platform == _route_target:
		score += 140.0
	return {"platform":platform,"flight":flight,"x":landing_x,"impulse":impulse,"score":score}

func _route_edge_cost(source: Rect2,destination: Rect2) -> float:
	var flight := _flight_time_from(source.position.y,destination.position.y)
	if flight < 0:
		return INF
	var source_left := source.position.x+HALF_WIDTH+3.0
	var source_right := source.end.x-HALF_WIDTH-3.0
	var target_left := destination.position.x+HALF_WIDTH+3.0
	var target_right := destination.end.x-HALF_WIDTH-3.0
	if source_right < source_left or target_right < target_left:
		return INF
	# A support entirely under the destination cannot launch onto its top.
	# The graph must allow takeoff outside at least one destination edge.
	if destination.position.y < source.position.y-5.0 and source_left >= destination.position.x-HALF_WIDTH-5.0 and source_right <= destination.end.x+HALF_WIDTH+5.0:
		return INF
	var horizontal_gap := maxf(0.0,maxf(target_left-source_right,source_left-target_right))
	if horizontal_gap > run_speed*flight-8.0:
		return INF
	return flight+absf(destination.get_center().x-source.get_center().x)/run_speed*0.28+(0.3 if destination.position.y >= FLOOR_Y else 0.0)

func _route_waypoint(goal: Vector2) -> Vector2:
	# A small support graph finds useful detours to a higher floor. Purely
	# greedy climbing can loop on a ledge below an unreachable overhang.
	_route_target = null
	var nodes := _navigation_surfaces()
	var rects: Array[Rect2] = []
	for surface in nodes:
		rects.append(surface.surface_rect())
	var surface_count := nodes.size()
	if world.solved:
		rects.append(Rect2(0,FLOOR_Y,safe_max_x+24.0,78))
	else:
		rects.append(Rect2(0,FLOOR_Y,840,78))
		rects.append(Rect2(960,FLOOR_Y,safe_max_x-960.0+24.0,78))
	var source_index: int = nodes.find(current_platform)
	if source_index < 0:
		for index in range(surface_count,rects.size()):
			if global_position.x >= rects[index].position.x and global_position.x <= rects[index].end.x:
				source_index = index
				break
	if source_index < 0:
		return goal
	var goal_index: int = -1
	var closest_height: float = INF
	for index in range(rects.size()):
		var rect := rects[index]
		if goal.x >= rect.position.x and goal.x <= rect.end.x:
			var height := absf(rect.position.y-(goal.y+16.0))
			if height < closest_height:
				closest_height = height
				goal_index = index
	if goal_index < 0 or closest_height > 40.0 or goal_index == source_index:
		return goal
	var costs: Array[float] = []
	var visited: Array[bool] = []
	for index in range(rects.size()):
		costs.append(INF)
		visited.append(false)
	costs[goal_index] = 0.0
	for iteration in range(rects.size()):
		var selected: int = -1
		var lowest: float = INF
		for index in range(rects.size()):
			if not visited[index] and costs[index] < lowest:
				selected = index
				lowest = costs[index]
		if selected < 0:
			break
		visited[selected] = true
		for index in range(rects.size()):
			if index == selected or visited[index]:
				continue
			var cost := _route_edge_cost(rects[index],rects[selected])
			if costs[selected]+cost < costs[index]:
				costs[index] = costs[selected]+cost
	var next_index: int = -1
	var best: float = INF
	for index in range(rects.size()):
		if index == source_index or not is_finite(costs[index]):
			continue
		var edge := _route_edge_cost(rects[source_index],rects[index])
		var departure_x := clampf(rects[index].get_center().x,rects[source_index].position.x+HALF_WIDTH+3.0,rects[source_index].end.x-HALF_WIDTH-3.0)
		var cost := edge+costs[index]+absf(departure_x-global_position.x)/run_speed*0.35
		if cost < best:
			best = cost
			next_index = index
	if next_index < 0:
		return goal
	var destination := rects[next_index]
	if next_index < surface_count:
		_route_target = nodes[next_index]
	return Vector2(destination.get_center().x,destination.position.y-HALF_HEIGHT)

func _start_jump(platform: Node2D, flight: float,landing_x: float = INF,impulse: float = 0.0) -> void:
	_jump_target = platform
	_jump_landing_x = landing_x
	_air_time_remaining = flight
	_jump_direction = _chase_direction
	velocity.y = -(jump_speed if impulse <= 0 else impulse)
	_jump_wait = jump_cooldown
	jump_count += 1

func _jump_path_clear(target: Node2D, landing_x: float, duration: float,impulse: float = 0.0) -> bool:
	var point := global_position
	var motion := Vector2(velocity.x,-(jump_speed if impulse <= 0 else impulse))
	var step := 1.0/120.0
	var elapsed := 0.0
	var surfaces := _navigation_surfaces()
	var blockers := _navigation_blockers()
	while elapsed < duration+0.08:
		var previous_feet := point.y+HALF_HEIGHT
		var remaining := maxf(0.07,duration-elapsed)
		var desired := clampf((landing_x-point.x)/remaining,-run_speed,run_speed)
		motion.x = move_toward(motion.x,desired,air_acceleration*step)
		point += motion*step
		elapsed += step
		if not _position_safe(point):
			return false
		var feet := point.y+HALF_HEIGHT
		var body := Rect2(point-Vector2(HALF_WIDTH,HALF_HEIGHT),Vector2(HALF_WIDTH*2.0,HALF_HEIGHT*2.0))
		for platform in surfaces:
			var surface: Rect2 = platform.predicted_surface_rect(elapsed)
			if body.intersects(surface):
				if platform == target and motion.y > 0 and previous_feet <= surface.position.y+3.0:
					return true
				return false
		for blocker in blockers:
			if body.intersects(blocker):
				return false
		var floor_y := _floor_y_at(point.x)
		if target == null and is_finite(floor_y) and motion.y > 0 and previous_feet <= floor_y and feet >= floor_y:
			return true
		motion.y = minf(motion.y+(fall_gravity if motion.y > 0 else gravity)*step,terminal_speed)
	return false

func _draw() -> void:
	if health <= 0:
		var broken := Color("46545b")
		draw_rect(Rect2(-21,7,37,12),broken)
		draw_circle(Vector2(-18,11),8,Color("293c44"))
		draw_line(Vector2(-23,22),Vector2(20,22),Color("303c42"),4)
		draw_line(Vector2(10,18),Vector2(29,7),Color("846a51"),4)
		draw_string(ThemeDB.fallback_font,Vector2(-36,-15),"T / RESET",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("b4bda8"))
		draw_string(ThemeDB.fallback_font,Vector2(-37,49),"DEFEATED",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("8fa099"))
		return
	var color := Color("526e73") if health > 0 else Color("303c42")
	if feedback_time > 0:
		color = Color("ffe0a2")
	draw_line(Vector2(0,14),Vector2(0,22),color,5)
	draw_line(Vector2(-17,22),Vector2(17,22),color,4)
	draw_rect(Rect2(-13,-27,26,41),color)
	draw_circle(Vector2(0,-11),10,Color("172b33"))
	draw_arc(Vector2(0,-11),7,0,TAU,20,Color("db9260") if alerted and health > 0 else Color("d9b37e") if health > 0 else Color("596064"),2)
	draw_circle(Vector2(facing*4,-11),2,Color("ffc98b"))
	for i in range(max_health):
		draw_rect(Rect2(-23+i*10,-42,7,5),Color("ebc78b") if i < health else Color("3c5058"))
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(-25,79),"GUARD",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("b4bda8"))
	if feedback_time > 0:
		draw_string(font,Vector2(-11,-55),"-1",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("ffde98"))
	if health == 0:
		draw_string(font,Vector2(-53,-57),"T / RESET",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("b4bda8"))

