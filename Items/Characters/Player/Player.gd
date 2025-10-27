extends CharacterBody2D

# -------------------------------
# CONFIG
# -------------------------------
@export var move_speed: float = 200.0
@export var dash_speed: float = 500.0
@export var dash_duration: float = 0.18

# Bounce tuning (your original values)
@export var run_bounce_height: float = 3
@export var run_bounce_speed: float = 10

# Attack tuning
@export var charge_threshold: float = 0.8   # seconds to trigger charged attack
@export var attack_cooldown: float = 0.5     # delay between normal slashes
@export var charged_cooldown: float = 0.8    # delay after charged slash

# Charged lunge tuning
@export var charged_lunge_speed: float = 600.0   # how fast the lunge moves
@export var charged_lunge_time: float = 0.15     # how long the lunge lasts (seconds)
@export var charged_lunge_delay: float = 0.25    # delay before lunge begins (seconds)

# -------------------------------
# STATE
# -------------------------------
var input_dir: Vector2 = Vector2.ZERO
var dash_dir: Vector2 = Vector2.ZERO
var is_dashing: bool = false
var facing_right: bool = true
var is_attacking: bool = false
var is_charging: bool = false
var charge_timer: float = 0.0
var attack_locked: bool = false
var current_attack: String = ""   # "vertical_slash" or "charged_slash"

# Lunge timing
var lunge_timer: float = 0.0
var lunge_delay_timer: float = 0.0
var lunge_triggered: bool = false

# -------------------------------
# NODES
# -------------------------------
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var dash_timer: Timer = $DashTimer if has_node("DashTimer") else null
@onready var attack_timer: Timer = Timer.new()

func _ready() -> void:
	add_child(attack_timer)
	attack_timer.one_shot = true
	attack_timer.connect("timeout", Callable(self, "_on_attack_timer_timeout"))


# -------------------------------
# MAIN LOOP
# -------------------------------
func _physics_process(delta: float) -> void:
	# During charged slash — handle delayed lunge
	if current_attack == "charged_slash":
		handle_charged_attack_movement(delta)
		move_and_slide()
		return

	if not is_dashing:
		handle_movement_input(delta)
	else:
		velocity = dash_dir * dash_speed

	move_and_slide()

	# Disable bounce during vertical slash
	if current_attack != "vertical_slash":
		handle_run_bounce()
	else:
		anim.position.y = 0


# -------------------------------
# MOVEMENT INPUT
# -------------------------------
func handle_movement_input(delta: float) -> void:
	if not is_attacking:
		input_dir = Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_down")  - Input.get_action_strength("move_up")
		).normalized()

		velocity = input_dir * move_speed

		if input_dir != Vector2.ZERO:
			update_facing(input_dir)

	if Input.is_action_just_pressed("dash") and not is_dashing and not is_attacking:
		start_dash()

	handle_attack_input(delta)
	update_animation()


# -------------------------------
# ATTACK LOGIC
# -------------------------------
func handle_attack_input(delta: float) -> void:
	if attack_locked:
		return

	# Start charging
	if Input.is_action_pressed("attack"):
		if not is_charging:
			is_charging = true
			charge_timer = 0.0
		else:
			charge_timer += delta

	# Release attack
	elif Input.is_action_just_released("attack") and is_charging:
		is_charging = false

		if charge_timer >= charge_threshold:
			start_charged_attack()
		else:
			start_vertical_slash()

		charge_timer = 0.0


func start_vertical_slash() -> void:
	is_attacking = true
	attack_locked = true
	current_attack = "vertical_slash"
	anim.play("vertical_slash")

	velocity = Vector2.ZERO
	attack_timer.start(attack_cooldown)


func start_charged_attack() -> void:
	is_attacking = true
	attack_locked = true
	current_attack = "charged_slash"
	anim.play("charged_slash")

	# Reset movement and timers
	input_dir = Vector2.ZERO
	velocity = Vector2.ZERO
	lunge_timer = charged_lunge_time
	lunge_delay_timer = charged_lunge_delay
	lunge_triggered = false

	attack_timer.start(charged_cooldown)


func handle_charged_attack_movement(delta: float) -> void:
	# Wait for the delay (wind-up)
	if lunge_delay_timer > 0.0:
		lunge_delay_timer -= delta
		velocity = Vector2.ZERO
		return

	# Trigger the lunge once after delay
	if not lunge_triggered:
		lunge_triggered = true
		lunge_timer = charged_lunge_time

	# Perform the lunge
	if lunge_timer > 0.0:
		var dir = Vector2.RIGHT if facing_right else Vector2.LEFT
		velocity = dir * charged_lunge_speed
		lunge_timer -= delta
	else:
		velocity = Vector2.ZERO


func _on_attack_timer_timeout() -> void:
	is_attacking = false
	attack_locked = false
	current_attack = ""
	lunge_triggered = false
	lunge_delay_timer = 0.0
	lunge_timer = 0.0


# -------------------------------
# FACING + ANIMATION
# -------------------------------
func update_facing(dir: Vector2) -> void:
	if dir.x != 0:
		facing_right = dir.x > 0
	anim.flip_h = not facing_right


func update_animation() -> void:
	if is_attacking or is_dashing:
		return
	elif input_dir == Vector2.ZERO:
		anim.play("idle")
	else:
		anim.play("run")


# -------------------------------
# DASH LOGIC
# -------------------------------
func start_dash() -> void:
	is_dashing = true
	dash_dir = input_dir if input_dir != Vector2.ZERO else Vector2(facing_right if facing_right else -1, 0)
	play_dash_animation(dash_dir)

	if dash_timer:
		dash_timer.start(dash_duration)
	else:
		push_warning("DashTimer not found! Please add a Timer node named 'DashTimer'.")


func play_dash_animation(dir: Vector2) -> void:
	anim.play("dash")
	anim.flip_h = dir.x < 0


func _on_dash_timer_timeout() -> void:
	is_dashing = false


# -------------------------------
# RUN BOUNCE (smooth sine wave)
# -------------------------------
func handle_run_bounce() -> void:
	if not is_dashing and input_dir != Vector2.ZERO:
		var run_fps = anim.sprite_frames.get_animation_speed("run")
		var t = Time.get_ticks_msec() / 1000.0
		var bounce_offset = sin(t * PI * (run_fps / 2.0) + PI / 2.0) * run_bounce_height
		anim.position.y = bounce_offset
	else:
		anim.position.y = 0
