extends Area2D

# -------------------------------
# CONFIG
# -------------------------------
@export var speed: float = 500.0
@export var lifetime: float = 0.35
@export var base_damage: int = 10
@export var hit_effect_scene: PackedScene
@export var damage_multiplier: float = 1.0
@export var fade_out: bool = true

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

	# Fade-out effect
	if fade_out:
		var t: float = timer / lifetime
		var alpha: float = clamp(1.0 - t, 0.0, 1.0)
		modulate.a = alpha

		# Optional shrink

	if timer >= lifetime:
		queue_free()

# -------------------------------
# COLLISION
# -------------------------------
func _on_body_entered(body):
	if body.is_in_group("enemy") and body not in already_hit:
		already_hit.append(body)

		# Damage
		body.take_damage(base_damage * damage_multiplier, global_position)

		# Hit spark for THIS enemy
		if hit_effect_scene:
			var fx = hit_effect_scene.instantiate()
			get_parent().add_child(fx)
			fx.global_position = body.global_position

	# IMPORTANT:
	# Do NOT queue_free() here
	# Slash continues moving through enemies


func _on_area_entered(area: Node) -> void:
	_handle_hit(area)


func _handle_hit(target: Node) -> void:
	if not target.is_in_group("enemy"):
		return

	if target not in already_hit:
		already_hit.append(target)

		# Hit spark for THIS enemy
		if hit_effect_scene:
			var fx = hit_effect_scene.instantiate()
			get_parent().add_child(fx)
			fx.global_position = target.global_position

		# Damage
		if target.has_method("take_damage"):
			var final_damage = int(base_damage * damage_multiplier)
			target.take_damage(final_damage)

	# Do NOT queue_free() here either
