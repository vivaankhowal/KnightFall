extends CharacterBody2D

@export var move_speed: float = 40.0
@export var damage: int = 10
@export var max_health: int = 30
@export var attack_cooldown: float = 1.0
@export var target_path: NodePath

var current_health: int
var player: Node = null
var can_attack: bool = true
var player_in_range: bool = false
var is_dead: bool = false
var has_spawned: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var cooldown_timer: Timer = Timer.new()
@onready var health_bar: ProgressBar = $HealthBar/ProgressBar
@onready var attack_area: Area2D = $AttackArea

func _ready() -> void:
	if target_path != NodePath():
		player = get_node_or_null(target_path)
	else:
		player = get_tree().get_first_node_in_group("player")

	if player == null:
		print("⚠️ Enemy: could not find player!")

	cooldown_timer.one_shot = true
	add_child(cooldown_timer)
	cooldown_timer.connect("timeout", Callable(self, "_on_cooldown_timeout"))
	attack_area.connect("body_entered", Callable(self, "_on_attack_area_body_entered"))
	attack_area.connect("body_exited", Callable(self, "_on_attack_area_body_exited"))

	current_health = max_health
	update_health_bar()
	health_bar.visible = false

	# --- Fixed spawn handling ---
	if "spawn" in anim.sprite_frames.get_animation_names():
		anim.play("spawn")
		var fallback = get_tree().create_timer(1.5)
		await anim.animation_finished or fallback.timeout
	has_spawned = true

	if "walk" in anim.sprite_frames.get_animation_names():
		anim.play("walk")

func _physics_process(delta: float) -> void:
	if is_dead or not player or not has_spawned:
		return

	if not player_in_range:
		var dir = (player.global_position - global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()
		anim.flip_h = dir.x < 0
		if anim.animation != "walk" and "walk" in anim.sprite_frames.get_animation_names():
			anim.play("walk")
	else:
		velocity = Vector2.ZERO
		move_and_slide()

	$HealthBar.position = Vector2(0, -40)

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
		# Deal damage halfway through the attack
		await get_tree().create_timer(0.3).timeout
		if player and player.has_method("take_damage"):
			player.take_damage(damage, global_position)
		await anim.animation_finished
	else:
		if player and player.has_method("take_damage"):
			player.take_damage(damage, global_position)

	cooldown_timer.start(attack_cooldown)

func _on_cooldown_timeout() -> void:
	can_attack = true
	if player_in_range:
		attack_player()

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
