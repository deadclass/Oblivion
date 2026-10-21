extends RefCounted

# Seeds are only proposals. A throw is accepted after the shared live bomb
# simulation reaches its first actual landing beside the selected target.
const PROJECTILE = preload("res://scripts/projectile.gd")
const STEP: float = 1.0 / 120.0
const MAX_STEPS: int = 720
const GRAVITY: float = 1100.0
const TERMINAL_SPEED: float = 700.0
const MAX_LAUNCH_SPEED: float = 1000.0
const LAUNCH_REACH: float = 24.0
const BOMB_RADIUS: float = 9.0
const TARGET_HALF_HEIGHT: float = 22.0
const LANDING_TOLERANCE: float = 55.0
const SUPPORT_TOLERANCE: float = 18.0
const LANDING_OFFSETS = [0.0, -24.0, 24.0, -45.0, 45.0]
const FLIGHT_TIMES = [
	0.16, 0.20, 0.24, 0.28, 0.32, 0.36, 0.40, 0.44,
	0.48, 0.52, 0.56, 0.60, 0.66, 0.72, 0.80, 0.88,
	0.96, 1.04, 1.12, 1.20, 1.32, 1.44, 1.60, 1.76,
	1.92, 2.16, 2.40, 2.64, 2.88, 3.20, 3.60, 4.00,
	4.50, 5.00, 5.50, 6.00
]

static func solve(source: Vector2, launch_origin: Vector2, range_limit: float, target: Node2D, space) -> Dictionary:
	var failure: Dictionary = _failure(source, launch_origin, range_limit, "No safe bomb arc lands near this target.")
	if not source.is_finite() or not launch_origin.is_finite() or not is_finite(range_limit) or range_limit <= 0.0:
		failure.reason = "Bomb launch position or range is invalid."
		return failure
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		failure.reason = "The selected target is no longer available."
		return failure
	if space == null:
		failure.reason = "Bomb trajectory physics are unavailable."
		return failure
	var target_position: Vector2 = target.global_position
	if not target_position.is_finite():
		failure.reason = "The selected target position is invalid."
		return failure
	if absf(target_position.x - launch_origin.x) > range_limit:
		failure.reason = "The selected target is outside the bomb's half-screen range."
		return failure
	# The ray lands on the support surface before the live step offsets the
	# bomb center by its radius. Aiming the ray at the target center would
	# overshoot by an entire body half-height on elevated platforms.
	var support: Vector2 = target_position + Vector2(0.0, TARGET_HALF_HEIGHT)
	var expected_landing: Vector2 = support - Vector2(0.0, BOMB_RADIUS)
	var horizontal_sign: float = 1.0 if target_position.x >= source.x else -1.0
	for proposed_time in FLIGHT_TIMES:
		var frames: int = clampi(roundi(float(proposed_time) / STEP), 1, MAX_STEPS)
		# A nearby landing point can avoid a platform edge intercepting an
		# otherwise valid descending arc. Every offset uses the same oracle.
		for horizontal_offset in LANDING_OFFSETS:
			var proposed_support: Vector2 = support + Vector2(float(horizontal_offset) * horizontal_sign, 0.0)
			if absf(proposed_support.x - launch_origin.x) > range_limit:
				continue
			var candidate: Dictionary = _candidate(source, launch_origin, range_limit, proposed_support, target_position, expected_landing, frames, space)
			if not candidate.is_empty():
				return candidate
	return failure

