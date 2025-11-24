extends CharacterBody2D

# ==========================
# ---  ENEMY STATS
# ==========================
@export var move_speed: float = 50.0
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
var spawning: bool = true     # prevents movement & attacks until spawn animation ends
var knockback_time := 0.0
const KNOCKBACK_DURATION := 0.18
var knockback_vector: Vector2 = Vector2.ZERO
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_friction: float = 600.0   # tuning value
var squash_tween: Tween
var sprite_material: ShaderMaterial

# ==========================
# ---  NODE REFERENCES
# ==========================
@onready var anim: AnimatedSprite2D = $SpriteRoot/AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var cooldown_timer: Timer = Timer.new()
@onready var health_bar: TextureProgressBar = $HealthBar/TextureBar
@onready var sprite_root = $SpriteRoot

# ======================================================
# READY
# ======================================================
func _ready():
	# Make the material UNIQUE per enemy
	anim.material = anim.material.duplicate()
	sprite_material = anim.material
	anim.animation_finished.connect(_on_anim_finished)
	# --- Locate player ---
	if target_path != NodePath():
		player = get_node_or_null(target_path)
	else:
		player = get_tree().get_first_node_in_group("player")

	if not player:
		print("⚠️ No player found!")

	# --- Timer ---
	cooldown_timer.one_shot = true
	add_child(cooldown_timer)
	cooldown_timer.timeout.connect(_on_cooldown_timeout)

	# --- Attack area signals ---
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	attack_area.body_exited.connect(_on_attack_area_body_exited)

	# --- Set health ---
	current_health = max_health
	update_health_bar()

	# --- PLAY SPAWN ANIMATION IF AVAILABLE ---
	if "spawn" in anim.sprite_frames.get_animation_names():
		play_scaled_animation("spawn", 0.23)
		await anim.animation_finished
	# after spawn animation finishes:
	spawning = false

	# --- Idle/Walk default ---
	if "walk" in anim.sprite_frames.get_animation_names():
		anim.play("walk")

	print("✅ Enemy ready")


# ======================================================
# MOVEMENT + AI
# ======================================================
func _physics_process(delta: float) -> void:
	# REALISTIC KNOCKBACK SLIDE
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

	# automatically try to attack
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


func attack_player() -> void:
	if is_dead or spawning or not can_attack:
		return

	can_attack = false

	# play attack animation
	if "attack" in anim.sprite_frames.get_animation_names():
		anim.play("attack")


	# deal damage
	if player and player.has_method("take_damage"):
		player.take_damage(damage, global_position)
		await anim.animation_finished
		anim.play("walk")

	# start cooldown
	cooldown_timer.start(attack_cooldown)


func _on_cooldown_timeout() -> void:
	can_attack = true

	if player_in_range and not is_dead:
		attack_player()


# ======================================================
# DAMAGE & DEATH
# ======================================================
func take_damage(amount: int, from: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	current_health -= amount
	update_health_bar()

	# -------------------------------------
	# WHITE SILHOUETTE FLASH
	# -------------------------------------
# WHITE FLASH
	if sprite_material:
		sprite_material.set("shader_parameter/flash_strength", 1.0)
		get_tree().create_timer(0.2).timeout.connect(func():
			sprite_material.set("shader_parameter/flash_strength", 0.0)
		)

# REALISTIC KNOCKBACK
	var dir = (global_position - player.global_position).normalized()
	knockback_velocity = dir * 150  # strong jerk

# --- SMOOTH VERTICAL SQUASH ---
	if squash_tween:
		squash_tween.kill()

	squash_tween = create_tween()

	squash_tween.tween_property(sprite_root, "scale",
		Vector2(1.0, 0.70),   # vertical squash
		0.08
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	squash_tween.tween_property(sprite_root, "scale",
		Vector2.ONE,
		0.12
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# -------------------------------------
	# HIT ANIMATION
	# -------------------------------------
	if "hit" in anim.sprite_frames.get_animation_names():
		anim.play("hit")

	if current_health <= 0:
		die()
		return

	if "walk" in anim.sprite_frames.get_animation_names():
		anim.play("walk")



func die() -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO
	$HealthBar.visible = false

	# death animation
	if "death" in anim.sprite_frames.get_animation_names():
		play_scaled_animation("death", 0.15)
		await anim.animation_finished

	queue_free()

# ======================================================
# HEALTH BAR
# ======================================================
func update_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

func play_scaled_animation(anim_name: String, scale: float):
	anim.scale = Vector2(scale, scale)
	anim.play(anim_name)

func _on_anim_finished():
	anim.scale = Vector2.ONE   # reset to normal
