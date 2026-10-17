extends CharacterBody2D

signal landed

@export var run_speed: float = 400.0
@export var air_speed: float = 320.0
@export var ground_acceleration: float = 3400.0
@export var air_acceleration: float = 1800.0
@export var braking: float = 4800.0
@export var air_braking: float = 600.0
@export var gravity: float = 1400.0
@export var fall_gravity: float = 1850.0
@export var jump_speed: float = 620.0
@export var air_jump_speed: float = 540.0
@export var jump_cut_speed: float = 260.0
@export var terminal_speed: float = 760.0
@export var fastfall_speed: float = 1100.0
@export var coyote_time: float = 0.09
@export var jump_buffer_time: float = 0.12
@export var dodge_speed: float = 480.0
@export var air_dodge_duration: float = 0.20
@export var air_dodge_recovery: float = 0.16
@export var roll_speed: float = 520.0
@export var roll_duration: float = 0.24
@export var spot_dodge_duration: float = 0.20
@export var ground_dash_speed: float = 620.0
@export var air_dash_speed: float = 560.0
@export var dash_duration: float = 0.18
@export var dash_recovery: float = 0.10
@export var dash_cooldown_duration: float = 0.55
@export var recovery_speed: float = 620.0
@export var recovery_duration: float = 0.34

var facing: float = 1.0
var blocking: bool = false
var crouching: bool = false
var jump_count: int = 0
var jumps_remaining: int = 2
var dodge_available: bool = true
var dash_available: bool = true
var recovery_used: bool = false
var helpless: bool = false
var action_lock_time: float = 0.0
var hitstop_time: float = 0.0
var fastfall: bool = false
var is_dodging: bool = false
var rolling: bool = false
var dodge_time: float = 0.0
var is_dashing: bool = false
var dash_time: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT
var dash_cooldown: float = 0.0
var coyote: float = 0.0
var jump_buffer: float = 0.0
var damage_flash: float = 0.0
var block_flash: float = 0.0
var boomerang_form: bool = false

# Deterministic movement fixtures use the same controller as live input.
var test_control: bool = false
var test_axis: float = 0.0
var test_vertical: float = 0.0
var test_jump_pressed: bool = false
var test_jump_held: bool = false
var test_block_pressed: bool = false
var test_block_held: bool = false
var test_dodge_pressed: bool = false

var _dodge_vector: Vector2 = Vector2.ZERO
var _dodge_grounded: bool = false
var _dash_airborne: bool = false
var _recovery_time: float = 0.0
var _drop_time: float = 0.0
var _jump_cuttable: bool = false
var _grounded_last_frame: bool = false
var _previous_vertical: float = 0.0

func _ready() -> void:
	collision_layer = 8
	collision_mask = 3
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(22, 36)
	shape.shape = box
	add_child(shape)
	floor_snap_length = 4.0
	floor_stop_on_slope = true
	platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING
	queue_redraw()

func _input_ready() -> bool:
	var host := get_parent()
	if host == null:
		return true
	var controls: Variant = host.get("controls")
	return controls == null or controls.gameplay_ready()

func can_act() -> bool:
	return not boomerang_form and not helpless and not blocking and not is_dodging and not rolling and not is_dashing and action_lock_time <= 0.0 and hitstop_time <= 0.0

func _block_requested() -> bool:
	# World requests dash before this node ticks; check a newly held shield too.
	return test_block_held if test_control else (_input_ready() and Input.is_action_pressed("block"))

