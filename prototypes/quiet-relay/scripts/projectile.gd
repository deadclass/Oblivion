extends Node2D

var abilities
var kind: String = "arrow"
var velocity: Vector2 = Vector2.ZERO
var damage: float = 4.0
var move_name: String = "Arrow"
var age: float = 0.0
var returning: bool = false
var hit_targets: Dictionary = {}
var settled: bool = false
var _return_hits: Dictionary = {}
var launch_origin: Vector2 = Vector2(INF, INF)
var range_limit: float = -1.0
var _launch_source: Vector2 = Vector2(INF, INF)
var _launch_checked: bool = false

func _ready() -> void:
	if is_instance_valid(abilities) and is_instance_valid(abilities.player):
		_launch_source = abilities.player.global_position + Vector2(0.0, -9.0)
	if kind != "orb":
		return
	if not launch_origin.is_finite():
		launch_origin = abilities.player.global_position if is_instance_valid(abilities) and is_instance_valid(abilities.player) else global_position
	if range_limit < 0.0:
		var zoom: float = 1.0
		if is_instance_valid(abilities) and is_instance_valid(abilities.world) and is_instance_valid(abilities.world.get("camera")):
			zoom = maxf(0.01, absf(abilities.world.camera.zoom.x))
		range_limit = get_viewport_rect().size.x / zoom * 0.5

func _physics_process(delta: float) -> void:
	if not is_instance_valid(abilities) or not is_instance_valid(abilities.player):
		_finish()
		return
	if abilities.player.hitstop_time > 0.0:
		return
	age += delta
	if kind == "orb":
		_step_orb(delta)
	elif kind == "crescent":
		_step_crescent(delta)
	else:
		_step_arrow(delta)
	queue_redraw()

func _step_arrow(delta: float) -> void:
	_check_launch_origin(6.0)
	if age > 1.5:
		_finish()
		return
	var previous: Vector2 = global_position
	var next: Vector2 = previous+velocity*delta
	var wall: Dictionary = _arrow_solid_hit(previous,next)
	if not wall.is_empty():
		next = wall.position
	if _sweep_targets(previous,next,hit_targets):
		_finish()
		return
	global_position = next
	if not wall.is_empty():
		_finish()

func _step_crescent(delta: float) -> void:
	if age > 3.0:
		_finish()
		return
	if not returning and age >= 0.38:
		returning = true
	var home: Vector2 = abilities.player.global_position+Vector2(0.0,-9.0)
	if returning:
		if global_position.distance_to(home) < 22.0:
			_finish()
			return
		velocity = global_position.direction_to(home)*760.0
	var previous: Vector2 = global_position
	var next: Vector2 = previous+velocity*delta
	var sweep_returning: bool = returning
	var wall: Dictionary = _solid_hit(previous,next)
	if not wall.is_empty():
		next = wall.position+wall.normal*4.0
		# A blocked outward throw returns. A blocked return expires rather
		# than crossing a floor or wall to reach the player.
		if returning:
			_finish()
			return
		returning = true
	_sweep_targets(previous,next,_return_hits if sweep_returning else hit_targets)
	if not is_queued_for_deletion():
		global_position = next

func _step_orb(delta: float) -> void:
	_check_launch_origin(9.0)
	if settled:
		return
	var state: Dictionary = simulate_orb_step(global_position, velocity, delta, launch_origin, range_limit, get_world_2d().direct_space_state)
	global_position = state.position
	velocity = state.velocity
	settled = state.settled
	if global_position.y > 1200.0 or absf(global_position.x) > 4000.0:
		_finish()

# Both flight and trajectory preview use this exact step. Range means hard
# horizontal displacement from the player's position at launch. Reaching
# either half-screen boundary zeros horizontal motion; gravity then lands
# the orb naturally. A bounce/settling offset cannot place it past that cap.
static func simulate_orb_step(position: Vector2, incoming_velocity: Vector2, delta: float, origin: Vector2, limit: float, space) -> Dictionary:
	var speed: Vector2 = incoming_velocity
	speed.y = minf(700.0, speed.y + 1100.0 * delta)
	var minimum_x: float = origin.x - maxf(0.0, limit)
	var maximum_x: float = origin.x + maxf(0.0, limit)
	var next: Vector2 = position + speed * delta
	var capped: bool = next.x < minimum_x or next.x > maximum_x
	next.x = clampf(next.x, minimum_x, maximum_x)
	if capped:
		speed.x = 0.0
	var ray := PhysicsRayQueryParameters2D.create(position, next, 3 if speed.y >= 0.0 else 1)
	ray.collide_with_areas = false
	var wall: Dictionary = space.intersect_ray(ray)
	if not wall.is_empty():
		var surface = wall.collider as CollisionObject2D
		if is_instance_valid(surface) and (surface.collision_layer & 2) != 0 and wall.normal.y >= -0.4:
			ray.collision_mask = 1
			wall = space.intersect_ray(ray)
	var landed: bool = false
	if not wall.is_empty():
		next = wall.position + wall.normal * 9.0
		if wall.normal.y < -0.4:
			speed = Vector2.ZERO
			landed = true
		else:
			speed = speed.bounce(wall.normal) * 0.45
	if next.x < minimum_x or next.x > maximum_x:
		capped = true
	next.x = clampf(next.x, minimum_x, maximum_x)
	if capped:
		speed.x = 0.0
	return {"position": next, "velocity": speed, "settled": landed, "capped": capped}

