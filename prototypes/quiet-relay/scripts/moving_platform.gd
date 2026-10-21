extends AnimatableBody2D

@export var horizontal_amplitude: float = 115.0
@export var horizontal_speed: float = 42.0
@export var vertical_amplitude: float = 6.0
@export var vertical_frequency: float = 0.8
var base_rect := Rect2(280,505,105,22)
var motion_enabled: bool = true
var elapsed: float = 0.0

func _ready() -> void:
	process_physics_priority = -100
	position = base_rect.get_center()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = base_rect.size
	collider.shape = shape
	add_child(collider)

func offset_at(seconds: float) -> Vector2:
	return Vector2(horizontal_amplitude*sin(seconds*horizontal_speed/horizontal_amplitude),vertical_amplitude*sin(seconds*vertical_frequency))

func _physics_process(delta: float) -> void:
	if motion_enabled:
		elapsed += delta
		position = base_rect.get_center()+offset_at(elapsed)

func surface_rect() -> Rect2:
	return Rect2(position-base_rect.size/2,base_rect.size)

func predicted_surface_rect(seconds: float) -> Rect2:
	if not motion_enabled:
		return surface_rect()
	return Rect2(base_rect.position+offset_at(elapsed+seconds),base_rect.size)

func reset_motion() -> void:
	elapsed = 0.0
	position = base_rect.get_center()
