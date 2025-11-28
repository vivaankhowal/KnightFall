extends CharacterBody2D

# ============================================================
# CONFIG
# ============================================================
@export var move_speed: float = 600.0
@export var attack_cooldown: float = 0.4
@export var attack_stop_time: float = 0.15
@export var slash_scene: PackedScene
@export var dust_scene: PackedScene
@export var weapon_damage_upgrade: float = 1.0
@export var max_health: int = 100
@onready var cam: Camera2D = $Camera2D
@export var hit_knockback_force: float = 150.0
@export var hit_knockback_friction: float = 600.0


# --- Dash Config ---
@export var dash_speed: float = 1600.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 0.1
@export var dash_smoke_scene: PackedScene
@export var dash_ghost_scene: PackedScene
@export var ghost_spawn_interval: float = 0.05

# ============================================================
# STATE
# ============================================================
var input_dir: Vector2 = Vector2.ZERO
var facing_right: bool = true
var is_attacking: bool = false
var attack_locked: bool = false
var attack_hit_triggered: bool = false
var current_attack: String = ""
var attack_freeze_timer: float = 0.0
var current_health: int = max_health
var ghost_timer: float = 0.0
var locked_attack_dir: Vector2 = Vector2.ZERO
var is_hit_stunned: bool = false

# --- Knockback ---
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_friction: float = 1800.0
var is_knockback: bool = false

# --- Invincibility ---
var is_invincible: bool = false
@export var invincibility_time: float = 2.0

# --- Dash State ---
var is_dashing: bool = false
var can_dash: bool = true
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_dir: Vector2 = Vector2.ZERO

# ============================================================
# NODES
# ============================================================
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_timer: Timer = Timer.new()
@onready var health_bar: AnimatedSprite2D = $HUD/HealthBar/AnimatedSprite2D
@onready var flash_mat := ShaderMaterial.new()

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	anim.frame_changed.connect(_on_frame_changed)
	add_child(attack_timer)
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	current_health = max_health
	update_health_bar()
	var shader := load("res://red_flash.gdshader")
	flash_mat.shader = shader
	var crosshair = load("res://crosshair.png")
	Input.set_custom_mouse_cursor(crosshair, Input.CURSOR_ARROW, Vector2(16, 16))

# ============================================================
# MAIN LOOP
# ============================================================

func _physics_process(delta: float) -> void:
	handle_dash_timers(delta)

	# --- DASH ---
	if is_dashing:
		velocity = dash_dir * dash_speed
		move_and_slide()

		ghost_timer -= delta
		if ghost_timer <= 0:
			spawn_dash_ghost()
			ghost_timer = ghost_spawn_interval
		return

	# --- KNOCKBACK ---
	if is_knockback:
		velocity = knockback_velocity * 3
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
		move_and_slide()
		if knockback_velocity.length() < 5:
			is_knockback = false
		return

	# --- ATTACK FREEZE ---
	if attack_freeze_timer > 0.0:
		attack_freeze_timer -= delta
		move_and_slide()
		return

	# --- NORMAL MOVEMENT ---
	handle_movement_input(delta)
	move_and_slide()

# ============================================================
# ANIMATION + FACING
# ============================================================
func update_facing(dir: Vector2) -> void:
	if dir.x != 0:
		facing_right = dir.x > 0
	anim.flip_h = not facing_right

func update_animation() -> void:
	if is_hit_stunned or is_knockback:
		return
	if is_attacking:
		return
	if is_dashing:
		return
	if input_dir == Vector2.ZERO:
		anim.play("idle")
	else:
		anim.play("run")

# ============================================================
# MOVEMENT INPUT
# ============================================================
func handle_movement_input(delta: float) -> void:
	if is_knockback or is_hit_stunned:
		return

	input_dir = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	).normalized()

	velocity = input_dir * move_speed

	if input_dir != Vector2.ZERO:
		update_facing(input_dir)

	handle_attack_input(delta)
	handle_dash_input()
	update_animation()

# ============================================================
# DASH SYSTEM (NO CAMERA ZOOM)
# ============================================================
func handle_dash_input() -> void:
	if Input.is_action_just_pressed("dash") and can_dash and not is_attacking:
		start_dash()

