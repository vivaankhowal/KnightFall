extends CharacterBody2D

# ============================================================
# CONFIG
# ============================================================
@export var move_speed := 200.0
@export var max_health := 100
@onready var damage_silhouette: Sprite2D = $DamageSilhouette

# --- Sword ---
@export var slash_time := 0.2
@export var sword_return_time := 0.35  # reduced for snappier feel

# --- Projectile Sword Slash (NEW) ---
@export var sword_slash_scene: PackedScene
@export var fire_slash_on_attack: bool = true     # set false if you want a separate input
@export var slash_spawn_offset: float = 20.0
@export var slash_speed: float = 1200.0
@export var slash_friction: float = 1600.0
@export var slash_damage: int = 10
@export var slash_max_pierces: int = 3            # number of enemies it can pierce through

# --- Damage ---
@export var hit_knockback_force := 550.0
@export var hit_knockback_friction := 1800.0
@export var invincibility_time := 1.5

# ============================================================
# STATE
# ============================================================
var input_dir := Vector2.ZERO
var current_health := max_health

# --- Facing ---
var current_look_dir := "right"

# --- Sword ---
var can_slash := true

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
@onready var flip_anim: AnimationPlayer = $Sprite2D.get_node_or_null("flip_anim")

@onready var sword: Sprite2D = $Sprite2D/Sword
@onready var sword_anim: AnimationPlayer = $Sprite2D/Sword/AnimationPlayer

@onready var cam: Camera2D = $Camera2D
@onready var health_bar: AnimatedSprite2D = $HUD/HealthBar/AnimatedSprite2D
@onready var damage_overlay := get_tree().get_first_node_in_group("damage_overlay")

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	current_health = max_health
	update_health_bar()

	if sword_anim:
		sword_anim.animation_finished.connect(_on_sword_animation_finished)

# ============================================================
# MAIN LOOP
# ============================================================
func _process(delta: float) -> void:
	update_damage_flash(delta)
	update_facing()
	handle_attack()
	_sync_damage_silhouette()

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
# MOVEMENT
# ============================================================
func handle_movement(delta: float) -> void:
	if is_hit_stunned:
		return

	input_dir = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	).normalized()

	if input_dir != Vector2.ZERO:
		if anim.current_animation != "run":
			anim.play("run")
		anim.speed_scale = 1.0
	else:
		if anim.current_animation != "idle":
			anim.play("idle")
		anim.speed_scale = 0.75

	var lerp_weight := delta * (5.0 if input_dir != Vector2.ZERO else 8.0)
	velocity = velocity.lerp(input_dir * move_speed, lerp_weight)

# ============================================================
# FACING
# ============================================================
func update_facing() -> void:
	if not flip_anim:
		return

	var mouse_x := get_global_mouse_position().x

	if current_look_dir == "right" and mouse_x < global_position.x:
		flip_anim.play("look_left")
		current_look_dir = "left"

	elif current_look_dir == "left" and mouse_x > global_position.x:
		flip_anim.play("look_right")
		current_look_dir = "right"

# ============================================================
# ATTACK (SWORD + OPTIONAL SLASH PROJECTILE)
# ============================================================
func handle_attack() -> void:
	if Input.is_action_just_pressed("attack") and can_slash:
		start_slash()

func start_slash() -> void:
	can_slash = false

	# Spawn projectile at the start of the attack (NEW)
	if fire_slash_on_attack:
		_spawn_sword_slash()

	var slash_anim := sword_anim.get_animation("slash")
	sword_anim.speed_scale = slash_anim.length / slash_time
	sword_anim.play("slash")

# ============================================================
# PROJECTILE SPAWN (NEW)
# ============================================================
func _spawn_sword_slash() -> void:
	if sword_slash_scene == null:
		return

	var slash := sword_slash_scene.instantiate()

	var parent := get_tree().current_scene
	if parent == null:
		parent = get_parent()
	parent.add_child(slash)

	# Aim directly at mouse position
	var mouse_pos := get_global_mouse_position()
	var dir := (mouse_pos - global_position).normalized()

	# Safety fallback
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	slash.global_position = global_position + dir * slash_spawn_offset
	slash.rotation = dir.angle()

	# Inject projectile parameters
	if "velocity" in slash:
		slash.velocity = dir * slash_speed
	if "friction" in slash:
		slash.friction = slash_friction
	if "damage" in slash:
		slash.damage = slash_damage
	if "max_pierces" in slash:
		slash.max_pierces = slash_max_pierces


# ============================================================
# SWORD ANIMATION CHAINING (FASTER RESET)
# ============================================================
func _on_sword_animation_finished(anim_name: StringName) -> void:
	if anim_name == "slash":
		var return_anim := sword_anim.get_animation("sword_return")
		sword_anim.speed_scale = return_anim.length / sword_return_time
		sword_anim.play("sword_return")

	elif anim_name == "sword_return":
		can_slash = true

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
	# Existing shader flash
	if sprite.material:
		sprite.material.set_shader_parameter("damage_flash", active)

	# NEW silhouette flash
	if damage_silhouette:
		damage_silhouette.visible = active


func _sync_damage_silhouette() -> void:
	if not damage_silhouette:
		return

	damage_silhouette.texture = sprite.texture
	damage_silhouette.frame = sprite.frame
	damage_silhouette.flip_h = sprite.flip_h
	damage_silhouette.flip_v = sprite.flip_v
	damage_silhouette.global_position = sprite.global_position
	damage_silhouette.rotation = sprite.rotation
	damage_silhouette.scale = sprite.scale
