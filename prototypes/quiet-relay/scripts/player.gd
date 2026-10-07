extends CharacterBody2D

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
var coyote: float = 0.0
var jump_buffer: float = 0.0
var carrying: bool = false
var facing: float = 1.0
var jump_count: int = 0
var test_control: bool = false
var test_axis: float = 0.0
var test_jump_pressed: bool = false
var test_jump_held: bool = false

func _ready() -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(22, 32)
	shape.shape = box
	add_child(shape)
	floor_snap_length = 5.0
	floor_stop_on_slope = true

func _physics_process(delta: float) -> void:
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
	move_and_slide()
	queue_redraw()

func reset_at(point: Vector2) -> void:
	position = point
	velocity = Vector2.ZERO
	coyote = 0.0
	jump_buffer = 0.0

func _draw() -> void:
	draw_circle(Vector2(0, -6), 25, Color(0.7, 0.87, 0.7, 0.05))
	draw_rect(Rect2(-11, -16, 22, 32), Color("cbd4b4"))
	draw_rect(Rect2(-8, -13, 16, 10), Color("354d53"))
	draw_circle(Vector2(facing * 4, -8), 3, Color("f6d48a"))
	draw_line(Vector2(-7, 17), Vector2(7, 17), Color("70827c"), 3)
