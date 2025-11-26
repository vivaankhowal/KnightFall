extends CharacterBody2D

# ==========================
# ---  ENEMY STATS
# ==========================
@export var move_speed: float = 200.0
@export var damage: int = 10
@export var max_health: int = 20
@export var attack_cooldown: float = 1.0
@export var target_path: NodePath

# ==========================
# ---  INTERNAL STATE
# ==========================
var current_health: int
var player: Node = null
var can_attack: bool = true
var is_dead: bool = false
var player_in_range: bool = false
var spawning: bool = true
var knockback_time := 0.0
const KNOCKBACK_DURATION := 0.18
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_friction: float = 600.0
var squash_tween: Tween
var sprite_material: ShaderMaterial


# ==========================
# ---  CORPSE JUMP MODE
# ==========================
var corpse_mode := false
var corpse_velocity := Vector2.ZERO
var corpse_drag := 8.0
var corpse_landed := false

var corpse_jump_height := 18.0
var corpse_jump_time := 0.28
var corpse_jump_elapsed := 0.0
var corpse_vertical_offset := 0.0


# ==========================
# ---  NODE REFERENCES
# ==========================
@onready var anim: AnimatedSprite2D = $SpriteRoot/AnimatedSprite2D
@onready var corpse_sprite: Sprite2D = $SpriteRoot/CorpseSprite
@onready var attack_area: Area2D = $AttackArea
@onready var cooldown_timer: Timer = Timer.new()
@onready var health_bar: TextureProgressBar = $HealthBar/TextureBar
@onready var sprite_root = $SpriteRoot


# ======================================================
# READY
# ======================================================
func _ready():
	anim.material = anim.material.duplicate()
	sprite_material = anim.material
	corpse_sprite.material = anim.material.duplicate()   # give corpse shader

	anim.animation_finished.connect(_on_anim_finished)

	if target_path != NodePath():
		player = get_node_or_null(target_path)
	else:
		player = get_tree().get_first_node_in_group("player")

	if not player:
		print("⚠️ No player found!")

	cooldown_timer.one_shot = true
	add_child(cooldown_timer)
	cooldown_timer.timeout.connect(_on_cooldown_timeout)

	attack_area.body_entered.connect(_on_attack_area_body_entered)
	attack_area.body_exited.connect(_on_attack_area_body_exited)

	current_health = max_health
	update_health_bar()

	if "spawn" in anim.sprite_frames.get_animation_names():
		play_scaled_animation("spawn", 0.3)
		await anim.animation_finished

	spawning = false
	play_scaled_animation("walk", 0.3)

	print("✅ Enemy ready")



# ======================================================
# PHYSICS PROCESS
# ======================================================
func _physics_process(delta: float) -> void:

	# ========= CORPSE MODE (jump arc) ==========
	if corpse_mode:

		# jump progression
		corpse_jump_elapsed += delta
		var t := corpse_jump_elapsed / corpse_jump_time
		if t > 1.0: t = 1.0

		# parabolic arc
		var jump_amount := 1.0 - pow(2.0*t - 1.0, 2.0)
		corpse_vertical_offset = jump_amount * corpse_jump_height

		sprite_root.position.y = -corpse_vertical_offset

		# horizontal slide
		corpse_velocity.x = lerp(corpse_velocity.x, 0.0, corpse_drag * delta)
		velocity = corpse_velocity
		move_and_slide()

		# EXACT landing moment
		if t == 1.0 and not corpse_landed:
			corpse_landed = true
			_on_corpse_landed()

		return
	# ==========================================


	# knockback slide
	if knockback_velocity.length() > 1.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
		move_and_slide()
		return

	if is_dead or spawning or not player:
		return

	var dir = (player.global_position - global_position).normalized()

	if not player_in_range:
		velocity = dir * move_speed
		anim.flip_h = dir.x < 0
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	if player_in_range and can_attack:
		attack_player()



# ======================================================
# ATTACK SYSTEM
# ======================================================
func _on_attack_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true

func _on_attack_area_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false


func attack_player():
	if is_dead or spawning or not can_attack:
		return

	can_attack = false

	if "attack" in anim.sprite_frames.get_animation_names():
		anim.play("attack")

	if player and player.has_method("take_damage"):
		player.take_damage(damage, global_position)
		await anim.animation_finished
		play_scaled_animation("walk", 0.3)

	cooldown_timer.start(attack_cooldown)



# ======================================================
# DAMAGE & DEATH
# ======================================================
func take_damage(amount: int, from: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	current_health -= amount
	update_health_bar()

	# white flash
	if sprite_material:
		sprite_material.set("shader_parameter/flash_strength", 1.0)
		get_tree().create_timer(0.2).timeout.connect(func():
			sprite_material.set("shader_parameter/flash_strength", 0.0)
		)

	# knockback
	var dir = (global_position - player.global_position).normalized()
	knockback_velocity = dir * 150

	# squash
	if squash_tween:
		squash_tween.kill()
	squash_tween = create_tween()
	squash_tween.tween_property(sprite_root, "scale", Vector2(1.0, 0.70), 0.08)
	squash_tween.tween_property(sprite_root, "scale", Vector2.ONE, 0.12)

	# hit anim
	if "hit" in anim.sprite_frames.get_animation_names():
		anim.play("hit")

	if current_health <= 0:
		die()
		return

	play_scaled_animation("walk", 0.3)



# ======================================================
# >>> DEATH – JUMP BACK ARC <<<
# ======================================================
func die():
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO
	$HealthBar.visible = false

	# disable attacks only
	attack_area.monitoring = false

	# corpse sprite takes over
	anim.visible = false
	corpse_sprite.visible = true
	corpse_sprite.texture = anim.sprite_frames.get_frame_texture("walk", 0)
	corpse_sprite.scale = Vector2(0.3, 0.3)   # scale corpse to match normal animations

	# backward tilt direction
	var dir: float = sign(global_position.x - player.global_position.x)
	if dir == 0.0: dir = 1.0

	# horizontal launch
	corpse_velocity = Vector2(dir * 700, 0)   # ← adjust distance here

	# enable corpse flight
	corpse_mode = true
	corpse_jump_elapsed = 0
	corpse_landed = false

	# tilt away from player
	var tilt_angle: float = 25.0 * dir
	var t: Tween = create_tween()
	t.tween_property(sprite_root, "rotation_degrees", tilt_angle, 0.12)



# ======================================================
# >>> LANDING → WHITE FLASH → UPRIGHT → DEATH ANIM <<<
# ======================================================
func _on_corpse_landed():
	# swap back to animated sprite
	corpse_sprite.visible = false
	anim.visible = true
	anim.scale = Vector2(0.3, 0.3)   # ensure normal-sized sprite when returning

	# RESET rotation before death animation
	sprite_root.rotation_degrees = 0

	# WHITE FLASH on landing
	if sprite_material:
		sprite_material.set("shader_parameter/flash_strength", 1.0)

	await get_tree().create_timer(0.10).timeout

	if sprite_material:
		sprite_material.set("shader_parameter/flash_strength", 0.0)

	# play death animation upright
	if anim.sprite_frames.has_animation("death"):
		play_scaled_animation("death", 0.1)
		await anim.animation_finished

	queue_free()



# ======================================================
# HEALTH BAR
# ======================================================
func update_health_bar():
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

func play_scaled_animation(anim_name: String, scale: float):
	anim.scale = Vector2(scale, scale)
	anim.play(anim_name)

func _on_anim_finished():
	anim.scale = Vector2.ONE

func _on_cooldown_timeout():
	can_attack = true

	if player_in_range and not is_dead:
		attack_player()
