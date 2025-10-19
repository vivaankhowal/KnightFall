extends CharacterBody2D

@export var move_speed: float = 200.0
@export var dash_speed: float = 500.0
@export var dash_duration: float = 0.2

var is_dashing: bool = false
var dash_dir: Vector2 = Vector2.ZERO
var last_move_dir: Vector2 = Vector2.DOWN  # remember last facing direction

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta):
	var input_vector = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	).normalized()

	# --- Movement ---
	if not is_dashing:
		velocity = input_vector * move_speed

		# Remember direction for facing/dash
		if input_vector != Vector2.ZERO:
			last_move_dir = input_vector

		# Start dash
		if Input.is_action_just_pressed("dash") and last_move_dir != Vector2.ZERO:
			start_dash(last_move_dir)

		update_animation(input_vector)
	else:
		velocity = dash_dir * dash_speed
		play_dash_animation(dash_dir)

	move_and_slide()


# ----------------------------------------------------
# --- Animation Logic ---
# ----------------------------------------------------
func update_animation(dir: Vector2):
	if is_dashing:
		return

	if dir == Vector2.ZERO:
		anim_sprite.play("idle")
		return

	anim_sprite.play("run")

	# Flip sprite horizontally if moving left
	if dir.x != 0:
		anim_sprite.flip_h = dir.x < 0


func play_dash_animation(dir: Vector2):
	if abs(dir.x) > abs(dir.y):
		anim_sprite.play("dash_side")
		anim_sprite.flip_h = dir.x < 0
	elif dir.y < 0:
		anim_sprite.play("dash_up")
	else:
		anim_sprite.play("dash_up")


# ----------------------------------------------------
# --- Dash System ---
# ----------------------------------------------------
func start_dash(direction: Vector2):
	is_dashing = true
	dash_dir = direction.normalized()
	play_dash_animation(dash_dir)
	$DashTimer.start(dash_duration)

func _on_dash_timer_timeout():
	is_dashing = false