static func _candidate(source: Vector2, launch_origin: Vector2, range_limit: float, support: Vector2, target_position: Vector2, expected_landing: Vector2, frames: int, space) -> Dictionary:
	var time: float = frames * STEP
	var origin: Vector2 = source
	var velocity: Vector2 = Vector2.ZERO
	# The muzzle offset depends on the eventual arc heading, and may be
	# shortened by a nearby wall. Iterate it rather than assuming open air.
	for iteration in range(4):
		var vertical: float = _vertical_speed(support.y - origin.y, frames)
		if not is_finite(vertical):
			return {}
		velocity = Vector2((support.x - origin.x) / time, vertical)
		if velocity.is_zero_approx():
			return {}
		var desired: Vector2 = source + velocity.normalized() * LAUNCH_REACH
		origin = PROJECTILE.safe_launch_origin(source, desired, BOMB_RADIUS, space)
		origin.x = clampf(origin.x, launch_origin.x - range_limit, launch_origin.x + range_limit)
	# Keep the last heading that produced this safe origin. A final velocity
	# recomputation can flip a very close vertical throw while leaving its
	# muzzle on the opposite side of the player. The live trace, rather than
	# the approximate seed endpoint, decides whether this arc is usable.
	if velocity.length() > MAX_LAUNCH_SPEED:
		return {}
	# A support offset may straddle the launcher for a very close dummy.
	# Do not turn that into a visibly backward targeted throw.
	if (target_position.x - source.x) * velocity.x < -0.001:
		return {}
	var traced: Dictionary = _trace(origin, velocity, launch_origin, range_limit, space)
	if not traced.settled:
		return {}
	var landing: Vector2 = traced.landing
	if landing.distance_to(target_position) > LANDING_TOLERANCE or absf(landing.y - expected_landing.y) > SUPPORT_TOLERANCE:
		return {}
	# Landing close is not sufficient when a solid wall would also stop
	# the live explosion's line-of-sight check from reaching the dummy.
	var blast_ray := PhysicsRayQueryParameters2D.create(landing, target_position, 1)
	blast_ray.collide_with_areas = false
	if not space.intersect_ray(blast_ray).is_empty():
		return {}
	return {
		"origin": origin,
		"velocity": velocity,
		"launch_origin": launch_origin,
		"range_limit": range_limit,
		"valid": true,
		"reason": "",
		"points": traced.points,
		"landing": landing,
		"flight_time": traced.flight_time,
		"settled": true
	}

static func _failure(source: Vector2, launch_origin: Vector2, range_limit: float, reason: String) -> Dictionary:
	# Zero velocity and no points make invalid results unambiguously inert;
	# the caller must not convert them into an ordinary/manual throw.
	return {
		"origin": source,
		"velocity": Vector2.ZERO,
		"launch_origin": launch_origin,
		"range_limit": range_limit,
		"valid": false,
		"reason": reason,
		"points": PackedVector2Array(),
		"landing": source,
		"flight_time": 0.0,
		"settled": false
	}

static func _vertical_speed(displacement: float, frames: int) -> float:
	# This sum exactly matches semi-implicit gravity and terminal clamping
	# at 120Hz. It avoids a continuous-parabola mismatch on long falling arcs.
	var minimum: float = -MAX_LAUNCH_SPEED
	var maximum: float = TERMINAL_SPEED
	if displacement < _vertical_displacement(minimum, frames) or displacement > _vertical_displacement(maximum, frames):
		return INF
	for iteration in range(22):
		var middle: float = (minimum + maximum) * 0.5
		if _vertical_displacement(middle, frames) < displacement:
			minimum = middle
		else:
			maximum = middle
	return (minimum + maximum) * 0.5

static func _vertical_displacement(speed: float, frames: int) -> float:
	var gravity_step: float = GRAVITY * STEP
	var accelerating_frames: int = clampi(floori((TERMINAL_SPEED - speed) / gravity_step), 0, frames)
	var count: float = float(accelerating_frames)
	var moving_sum: float = count * speed + gravity_step * count * (count + 1.0) * 0.5
	return STEP * (moving_sum + float(frames - accelerating_frames) * TERMINAL_SPEED)

static func _trace(origin: Vector2, incoming_velocity: Vector2, launch_origin: Vector2, range_limit: float, space) -> Dictionary:
	var position: Vector2 = origin
	var velocity: Vector2 = incoming_velocity
	var points := PackedVector2Array([origin])
	for step in range(MAX_STEPS):
		var state: Dictionary = PROJECTILE.simulate_orb_step(position, velocity, STEP, launch_origin, range_limit, space)
		position = state.position
		velocity = state.velocity
		points.append(position)
		if state.settled:
			return {"points": points, "landing": position, "flight_time": float(step + 1) * STEP, "settled": true}
		if position.y > 1200.0 or absf(position.x) > 4000.0:
			break
	return {"points": points, "landing": position, "flight_time": float(points.size() - 1) * STEP, "settled": false}
