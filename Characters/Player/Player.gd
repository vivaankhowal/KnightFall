extends CharacterBody2D

# ============================================================
# CONFIG
# ============================================================
@export var move_speed := 200.0
@export var max_health := 100

# --- Damage ---
@export var hit_knockback_force := 550.0
@export var hit_knockback_friction := 1800.0
@export var invincibility_time := 1.5

# ============================================================
# STATE
# ============================================================
var input_dir := Vector2.ZERO
var current_health := max_health

# --- Knockback ---
var is_knockback := false
var knockback_velocity := Vector2.ZERO
var is_hit_stunned := false
var is_invincible := false

# --- Damage Flash ---
var flash_timer := 0.0
var flash_interval := 0.12
var flash_on := false

# ============================================================
# NODES
# ============================================================
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $Sprite2D/AnimationPlayer
@onready var cam: Camera2D = $Camera2D
@onready var health_bar: AnimatedSprite2D = $HUD/HealthBar/AnimatedSprite2D
@onready var damage_overlay := get_tree().get_first_node_in_group("damage_overlay")

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	current_health = max_health
	update_health_bar()

# ============================================================
# MAIN LOOP
# ============================================================
func _process(delta: float) -> void:
	update_damage_flash(delta)

func _physics_process(delta: float) -> void:
	if is_knockback:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(
			Vector2.ZERO,
			hit_knockback_friction * delta
		)
		move_and_slide()

		if knockback_velocity.length() < 10.0:
			is_knockback = false
		return

	handle_movement(delta)
	move_and_slide()

# ============================================================
# MOVEMENT (SMOOTH, UNCHANGED INPUTS)
# ============================================================
func handle_movement(delta: float) -> void:
	if is_hit_stunned:
		return

	input_dir = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	).normalized()

	# Animation (Hframes/Vframes-friendly)
	if input_dir != Vector2.ZERO:
		if not anim.is_playing() or anim.current_animation != "run":
			anim.play("run")
		sprite.flip_h = input_dir.x < 0
		anim.speed_scale = 1.0
	else:
		if not anim.is_playing() or anim.current_animation != "idle":
			anim.play("idle")
		anim.speed_scale = 0.75

	# Smooth acceleration / friction
	var lerp_weight := delta * (5.0 if input_dir != Vector2.ZERO else 8.0)
	velocity = velocity.lerp(input_dir * move_speed, lerp_weight)

# ============================================================
# DAMAGE + FLASH
# ============================================================
func take_damage(amount: int, from: Vector2) -> void:
	if is_invincible:
		return

	current_health -= amount
	update_health_bar()

	is_invincible = true
	is_hit_stunned = true

	# 🔴 Screen vignette
	if damage_overlay:
		damage_overlay.flash(0.55, 0.4)

	flash_timer = 0.0
	flash_on = true
	set_damage_flash(true)

	var dir := (global_position - from).normalized()
	knockback_velocity = dir * hit_knockback_force
	is_knockback = true

	if cam:
		cam.shake(6, 0.15)

	await get_tree().create_timer(0.15).timeout
	is_hit_stunned = false

	await get_tree().create_timer(invincibility_time - 0.15).timeout
	is_invincible = false
	set_damage_flash(false)

	if current_health <= 0:
		queue_free()

func update_damage_flash(delta: float) -> void:
	if not is_invincible:
		return

	flash_timer -= delta
	if flash_timer <= 0.0:
		flash_timer = flash_interval
		flash_on = not flash_on
		set_damage_flash(flash_on)

# ============================================================
# UI
# ============================================================
func update_health_bar() -> void:
	var percent := float(current_health) / float(max_health)
	health_bar.frame = clamp(int(round(percent * 10.0)), 0, 10)

# ============================================================
# SHADER HELPERS
# ============================================================
func set_damage_flash(active: bool) -> void:
	if sprite.material:
		sprite.material.set_shader_parameter("damage_flash", active)
