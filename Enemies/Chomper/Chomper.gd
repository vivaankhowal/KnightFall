extends CharacterBody2D

# ======================================================
# ===============  TUNABLE EXPORTED VARIABLES ==========
# ======================================================

@export var move_speed: float = 55.0
@export var damage: int = 10
@export var max_health: int = 30
@export var attack_cooldown: float = 1.0
@export var target_path: NodePath
@export var separation_radius: float = 40.0
@export var separation_force: float = 200.0

# Normal hit knockback
@export var hit_knockback_force: float = 200.0
@export var hit_knockback_friction: float = 600.0

# Death slide knockback
@export var death_slide_force: float = 1000.0
@export var death_slide_friction: float = 6000.0

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

# Death slide
var death_knockback_velocity: Vector2 = Vector2.ZERO
var sliding_on_death: bool = false

# Hit spark alternator
var hitspark_toggle: bool = false

# ======================================================
# ===================== NODE REFERENCES ===============
# ======================================================

@onready var anim: AnimatedSprite2D = $SpriteRoot/AnimatedSprite2D
@onready var hitspark: AnimatedSprite2D = $SpriteRoot/HitSpark
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
	anim.animation_finished.connect(_on_anim_finished)

	# hitspark initially hidden
	hitspark.visible = false

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
	if sliding_on_death:
		velocity = death_knockback_velocity
		death_knockback_velocity = death_knockback_velocity.move_toward(Vector2.ZERO, death_slide_friction * delta)
		move_and_slide()
		return

	if is_dead:
		return

	if spawning or not player:
		return

	# Hit knockback
	if knockback_velocity.length() > 1.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, hit_knockback_friction * delta)
		move_and_slide()
		return

	# follow player
	var dir = (player.global_position - global_position).normalized()

	if not player_in_range:
		var sep = get_separation_vector()
		velocity = (dir + sep * separation_force).normalized() * move_speed
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

	cooldown_timer.start(attack_cooldown)

func _on_cooldown_timeout():
	can_attack = true

# ======================================================
# ======================== HITSPARK =====================
# ======================================================

func _play_hitspark():
	hitspark.visible = true

	# alternate between hit1 and hit2
	if hitspark_toggle:
		hitspark.play("hit1")
	else:
		hitspark.play("hit2")

	hitspark_toggle = !hitspark_toggle

	hitspark.animation_finished.connect(func():
		hitspark.visible = false
	, CONNECT_ONE_SHOT)

# ======================================================
# ==================== DAMAGE & HIT ====================
# ======================================================

func take_damage(amount: int, from: Vector2 = Vector2.ZERO):
	if is_dead:
		return

	current_health -= amount
	update_health_bar()

	# HITSPARK
	_play_hitspark()

	# Normal slide knockback
	var dir = (global_position - from).normalized()
	knockback_velocity = dir * hit_knockback_force

	# White flash
	if sprite_material:
		sprite_material.set("shader_parameter/flash_strength", 1.0)
		get_tree().create_timer(0.05).timeout.connect(func():
			sprite_material.set("shader_parameter/flash_strength", 0.0)
		)

	# Stretch (ONLY enemy sprite, NOT hitspark)
	if squash_tween:
		squash_tween.kill()

	sprite_root.scale = Vector2.ONE

	squash_tween = create_tween()
	squash_tween.set_trans(Tween.TRANS_SINE)
	squash_tween.set_ease(Tween.EASE_OUT)
	squash_tween.tween_property(sprite_root, "scale", Vector2(1.1, 1.4), 0.08)
	squash_tween.tween_property(sprite_root, "scale", Vector2.ONE, 0.18)

	# hit animation
	if anim.sprite_frames.has_animation("hit"):
		anim.play("hit")
		await anim.animation_finished

	if current_health <= 0:
		die(from)
		return

	anim.play("walk")

# ======================================================
# ======================== DEATH =======================
# ======================================================

func die(from: Vector2):
	if is_dead:
		return
	is_dead = true

	$HealthBar.visible = false
	player_in_range = false
	attack_area.monitoring = false

	# Death animation instantly
	if anim.sprite_frames.has_animation("death"):
		anim.play("death")

	# Death hitspark (hit3)
	_play_death_hitspark()

	# Strong backward slide
	var slide_dir = (global_position - from).normalized()
	death_knockback_velocity = slide_dir * death_slide_force
	sliding_on_death = true


# ======================================================
# ===================== HEALTH BAR =====================
# ======================================================

func update_health_bar():
	health_bar.max_value = max_health
	health_bar.value = current_health

func _on_anim_finished():
	if is_dead:
		queue_free()

func _play_death_hitspark():
	hitspark.visible = true
	hitspark.play("hit3")

	hitspark.animation_finished.connect(func():
		hitspark.visible = false
	, CONNECT_ONE_SHOT)

func get_separation_vector() -> Vector2:
	var push = Vector2.ZERO

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self:
			continue
		
		var dist = global_position.distance_to(enemy.global_position)
		if dist < separation_radius and dist > 0:
			push += (global_position - enemy.global_position).normalized() * (separation_radius - dist)

	return push.normalized()
