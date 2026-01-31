extends CharacterBody2D

# ======================================================
# ===============  TUNABLE EXPORTED VARIABLES ==========
# ======================================================

@export var move_speed: float = 50.0
@export var damage: int = 10
@export var max_health: int = 20
@export var attack_cooldown: float = 1.0
@export var target_path: NodePath

# Normal hit knockback
@export var hit_knockback_force: float = 200.0
@export var hit_knockback_friction: float = 600.0

# ======================================================
# ================== INTERNAL STATE ====================
# ======================================================

var current_health: int
var player: Node = null
var can_attack: bool = true
var is_dead: bool = false
var player_in_range: bool = false
var spawning: bool = true

var sprite_material: ShaderMaterial
var squash_tween: Tween
var knockback_velocity: Vector2 = Vector2.ZERO

# ======================================================
# ===================== NODE REFERENCES ===============
# ======================================================

@onready var anim: AnimatedSprite2D = $SpriteRoot/AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var cooldown_timer: Timer = Timer.new()
@onready var health_bar: TextureProgressBar = $HealthBar/TextureBar
@onready var sprite_root := $SpriteRoot

# ======================================================
# ========================= READY ======================
# ======================================================

func _ready():
	anim.material = anim.material.duplicate()
	sprite_material = anim.material

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
	if is_dead or spawning or not player:
		return

	# Hit knockback
	if knockback_velocity.length() > 1.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(
			Vector2.ZERO,
			hit_knockback_friction * delta
		)
		move_and_slide()
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

	if player and player.has_method("take_damage"):
		player.take_damage(damage, global_position)

	# Enemy recoil
	var dir = (global_position - player.global_position).normalized()
	knockback_velocity = dir * hit_knockback_force

	cooldown_timer.start(attack_cooldown)

func _on_cooldown_timeout():
	can_attack = true

# ======================================================
# ==================== DAMAGE & DEATH ==================
# ======================================================

func take_damage(amount: int, from: Vector2 = Vector2.ZERO):
	if is_dead:
		return

	current_health -= amount
	update_health_bar()

	# Knockback
	var dir = (global_position - from).normalized()
	knockback_velocity = dir * hit_knockback_force

	# White flash
	if sprite_material:
		sprite_material.set("shader_parameter/flash_strength", 1.0)
		get_tree().create_timer(0.05).timeout.connect(func():
			sprite_material.set("shader_parameter/flash_strength", 0.0)
		)

	# Squash/stretch
	if squash_tween:
		squash_tween.kill()

	sprite_root.scale = Vector2.ONE

	squash_tween = create_tween()
	squash_tween.set_trans(Tween.TRANS_SINE)
	squash_tween.set_ease(Tween.EASE_OUT)
	squash_tween.tween_property(sprite_root, "scale", Vector2(1.1, 1.4), 0.08)
	squash_tween.tween_property(sprite_root, "scale", Vector2.ONE, 0.18)

	# Hit animation
	if anim.sprite_frames.has_animation("hit"):
		anim.play("hit")
		await anim.animation_finished

	if current_health <= 0:
		queue_free()
		return

	anim.play("walk")

# ======================================================
# ===================== HEALTH BAR =====================
# ======================================================

func update_health_bar():
	health_bar.max_value = max_health
	health_bar.value = current_health
