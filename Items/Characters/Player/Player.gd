extends CharacterBody2D

# -------------------------------
# CONFIG
# -------------------------------
@export var move_speed: float = 200.0
@export var attack_cooldown: float = 0.4
@export var slash_scene: PackedScene
@export var dust_scene: PackedScene
@export var weapon_damage_upgrade: float = 1.0
@export var attack_stop_time: float = 0.15
@export var guard_speed_mult: float = 0.6   # slower while guarding
@export var max_health: int = 100           # ❤️ player max health

# -------------------------------
# STATE
# -------------------------------
var input_dir: Vector2 = Vector2.ZERO
var facing_right: bool = true
var is_attacking: bool = false
var is_blocking: bool = false
var attack_locked: bool = false
var attack_hit_triggered: bool = false
var current_attack: String = ""
var attack_freeze_timer: float = 0.0
var current_health: int = max_health

# -------------------------------
# NODES
# -------------------------------
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_timer: Timer = Timer.new()
@onready var health_bar: ProgressBar = $HealthBar/ProgressBar

# -------------------------------
# READY
# -------------------------------
func _ready() -> void:
	anim.connect("frame_changed", Callable(self, "_on_frame_changed"))
	add_child(attack_timer)
	attack_timer.one_shot = true
	attack_timer.connect("timeout", Callable(self, "_on_attack_timer_timeout"))
	current_health = max_health
	update_health_bar()

# -------------------------------
# MAIN LOOP
# -------------------------------
func _physics_process(delta: float) -> void:
	# Short movement freeze during attack
	if attack_freeze_timer > 0.0:
		attack_freeze_timer -= delta
		move_and_slide()
	else:
		handle_movement_input(delta)
		move_and_slide()

	# keep health bar above player
	if health_bar:
		$HealthBar.position = Vector2(0, -40)

# -------------------------------
# MOVEMENT INPUT
# -------------------------------
func handle_movement_input(delta: float) -> void:
	# Handle blocking
	if Input.is_action_pressed("block"):
		start_block()
	else:
		stop_block()

	if not is_attacking:
		input_dir = Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
		).normalized()

		var speed = move_speed
		if is_blocking:
			speed *= guard_speed_mult

		velocity = input_dir * speed

		if input_dir != Vector2.ZERO:
			update_facing(input_dir)

	handle_attack_input(delta)
	update_animation()

# -------------------------------
# BLOCK / GUARD
# -------------------------------
func start_block() -> void:
	if is_attacking:
		# cancel attack if you block mid-swing
		is_attacking = false
		current_attack = ""
		attack_timer.stop()
	is_blocking = true

func stop_block() -> void:
	if is_blocking and not Input.is_action_pressed("block"):
		is_blocking = false

# -------------------------------
# ATTACK LOGIC
# -------------------------------
func handle_attack_input(delta: float) -> void:
	if attack_locked or is_blocking:
		return

	if Input.is_action_just_pressed("attack"):
		start_attack()

func start_attack() -> void:
	is_attacking = true
	attack_locked = true
	attack_hit_triggered = false

	var mouse_pos = get_global_mouse_position()
	var dir_to_mouse = (mouse_pos - global_position).normalized()
	var angle = rad_to_deg(dir_to_mouse.angle())

	facing_right = dir_to_mouse.x >= 0
	anim.flip_h = not facing_right

	# Stop player briefly during swing
	velocity = Vector2.ZERO
	attack_freeze_timer = attack_stop_time

	# Choose attack animation
	if angle < -25 and angle > -155:
		current_attack = "vertical_slash"
	elif angle > 25 and angle < 155:
		current_attack = "charged_slash"
	else:
		current_attack = "horizontal_slash"

	anim.play(current_attack)
	attack_timer.start(attack_cooldown)

# -------------------------------
# FRAME EVENTS (ATTACK + DUST)
# -------------------------------
func _on_frame_changed() -> void:
	# --- Attack frames ---
	if anim.animation == "horizontal_slash" and anim.frame == 4:
		trigger_attack_hit()
	elif anim.animation == "vertical_slash" and anim.frame == 3:
		trigger_attack_hit()
	elif anim.animation == "charged_slash" and anim.frame == 4:
		trigger_attack_hit()

	# --- Frame-synced dust ---
	if anim.animation == "run" and (anim.frame == 2 or anim.frame == 6):
		spawn_dust()
	elif anim.animation == "guard_run" and (anim.frame == 2 or anim.frame == 6):
		spawn_dust()

# -------------------------------
# ATTACK PROJECTILE
# -------------------------------
func trigger_attack_hit() -> void:
	if attack_hit_triggered:
		return
	attack_hit_triggered = true

	var dir_to_mouse = (get_global_mouse_position() - global_position).normalized()
	spawn_slash_projectile(dir_to_mouse)

func spawn_slash_projectile(direction: Vector2) -> void:
	if slash_scene == null:
		push_warning("Slash scene not assigned!")
		return

	var slash = slash_scene.instantiate()
	get_parent().add_child(slash)

	# Fixed offset – always the same distance from player
	var spawn_distance := 40.0
	slash.global_position = global_position + direction * spawn_distance
	slash.rotation = direction.angle()
	slash.direction = direction
	slash.damage_multiplier = weapon_damage_upgrade

# -------------------------------
# ATTACK RESET
# -------------------------------
func _on_attack_timer_timeout() -> void:
	is_attacking = false
	attack_locked = false
	current_attack = ""
	attack_hit_triggered = false

# -------------------------------
# FACING + ANIMATION
# -------------------------------
func update_facing(dir: Vector2) -> void:
	if dir.x != 0:
		facing_right = dir.x > 0
	anim.flip_h = not facing_right

func update_animation() -> void:
	if is_attacking:
		return
	elif is_blocking:
		if input_dir == Vector2.ZERO:
			anim.play("guard")
		else:
			anim.play("guard_run")
	elif input_dir == Vector2.ZERO:
		anim.play("idle")
	else:
		anim.play("run")

# -------------------------------
# FRAME-SYNCED DUST SYSTEM 💨
# -------------------------------
func spawn_dust() -> void:
	if dust_scene == null:
		return

	var dust = dust_scene.instantiate()
	get_parent().add_child(dust)

	# Offset slightly behind player
	var offset_distance = 10.0
	var offset_dir = Vector2.LEFT if facing_right else Vector2.RIGHT
	dust.global_position = global_position + offset_dir * offset_distance + Vector2(0, 8)

	# Flip to match facing
	dust.flip_h = not facing_right
	dust.speed_scale = 0.6 if is_blocking else 1.0

# -------------------------------
# HEALTH SYSTEM ❤️
# -------------------------------
func take_damage(amount: int) -> void:
	current_health -= amount
	current_health = clamp(current_health, 0, max_health)
	update_health_bar()
	if current_health <= 0:
		die()

func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)
	update_health_bar()

func update_health_bar() -> void:
	if health_bar:
		health_bar.value = current_health

func die() -> void:
	print("💀 Player Died!")

	if "death" in anim.sprite_frames.get_animation_names():
		anim.play("death")
		velocity = Vector2.ZERO
		set_physics_process(false)  # stop movement/attacks
		# wait for animation to finish before removing player
		await anim.animation_finished
		queue_free()
	else:
		queue_free()
