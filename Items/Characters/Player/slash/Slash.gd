extends Area2D

# -------------------------------
# CONFIG
# -------------------------------
@export var speed: float = 400.0
@export var lifetime: float = 0.3
@export var base_damage: int = 10
@export var hit_effect_scene: PackedScene
@export var damage_multiplier: float = 1.0   # upgraded by Weaponsmith

# -------------------------------
# STATE
# -------------------------------
var direction: Vector2 = Vector2.ZERO
var timer: float = 0.0

# -------------------------------
# NODES
# -------------------------------
@onready var sprite: Sprite2D = $Sprite2D

# -------------------------------
# READY
# -------------------------------
func _ready() -> void:
	sprite.modulate = Color(1, 1, 1, 1)
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
# COLLISION (ENEMY HIT)
# -------------------------------
func _on_body_entered(body: Node) -> void:
	_handle_hit(body)

func _on_area_entered(area: Node) -> void:
	_handle_hit(area)

func _handle_hit(target: Node) -> void:
	# Only damage enemies
	if not target.is_in_group("enemy"):
		return

	# Spawn hit effect
	if hit_effect_scene:
		var fx = hit_effect_scene.instantiate()
		get_parent().add_child(fx)
		fx.global_position = global_position

	# Apply damage (base × multiplier)
	if target.has_method("take_damage"):
		var final_damage = int(base_damage * damage_multiplier)
		target.take_damage(final_damage)

	queue_free()
