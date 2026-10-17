extends CharacterBody2D

@export var gravity: float = 1600.0
@export var braking: float = 900.0
@export var reset_delay: float = 2.5
var target_name: String = "Target"
var spawn_position: Vector2
var percent: float = 0.0
var hit_count: int = 0
var last_move: String = "No hits yet"
var last_damage: float = 0.0
var hitstun: float = 0.0
var damage_flash: float = 0.0
var idle_time: float = 0.0
var last_impulse: Vector2 = Vector2.ZERO
var _label_time: float = 0.0
var _hit_label: String = ""
var _has_been_hit: bool = false

func _ready() -> void:
	spawn_position = position
	collision_layer = 0
	collision_mask = 3
	add_to_group("training_targets")
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(30, 44)
	shape.shape = box
	add_child(shape)
	var target := Area2D.new()
	target.name = "HitTarget"
	target.collision_layer = 4
	target.collision_mask = 0
	target.monitoring = false
	target.monitorable = true
	var target_shape := CollisionShape2D.new()
	target_shape.shape = box
	target.add_child(target_shape)
	add_child(target)
	floor_snap_length = 3.0
	floor_stop_on_slope = true
	platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING
	queue_redraw()

func _physics_process(delta: float) -> void:
	hitstun = maxf(0.0, hitstun - delta)
	damage_flash = maxf(0.0, damage_flash - delta)
	_label_time = maxf(0.0, _label_time - delta)
	if _has_been_hit:
		idle_time += delta
	velocity.y = minf(velocity.y + gravity * delta, 1000.0)
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, braking * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 100.0 * delta)
	move_and_slide()
	var host := get_parent()
	var width: float = 1600.0 if host == null or host.get("arena_width") == null else float(host.get("arena_width"))
	if position.y > 900.0 or position.x < -100.0 or position.x > width + 100.0 or (_has_been_hit and idle_time >= reset_delay and hitstun <= 0.0):
		_return_home()
	queue_redraw()

func accept_hit(damage: float, impulse: Vector2, move_name: String) -> bool:
	if damage <= 0.0 or not is_finite(damage):
		return false
	percent += damage
	hit_count += 1
	last_move = move_name
	last_damage = damage
	last_impulse = impulse
	# Damage keeps accumulating; the target never attacks or dies.
	var multiplier: float = 1.0 + minf(percent, 300.0) / 100.0
	velocity = impulse * multiplier
	hitstun = clampf(0.10 + damage * 0.015 + percent * 0.001, 0.12, 0.8)
	damage_flash = 0.16
	idle_time = 0.0
	_label_time = 0.70
	_hit_label = "+%s%%" % _number(damage)
	_has_been_hit = true
	queue_redraw()
	return true

func _return_home() -> void:
	position = spawn_position
	velocity = Vector2.ZERO
	hitstun = 0.0
	idle_time = 0.0
	_has_been_hit = false
	damage_flash = 0.0
	_label_time = 0.0
	# Automatic return preserves the damage and move readout for practice.
	queue_redraw()

func reset_dummy() -> void:
	percent = 0.0
	hit_count = 0
	last_move = "No hits yet"
	last_damage = 0.0
	last_impulse = Vector2.ZERO
	_return_home()

func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value

func _draw() -> void:
	var flash: bool = damage_flash > 0.0
	draw_circle(Vector2(0, -6), 34, Color(0.93, 0.69, 0.34, 0.05))
	draw_line(Vector2(-25, 22), Vector2(25, 22), Color("4b6578"), 4)
	draw_rect(Rect2(-13, -12, 26, 34), Color("f5d295") if flash else Color("b69365"))
	draw_circle(Vector2(0, -20), 13, Color("ffe5b2") if flash else Color("d1b184"))
	draw_circle(Vector2(0, -4), 9, Color("273d52"))
	draw_circle(Vector2(0, -4), 4, Color("f4c16c"))
	draw_line(Vector2(-24, -6), Vector2(24, -6), Color("c1a276"), 7)
	var font := ThemeDB.fallback_font
	var name_width: float = font.get_string_size(target_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, Vector2(-name_width * 0.5, 48), target_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("b7dccd"))
	var readout: String = "%s%%" % _number(percent)
	var text_width: float = font.get_string_size(readout, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(font, Vector2(-text_width * 0.5, -46), readout, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("fce5b7"))
	if _label_time > 0.0:
		var label_width: float = font.get_string_size(_hit_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, Vector2(-label_width * 0.5, -68 - (0.70 - _label_time) * 20.0), _hit_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("fff1c9"))
