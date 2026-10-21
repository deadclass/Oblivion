extends Node2D

# This is the character's temporary body, not a thrown copy. Every travelled
# point is saved, so a curved aimed excursion returns around the same walls.
const OUTWARD_SPEED: float = 660.0
const RETURN_SPEED: float = 760.0
const PLAIN_DURATION: float = 1.20
const AIMED_DURATION: float = 3.00
# Fit inside the original 22px-wide body even at a touching side wall.
# A larger initial circle overlaps that wall and cast_motion ignores it.
const BODY_RADIUS: float = 10.0
const HIT_RADIUS: float = 17.0

var abilities
var player
var kind: String = "crescent"
var move_name: String = "Boomerang form"
var damage: float = 5.0
var launch_origin: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var velocity: Vector2 = Vector2.ZERO
var age: float = 0.0
var returning: bool = false
var aimed: bool = false
var finished: bool = false
var route: Array[Vector2] = []
var hit_targets: Dictionary = {}
var return_hits: Dictionary = {}
var saved_player: Dictionary = {}
var launch_room: int = 1
var _return_index: int = -1

func begin(host, character, facing: float, use_aim: bool, heading: Vector2) -> bool:
	abilities = host
	player = character
	saved_player = player.begin_boomerang_form()
	if saved_player.is_empty():
		return false
	launch_room = abilities.world.current_room
	launch_origin = player.global_position
	global_position = launch_origin
	aimed = use_aim
	# Plain flight samples the selected target's heading once. Only an aimed
	# flight changes direction after launch; neither version homes on a target.
	direction = heading.normalized() if heading.length() > 0.15 else Vector2(facing, 0.0)
	velocity = direction * OUTWARD_SPEED
	route.append(launch_origin)
	player.queue_redraw()
	queue_redraw()
	return true

func _aim_held() -> bool:
	return is_instance_valid(abilities) and is_instance_valid(abilities.world) and is_instance_valid(abilities.world.aim) and abilities.world.aim.held

func _physics_process(delta: float) -> void:
	if finished:
		return
	if not is_instance_valid(abilities) or not is_instance_valid(player):
		_finish(true)
		return
	if player.hitstop_time > 0.0:
		return
	if not returning:
		var duration: float = AIMED_DURATION if aimed else PLAIN_DURATION
		var remaining: float = maxf(0.0, duration - age)
		if (aimed and not _aim_held()) or remaining <= 0.0:
			begin_return()
		else:
			if aimed:
				var stick: Vector2 = abilities.world.aim.raw_direction
				if stick.length() > 0.15:
					direction = stick.normalized()
			velocity = direction * OUTWARD_SPEED
			_step_outward(minf(delta, remaining))
			age += delta
			if age >= duration and not finished:
				begin_return()
			queue_redraw()
			return
	age += delta
	_step_return(delta)
	queue_redraw()

func begin_return() -> void:
	if returning or finished:
		return
	returning = true
	_return_index = route.size() - 2
	if route.size() < 2:
		_finish(false)
	else:
		abilities.active_move = "Boomerang returning"

func _step_outward(delta: float) -> void:
	var blocked: bool = _advance(direction * OUTWARD_SPEED * delta, hit_targets)
	if finished:
		return
	if route[-1].distance_squared_to(global_position) > 0.0001:
		route.append(global_position)
	if blocked:
		begin_return()

func _step_return(delta: float) -> void:
	var remaining: float = RETURN_SPEED * delta
	# A frame can consume several short route segments without changing speed.
	while remaining > 0.0001 and not finished:
		if _return_index < 0:
			_finish(false)
			return
		var waypoint: Vector2 = route[_return_index]
		var distance: float = global_position.distance_to(waypoint)
		if distance < 0.0001:
			_return_index -= 1
			continue
		direction = global_position.direction_to(waypoint)
		velocity = direction * RETURN_SPEED
		var travel: float = minf(remaining, distance)
		var previous: Vector2 = global_position
		var blocked: bool = _advance(direction * travel, return_hits)
		if finished:
			return
		remaining -= previous.distance_to(global_position)
		if blocked:
			# Newly inserted solids stop return, rather than allowing a shortcut
			# through geometry. Pause/reset can always restore the launch body.
			return
		if travel >= distance - 0.0001:
			_return_index -= 1
	if not finished and _return_index < 0:
		_finish(false)