static func safe_launch_origin(source: Vector2, desired: Vector2, clearance: float, space, collision_mask: int = 1) -> Vector2:
	var offset: Vector2 = desired - source
	var reach: float = offset.length()
	if reach <= 0.001:
		return source
	var forward: Vector2 = offset / reach
	if (collision_mask & 2) != 0:
		# Arrows treat platforms as full geometry. Sweep their round muzzle
		# clearance too: a center ray can miss a platform corner while the
		# projectile itself begins embedded above its edge.
		var circle := CircleShape2D.new()
		circle.radius = maxf(0.0, clearance) + 0.5
		var sweep := PhysicsShapeQueryParameters2D.new()
		sweep.shape = circle
		sweep.transform = Transform2D(0.0, source)
		sweep.collision_mask = collision_mask
		sweep.collide_with_areas = false
		sweep.collide_with_bodies = true
		if not space.intersect_shape(sweep, 1).is_empty():
			return source
		sweep.motion = offset
		var fractions: PackedFloat32Array = space.cast_motion(sweep)
		if fractions.size() >= 2 and fractions[0] < 1.0:
			return source + offset * maxf(0.0, fractions[0])
		return desired
	# Check the clearance beyond the desired center too: stopping the center
	# just short of a wall could still begin a round projectile inside it.
	var ray := PhysicsRayQueryParameters2D.create(source, desired + forward * (clearance + 0.5), collision_mask)
	ray.collide_with_areas = false
	ray.hit_from_inside = true
	var hit: Dictionary = space.intersect_ray(ray)
	if hit.is_empty():
		return desired
	var allowed: float = maxf(0.0, source.distance_to(hit.position) - clearance - 0.5)
	return source + forward * minf(reach, allowed)

func _check_launch_origin(clearance: float) -> void:
	if _launch_checked:
		return
	_launch_checked = true
	if not _launch_source.is_finite():
		_launch_source = abilities.player.global_position + Vector2(0.0, -9.0)
	global_position = safe_launch_origin(_launch_source, global_position, clearance, get_world_2d().direct_space_state, 3 if kind == "arrow" else 1)

func _arrow_solid_hit(previous: Vector2, next: Vector2) -> Dictionary:
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, previous)
	query.collision_mask = 3
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var space = get_world_2d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return {"position": previous}
	query.motion = next - previous
	var fractions: PackedFloat32Array = space.cast_motion(query)
	if fractions.size() >= 2 and fractions[0] < 1.0:
		return {"position": previous + query.motion * fractions[0]}
	return {}

func _solid_hit(previous: Vector2, next: Vector2, collision_mask: int = 1) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(previous,next,collision_mask)
	query.collide_with_areas = false
	return get_world_2d().direct_space_state.intersect_ray(query)

func _sweep_targets(previous: Vector2, next: Vector2, seen: Dictionary) -> bool:
	var radius: float = 12.0 if kind == "crescent" else 6.0
	var travel: Vector2 = next-previous
	var shape := RectangleShape2D.new()
	shape.size = Vector2(travel.length()+radius*2.0,radius*2.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(travel.angle(),(previous+next)*0.5)
	query.collision_mask = 4
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var did_hit: bool = false
	for result in get_world_2d().direct_space_state.intersect_shape(query):
		var target = abilities._target_body(result.collider)
		if not is_instance_valid(target) or seen.has(target.get_instance_id()):
			continue
		if kind == "arrow":
			var sight := PhysicsRayQueryParameters2D.create(previous, target.global_position, 3)
			sight.collide_with_areas = false
			sight.hit_from_inside = true
			if not get_world_2d().direct_space_state.intersect_ray(sight).is_empty():
				continue
		elif not abilities.has_line_of_sight(previous,target.global_position):
			continue
		seen[target.get_instance_id()] = true
		var horizontal: float = signf(velocity.x)
		var impulse: Vector2 = velocity.normalized() * 245.0 + Vector2(0.0, -155.0) if kind == "arrow" else Vector2(horizontal * 180.0, -155.0)
		did_hit = abilities.apply_hit(target,damage,impulse,move_name) or did_hit
		if not is_instance_valid(abilities) or is_queued_for_deletion():
			return did_hit
		if kind == "arrow" and did_hit:
			return true
	return did_hit

func _finish() -> void:
	if is_instance_valid(abilities):
		abilities.projectile_finished(self)
	queue_free()

func _draw() -> void:
	if kind == "orb":
		var pulse: float = 0.6+0.4*sin(age*6.0)
		draw_circle(Vector2.ZERO,12.0,Color(0.27,0.84,0.95,0.18+pulse*0.12))
		draw_circle(Vector2.ZERO,7.5,Color("b5f5ed"))
		draw_arc(Vector2.ZERO,10.0,0.0,TAU,24,Color("61d4ed"),1.8)
		draw_line(Vector2(-4.0,0.0),Vector2(4.0,0.0),Color("318994"),2.0)
		draw_line(Vector2(0.0,-4.0),Vector2(0.0,4.0),Color("318994"),2.0)
	elif kind == "crescent":
		var angle: float = age*17.0
		draw_arc(Vector2.ZERO,12.0,angle,angle+PI*1.4,20,Color("e0e5ad"),4.0)
		draw_line(Vector2.from_angle(angle)*12.0,Vector2.from_angle(angle+1.2)*8.0,Color("f8f1c8"),3.0)
	else:
		var forward: Vector2 = velocity.normalized() if not velocity.is_zero_approx() else Vector2.RIGHT
		var side: Vector2 = forward.orthogonal()
		draw_line(-forward * 14.0, forward * 10.0, Color("f4e9ae"), 2.5)
		draw_colored_polygon(PackedVector2Array([forward * 15.0, forward * 7.0 - side * 4.0, forward * 7.0 + side * 4.0]), Color("dbffdf"))
		draw_line(-forward * 12.0, -forward * 16.0 - side * 4.0, Color("b1dabd"), 2.0)
