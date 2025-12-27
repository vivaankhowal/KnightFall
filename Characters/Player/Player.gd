extends CharacterBody2D

# ============================================================
# CONFIG
# ============================================================
@export var move_speed: float = 200.0
@export var max_health: int = 100
@export var attack_cooldown: float = 0.35

# --- Dash Ghosts ---
@export var dash_ghost_interval: float = 0.025
@onready var dash_ghost_scene := preload("res://Characters/Player/dash/DashGhost.tscn")

var dash_ghost_timer: float = 0.0
var dash_ghost_index: int = 0

# --- Sword ---
@export var hand_reach: float = 22.0
@export var swing_arc: float = 140.0
@export var swing_speed: float = 7.0
@export var return_speed: float = 14.0
@export var hand_damage: int = 8
@export var slash_scene: PackedScene

# --- Dash ---
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 0.1

# --- Damage ---
@export var hit_knockback_force: float = 550.0
@export var hit_knockback_friction: float = 1800.0
@export var invincibility_time: float = 1.5

# ============================================================
# STATE
# ============================================================
var input_dir := Vector2.ZERO
var attack_dir := Vector2.RIGHT
var facing_right := true
var current_health := max_health

# --- Dash ---
var is_dashing := false
var can_dash := true
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_dir := Vector2.ZERO

# --- Knockback ---
var is_knockback := false
var knockback_velocity := Vector2.ZERO
var is_hit_stunned := false
var is_invincible := false

# --- Damage Flash ---
var flash_timer := 0.0
var flash_interval := 0.12
var flash_on := false

# --- Attack ---
enum AttackState { IDLE, SWINGING, RETURNING }
var attack_state := AttackState.IDLE
var swing_progress := 0.0
var attack_cooldown_timer: float = 0.0

# ============================================================
# NODES
# ============================================================
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var cam: Camera2D = $Camera2D
@onready var hand_pivot: Node2D = $HandPivot
@onready var hand: Node2D = $HandPivot/Hand
@onready var hand_hitbox: Area2D = $HandPivot/Hand/Hitbox
@onready var health_bar: AnimatedSprite2D = $HUD/HealthBar/AnimatedSprite2D

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	current_health = max_health
	update_health_bar()

	hand.position = Vector2(hand_reach, 0)
	hand_hitbox.monitoring = false
	hand_hitbox.area_entered.connect(_on_hand_area_hit)

# ============================================================
# MAIN LOOP
# ============================================================
func _process(delta: float) -> void:
	update_attack_direction()
	handle_attack(delta)
	update_damage_flash(delta)

	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

func _physics_process(delta: float) -> void:
	handle_dash_timers(delta)

	# --- DASH GHOSTS + MOVEMENT ---
	if is_dashing:
		dash_ghost_timer -= delta
		if dash_ghost_timer <= 0.0:
			spawn_dash_ghost()
			dash_ghost_timer = dash_ghost_interval

		velocity = dash_dir * dash_speed
		move_and_slide()
		return

	# --- KNOCKBACK ---
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

	handle_movement()
	move_and_slide()

# ============================================================
# MOVEMENT
# ============================================================
func handle_movement() -> void:
	if is_hit_stunned:
		return

	input_dir = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	).normalized()

	velocity = input_dir * move_speed
	anim.play("run" if input_dir != Vector2.ZERO else "idle")

	handle_dash_input()

# ============================================================
# ATTACK DIRECTION
# ============================================================
func update_attack_direction() -> void:
	var dir := get_global_mouse_position() - global_position
	if dir.length() > 0:
		attack_dir = dir.normalized()

	facing_right = attack_dir.x >= 0
	anim.flip_h = not facing_right

