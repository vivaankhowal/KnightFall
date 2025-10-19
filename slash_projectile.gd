extends Area2D

@export var speed: float = 600.0
@export var lifetime: float = 0.3
var direction: Vector2 = Vector2.ZERO

func _ready():
	rotation = direction.angle()
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta):
	position += direction * speed * delta
