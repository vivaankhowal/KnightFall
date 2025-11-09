extends Sprite2D

@export var fade_speed: float = 5.0

func _ready() -> void:
	modulate = Color(1, 1, 1, 0.6)

func _process(delta: float) -> void:
	modulate.a -= delta * fade_speed
	if modulate.a <= 0:
		queue_free()