func _physics_process(delta: float) -> void:
	damage_flash = maxf(0.0, damage_flash - delta)
	block_flash = maxf(0.0, block_flash - delta)
	if hitstop_time > 0.0:
		hitstop_time = maxf(0.0, hitstop_time - delta)
		queue_redraw()
		return
	if boomerang_form:
		# The form owns travel. Neither gravity nor buffered input can spend
		# a jump/dash/dodge or refresh those resources during the excursion.
		test_jump_pressed = false
		test_block_pressed = false
		test_dodge_pressed = false
		queue_redraw()
		return
	action_lock_time = maxf(0.0, action_lock_time - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	_drop_time = maxf(0.0, _drop_time - delta)
	set_collision_mask_value(2, _drop_time <= 0.0)
	if _recovery_time > 0.0:
		_recovery_time = maxf(0.0, _recovery_time - delta)
		if _recovery_time <= 0.0:
			finish_recovery()
	var ready_for_input: bool = test_control or _input_ready()
	var axis: float = test_axis if test_control else (Input.get_axis("left", "right") if ready_for_input else 0.0)
	var vertical: float = test_vertical if test_control else (Input.get_axis("up", "down") if ready_for_input else 0.0)
	var dodge_direction := Vector2(axis, vertical)
	var pressed: bool = test_jump_pressed if test_control else (ready_for_input and Input.is_action_just_pressed("jump"))
	var held: bool = test_jump_held if test_control else (ready_for_input and Input.is_action_pressed("jump"))
	var block_held: bool = test_block_held if test_control else (ready_for_input and Input.is_action_pressed("block"))
	var dodge_pressed: bool = test_dodge_pressed if test_control else (ready_for_input and Input.is_action_just_pressed("dodge"))
	var down_pressed: bool = vertical > 0.55 and _previous_vertical <= 0.55
	test_jump_pressed = false
	test_block_pressed = false
	test_dodge_pressed = false
	_previous_vertical = vertical
	var grounded: bool = is_on_floor()
	coyote = coyote_time if grounded else maxf(0.0, coyote - delta)
	jump_buffer = jump_buffer_time if pressed else maxf(0.0, jump_buffer - delta)
	blocking = false
	crouching = false
	if dodge_pressed and not block_held and can_act():
		request_dodge(dodge_direction)
	if grounded and block_held and not is_dodging and not rolling and not is_dashing and not helpless and action_lock_time <= 0.0:
		blocking = true
	crouching = grounded and vertical > 0.55 and not blocking and action_lock_time <= 0.0
	if down_pressed and not grounded and velocity.y > 0.0 and not is_dodging and not is_dashing:
		fastfall = true
	if jump_buffer > 0.0 and not helpless and not is_dodging and not rolling and not is_dashing and action_lock_time <= 0.0:
		# Jumping out of shield is allowed; shield does not trap the player.
		if grounded and vertical > 0.55 and _standing_on_one_way():
			_drop_through()
		elif grounded or coyote > 0.0:
			_jump(false)
		elif jumps_remaining > 0:
			_jump(true)
	if is_dashing:
		dash_time = maxf(0.0, dash_time - delta)
		velocity = dash_direction * (air_dash_speed if _dash_airborne else ground_dash_speed)
		if not _dash_airborne:
			velocity.y = minf(velocity.y + fall_gravity * delta, terminal_speed)
		if dash_time <= 0.0:
			is_dashing = false
			velocity *= 0.38
	elif is_dodging or rolling:
		dodge_time = maxf(0.0, dodge_time - delta)
		velocity = _dodge_vector * (roll_speed if rolling else dodge_speed)
		if _dodge_grounded:
			velocity.y = minf(velocity.y + fall_gravity * delta, terminal_speed)
		if dodge_time <= 0.0:
			is_dodging = false
			rolling = false
			velocity *= 0.38
	else:
		var speed: float = run_speed if grounded else air_speed
		var target: float = axis * speed
		if blocking:
			target = 0.0
		elif crouching:
			target *= 0.30
		var acceleration: float = ground_acceleration if grounded else air_acceleration
		if is_zero_approx(axis) or blocking:
			acceleration = braking if grounded else air_braking
		velocity.x = move_toward(velocity.x, target, acceleration * delta)
		if not is_zero_approx(axis) and not blocking and action_lock_time <= 0.0:
			facing = signf(axis)
		var vertical_limit: float = fastfall_speed if fastfall else terminal_speed
		if fastfall:
			velocity.y = maxf(velocity.y, fastfall_speed)
		else:
			velocity.y = minf(velocity.y + (fall_gravity if velocity.y > 0.0 else gravity) * delta, vertical_limit)
		if _jump_cuttable and not held and velocity.y < -jump_cut_speed:
			velocity.y = -jump_cut_speed
		if velocity.y >= 0.0:
			_jump_cuttable = false
	move_and_slide()
	if is_on_floor():
		_refresh_airtime()
		if not _grounded_last_frame:
			landed.emit()
	elif grounded and jumps_remaining == 2 and velocity.y >= 0.0:
		# Walking off consumes the grounded jump, preserving one air jump.
		jumps_remaining = 1
	_grounded_last_frame = is_on_floor()
	queue_redraw()

func request_jump() -> void:
	if boomerang_form:
		return
	jump_buffer = jump_buffer_time

func _jump(air_jump: bool) -> void:
	velocity.y = -air_jump_speed if air_jump else -jump_speed
	jumps_remaining = 0 if air_jump else 1
	jump_count += 1
	jump_buffer = 0.0
	coyote = 0.0
	blocking = false
	crouching = false
	fastfall = false
	_jump_cuttable = true

func request_dodge(direction: Vector2) -> bool:
	if not can_act() or _block_requested():
		return false
	_dodge_grounded = is_on_floor()
	if _dodge_grounded:
		if absf(direction.x) >= 0.25:
			_dodge_vector = Vector2(signf(direction.x), 0.0)
			facing = _dodge_vector.x
			rolling = true
			dodge_time = roll_duration
		else:
			_dodge_vector = Vector2.ZERO
			is_dodging = true
			dodge_time = spot_dodge_duration
		action_lock_time = dodge_time + 0.10
	else:
		if not dodge_available:
			return false
		dodge_available = false
		is_dodging = true
		# Neutral dodge avoids forced drift; direction is snapped to eight ways.
		var angle: float = snappedf(direction.angle(), PI / 4.0)
		_dodge_vector = Vector2.ZERO if direction.length() < 0.25 else Vector2.from_angle(angle)
		dodge_time = air_dodge_duration
		action_lock_time = air_dodge_duration + air_dodge_recovery
	blocking = false
	fastfall = false
	_jump_cuttable = false
	velocity = _dodge_vector * (roll_speed if rolling else dodge_speed)
	return true

func request_dash(direction: Vector2, combo_override: bool = false) -> bool:
	# Only the short sword-to-dash chord may bypass an existing sword lock.
	if boomerang_form or helpless or blocking or is_dodging or rolling or is_dashing or hitstop_time > 0.0 or (action_lock_time > 0.0 and not combo_override) or _block_requested() or dash_cooldown > 0.0:
		return false
	_dash_airborne = not is_on_floor()
	if _dash_airborne:
		if not dash_available:
			return false
		dash_available = false
		# Keep the full analog angle. Dash has its own airtime resource.
		dash_direction = direction.normalized() if direction.length() >= 0.25 else Vector2(facing, 0.0)
	else:
		dash_direction = Vector2(signf(direction.x) if absf(direction.x) >= 0.25 else facing, 0.0)
	if absf(dash_direction.x) > 0.05:
		facing = signf(dash_direction.x)
	is_dashing = true
	dash_time = dash_duration
	dash_cooldown = dash_cooldown_duration
	action_lock_time = maxf(action_lock_time, dash_duration + dash_recovery)
	blocking = false
	crouching = false
	fastfall = false
	_jump_cuttable = false
	velocity = dash_direction * (air_dash_speed if _dash_airborne else ground_dash_speed)
	queue_redraw()
	return true

func cancel_transients() -> void:
	# Pause/unplug cancels momentum abilities without granting another air use.
	if boomerang_form:
		var host := get_parent()
		var kit: Variant = host.get("abilities") if host != null else null
		if is_instance_valid(kit) and kit.has_method("cancel_boomerang"):
			kit.cancel_boomerang()
	if is_dashing or is_dodging or rolling:
		velocity = Vector2.ZERO
	is_dashing = false
	dash_time = 0.0
	is_dodging = false
	rolling = false
	dodge_time = 0.0
	_dodge_vector = Vector2.ZERO
	_dodge_grounded = false
	blocking = false
	crouching = false
	action_lock_time = 0.0
	hitstop_time = 0.0
	jump_buffer = 0.0
	test_jump_pressed = false
	test_block_pressed = false
	test_dodge_pressed = false
	if _recovery_time > 0.0:
		finish_recovery()
	queue_redraw()

func begin_boomerang_form() -> Dictionary:
	if not can_act():
		return {}
	var saved: Dictionary = {
		"jumps_remaining": jumps_remaining, "jump_count": jump_count,
		"dodge_available": dodge_available, "dash_available": dash_available,
		"dash_cooldown": dash_cooldown, "recovery_used": recovery_used,
		"helpless": helpless, "fastfall": fastfall, "coyote": coyote,
		"drop_time": _drop_time, "jump_cuttable": _jump_cuttable,
		"grounded_last_frame": _grounded_last_frame, "facing": facing,
		"collision_layer": collision_layer, "collision_mask": collision_mask,
	}
	boomerang_form = true
	# The ordinary body is absent while a circle sweep constrains the form.
	# Keeping the CharacterBody out of collision queries avoids a duplicate.
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	blocking = false
	crouching = false
	jump_buffer = 0.0
	_jump_cuttable = false
	queue_redraw()
	return saved

func end_boomerang_form(origin: Vector2, saved: Dictionary) -> void:
	if not boomerang_form:
		return
	global_position = origin
	jumps_remaining = saved.get("jumps_remaining", jumps_remaining)
	jump_count = saved.get("jump_count", jump_count)
	dodge_available = saved.get("dodge_available", dodge_available)
	dash_available = saved.get("dash_available", dash_available)
	dash_cooldown = saved.get("dash_cooldown", dash_cooldown)
	recovery_used = saved.get("recovery_used", recovery_used)
	helpless = saved.get("helpless", helpless)
	fastfall = saved.get("fastfall", fastfall)
	coyote = saved.get("coyote", coyote)
	_drop_time = saved.get("drop_time", _drop_time)
	_jump_cuttable = saved.get("jump_cuttable", false)
	_grounded_last_frame = saved.get("grounded_last_frame", false)
	facing = saved.get("facing", facing)
	collision_layer = saved.get("collision_layer", 8)
	collision_mask = saved.get("collision_mask", 3)
	velocity = Vector2.ZERO
	jump_buffer = 0.0
	hitstop_time = 0.0
	blocking = false
	crouching = false
	test_jump_pressed = false
	test_block_pressed = false
	test_dodge_pressed = false
	boomerang_form = false
	queue_redraw()

func start_recovery() -> bool:
	if not can_act() or recovery_used:
		return false
	recovery_used = true
	_recovery_time = recovery_duration
	action_lock_time = maxf(action_lock_time, recovery_duration)
	velocity.y = -recovery_speed
	jumps_remaining = mini(jumps_remaining, 1)
	fastfall = false
	_jump_cuttable = false
	blocking = false
	coyote = 0.0
	return true

func finish_recovery() -> void:
	_recovery_time = 0.0
	if not is_on_floor():
		helpless = true
		blocking = false

func _refresh_airtime() -> void:
	jumps_remaining = 2
	dodge_available = true
	dash_available = true
	recovery_used = false
	helpless = false
	fastfall = false
	_jump_cuttable = false
	_recovery_time = 0.0
	if is_dodging and not _dodge_grounded:
		is_dodging = false
		dodge_time = 0.0

func _standing_on_one_way() -> bool:
	for index in get_slide_collision_count():
		var contact := get_slide_collision(index)
		var collider: Variant = contact.get_collider()
		if contact.get_normal().y < -0.5 and collider is CollisionObject2D and collider.get_collision_layer_value(2):
			return true
	return false

func _drop_through() -> void:
	_drop_time = 0.24
	set_collision_mask_value(2, false)
	position.y += 3.0
	velocity.y = 90.0
	jump_buffer = 0.0
	coyote = 0.0
	jumps_remaining = 1
	blocking = false
	crouching = false
	_jump_cuttable = false

func reset_at(point: Vector2) -> void:
	cancel_transients()
	position = point
	velocity = Vector2.ZERO
	coyote = 0.0
	jump_buffer = 0.0
	jump_count = 0
	action_lock_time = 0.0
	hitstop_time = 0.0
	dodge_time = 0.0
	is_dodging = false
	rolling = false
	dash_cooldown = 0.0
	dash_direction = Vector2(facing, 0.0)
	_dash_airborne = false
	_drop_time = 0.0
	set_collision_mask_value(2, true)
	blocking = false
	crouching = false
	block_flash = 0.0
	damage_flash = 0.0
	_grounded_last_frame = false
	_previous_vertical = 0.0
	test_jump_pressed = false
	test_block_pressed = false
	test_dodge_pressed = false
	_refresh_airtime()
	queue_redraw()

func _draw() -> void:
	if boomerang_form:
		return
	var body_color := Color("e7d9b2")
	if helpless:
		body_color = Color("929ca7")
	elif is_dashing:
		body_color = Color("ffe0a1")
	elif is_dodging or rolling:
		body_color = Color("9ed9f0")
	if damage_flash > 0.0:
		body_color = Color("ff917d")
	var height: float = 25.0 if crouching else 36.0
	draw_circle(Vector2(0, -4), 29, Color(0.77, 0.84, 0.88, 0.05))
	draw_rect(Rect2(-11, 18.0 - height, 22, height), body_color)
	draw_rect(Rect2(-9, 18.0 - height, 18, 9), Color("334d64"))
	draw_circle(Vector2(facing * 4, 24.0 - height), 3, Color("ffe1a0"))
	draw_line(Vector2(-7, 18), Vector2(7, 18), Color("708ba1"), 3)
	if blocking or block_flash > 0.0:
		draw_circle(Vector2(0, -2), 27, Color(0.36, 0.84, 0.95, 0.18))
		draw_arc(Vector2(0, -2), 27, 0, TAU, 40, Color("a9eaff"), 3)
	if is_dodging or rolling:
		draw_arc(Vector2(0, -2), 24, -1.2, 1.2, 20, Color("c9f2ff"), 2)
	if is_dashing:
		var trail: Vector2 = -dash_direction
		for index in range(3):
			var offset: Vector2 = trail * (22.0 + float(index) * 13.0)
			draw_line(Vector2(0, -2) + offset - Vector2(0, 11), Vector2(0, -2) + offset + Vector2(0, 11), Color(1.0, 0.75, 0.36, 0.50 - float(index) * 0.12), 3.0)
	if fastfall:
		draw_line(Vector2(-15, -10), Vector2(-15, -32), Color("8bb5d3"), 2)
		draw_line(Vector2(15, -10), Vector2(15, -32), Color("8bb5d3"), 2)

