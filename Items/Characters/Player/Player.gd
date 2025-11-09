extends CharacterBody2D

# -------------------------------
# CONFIG
# -------------------------------
@export var move_speed: float = 200.0
@export var attack_cooldown: float = 0.4
@export var attack_stop_time: float = 0.15
@export var slash_scene: PackedScene
@export var dust_scene: PackedScene
@export var weapon_damage_upgrade: float = 1.0
@export var max_health: int = 1
@onready var cam: Camera2D = $Camera2D

# --- Dash Config ---
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.2
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
var ghost_timer: float = 0.0
var locked_attack_dir: Vector2 = Vector2.ZERO
var is_hit_stunned: bool = false

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

	if is_dashing:
		velocity = dash_dir * dash_speed
		move_and_slide()
		ghost_timer -= delta
		if ghost_timer <= 0:
			spawn_dash_ghost()
			ghost_timer = ghost_spawn_interval
		return

	if attack_freeze_timer > 0.0:
		attack_freeze_timer -= delta
		move_and_slide()
	else:
		handle_movement_input(delta)
		move_and_slide()

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
	spawn_dash_smoke()

	if cam:
		var tw = create_tween()
		tw.tween_property(cam, "zoom", dash_zoom_in, dash_zoom_speed).set_trans(Tween.TRANS_SINE)

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

func end_dash() -> void:
	is_dashing = false
	dash_cooldown_timer = dash_cooldown
	anim.material = null

	if cam:
		var tw = create_tween()
		tw.tween_property(cam, "zoom", normal_zoom, dash_zoom_speed)

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
	if is_hit_stunned:
		return
	if is_attacking:
		return
	elif is_dashing:
		if "dash" in anim.sprite_frames.get_animation_names():
			anim.play("dash")
		else:
			anim.play("run")
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
var is_invincible: bool = false
@export var invincibility_time: float = 0.6

func update_health_bar() -> void:
	if health_bar:
		health_bar.value = current_health

func take_damage(amount: int, from: Vector2 = Vector2.ZERO) -> void:
	if is_dashing or is_invincible:
		return
	current_health -= amount
	current_health = clamp(current_health, 0, max_health)
	update_health_bar()
	play_hit_effects(from)
	if current_health <= 0:
		die()

func play_hit_effects(from: Vector2 = Vector2.ZERO) -> void:
	if is_invincible or current_health <= 0:
		return
	is_invincible = true
	is_attacking = false
	is_dashing = false
	is_hit_stunned = true

	# Knockback
	var knockback_dir = Vector2.ZERO
	if from != Vector2.ZERO:
		knockback_dir = (global_position - from).normalized()
	var knockback_force = 400.0
	var knockback_time = 0.15

	# Shake + overlay
	if cam:
		cam.shake(6, 0.15)
	var overlay = get_tree().get_first_node_in_group("overlay")
	if overlay:
		overlay.flash()

	# Small impact freeze
	await get_tree().create_timer(0.05).timeout

	# Knockback with collision
	var knockback_timer := get_tree().create_timer(knockback_time)
	while knockback_timer.time_left > 0:
		var motion: Vector2 = knockback_dir * knockback_force * get_process_delta_time()
		var collision = move_and_collide(motion)
		if collision:
			break
		await get_tree().process_frame

	is_hit_stunned = false
	velocity = Vector2.ZERO
	await get_tree().create_timer(invincibility_time).timeout
	is_invincible = false

# -------------------------------
# DEATH SEQUENCE 💀
# -------------------------------
func die() -> void:
	print("💀 Player died")

	# --- 1️⃣ Stop all player motion instantly ---
	velocity = Vector2.ZERO
	set_physics_process(false)
	set_process_input(false)

	# --- 2️⃣ Pause entire world ---
	get_tree().paused = true

	# --- 3️⃣ Allow only animation + overlays to keep running ---
	process_mode = Node.PROCESS_MODE_ALWAYS
	if anim:
		anim.process_mode = Node.PROCESS_MODE_ALWAYS

	var dmg_overlay = get_tree().get_first_node_in_group("overlay")
	var grey_layer = get_tree().get_first_node_in_group("greyscale")
	var death_overlay = get_tree().get_first_node_in_group("death_overlay")

	for node in [dmg_overlay, grey_layer, death_overlay]:
		if node:
			node.process_mode = Node.PROCESS_MODE_ALWAYS

	# --- 4️⃣ Trigger visuals simultaneously ---
	if dmg_overlay:
		dmg_overlay.flash(0.6, 0.3)  # red vignette flash

	if grey_layer:
		var rect = grey_layer.get_node_or_null("ColorRect")
		if rect and rect.material:
			var mat: ShaderMaterial = rect.material
			print("🎞️ Starting greyscale fade...")
			var tw := create_tween()
			tw.tween_method(
				func(value): mat.set_shader_parameter("intensity", value),
				0.0, 1.0, 0.4
			)

	# --- 5️⃣ Play death animation (still runs when paused) ---
	if anim and "death" in anim.sprite_frames.get_animation_names():
		print("🎭 Playing death animation")
		anim.play("death")
	else:
		print("⚠️ No 'death' animation found!")

	await anim.animation_finished

	# --- 6️⃣ Fade to black ---
	if death_overlay:
		print("🕳️ Fading to black...")
		await death_overlay.fade_to_black(2.0)
	else:
		print("⚠️ DeathOverlay not found!")

	print("🪦 Death sequence complete.")

# -------------------------------
# DASH VISUALS
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
		ghost.modulate = Color(0.4, 0.7, 1.0, 0.8)
	var tw = create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_callback(Callable(ghost, "queue_free"))
