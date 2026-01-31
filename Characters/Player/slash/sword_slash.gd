extends Area2D

@export var damage: int = 10

@export var initial_speed: float = 1200.0
@export var friction: float = 1600.0   # higher = stops faster
@export var lifetime: float = 0.6

@export var max_pierces: int = 3        # number of enemies it can hit

var velocity: Vector2
var remaining_pierces: int
var hit_targets := {}

func _ready():
	remaining_pierces = max_pierces
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta):
	# Apply friction
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	global_position += velocity * delta

	if velocity.length() < 10.0:
		queue_free()

func _on_body_entered(body: Node):
	if not body.is_in_group("enemy"):
		return

	# Prevent multi-hit on same enemy
	if hit_targets.has(body):
		return

	hit_targets[body] = true

	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)

	remaining_pierces -= 1
	if remaining_pierces < 0:
		queue_free()

func get_damage() -> int:
	return damage
