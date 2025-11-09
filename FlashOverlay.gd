extends ColorRect

@export var fade_speed: float = 8.0

func flash() -> void:
	modulate.a = 0.6  # brightness of flash

func _process(delta: float) -> void:
	if modulate.a > 0.0:
		modulate.a = max(modulate.a - delta * fade_speed, 0.0)
