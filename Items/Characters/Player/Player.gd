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
@export var max_health: int = 100   
@onready var cam: Camera2D = $Camera2D

# --- Dash Config ---
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.1
@export var dash_cooldown: float = 0.1
@export var dash_smoke_scene: PackedScene
@export var dash_zoom_in: Vector2 = Vector2(4.4, 4.4)
@export var normal_zoom: Vector2 = Vector2(4.0, 4.0)
@export var dash_zoom_speed: float = 0.15
@export var dash_ghost_scene: PackedScene
@export var ghost_spawn_interval: float = 0.05


# -------------------------------
# STATE
# -------------------------------
var input_dir: Vector2 = Vector2.ZERO
var facing_right: bool = true
var is_attacking: bool = false
var attack_locked: bool = false
var attack_hit_triggered: bool = false
var current_attack: String = ""
var attack_freeze_timer: float = 0.0
var current_health: int = max_health
var locked_attack_dir: Vector2 = Vector2.ZERO
var ghost_timer: float = 0.0

# --- Dash State ---
var is_dashing: bool = false
var can_dash: bool = true
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_dir: Vector2 = Vector2.ZERO

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
	handle_dash_timers(delta)

	# --- Prevent scale buildup ---
	if not is_dashing and anim.scale != Vector2.ONE:
		anim.scale = Vector2.ONE

	# --- Handle Dash Movement ---
	if is_dashing:
		velocity = dash_dir * dash_speed
		move_and_slide()

		# Spawn ghost trail while dashing
		ghost_timer -= delta
		if ghost_timer <= 0:
			spawn_dash_ghost()
			ghost_timer = ghost_spawn_interval
		return

	handle_movement_input(delta)
	move_and_slide()   # 🟢 movement always active (no freeze)

	# --- Keep health bar above player ---
	if health_bar:
		$HealthBar.position = Vector2(0, -40)


# -------------------------------
# MOVEMENT INPUT
# -------------------------------
func handle_movement_input(delta: float) -> void:
	if not is_attacking:
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


# -------------------------------
# DASH MECHANIC ⚡
# -------------------------------
func handle_dash_input() -> void:
	if Input.is_action_just_pressed("dash") and can_dash and not is_attacking:
		start_dash()

func start_dash() -> void:
	is_dashing = true
	can_dash = false
	dash_timer = dash_duration

	dash_dir = input_dir if input_dir != Vector2.ZERO else (Vector2.RIGHT if facing_right else Vector2.LEFT)
	anim.scale = Vector2.ONE
	spawn_dash_smoke()

	# --- CAMERA ZOOM IN ---
	if cam:
		var tw = create_tween()
		tw.tween_property(cam, "zoom", dash_zoom_in, dash_zoom_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# --- WHITE SILHOUETTE + SQUASH ---
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
		shader_type canvas_item;
		void fragment() {
			COLOR = vec4(1.0, 1.0, 1.0, texture(TEXTURE, UV).a);
		}
	"""
	mat.shader = shader
	anim.material = mat

	var tw = create_tween()
	tw.parallel().tween_property(anim, "scale", Vector2(1.4, 0.6), 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(anim, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func end_dash() -> void:
	is_dashing = false
	dash_cooldown_timer = dash_cooldown
	anim.scale = Vector2(1, 1)
	anim.material = null

	if cam:
		var tw = create_tween()
		tw.tween_property(cam, "zoom", normal_zoom, dash_zoom_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func handle_dash_timers(delta: float) -> void:
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			end_dash()
	elif not can_dash:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0:
			can_dash = true


# -------------------------------
# ATTACK LOGIC ⚔️
# -------------------------------
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

	# 🟢 Movement no longer frozen here
	attack_freeze_timer = 0.0

	if angle < -25 and angle > -155:
		current_attack = "vertical_slash"
	elif angle > 25 and angle < 155:
		current_attack = "charged_slash"
	else:
		current_attack = "horizontal_slash"

	anim.play(current_attack)
	attack_timer.start(attack_cooldown)


# -------------------------------
# FRAME EVENTS
# -------------------------------
func _on_frame_changed() -> void:
	if anim.animation == "horizontal_slash" and anim.frame == 4:
		trigger_attack_hit()
	elif anim.animation == "vertical_slash" and anim.frame == 3:
		trigger_attack_hit()
	elif anim.animation == "charged_slash" and anim.frame == 4:
		trigger_attack_hit()

	if anim.animation == "run" and (anim.frame == 2 or anim.frame == 6):
		spawn_dust()


# -------------------------------
# ATTACK PROJECTILE
# -------------------------------
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
	elif is_dashing:
		anim.play("dash") if "dash" in anim.sprite_frames.get_animation_names() else anim.play("run")
	elif input_dir == Vector2.ZERO:
		anim.play("idle")
	else:
		anim.play("run")


# -------------------------------
# FRAME-SYNCED DUST 💨
# -------------------------------
func spawn_dust() -> void:
	if dust_scene == null:
		return
	var dust = dust_scene.instantiate()
	get_parent().add_child(dust)
	var offset_distance = 10.0
	var offset_dir = Vector2.LEFT if facing_right else Vector2.RIGHT
	dust.global_position = global_position + offset_dir * offset_distance + Vector2(0, 8)
	dust.flip_h = not facing_right


# -------------------------------
# HEALTH SYSTEM ❤️
# -------------------------------
func take_damage(amount: int) -> void:
	if is_dashing:
		return
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
		set_physics_process(false)
		await anim.animation_finished
		queue_free()
	else:
		queue_free()


# -------------------------------
# DASH SMOKE 💨
# -------------------------------
func spawn_dash_smoke() -> void:
	if dash_smoke_scene == null:
		return
	var smoke = dash_smoke_scene.instantiate()
	get_parent().add_child(smoke)
	var offset_distance := 20.0
	var y_offset := -10.0
	var facing_dir := Vector2.RIGHT if facing_right else Vector2.LEFT
	var offset := -facing_dir * offset_distance + Vector2(0, y_offset)
	smoke.global_position = global_position + offset
	smoke.flip_h = not facing_right
	smoke.rotation = 0.0


# -------------------------------
# DASH GHOST TRAIL 👻 (with fade)
# -------------------------------
func spawn_dash_ghost() -> void:
	if dash_ghost_scene == null:
		return

	var ghost = dash_ghost_scene.instantiate()
	get_parent().add_child(ghost)

	var offset_distance := 15.0
	var facing_dir := Vector2.RIGHT if facing_right else Vector2.LEFT
	var offset := -facing_dir * offset_distance
	ghost.global_position = global_position + offset

	var frame_tex = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	if frame_tex:
		ghost.texture = frame_tex
		ghost.flip_h = anim.flip_h
		ghost.scale = Vector2(0.3, 0.3)

	# 🟢 Fade out smoothly, then free
	var tw = create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(Callable(ghost, "queue_free"))
