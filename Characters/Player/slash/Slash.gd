extends Area2D

# ============================================================
# CONFIG
# ============================================================
@export var speed: float = 1000.0
@export var base_damage: int = 10
@export var damage_multiplier: float = 1.0

# Optional slowdown for Blasphemy feel
@export var slowdown_rate: float = 0.0   # set >0 if you want decay

# ============================================================
# STATE
# ============================================================
var direction: Vector2 = Vector2.ZERO
var speed_multiplier: float = 1.0
var already_hit: Array[Node] = []

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

# ============================================================
# PHYSICS
# ============================================================
func _physics_process(delta: float) -> void:
	# Optional speed decay
	if slowdown_rate > 0.0:
		speed_multiplier = maxf(speed_multiplier - slowdown_rate * delta, 0.0)

	global_position += direction * speed * speed_multiplier * delta

# ============================================================
# COLLISION — BODY (WALLS + ENEMIES)
# ============================================================
func _on_body_entered(body: Node) -> void:
	# Hit enemy body
	if body.has_method("take_damage"):
		_apply_damage(body)
		queue_free()
		return

	# Hit wall / environment
	queue_free()

# ============================================================
# COLLISION — AREA (ENEMY HURTBOX)
# ============================================================
func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target == null:
		return

	if target.has_method("take_damage"):
		_apply_damage(target)
		queue_free()

# ============================================================
# DAMAGE
# ============================================================
func _apply_damage(target: Node) -> void:
	if target in already_hit:
		return

	already_hit.append(target)

	var final_damage := int(base_damage * damage_multiplier)
	target.take_damage(final_damage, global_position)
