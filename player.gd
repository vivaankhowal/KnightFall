extends CharacterBody2D

@export var move_speed: float = 200.0
@export var dash_speed: float = 500.0
@export var dash_duration: float = 0.2
@export var weapon_distance: float = 13.0     # how far the sword drags behind player
@export var drag_height: float = 10.0         # how low the sword drags (vertical offset)

var is_dashing: bool = false
var dash_dir: Vector2 = Vector2.ZERO
var last_move_dir: Vector2 = Vector2.DOWN
var facing_right: bool = true
var is_swinging: bool = false

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var weapon: Node2D = $Weapon/Sword
@onready var dash_timer: Timer = $DashTimer


func _physics_process(delta):
	# --------------------------------
	# Player movement input
	# --------------------------------
	var input_vector = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	).normalized()

	# Dash logic
	if not is_dashing:
		velocity = input_vector * move_speed
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
	$Weapon.facing_right = facing_right

	update_facing_direction(input_vector)
	update_weapon_position()
	
	if Input.is_action_just_pressed("attack") and not is_swinging:
		swing_sword()



# ----------------------------------------------------
# --- Facing Direction + Sword Drag ---
# ----------------------------------------------------
func update_facing_direction(input_vector: Vector2):
	if input_vector.x > 0:
		facing_right = true
	elif input_vector.x < 0:
		facing_right = false

	anim_sprite.flip_h = not facing_right

	# Flip sword horizontally
	$Weapon/Sword.scale.x = 1 if facing_right else -1



func update_weapon_position():
	# Sword follows the player's exact position (no offset)
	weapon.global_position = global_position

	# Keep rotation and flip logic as-is
	weapon.rotation_degrees = 250 if facing_right else -250
	weapon.scale.x = -1 if facing_right else 1


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
	dash_timer.start(dash_duration)


func _on_dash_timer_timeout():
	is_dashing = false

func swing_sword():
	if is_swinging:
		return
	is_swinging = true

	var base_rot = 250 if facing_right else -250
	var swing_range = 140  # swing width

	var swing_start = base_rot + (swing_range / 2) * (1 if facing_right else -1)
	var swing_end = base_rot - (swing_range / 2) * (1 if facing_right else -1)

	var tween = create_tween()
	tween.set_parallel(false)

	# Rotate the visible sword, not the Weapon node
	tween.tween_property($Weapon/Sword, "rotation_degrees", swing_end, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property($Weapon/Sword, "rotation_degrees", base_rot, 0.18).set_delay(0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	tween.tween_callback(func():
		is_swinging = false
	)
