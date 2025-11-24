extends Area2D

# -------------------------------
# CONFIG
# -------------------------------
@export var speed: float = 500.0
@export var lifetime: float = 0.35
@export var base_damage: int = 10
@export var hit_effect_scene: PackedScene
@export var damage_multiplier: float = 1.0

# -------------------------------
# STATE
# -------------------------------
var direction: Vector2 = Vector2.ZERO
var timer: float = 0.0
var already_hit = []

# -------------------------------
# READY
# -------------------------------
func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("area_entered", Callable(self, "_on_area_entered"))

# -------------------------------
# PHYSICS
# -------------------------------
func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	timer += delta
	if timer >= lifetime:
		queue_free()

# -------------------------------
# COLLISION
# -------------------------------
func _on_body_entered(body):
	if body.is_in_group("enemy") and body not in already_hit:
		already_hit.append(body)
		body.take_damage(base_damage * damage_multiplier, global_position)


func _on_area_entered(area: Node) -> void:
	_handle_hit(area)

func _handle_hit(target: Node) -> void:
	if not target.is_in_group("enemy"):
		return

	# Spawn hit effect
	if hit_effect_scene:
		var fx = hit_effect_scene.instantiate()
		get_parent().add_child(fx)
		fx.global_position = global_position

	# Apply damage
	if target.has_method("take_damage"):
		var final_damage = int(base_damage * damage_multiplier)
		target.take_damage(final_damage)

	queue_free()
