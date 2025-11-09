extends Camera2D

@export var shake_intensity: float = 8.0   # default intensity
@export var shake_duration: float = 0.2    # default duration

var shake_timer: float = 0.0
var current_intensity: float = 0.0

func shake(intensity: float = shake_intensity, duration: float = shake_duration) -> void:
	# Start a new shake with custom or default values
	shake_timer = duration
	current_intensity = intensity

func _process(delta: float) -> void:
	if shake_timer > 0:
		shake_timer -= delta
		# Random offset scaled by remaining intensity
		var strength = current_intensity * (shake_timer / shake_duration)
		offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
	else:
		offset = Vector2.ZERO
