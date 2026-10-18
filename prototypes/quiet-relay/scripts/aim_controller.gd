extends Node2D

# Manual aim is freely steered and never changes the world's tapped target.
# Selected-target bomb predictions share the exact live ballistic simulator.
const PROJECTILE = preload("res://scripts/projectile.gd")
const BOMB_SOLVER = preload("res://scripts/bomb_solver.gd")
const INPUT_DEADZONE: float = 0.20
const ASSIST_CONE: float = 16.0
const ASSIST_BLEND: float = 0.70
const ASSIST_MAX_CORRECTION: float = 12.0
const ASSIST_RANGE: float = 650.0
const BOMB_SPEED: float = 650.0
const PREVIEW_STEP: float = 1.0 / 120.0
const PREVIEW_STEPS: int = 720

var world
var player
var held: bool = false
var direction: Vector2 = Vector2.RIGHT
var raw_direction: Vector2 = Vector2.RIGHT
var assisted_target
var preview_points: PackedVector2Array = PackedVector2Array()
var preview_landing: Vector2 = Vector2.ZERO
var preview_settled: bool = false
var preview_launch: Dictionary = {}
var preview_result: Dictionary = {}
var bomb_failure_reason: String = ""
var solver_runs: int = 0
var _remembered_direction: Vector2 = Vector2.RIGHT
var _has_remembered_direction: bool = false
var _bomb_cache: Dictionary = {}
var _bomb_cache_target_id: int = 0
var _bomb_cache_player: Vector2 = Vector2(INF, INF)
var _bomb_cache_target: Vector2 = Vector2(INF, INF)
var _bomb_cache_limit: float = -1.0
var _bomb_cache_frame: int = -1000

func aim_origin() -> Vector2:
	return player.global_position + Vector2(0.0, -9.0) if is_instance_valid(player) else global_position

func update_aim(hold: bool, input: Vector2) -> void:
	held = hold
	assisted_target = null
	if not is_instance_valid(player):
		_clear_preview()
		return
	if held:
		if input.length() > INPUT_DEADZONE:
			raw_direction = input.normalized()
			_remembered_direction = raw_direction
			_has_remembered_direction = true
		else:
			raw_direction = _remembered_direction if _has_remembered_direction else Vector2(float(player.facing), 0.0)
		direction = _assisted_direction(raw_direction)
	else:
		raw_direction = Vector2(float(player.facing), 0.0)
		direction = raw_direction
	if _should_preview_bomb():
		preview_bomb()
	else:
		_clear_preview()
	queue_redraw()

func _assisted_direction(raw: Vector2) -> Vector2:
	var origin: Vector2 = aim_origin()
	var best_score: float = INF
	var correction: float = 0.0
	var candidates: Array = get_tree().get_nodes_in_group("training_targets")
	if is_instance_valid(world) and world.get("targets") is Array:
		candidates = world.targets
	for target in candidates:
		if not is_instance_valid(target) or not target is Node2D or not target.is_visible_in_tree():
			continue
		var offset: Vector2 = target.global_position - origin
		var distance: float = offset.length()
		if distance <= 0.01 or distance > ASSIST_RANGE:
			continue
		var angle: float = raw.angle_to(offset.normalized())
		if absf(angle) > deg_to_rad(ASSIST_CONE) or not _unobstructed(origin, target.global_position):
			continue
		# Angular closeness dominates. A small distance term breaks near ties
		# without snapping to whichever target was selected in a prior frame.
		var score: float = absf(angle) + distance / ASSIST_RANGE * 0.015
		if score < best_score:
			best_score = score
			assisted_target = target
			correction = clampf(angle * ASSIST_BLEND, -deg_to_rad(ASSIST_MAX_CORRECTION), deg_to_rad(ASSIST_MAX_CORRECTION))
	return raw.rotated(correction).normalized()

