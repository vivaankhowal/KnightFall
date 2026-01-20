extends CharacterBody2D

# ============================================================
# CONFIG
# ============================================================
@export var move_speed := 200.0
@export var max_health := 100

# --- Dash ---
@export var dash_speed := 500.0
@export var dash_time := 0.05
@export var dash_cooldown := 0.4
@export var dash_afterimage_interval := 0.03
@export var dash_afterimage_scene: PackedScene

@export var dash_phase_enemies_mask_bit: int = 2
@export var dash_phase_bullets_mask_bit: int = 3

# --- Sword ---
@export var slash_time := 0.2
@export var sword_return_time := 0.35

# --- Projectile Sword Slash ---
@export var sword_slash_scene: PackedScene
@export var fire_slash_on_attack := true
@export var slash_spawn_offset := 20.0
@export var slash_speed := 1200.0
@export var slash_friction := 1600.0
@export var slash_damage := 10
@export var slash_max_pierces := 3

# --- Damage ---
@export var hit_knockback_force := 550.0
@export var hit_knockback_friction := 1800.0
@export var invincibility_time := 1.5

# ============================================================
# STATE
# ============================================================
var input_dir := Vector2.ZERO
var current_health := max_health

# Facing
var current_look_dir := "right"

# Sword
var can_slash := true

# Knockback / stun
var is_knockback := false
var knockback_velocity := Vector2.ZERO
var is_hit_stunned := false

# Invincibility
var is_damage_invincible := false
var is_dash_invincible := false

# Damage flash
var flash_timer := 0.0
var flash_interval := 0.12
var flash_on := false

# Dash
var is_dashing := false
var dash_dir := Vector2.ZERO
var dash_timer := 0.0
var dash_cd_timer := 0.0
var afterimage_timer := 0.0

# ============================================================
# NODES
# ============================================================
@onready var sprite: Sprite2D = $Sprite2D
@onready var sprite_mat: ShaderMaterial = sprite.material as ShaderMaterial
@onready var anim: AnimationPlayer = $Sprite2D/AnimationPlayer
@onready var flip_anim: AnimationPlayer = $Sprite2D.get_node_or_null("flip_anim")

@onready var sword: Sprite2D = $Sprite2D/Sword
@onready var sword_anim: AnimationPlayer = $Sprite2D/Sword/AnimationPlayer

@onready var cam: Camera2D = $Camera2D
@onready var health_bar: AnimatedSprite2D = $HUD/HealthBar/AnimatedSprite2D
@onready var damage_overlay := get_tree().get_first_node_in_group("damage_overlay")

# ============================================================
# HELPERS
# ============================================================
func is_invincible() -> bool:
	return is_damage_invincible or is_dash_invincible

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
	handle_dash(delta)
	_update_flash_shader()

func _physics_process(delta: float) -> void:
	if is_dashing:
		move_and_slide()
		return

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
# ATTACK
# ============================================================
func handle_attack() -> void:
	if Input.is_action_just_pressed("attack") and can_slash:
		start_slash()

func start_slash() -> void:
	can_slash = false

	if fire_slash_on_attack:
		_spawn_sword_slash()

	var slash_anim := sword_anim.get_animation("slash")
	sword_anim.speed_scale = slash_anim.length / slash_time
	sword_anim.play("slash")

