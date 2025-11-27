extends Area2D

# -------------------------------
# CONFIG
# -------------------------------
@export var speed: float = 3000.0
@export var lifetime: float = 0.5
@export var base_damage: int = 10
@export var hit_effect_scene: PackedScene
@export var damage_multiplier: float = 1.0

# Slash slowdown over time
@export var slowdown_rate: float = 2.2

# -------------------------------
# STATE
# -------------------------------
var direction: Vector2 = Vector2.ZERO
var timer: float = 0.0
var already_hit := []
var speed_multiplier: float = 1.0


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

	# --- SPEED DECREASE ---
	speed_multiplier = max(speed_multiplier - slowdown_rate * delta, 0.0)

	# --- MOVEMENT ---
	global_position += direction * speed * speed_multiplier * delta

	timer += delta
	if timer >= lifetime:
		queue_free()


# -------------------------------
# COLLISION HANDLING
# -------------------------------
func _on_body_entered(body):

	# -------------------------
	# ENEMY HIT
	# -------------------------
	if body.is_in_group("enemy") and body not in already_hit:

		already_hit.append(body)
		body.take_damage(base_damage * damage_multiplier, global_position)

		_play_enemy_hit_fx(body)
		queue_free()
		return


func _on_area_entered(area: Node) -> void:
	_handle_hit(area)


func _handle_hit(target: Node) -> void:

	# -------------------------
	# ENEMY HIT
	# -------------------------
	if target.is_in_group("enemy"):

		if target not in already_hit:
			already_hit.append(target)
			_play_enemy_hit_fx(target)

			if target.has_method("take_damage"):
				var final_damage = int(base_damage * damage_multiplier)
				target.take_damage(final_damage)

		queue_free()
		return


# -------------------------------
# HIT EFFECT HELPERS
# -------------------------------
func _play_enemy_hit_fx(enemy):
	if hit_effect_scene:
		var fx = hit_effect_scene.instantiate()
		get_parent().add_child(fx)

		# place spark slightly INTO the enemy
		fx.global_position = enemy.global_position - direction * 6

		# flip spark based on slash direction
		if direction.x > 0:
			fx.scale.x = -fx.scale.x