func _unobstructed(origin: Vector2, destination: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(origin, destination, 3)
	query.collide_with_areas = false
	query.hit_from_inside = true
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _selected_target():
	if not is_instance_valid(world) or not world.has_method("selected_target"):
		return null
	var target = world.selected_target()
	return target if is_instance_valid(target) and not target.is_queued_for_deletion() else null

func ranged_direction() -> Vector2:
	if held:
		return direction.normalized()
	var target = _selected_target()
	if is_instance_valid(target):
		var offset: Vector2 = target.global_position - aim_origin()
		if not offset.is_zero_approx():
			return offset.normalized()
	return Vector2(float(player.facing), 0.0) if is_instance_valid(player) else Vector2.RIGHT

func visible_world_width() -> float:
	var zoom: float = 1.0
	if is_instance_valid(world) and is_instance_valid(world.get("camera")):
		zoom = maxf(0.01, absf(world.camera.zoom.x))
	return get_viewport_rect().size.x / zoom

func bomb_launch() -> Dictionary:
	var launch_direction: Vector2 = direction.normalized() if held else Vector2(float(player.facing), -0.75).normalized()
	var origin: Vector2 = projectile_origin(launch_direction, 24.0, 9.0, 1)
	return {"origin": origin, "velocity": launch_direction * BOMB_SPEED, "launch_origin": player.global_position, "range_limit": visible_world_width() * 0.5, "valid": true, "reason": ""}

func projectile_origin(launch_direction: Vector2, reach: float = 25.0, clearance: float = 6.0, collision_mask: int = 3) -> Vector2:
	var origin: Vector2 = aim_origin()
	return PROJECTILE.safe_launch_origin(origin, origin + launch_direction.normalized() * reach, clearance, get_world_2d().direct_space_state, collision_mask)

func targeted_bomb_launch(target, force_refresh: bool = false) -> Dictionary:
	var limit: float = visible_world_width() * 0.5
	var source: Vector2 = aim_origin()
	var player_position: Vector2 = player.global_position if is_instance_valid(player) else source
	var target_valid: bool = is_instance_valid(target) and target is Node2D and not target.is_queued_for_deletion()
	if target_valid and not force_refresh and not _bomb_cache.is_empty() and _bomb_cache_target_id == target.get_instance_id() and absf(_bomb_cache_limit - limit) <= 0.01:
		var target_changed: bool = _bomb_cache_target.distance_to(target.global_position) > 3.0
		var changed: bool = _bomb_cache_player.distance_to(player_position) > 3.0 or target_changed
		var range_changed: bool = (absf(target.global_position.x - player_position.x) > limit) != (absf(_bomb_cache_target.x - _bomb_cache_player.x) > _bomb_cache_limit)
		# A blocked search tries many arcs. Retry that expensive preview at
		# most five times per second while moving; an actual throw always
		# requests force_refresh and never uses a stale failure or launch.
		var moving: bool = is_instance_valid(player) and player.velocity.length() > 40.0
		var recent_failure: bool = not bool(_bomb_cache.get("valid", false)) and not target_changed and moving and Engine.get_physics_frames() - _bomb_cache_frame < 24
		if not range_changed and (not changed or recent_failure):
			return _bomb_cache.duplicate(true)
	solver_runs += 1
	_bomb_cache = BOMB_SOLVER.solve(source, player_position, limit, target if target_valid else null, get_world_2d().direct_space_state)
	_bomb_cache_target_id = target.get_instance_id() if target_valid else 0
	_bomb_cache_player = player_position
	_bomb_cache_target = target.global_position if target_valid else Vector2(INF, INF)
	_bomb_cache_limit = limit
	_bomb_cache_frame = Engine.get_physics_frames()
	return _bomb_cache.duplicate(true)

func invalidate_bomb_cache() -> void:
	_bomb_cache = {}
	_bomb_cache_target_id = 0
	_bomb_cache_player = Vector2(INF, INF)
	_bomb_cache_target = Vector2(INF, INF)
	_bomb_cache_limit = -1.0
	_bomb_cache_frame = -1000

func preview_bomb(launch: Dictionary = {}) -> Dictionary:
	if not is_instance_valid(player):
		_clear_preview()
		return {}
	if launch.is_empty():
		var target = _selected_target()
		preview_launch = targeted_bomb_launch(target) if not held and is_instance_valid(target) else bomb_launch()
	else:
		preview_launch = launch.duplicate()
	if not bool(preview_launch.get("valid", true)):
		preview_points = PackedVector2Array()
		preview_landing = Vector2.ZERO
		preview_settled = false
		bomb_failure_reason = str(preview_launch.get("reason", "No safe bomb arc."))
		preview_result = {"valid": false, "reason": bomb_failure_reason, "points": preview_points, "settled": false}
		queue_redraw()
		return preview_result
	bomb_failure_reason = ""
	if preview_launch.has("points") and bool(preview_launch.get("settled", false)):
		preview_points = preview_launch.points
		preview_landing = preview_launch.landing
		preview_settled = true
		preview_result = {"points": preview_points, "position": preview_landing, "velocity": Vector2.ZERO, "settled": true, "origin": preview_launch.origin, "launch_origin": preview_launch.launch_origin, "range_limit": preview_launch.range_limit, "valid": true, "reason": ""}
		queue_redraw()
		return preview_result
	var position: Vector2 = preview_launch.origin
	var velocity: Vector2 = preview_launch.velocity
	var launch_origin: Vector2 = preview_launch.launch_origin
	var range_limit: float = float(preview_launch.range_limit)
	var space = get_world_2d().direct_space_state
	preview_points = PackedVector2Array([position])
	var state: Dictionary = {"position": position, "velocity": velocity, "settled": false}
	for step in range(PREVIEW_STEPS):
		state = PROJECTILE.simulate_orb_step(position, velocity, PREVIEW_STEP, launch_origin, range_limit, space)
		position = state.position
		velocity = state.velocity
		preview_points.append(position)
		if state.settled:
			break
	preview_landing = position
	preview_settled = bool(state.settled)
	preview_result = {"points": preview_points, "position": position, "velocity": velocity, "settled": preview_settled, "origin": preview_launch.origin, "launch_origin": launch_origin, "range_limit": range_limit, "valid": true, "reason": ""}
	queue_redraw()
	return preview_result

func _should_preview_bomb() -> bool:
	if (not held and not is_instance_valid(_selected_target())) or not is_instance_valid(world) or not is_instance_valid(world.get("abilities")):
		return false
	var kit = world.abilities
	if kit.has_method("boomerang_active") and kit.boomerang_active():
		return false
	return kit.has_method("selected_weapon_name") and kit.selected_weapon_name() == "Bomb" and not is_instance_valid(kit.orb)

func _clear_preview() -> void:
	preview_points = PackedVector2Array()
	preview_landing = Vector2.ZERO
	preview_settled = false
	preview_launch = {}
	preview_result = {}
	bomb_failure_reason = ""

func cancel() -> void:
	held = false
	assisted_target = null
	_clear_preview()
	invalidate_bomb_cache()
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(player) or (not held and preview_points.is_empty() and bomb_failure_reason.is_empty()):
		return
	if held:
		var origin: Vector2 = to_local(aim_origin())
		var reticle: Vector2 = origin + direction * 150.0
		draw_line(origin + direction * 26.0, reticle - direction * 9.0, Color(0.66, 0.91, 0.87, 0.40), 1.5)
		draw_arc(reticle, 7.0, 0.0, TAU, 20, Color("b9e8d6"), 1.5)
		var side: Vector2 = direction.orthogonal()
		draw_line(reticle - side * 11.0, reticle - side * 5.0, Color("b9e8d6"), 1.5)
		draw_line(reticle + side * 5.0, reticle + side * 11.0, Color("b9e8d6"), 1.5)
	if held and is_instance_valid(assisted_target):
		var center: Vector2 = to_local(assisted_target.global_position)
		# Two faint corner strokes communicate assistance without a lock ring.
		for sign_x in [-1.0, 1.0]:
			var corner: Vector2 = center + Vector2(sign_x * 23.0, -30.0)
			draw_line(corner, corner + Vector2(-sign_x * 7.0, 0.0), Color(0.67, 0.94, 0.84, 0.45), 1.5)
			draw_line(corner, corner + Vector2(0.0, 7.0), Color(0.67, 0.94, 0.84, 0.45), 1.5)
	if not bomb_failure_reason.is_empty():
		draw_string(ThemeDB.fallback_font, to_local(player.global_position) + Vector2(-68.0, -57.0), "BOMB PATH UNAVAILABLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("eab89b"))
	var accumulated: float = 0.0
	for index in range(1, preview_points.size()):
		accumulated += preview_points[index - 1].distance_to(preview_points[index])
		if accumulated >= 16.0:
			draw_circle(to_local(preview_points[index]), 2.2, Color(0.66, 0.92, 0.97, 0.70))
			accumulated = 0.0
	if preview_settled:
		var landing: Vector2 = to_local(preview_landing)
		draw_arc(landing, 10.0, 0.0, TAU, 28, Color("b4f4eb"), 2.0)
		draw_line(landing + Vector2(-16.0, 9.0), landing + Vector2(16.0, 9.0), Color("b4f4eb"), 2.0)
		draw_line(landing + Vector2(0.0, -15.0), landing + Vector2(0.0, -7.0), Color("b4f4eb"), 2.0)