# ============================================================
# PROJECTILE SLASH
# ============================================================
func _spawn_sword_slash() -> void:
	if sword_slash_scene == null:
		return

	var slash := sword_slash_scene.instantiate()
	get_tree().current_scene.add_child(slash)

	var dir := (get_global_mouse_position() - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	slash.global_position = global_position + dir * slash_spawn_offset
	slash.rotation = dir.angle()

	if "velocity" in slash:
		slash.velocity = dir * slash_speed
	if "friction" in slash:
		slash.friction = slash_friction
	if "damage" in slash:
		slash.damage = slash_damage
	if "max_pierces" in slash:
		slash.max_pierces = slash_max_pierces

# ============================================================
# SWORD ANIMATION
# ============================================================
func _on_sword_animation_finished(anim_name: StringName) -> void:
	if anim_name == "slash":
		var ret := sword_anim.get_animation("sword_return")
		sword_anim.speed_scale = ret.length / sword_return_time
		sword_anim.play("sword_return")
	elif anim_name == "sword_return":
		can_slash = true

# ============================================================
# DAMAGE
# ============================================================
func take_damage(amount: int, from: Vector2) -> void:
	if is_dashing or is_dash_invincible or is_damage_invincible:
		return


	current_health -= amount
	update_health_bar()

	is_damage_invincible = true
	is_hit_stunned = true

	if damage_overlay:
		damage_overlay.flash(0.55, 0.4)

	flash_timer = 0.0
	flash_on = true

	var dir := (global_position - from).normalized()
	knockback_velocity = dir * hit_knockback_force
	is_knockback = true

	if cam:
		cam.shake(6, 0.15)

	await get_tree().create_timer(0.15).timeout
	is_hit_stunned = false

	await get_tree().create_timer(invincibility_time - 0.15).timeout
	is_damage_invincible = false

	if current_health <= 0:
		queue_free()

func update_damage_flash(delta: float) -> void:
	if not is_damage_invincible:
		return

	flash_timer -= delta
	if flash_timer <= 0.0:
		flash_timer = flash_interval
		flash_on = not flash_on

# ============================================================
# DASH
# ============================================================
func handle_dash(delta: float) -> void:
	if dash_cd_timer > 0.0:
		dash_cd_timer -= delta

	if Input.is_action_just_pressed("dash") \
	and not is_dashing \
	and dash_cd_timer <= 0.0 \
	and not is_knockback:
		start_dash()

	if is_dashing:
		dash_timer -= delta
		velocity = dash_dir * dash_speed

		afterimage_timer -= delta
		if afterimage_timer <= 0.0:
			afterimage_timer = dash_afterimage_interval
			spawn_dash_afterimage()

		if dash_timer <= 0.0:
			end_dash()

func start_dash() -> void:
	is_dashing = true
	is_dash_invincible = true
	is_hit_stunned = true

	dash_timer = dash_time
	dash_cd_timer = dash_cooldown
	afterimage_timer = 0.0

	dash_dir = (get_global_mouse_position() - global_position).normalized()
	if dash_dir == Vector2.ZERO:
		dash_dir = Vector2.RIGHT

	set_collision_mask_value(dash_phase_enemies_mask_bit, false)
	set_collision_mask_value(dash_phase_bullets_mask_bit, false)

	if cam:
		cam.shake(1.5, 0.06)

	if anim.has_animation("dash"):
		anim.play("dash")

func end_dash() -> void:
	is_dashing = false
	is_hit_stunned = false
	is_dash_invincible = false

	set_collision_mask_value(dash_phase_enemies_mask_bit, true)
	set_collision_mask_value(dash_phase_bullets_mask_bit, true)

# ============================================================
# AFTERIMAGE
# ============================================================
func spawn_dash_afterimage() -> void:
	if dash_afterimage_scene == null:
		return

	var ghost := dash_afterimage_scene.instantiate()
	get_tree().current_scene.add_child(ghost)

	ghost.global_position = global_position
	ghost.z_index = sprite.z_index - 1

	var g := ghost.get_node_or_null("Sprite2D")
	if g:
		g.texture = sprite.texture
		g.frame = sprite.frame
		g.flip_h = sprite.flip_h
		g.flip_v = sprite.flip_v
		g.scale = sprite.scale
		g.modulate = Color(1, 1, 1, 0.65)

# ============================================================
# SHADER CONTROL
# ============================================================
func _update_flash_shader() -> void:
	if not sprite_mat:
		return

	if is_damage_invincible:
		sprite_mat.set_shader_parameter("flash_enabled", flash_on)
		sprite_mat.set_shader_parameter("flash_color", Color(1, 0, 0, 1))
		return

	if is_dashing:
		sprite_mat.set_shader_parameter("flash_enabled", true)
		sprite_mat.set_shader_parameter("flash_color", Color(1, 1, 1, 1))
		return

	sprite_mat.set_shader_parameter("flash_enabled", false)

# ============================================================
# UI
# ============================================================
func update_health_bar() -> void:
	var percent := float(current_health) / float(max_health)
	health_bar.frame = clamp(int(round(percent * 10.0)), 0, 10)

func disable():
	set_physics_process(false)
	visible = false

func enable():
	set_physics_process(true)
	visible = true
