extends Camera2D

@export var shake_intensity: float = 0.0
@export var shake_duration: float = 0.15

var shake_timer: float = 0.0

func shake() -> void:
	shake_timer = shake_duration

func _process(delta: float) -> void:
	if shake_timer > 0:
		shake_timer -= delta
		offset = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
	else:
		offset = Vector2.ZERO
