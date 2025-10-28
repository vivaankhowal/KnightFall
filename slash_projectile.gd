extends Area2D

@export var speed: float = 600.0
@export var lifetime: float = 0.6
var direction: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Hide initially so it doesn't show before rotation
	visible = false
	scale = Vector2(0.4, 0.4)

	# Auto-delete after a short time
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	if not visible and direction != Vector2.ZERO:
		# Once direction is set, orient and show it
		rotation = direction.angle()
		visible = true

	position += direction * speed * delta
