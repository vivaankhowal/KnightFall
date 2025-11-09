extends CharacterBody2D

@export var move_speed: float = 40.0
@export var damage: int = 10
@export var max_health: int = 30
@export var attack_cooldown: float = 1.0
@export var target_path: NodePath

var current_health: int
var player: Node = null
var can_attack: bool = true

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var cooldown_timer: Timer = Timer.new()
@onready var health_bar: ProgressBar = $HealthBar/ProgressBar
@onready var attack_area: Area2D = $AttackArea

func _ready() -> void:
	# Find player
	if target_path != NodePath():
		player = get_node(target_path)
	else:
		player = get_tree().get_first_node_in_group("player")

	# Start walking animation
	if "walk" in anim.sprite_frames.get_animation_names():
		anim.play("walk")

	# Setup cooldown timer
	cooldown_timer.one_shot = true
	add_child(cooldown_timer)
	cooldown_timer.connect("timeout", Callable(self, "_on_cooldown_timeout"))

	# Connect attack signal
	attack_area.connect("body_entered", Callable(self, "_on_attack_area_body_entered"))

	# Health
	current_health = max_health
	update_health_bar()

func _physics_process(delta: float) -> void:
	if player == null:
		return

	# Follow the player (no physical push)
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()

	anim.flip_h = direction.x < 0
	$HealthBar.position = Vector2(0, -40)

# -------------------------------
# ATTACK SYSTEM
# -------------------------------
var player_in_range: bool = false  # NEW

# Called when player enters attack range
func _on_attack_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		if can_attack:
			attack_player()

# Called when player leaves attack range
func _on_attack_area_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false

func attack_player() -> void:
	if player and player.has_method("take_damage"):
		player.take_damage(damage, global_position)
		can_attack = false
		cooldown_timer.start(attack_cooldown)

func _on_cooldown_timeout() -> void:
	can_attack = true
	# Immediately re-attack if player is still nearby
	if player_in_range:
		attack_player()


# -------------------------------
# HEALTH SYSTEM
# -------------------------------
func take_damage(amount: int) -> void:
	current_health -= amount
	current_health = clamp(current_health, 0, max_health)
	update_health_bar()
	if current_health <= 0:
		die()

func update_health_bar() -> void:
	if health_bar:
		health_bar.value = current_health

func die() -> void:
	print("Enemy died")
	queue_free()