func _advance(motion: Vector2, seen: Dictionary) -> bool:
	var previous: Vector2 = global_position
	var body := CircleShape2D.new()
	body.radius = BODY_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body
	query.transform = Transform2D(0.0, previous)
	query.motion = motion
	query.margin = 0.001
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	var limits: PackedFloat32Array = get_world_2d().direct_space_state.cast_motion(query)
	var safe: float = clampf(limits[0], 0.0, 1.0) if limits.size() >= 2 else 1.0
	global_position = previous + motion * safe
	player.global_position = global_position
	player.velocity = velocity
	_sweep_targets(previous, global_position, seen)
	return safe < 0.9999

func _sweep_targets(previous: Vector2, next: Vector2, seen: Dictionary) -> void:
	var travel: Vector2 = next - previous
	var shape := RectangleShape2D.new()
	shape.size = Vector2(travel.length() + HIT_RADIUS * 2.0, HIT_RADIUS * 2.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(travel.angle(), (previous + next) * 0.5)
	query.collision_mask = 4
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for result in get_world_2d().direct_space_state.intersect_shape(query):
		var target = abilities._target_body(result.collider)
		if not is_instance_valid(target) or seen.has(target.get_instance_id()) or not abilities.has_line_of_sight(previous, target.global_position):
			continue
		seen[target.get_instance_id()] = true
		var heading: Vector2 = direction
		abilities.apply_hit(target, damage, heading * 180.0 + Vector2(0.0, -155.0), "Boomerang return" if returning else move_name)
		if finished or is_queued_for_deletion() or not is_instance_valid(abilities):
			return

func cancel() -> void:
	_finish(true)

func _finish(cancelled: bool) -> void:
	if finished:
		return
	finished = true
	_restore_player()
	if is_instance_valid(abilities):
		abilities.boomerang_finished(self, cancelled)
	queue_free()

func _exit_tree() -> void:
	# Direct removal is safe too; avoid leaving an invisible disabled body.
	if not finished and is_instance_valid(player):
		_restore_player()

func _restore_player() -> void:
	if is_instance_valid(player):
		player.end_boomerang_form(launch_origin, saved_player)
		if is_instance_valid(abilities) and is_instance_valid(abilities.world) and not abilities.world.is_queued_for_deletion():
			abilities.world.restore_form_room(launch_room)

func _draw() -> void:
	if finished:
		return
	# An outline marks where the real character will reform. The trail shows
	# the return route without displaying another filled character body.
	var home: Vector2 = to_local(launch_origin)
	draw_rect(Rect2(home + Vector2(-11.0, -18.0), Vector2(22.0, 36.0)), Color(0.66, 0.91, 0.84, 0.22), false, 1.5)
	draw_arc(home, 25.0, 0.0, TAU, 36, Color(0.50, 0.93, 0.81, 0.55), 2.0)
	draw_line(home + Vector2(-7.0, 0.0), home + Vector2(7.0, 0.0), Color(0.64, 0.97, 0.87, 0.65), 1.5)
	draw_line(home + Vector2(0.0, -7.0), home + Vector2(0.0, 7.0), Color(0.64, 0.97, 0.87, 0.65), 1.5)
	for index in range(1, route.size()):
		draw_line(to_local(route[index - 1]), to_local(route[index]), Color(0.59, 0.94, 0.84, 0.13), 2.0)
	var angle: float = age * 17.0
	var rim := Color("a7ebdf") if returning else Color("e7d9b2")
	draw_circle(Vector2.ZERO, 24.0, Color(0.41, 0.88, 0.79, 0.12))
	draw_arc(Vector2.ZERO, 16.0, angle, angle + PI * 1.45, 28, rim, 6.0)
	draw_line(Vector2.from_angle(angle) * 16.0, Vector2.from_angle(angle + 1.2) * 10.0, Color("334d64"), 5.0)
	draw_circle(Vector2.from_angle(angle + 0.5) * 13.0, 3.0, Color("ffe1a0"))
	for index in range(2):
		var offset: Vector2 = -direction * (25.0 + float(index) * 14.0)
		draw_arc(offset, 11.0, angle, angle + PI, 16, Color(0.63, 0.93, 0.84, 0.25 - float(index) * 0.10), 2.0)
