extends CharacterBody2D

# ============================================================
# KNIGHT SWITCHING
# ============================================================
enum KnightType { RED, BLUE }
var current_knight: KnightType = KnightType.RED
var current_anim := "idle"
var current_look_dir := "right"
var is_switching := false

# --- Red Knight ---
@export var red_move_speed := 150.0
@export var red_slash_damage := 10

# --- Blue Knight ---
@export var blue_move_speed := 250.0
@export var blue_slash_damage := 5

# ============================================================
# CONFIG
# ============================================================
@export var move_speed := 200.0
@export var max_health := 100

# --- Sword ---
@export var slash_time := 0.2
@export var sword_return_time := 0.35
@export var sword_slash_scene: PackedScene
@export var slash_spawn_offset := 20.0
@export var slash_speed := 1200.0
@export var slash_friction := 1600.0
@export var slash_damage := 10
@export var slash_max_pierces := 3

# --- Damage ---
@export var hit_knockback_force := 500.0
@export var hit_knockback_friction := 1800.0
@export var invincibility_time := 1.5

# ============================================================
# STATE
# ============================================================
var input_dir := Vector2.ZERO
var last_move_dir := Vector2.RIGHT
var current_health := max_health
var can_slash := true
var is_knockback := false
var knockback_velocity := Vector2.ZERO
var is_hit_stunned := false
var is_damage_invincible := false

# Damage flash
var flash_timer := 0.0
var flash_interval := 0.12
var flash_on := false

# ============================================================
# NODES
# ============================================================
@onready var knights: AnimatedSprite2D = $Knights
@onready var sprite_mat: ShaderMaterial = knights.material as ShaderMaterial
@onready var flip_anim: AnimationPlayer = $Knights/flip_anim
@onready var sword_anim: AnimationPlayer = $Knights/Sword/AnimationPlayer
@onready var cam: Camera2D = $Camera2D
@onready var health_bar: AnimatedSprite2D = $HUD/HealthBar/AnimatedSprite2D
@onready var damage_overlay := get_tree().get_first_node_in_group("damage_overlay")

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	current_health = max_health
	update_health_bar()
	apply_knight(current_knight)

	knights.animation_finished.connect(_on_knights_animation_finished)

	if sword_anim:
		sword_anim.animation_finished.connect(_on_sword_animation_finished)

# ============================================================
# PROCESS
# ============================================================
func _process(delta: float) -> void:
	update_damage_flash(delta)
	update_facing()
	handle_attack()
	_update_flash_shader()

func _physics_process(delta: float) -> void:
	# KNOCKBACK
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
# INPUT
# ============================================================
func _input(event):
	if event.is_action_pressed("switch_knight"):
		switch_knight()

# ============================================================
# MOVEMENT + ANIMATION
# ============================================================
func handle_movement(delta: float) -> void:
	if is_hit_stunned:
		return

	input_dir = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	).normalized()

	if input_dir != Vector2.ZERO:
		last_move_dir = input_dir
		play_anim("run")
	else:
		play_anim("idle")

	velocity = velocity.lerp(input_dir * move_speed, delta * 8.0)

func play_anim(name: String) -> void:
	if is_switching:
		return

	current_anim = name
	var prefix := "red_" if current_knight == KnightType.RED else "blue_"
	var anim := prefix + name

	if knights.animation != anim:
		knights.play(anim)

# ============================================================
# ATTACK
# ============================================================
func handle_attack() -> void:
	if Input.is_action_just_pressed("attack") and can_slash:
		start_slash()

func start_slash() -> void:
	can_slash = false
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
	slash.velocity = dir * slash_speed
	slash.friction = slash_friction
	slash.damage = slash_damage
	slash.max_pierces = slash_max_pierces

# ============================================================
# KNIGHT SWITCH (ANIMATION-DRIVEN)
# ============================================================
func switch_knight() -> void:
	if is_switching:
		return

	is_switching = true

	var anim_name := "redtoblue" if current_knight == KnightType.RED else "bluetored"
	knights.play(anim_name)

func _on_knights_animation_finished() -> void:
	if not is_switching:
		return

	# Swap knight AFTER animation
	current_knight = KnightType.BLUE if current_knight == KnightType.RED else KnightType.RED
	apply_knight(current_knight)

	is_switching = false

# ============================================================
# APPLY KNIGHT STATS
# ============================================================
func apply_knight(knight: KnightType) -> void:
	match knight:
		KnightType.RED:
			move_speed = red_move_speed
			slash_damage = red_slash_damage
		KnightType.BLUE:
			move_speed = blue_move_speed
			slash_damage = blue_slash_damage

	play_anim(current_anim)

# ============================================================
# DAMAGE / SHADER / UI
# ============================================================
func _on_sword_animation_finished(anim_name: StringName) -> void:
	if anim_name == "slash":
		var ret := sword_anim.get_animation("sword_return")
		sword_anim.speed_scale = ret.length / sword_return_time
		sword_anim.play("sword_return")
	elif anim_name == "sword_return":
		can_slash = true

func take_damage(amount: int, from: Vector2) -> void:
	if is_damage_invincible:
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

func _update_flash_shader() -> void:
	if not sprite_mat:
		return

	if is_damage_invincible:
		sprite_mat.set_shader_parameter("flash_enabled", flash_on)
		sprite_mat.set_shader_parameter("flash_color", Color.RED)
	else:
		sprite_mat.set_shader_parameter("flash_enabled", false)

func update_health_bar() -> void:
	var percent := float(current_health) / float(max_health)
	health_bar.frame = clamp(int(round(percent * 10.0)), 0, 10)

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
