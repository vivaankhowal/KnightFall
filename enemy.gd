extends CharacterBody2D

@export var move_speed: float = 40.0
@export var damage: int = 10
@export var max_health: int = 30
@export var attack_range: float = 20.0
@export var attack_cooldown: float = 1.0
@export var target_path: NodePath

var current_health: int
var player: Node = null
var can_attack: bool = true

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var cooldown_timer: Timer = Timer.new()
@onready var health_bar: ProgressBar = $HealthBar/ProgressBar

func _ready() -> void:
	# Find player
	if target_path != NodePath():
		player = get_node(target_path)
	else:
		player = get_tree().get_first_node_in_group("player")

	# Animation
	if "walk" in anim.sprite_frames.get_animation_names():
		anim.play("walk")
	else:
		anim.play()

	# Cooldown
	cooldown_timer.one_shot = true
	add_child(cooldown_timer)
	cooldown_timer.connect("timeout", Callable(self, "_on_cooldown_timeout"))

	# Health
	current_health = max_health
	update_health_bar()

func _physics_process(delta: float) -> void:
	if player == null:
		return

	# Movement
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()

	anim.flip_h = direction.x < 0
	$HealthBar.position = Vector2(0, -40)

	# Attack
	if can_attack and global_position.distance_to(player.global_position) < attack_range:
		attack_player()

func attack_player() -> void:
	if player and player.has_method("take_damage"):
		player.take_damage(damage)
		can_attack = false
		cooldown_timer.start(attack_cooldown)

func _on_cooldown_timeout() -> void:
	can_attack = true

# -------------------------------
# HEALTH SYSTEM ❤️
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
