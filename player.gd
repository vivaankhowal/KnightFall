extends CharacterBody2D

# -------------------------------
# CONFIG
# -------------------------------
@export var move_speed: float = 200.0
@export var dash_speed: float = 500.0
@export var dash_duration: float = 0.18

# -------------------------------
# STATE
# -------------------------------
var input_dir: Vector2 = Vector2.ZERO
var dash_dir: Vector2 = Vector2.ZERO
var is_dashing: bool = false
var facing_right: bool = true

# -------------------------------
# NODES
# -------------------------------
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var dash_timer: Timer = $DashTimer if has_node("DashTimer") else null


# -------------------------------
# MAIN LOOP
# -------------------------------
func _physics_process(delta: float) -> void:
	if not is_dashing:
		handle_movement_input()
	else:
		velocity = dash_dir * dash_speed

	move_and_slide()


# -------------------------------
# MOVEMENT INPUT
# -------------------------------
func handle_movement_input() -> void:
	input_dir = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down")  - Input.get_action_strength("move_up")
	).normalized()

	velocity = input_dir * move_speed

	if input_dir != Vector2.ZERO:
		update_facing(input_dir)

	if Input.is_action_just_pressed("dash") and not is_dashing:
		start_dash()

	update_animation()


# -------------------------------
# FACING + ANIMATION
# -------------------------------
func update_facing(dir: Vector2) -> void:
	if dir.x != 0:
		facing_right = dir.x > 0
	anim.flip_h = not facing_right


func update_animation() -> void:
	if is_dashing:
		return  # handled separately
	elif input_dir == Vector2.ZERO:
		anim.play("idle")
	else:
		anim.play("run")


# -------------------------------
# DASH LOGIC
# -------------------------------
func start_dash() -> void:
	is_dashing = true

	# Choose dash direction — if no input, dash in facing direction
	dash_dir = input_dir if input_dir != Vector2.ZERO else Vector2(facing_right if facing_right else -1, 0)

	play_dash_animation(dash_dir)

	if dash_timer:
		dash_timer.start(dash_duration)
	else:
		push_warning("DashTimer not found! Please add a Timer node named 'DashTimer'.")


func play_dash_animation(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		anim.play("dash_side")
		anim.flip_h = dir.x < 0
	elif dir.y < 0:
		anim.play("dash_up")
	else:
		anim.play("dash_down")


func _on_dash_timer_timeout() -> void:
	is_dashing = false