# ============================================================
# ATTACK LOGIC
# ============================================================
func handle_attack(delta: float) -> void:
	match attack_state:
		AttackState.IDLE:
			smooth_return(delta)
			if Input.is_action_just_pressed("attack"):
				start_attack()

		AttackState.SWINGING:
			swing_progress += delta * swing_speed
			var t := clampf(swing_progress, 0.0, 1.0)
			var half_arc := deg_to_rad(swing_arc * 0.5)
			update_hand_orbit(attack_dir.angle() + lerpf(-half_arc, half_arc, t))
			if t >= 1.0:
				attack_state = AttackState.RETURNING

		AttackState.RETURNING:
			smooth_return(delta)
			if Input.is_action_just_pressed("attack"):
				start_attack()
				return
			if abs(hand_pivot.rotation - attack_dir.angle()) < 0.02:
				attack_state = AttackState.IDLE
				hand_hitbox.monitoring = false

func start_attack() -> void:
	if attack_state == AttackState.SWINGING:
		return
	if attack_cooldown_timer > 0.0:
		return

	attack_state = AttackState.SWINGING
	swing_progress = 0.0
	hand_hitbox.monitoring = true
	attack_cooldown_timer = attack_cooldown

	spawn_slash()

# ============================================================
# HAND
# ============================================================
func update_hand_orbit(angle: float) -> void:
	hand_pivot.rotation = angle
	hand.position = Vector2(hand_reach, 0)

func smooth_return(delta: float) -> void:
	hand_pivot.rotation = lerp_angle(
		hand_pivot.rotation,
		attack_dir.angle(),
		delta * return_speed
	)
	hand.position = Vector2(hand_reach, 0)

# ============================================================
# SLASH
# ============================================================
func spawn_slash() -> void:
	if slash_scene == null:
		return

	var slash := slash_scene.instantiate() as Node2D
	get_tree().current_scene.add_child(slash)

	slash.global_position = global_position + attack_dir * (hand_reach + 20.0)
	slash.rotation = attack_dir.angle()
	slash.direction = attack_dir

# ============================================================
# HAND HIT
# ============================================================
func _on_hand_area_hit(area: Area2D) -> void:
	var enemy := area.get_parent()
	if enemy and enemy.has_method("take_damage"):
		enemy.take_damage(hand_damage, global_position)

# ============================================================
# DASH
# ============================================================
func handle_dash_input() -> void:
	if Input.is_action_just_pressed("dash") and can_dash:
		start_dash()

func start_dash() -> void:
	is_dashing = true
	can_dash = false
	dash_timer = dash_duration
	dash_dir = input_dir if input_dir != Vector2.ZERO else attack_dir

	dash_ghost_timer = 0.0
	dash_ghost_index = 0

	set_white_silhouette(true)

func handle_dash_timers(delta: float) -> void:
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			dash_cooldown_timer = dash_cooldown
			set_white_silhouette(false)

	elif not can_dash:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0.0:
			can_dash = true

# ============================================================
# DAMAGE + FLASH FX (SHADER-BASED)
# ============================================================
func take_damage(amount: int, from: Vector2 = Vector2.ZERO) -> void:
	if is_invincible or is_dashing:
		return

	current_health -= amount
	current_health = clamp(current_health, 0, max_health)
	update_health_bar()

	is_invincible = true
	is_hit_stunned = true

	var overlay = get_tree().get_first_node_in_group("overlay")
	if overlay:
		overlay.flash(0.6, 0.25)

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
	flash_on = false

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
func set_white_silhouette(active: bool) -> void:
	if anim.material:
		anim.material.set_shader_parameter("silhouette", active)

func set_damage_flash(active: bool) -> void:
	if anim.material:
		anim.material.set_shader_parameter("damage_flash", active)

# ============================================================
# DASH GHOST
# ============================================================
func spawn_dash_ghost() -> void:
	var ghost := dash_ghost_scene.instantiate()
	get_tree().current_scene.add_child(ghost)

	var trail_dir := dash_dir if dash_dir != Vector2.ZERO else attack_dir
	ghost.setup_from_player(anim, trail_dir, dash_ghost_index)
	dash_ghost_index += 1