func start_dash() -> void:
	is_dashing = true
	can_dash = false
	dash_timer = dash_duration
	dash_dir = input_dir if input_dir != Vector2.ZERO else (Vector2.RIGHT if facing_right else Vector2.LEFT)

	spawn_dash_smoke()
	ghost_timer = ghost_spawn_interval

	# REMOVE CAMERA ZOOM
	# REMOVE SCALING

	# White silhouette flash only (no scale change)
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
		shader_type canvas_item;
		void fragment() {
			vec4 tex = texture(TEXTURE, UV);
			COLOR = vec4(1.0, 1.0, 1.0, tex.a);
		}
	"""
	mat.shader = shader
	anim.material = mat

func end_dash() -> void:
	is_dashing = false
	dash_cooldown_timer = dash_cooldown
	anim.material = null  # Reset sprite material

	# CAMERA ZOOM REMOVED — nothing here

func handle_dash_timers(delta: float) -> void:
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			end_dash()
	elif not can_dash:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0:
			can_dash = true

# ============================================================
# DASH FX
# ============================================================
func spawn_dash_smoke() -> void:
	if dash_smoke_scene == null:
		return
	var smoke = dash_smoke_scene.instantiate()
	get_parent().add_child(smoke)

	var offset_distance := -10.0
	var y_offset := -10.0
	var facing_dir = Vector2.RIGHT if facing_right else Vector2.LEFT
	smoke.global_position = global_position + facing_dir * offset_distance + Vector2(0, y_offset)
	smoke.flip_h = not facing_right

func spawn_dash_ghost() -> void:
	if dash_ghost_scene == null:
		return
	var ghost = dash_ghost_scene.instantiate()
	get_parent().add_child(ghost)
	ghost.global_position = global_position

	var frame_tex = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	if frame_tex:
		ghost.texture = frame_tex
		ghost.flip_h = anim.flip_h

	var tw = create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_callback(Callable(ghost, "queue_free"))

# ============================================================
# ATTACK SYSTEM
# ============================================================
func handle_attack_input(delta: float) -> void:
	if attack_locked or is_dashing:
		return
	if Input.is_action_just_pressed("attack"):
		start_attack()

func start_attack() -> void:
	is_attacking = true
	attack_locked = true
	attack_hit_triggered = false

	var mouse_pos = get_global_mouse_position()
	var dir_to_mouse = (mouse_pos - global_position).normalized()
	locked_attack_dir = dir_to_mouse

	var angle = rad_to_deg(dir_to_mouse.angle())

	facing_right = dir_to_mouse.x >= 0
	anim.flip_h = not facing_right

	velocity = Vector2.ZERO
	attack_freeze_timer = attack_stop_time

	if angle < -25 and angle > -155:
		current_attack = "vertical_slash"
	elif angle > 25 and angle < 155:
		current_attack = "charged_slash"
	else:
		current_attack = "horizontal_slash"

	anim.play(current_attack)
	attack_timer.start(attack_cooldown)

func _on_attack_timer_timeout() -> void:
	is_attacking = false
	attack_locked = false
	current_attack = ""
	attack_hit_triggered = false

func _on_frame_changed() -> void:
	if anim.animation == "horizontal_slash" and anim.frame == 4:
		trigger_attack_hit()
	elif anim.animation == "vertical_slash" and anim.frame == 3:
		trigger_attack_hit()
	elif anim.animation == "charged_slash" and anim.frame == 4:
		trigger_attack_hit()

	if anim.animation == "run" and (anim.frame == 2 or anim.frame == 6):
		spawn_dust()

func trigger_attack_hit() -> void:
	if attack_hit_triggered:
		return
	attack_hit_triggered = true
	spawn_slash_projectile(locked_attack_dir)

func spawn_slash_projectile(direction: Vector2) -> void:
	if slash_scene == null:
		push_warning("Slash scene not assigned!")
		return
	var slash = slash_scene.instantiate()
	get_parent().add_child(slash)
	var spawn_distance := 40.0
	slash.global_position = global_position + direction * spawn_distance
	slash.rotation = direction.angle()
	slash.direction = direction
	slash.damage_multiplier = weapon_damage_upgrade

# ============================================================
# FX
# ============================================================
func spawn_dust() -> void:
	if dust_scene == null:
		return
	var dust = dust_scene.instantiate()
	get_parent().add_child(dust)
	var offset_distance = 5.0
	var offset_dir = Vector2.LEFT if facing_right else Vector2.RIGHT
	dust.global_position = global_position + offset_dir * offset_distance + Vector2(0, 8)
	dust.flip_h = not facing_right

# ============================================================
# HEALTH + DAMAGE
# ============================================================
func update_health_bar():
	var percent := float(current_health) / float(max_health)
	var frame := int(round(percent * 10))
	frame = clamp(frame, 0, 10)
	health_bar.frame = frame

func take_damage(amount: int, from: Vector2 = Vector2.ZERO) -> void:
	if is_dashing or is_invincible:
		return

	current_health -= amount
	current_health = clamp(current_health, 0, max_health)
	update_health_bar()

	play_hit_effects(from)

	if current_health <= 0:
		die()


func play_hit_effects(from: Vector2 = Vector2.ZERO):
	if is_invincible or current_health <= 0:
		return

	is_invincible = true
	is_hit_stunned = true
	is_attacking = false
	is_dashing = false

	# Camera shake
	if cam:
		cam.shake(6, 0.15)

	# Red screen overlay flash
	var overlay = get_tree().get_first_node_in_group("overlay")
	if overlay:
		overlay.flash(0.6, 0.25)

	# --- KNOCKBACK ---
	var dir = (global_position - from).normalized()
	dir.y -= 0.1
	dir = dir.normalized()
	knockback_velocity = dir * 550
	is_knockback = true

	# Play hit animation
	if "hit" in anim.sprite_frames.get_animation_names():
		anim.play("hit")

	# Apply red flashing material
	anim.material = flash_mat
	start_red_flash()

	# After 0.15 seconds (knockback duration), allow movement again
	await get_tree().create_timer(0.15).timeout
	is_hit_stunned = false   # <-- regain movement here

	# But invincibility continues for full duration
	await get_tree().create_timer(invincibility_time - 0.15).timeout
	is_invincible = false

# ============================================================
# DEATH
# ============================================================
func die() -> void:
	print("💀 Player died")
	if "death" in anim.sprite_frames.get_animation_names():
		anim.play("death")
	await anim.animation_finished
	queue_free()

func start_red_flash():
	var overlay = get_tree().get_first_node_in_group("overlay")
	var blink_count: int = 8   # number of flashes
	var blink_interval: float = invincibility_time / (blink_count * 2.0)

	for i in blink_count:
		# RED SILHOUETTE FLASH
		anim.material.set_shader_parameter("flash", true)

		# RED VIGNETTE FLASH
		if overlay:
			overlay.flash(0.6, blink_interval)

		await get_tree().create_timer(blink_interval).timeout

		# RED SILHOUETTE OFF
		anim.material.set_shader_parameter("flash", false)

		await get_tree().create_timer(blink_interval).timeout

	# Ensure silhouette ends off
	anim.material.set_shader_parameter("flash", false)
