extends Area2D

# -------------------------------
# CONFIG
# -------------------------------
@export var speed: float = 400.0
@export var lifetime: float = 0.3
@export var base_damage: int = 1
@export var hit_effect_scene: PackedScene
@export var damage_multiplier: float = 1.0   # <-- upgraded by Weaponsmith

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

# -------------------------------
# PHYSICS
# -------------------------------
func _physics_process(delta: float) -> void:
	# Move forward constantly
	global_position += direction * speed * delta
	timer += delta

	# Remove after time expires
	if timer >= lifetime:
		queue_free()

# -------------------------------
# COLLISION
# -------------------------------
func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("Enemies"):
		# Spawn hit effect
		if hit_effect_scene:
			var fx = hit_effect_scene.instantiate()
			get_parent().add_child(fx)
			fx.global_position = global_position

		# Apply damage (base × multiplier)
		if area.has_method("take_damage"):
			var final_damage = int(base_damage * damage_multiplier)
			area.take_damage(final_damage)

		queue_free()
