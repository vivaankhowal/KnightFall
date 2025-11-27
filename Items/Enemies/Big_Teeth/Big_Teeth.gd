extends CharacterBody2D

# ======================================================
# ===============  TUNABLE EXPORTED VARIABLES ==========
# ======================================================

# Movement / Combat
@export var move_speed: float = 160.0
@export var damage: int = 10
@export var max_health: int = 50
@export var attack_cooldown: float = 1.0
@export var target_path: NodePath

# Hit Knockback
@export var hit_knockback_force: float = 150.0
@export var hit_knockback_friction: float = 600.0

# Death Knockback
@export var death_knockback_force: float = 2200.0
@export var death_tilt_angle: float = 20.0
@export var corpse_drag: float = 4.0

# Death Arc
@export var corpse_jump_height: float = 40.0
@export var corpse_jump_time: float = 0.4

# ======================================================
# ================== INTERNAL STATE ====================
# ======================================================

var current_health: int
var player: Node = null
var can_attack: bool = true
var is_dead: bool = false
var player_in_range: bool = false
var spawning: bool = true

var knockback_velocity: Vector2 = Vector2.ZERO
var squash_tween: Tween
var sprite_material: ShaderMaterial

# Corpse physics
var corpse_mode := false
var corpse_velocity := Vector2.ZERO
var corpse_landed := false
var corpse_jump_elapsed: float = 0.0
var corpse_vertical_offset: float = 0.0

# ======================================================
# ===================== NODE REFERENCES ===============
# ======================================================

@onready var anim: AnimatedSprite2D = $SpriteRoot/AnimatedSprite2D
@onready var corpse_sprite: Sprite2D = $SpriteRoot/CorpseSprite
@onready var attack_area: Area2D = $AttackArea
@onready var cooldown_timer: Timer = Timer.new()
@onready var health_bar: TextureProgressBar = $HealthBar/TextureBar
@onready var sprite_root = $SpriteRoot

# ======================================================
# ========================= READY ======================
# ======================================================

func _ready():
	anim.material = anim.material.duplicate()
	sprite_material = anim.material
	corpse_sprite.material = anim.material.duplicate()
	anim.animation_finished.connect(_on_anim_finished)

	if target_path != NodePath():
		player = get_node_or_null(target_path)
	else:
		player = get_tree().get_first_node_in_group("player")

	add_child(cooldown_timer)
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_timeout)

	attack_area.body_entered.connect(_on_attack_area_body_entered)
	attack_area.body_exited.connect(_on_attack_area_body_exited)

	current_health = max_health
	update_health_bar()

	if anim.sprite_frames.has_animation("spawn"):
		anim.play("spawn")
		await anim.animation_finished

	spawning = false
	anim.play("walk")

# ======================================================
# ==================== PHYSICS PROCESS =================
# ======================================================

func _physics_process(delta: float) -> void:

	if corpse_mode:
		_process_corpse_jump(delta)
		return

	if knockback_velocity.length() > 1.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, hit_knockback_friction * delta)
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
# ====================== CORPSE JUMP ===================
# ======================================================

func _process_corpse_jump(delta):
	corpse_jump_elapsed += delta
	var t: float = min(corpse_jump_elapsed / corpse_jump_time, 1.0)

	var jump_amount := 1.0 - pow(2.0 * t - 1.0, 2.0)
	corpse_vertical_offset = jump_amount * corpse_jump_height
	sprite_root.position.y = -corpse_vertical_offset

	corpse_velocity.x = lerp(corpse_velocity.x, 0.0, corpse_drag * delta)
	velocity = corpse_velocity
	move_and_slide()

	if t == 1.0 and not corpse_landed:
		corpse_landed = true
		_on_corpse_landed()

# ======================================================
# ======================== ATTACK ======================
# ======================================================

func _on_attack_area_body_entered(body: Node):
	if body.is_in_group("player"):
		player_in_range = true

func _on_attack_area_body_exited(body: Node):
	if body.is_in_group("player"):
		player_in_range = false

func attack_player():
	if is_dead or spawning or not can_attack:
		return

	can_attack = false

	if anim.sprite_frames.has_animation("attack"):
		anim.play("attack")

	if player and player.has_method("take_damage"):
		player.take_damage(damage, global_position)
		await anim.animation_finished
		anim.play("walk")

	cooldown_timer.start(attack_cooldown)

func _on_cooldown_timeout():
	can_attack = true

# ======================================================
# ==================== DAMAGE & DEATH ==================
# ======================================================

func take_damage(amount: int, from: Vector2 = Vector2.ZERO):
	if is_dead: return

	current_health -= amount
	update_health_bar()

	if sprite_material:
		sprite_material.set("shader_parameter/flash_strength", 1.0)
		get_tree().create_timer(0.2).timeout.connect(func():
			sprite_material.set("shader_parameter/flash_strength", 0.0)
		)

	var dir = (global_position - player.global_position).normalized()
	knockback_velocity = dir * hit_knockback_force

	if anim.sprite_frames.has_animation("hit"):
		anim.play("hit")

	if current_health <= 0:
		die()
		return

	anim.play("walk")

# ======================================================
# ======================== DEATH =======================
# ======================================================

func die():
	if is_dead: return

	is_dead = true
	velocity = Vector2.ZERO
	$HealthBar.visible = false
	player_in_range = false
	attack_area.monitoring = false

	anim.stop()
	anim.visible = false

	corpse_sprite.texture = anim.sprite_frames.get_frame_texture("walk", 0)
	corpse_sprite.visible = true

	var face_dir: float = sign(player.global_position.x - global_position.x)
	if face_dir == 0: face_dir = 1

	anim.flip_h = face_dir < 0
	corpse_sprite.flip_h = face_dir < 0

	var knockback_dir: float = -face_dir
	corpse_velocity = Vector2(knockback_dir * death_knockback_force, 0)

	corpse_mode = true
	corpse_jump_elapsed = 0.0
	corpse_landed = false
	sprite_root.rotation_degrees = -death_tilt_angle * face_dir

# ======================================================
# ======================= LANDING ======================
# ======================================================

func _on_corpse_landed():
	corpse_sprite.visible = false
	anim.visible = true

	sprite_root.rotation_degrees = 0.0

	if sprite_material:
		sprite_material.set("shader_parameter/flash_strength", 1.0)
	await get_tree().create_timer(0.1).timeout
	if sprite_material:
		sprite_material.set("shader_parameter/flash_strength", 0.0)

	if anim.sprite_frames.has_animation("death"):
		anim.play("death")
		await anim.animation_finished

	queue_free()

# ======================================================
# ===================== HEALTH BAR =====================
# ======================================================

func update_health_bar():
	health_bar.max_value = max_health
	health_bar.value = current_health

func _on_anim_finished():
	anim.scale = Vector2.ONE  # scale stays default
