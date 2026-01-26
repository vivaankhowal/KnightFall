extends Area2D

@export var speed := 500.0
@export var damage := 10
@export var lifetime := 3.0

var velocity := Vector2.ZERO

func _ready():
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta):
	position += velocity * delta

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)
	queue_free()
