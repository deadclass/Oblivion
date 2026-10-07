extends CharacterBody2D

signal hard_landing(drop_distance: float)

@export var run_speed: float = 255.0
@export var ground_acceleration: float = 2100.0
@export var air_acceleration: float = 1400.0
@export var braking: float = 2600.0
@export var gravity: float = 1450.0
@export var fall_gravity: float = 1850.0
@export var jump_speed: float = 550.0
@export var terminal_speed: float = 800.0
@export var coyote_time: float = 0.105
@export var jump_buffer_time: float = 0.12
@export var jump_cut_speed: float = 210.0
@export var large_fall_threshold: float = 180.0
var fall_tracking: bool = false
var fall_apex_y: float = 0.0
var damage_flash: float = 0.0
var coyote: float = 0.0
var jump_buffer: float = 0.0
var carrying: bool = false
var facing: float = 1.0
var jump_count: int = 0
var test_control: bool = false
var test_axis: float = 0.0
var test_jump_pressed: bool = false
var test_jump_held: bool = false
var knockback_time: float = 0.0

func _ready() -> void:
	# Separate the player from the loose weight's world-only collision mask.
	collision_layer = 8
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(22, 32)
	shape.shape = box
	add_child(shape)
	floor_snap_length = 5.0
	floor_stop_on_slope = true
	platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING

func _physics_process(delta: float) -> void:
	damage_flash = maxf(0.0,damage_flash-delta)
	var axis := test_axis if test_control else Input.get_axis("left", "right")
	var pressed := test_jump_pressed if test_control else Input.is_action_just_pressed("jump")
	var held := test_jump_held if test_control else Input.is_action_pressed("jump")
	test_jump_pressed = false
	if is_on_floor():
		coyote = coyote_time
	else:
		coyote = maxf(0.0, coyote - delta)
	jump_buffer = jump_buffer_time if pressed else maxf(0.0, jump_buffer - delta)
	var target := axis * run_speed * (0.84 if carrying else 1.0)
	var acceleration := ground_acceleration if is_on_floor() else air_acceleration
	if is_zero_approx(axis) and is_on_floor():
		acceleration = braking
	if knockback_time>0:
		knockback_time = maxf(0.0,knockback_time-delta)
	else:
		velocity.x = move_toward(velocity.x, target, acceleration * delta)
	if axis != 0:
		facing = signf(axis)
	velocity.y = minf(velocity.y + (fall_gravity if velocity.y > 0 else gravity) * delta, terminal_speed)
	if jump_buffer > 0 and coyote > 0:
		velocity.y = -jump_speed
		jump_buffer = 0.0
		coyote = 0.0
		jump_count += 1
	if not held and velocity.y < -jump_cut_speed:
		velocity.y = -jump_cut_speed
	var before_y := position.y
	if not is_on_floor() or velocity.y < 0:
		if not fall_tracking:
			fall_tracking = true
			fall_apex_y = before_y
		fall_apex_y = minf(fall_apex_y,before_y)
	move_and_slide()
	if not is_on_floor() and not fall_tracking:
		fall_tracking = true
		fall_apex_y = before_y
	if is_on_floor() and fall_tracking:
		var drop := position.y-fall_apex_y
		fall_tracking = false
		if drop >= large_fall_threshold:
			hard_landing.emit(drop)
	queue_redraw()

func reset_at(point: Vector2) -> void:
	position = point
	velocity = Vector2.ZERO
	coyote = 0.0
	jump_buffer = 0.0
	fall_tracking = false
	fall_apex_y = point.y
	knockback_time = 0.0

func apply_knockback(source_position: Vector2) -> void:
	var direction := signf(position.x-source_position.x)
	if is_zero_approx(direction):
		direction = -facing
	velocity.x = direction*165
	velocity.y = -90
	knockback_time = 0.16
	damage_flash = 0.55

func _draw() -> void:
	draw_circle(Vector2(0, -6), 25, Color(0.7, 0.87, 0.7, 0.05))
	draw_rect(Rect2(-11, -16, 22, 32), Color("ff8d79") if damage_flash > 0 else Color("cbd4b4"))
	draw_rect(Rect2(-8, -13, 16, 10), Color("354d53"))
	draw_circle(Vector2(facing * 4, -8), 3, Color("f6d48a"))
	draw_line(Vector2(-7, 17), Vector2(7, 17), Color("70827c"), 3)
