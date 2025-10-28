extends CharacterBody2D

# -------------------------------
# CONFIG
# -------------------------------
@export var move_speed: float = 200.0
@export var attack_cooldown: float = 0.5
@export var slash_scene: PackedScene


# -------------------------------
# STATE
# -------------------------------
var input_dir: Vector2 = Vector2.ZERO
var facing_right: bool = true
var is_attacking: bool = false
var is_charging: bool = false
var is_blocking: bool = false
var attack_locked: bool = false
var current_attack: String = ""

# -------------------------------
# NODES
# -------------------------------
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_timer: Timer = Timer.new()

func _ready() -> void:
	add_child(attack_timer)
	attack_timer.one_shot = true
	attack_timer.connect("timeout", Callable(self, "_on_attack_timer_timeout"))


# -------------------------------
# MAIN LOOP
# -------------------------------
func _physics_process(delta: float) -> void:
	handle_movement_input(delta)
	move_and_slide()


# -------------------------------
# MOVEMENT INPUT
# -------------------------------
func handle_movement_input(delta: float) -> void:
	if Input.is_action_pressed("block"):
		start_block()
	else:
		stop_block()

	if not is_attacking and not is_blocking:
		input_dir = Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_down")  - Input.get_action_strength("move_up")
		).normalized()

		velocity = input_dir * move_speed

		if input_dir != Vector2.ZERO:
			update_facing(input_dir)

	elif is_blocking:
		input_dir = Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_down")  - Input.get_action_strength("move_up")
		).normalized()

		var guard_speed = move_speed * 0.6
		velocity = input_dir * guard_speed

		if input_dir != Vector2.ZERO:
			update_facing(input_dir)

	handle_attack_input(delta)
	update_animation()


# -------------------------------
# BLOCK / SHIELD
# -------------------------------
func start_block() -> void:
	if is_attacking:
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
		start_directional_attack()


func start_directional_attack() -> void:
	is_attacking = true
	attack_locked = true

	var mouse_pos = get_global_mouse_position()
	var dir_to_mouse = (mouse_pos - global_position).normalized()
	var angle = rad_to_deg(dir_to_mouse.angle())

	print("Cursor angle:", angle)

	facing_right = dir_to_mouse.x >= 0
	anim.flip_h = not facing_right

	if angle < -25 and angle > -155:
		current_attack = "vertical_slash"
	elif angle > 25 and angle < 155:
		current_attack = "charged_slash"
	else:
		current_attack = "horizontal_slash"

	anim.play(current_attack)
	velocity = Vector2.ZERO
	attack_timer.start(attack_cooldown)

	# 🔥 Spawn the slash projectile
	var slash = slash_scene.instantiate()
	get_parent().add_child(slash)
	var dir = dir_to_mouse
	var perpendicular = Vector2(-dir.y, dir.x).normalized()
	slash.global_position = global_position + dir * 5.0 + perpendicular * -6.0
	slash.direction = dir



func _on_attack_timer_timeout() -> void:
	is_attacking = false
	attack_locked = false
	current_attack = ""


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
