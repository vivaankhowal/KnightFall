extends CharacterBody2D

# -------------------------------
# CONFIG
# -------------------------------
@export var move_speed: float = 40.0
@export var damage: int = 10
@export var max_health: int = 30
@export var attack_cooldown: float = 1.0
@export var target_path: NodePath

# -------------------------------
# STATE
# -------------------------------
var current_health: int
var player: Node = null
var can_attack: bool = true
var player_in_range: bool = false
var is_dead: bool = false
var has_spawned: bool = false

# -------------------------------
# NODES
# -------------------------------
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var cooldown_timer: Timer = Timer.new()
@onready var health_bar: ProgressBar = $HealthBar/ProgressBar
@onready var attack_area: Area2D = $AttackArea

# -------------------------------
# READY
# -------------------------------
func _ready() -> void:
	# Find player
	if target_path != NodePath():
		player = get_node(target_path)
	else:
		player = get_tree().get_first_node_in_group("player")

	# Setup cooldown timer
	cooldown_timer.one_shot = true
	add_child(cooldown_timer)
	cooldown_timer.connect("timeout", Callable(self, "_on_cooldown_timeout"))

	# Connect attack signals
	attack_area.connect("body_entered", Callable(self, "_on_attack_area_body_entered"))
	attack_area.connect("body_exited", Callable(self, "_on_attack_area_body_exited"))

	# Initialize health
	current_health = max_health
	update_health_bar()
	health_bar.visible = false

	# Play spawn animation if available
	if "spawn" in anim.sprite_frames.get_animation_names():
		anim.play("spawn")
		await anim.animation_finished
	has_spawned = true
	if "walk" in anim.sprite_frames.get_animation_names():
		anim.play("walk")

# -------------------------------
# PHYSICS
# -------------------------------
func _physics_process(delta: float) -> void:
	if not has_spawned or is_dead or not player:
		return

	# Move toward player only if not attacking
	if not player_in_range:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()
		anim.flip_h = direction.x < 0
		if anim.animation != "walk" and "walk" in anim.sprite_frames.get_animation_names():
			anim.play("walk")
	else:
		velocity = Vector2.ZERO
		move_and_slide()

	# Keep health bar positioned above enemy
	$HealthBar.position = Vector2(0, -40)

# -------------------------------
# ATTACK SYSTEM ⚔️
# -------------------------------
func _on_attack_area_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not is_dead:
		player_in_range = true
		if can_attack:
			attack_player()

func _on_attack_area_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false

func attack_player() -> void:
	if not player or not can_attack or is_dead:
		return

	can_attack = false

	if "attack" in anim.sprite_frames.get_animation_names():
		anim.play("attack")
		await anim.animation_finished

	if player and player.has_method("take_damage"):
		player.take_damage(damage, global_position)

	cooldown_timer.start(attack_cooldown)

func _on_cooldown_timeout() -> void:
	can_attack = true
	if player_in_range:
		attack_player()

# -------------------------------
# HEALTH SYSTEM ❤️
# -------------------------------
func take_damage(amount: int) -> void:
	if is_dead:
		return

	current_health -= amount
	current_health = clamp(current_health, 0, max_health)
	update_health_bar()
	health_bar.visible = true

	if "hit" in anim.sprite_frames.get_animation_names():
		anim.play("hit")

	if current_health <= 0:
		die()
	elif anim.animation != "walk" and "walk" in anim.sprite_frames.get_animation_names():
		anim.play("walk")

func update_health_bar() -> void:
	if health_bar:
		health_bar.value = current_health
		health_bar.visible = current_health < max_health

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	if "death" in anim.sprite_frames.get_animation_names():
		anim.play("death")
		await anim.animation_finished
	queue_free()
