extends CharacterBody2D

# ============================================================
# CONFIG
# ============================================================
@export var max_health := 30

@export var move_speed := 80.0
@export var preferred_distance := 300.0
@export var strafe_change_time := 1.5

@export var projectile_scene: PackedScene
@export var shoot_interval := 1.2
@export var projectile_speed := 500.0
@export var shoot_range := 800.0

# ============================================================
# STATE
# ============================================================
var current_health := max_health
var player: Node2D
var strafe_dir := 1

# ============================================================
# NODES
# ============================================================
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shoot_timer: Timer = $ShootTimer

# IMPORTANT:
# This must be the SAME Area2D node type/name you use
# for other enemies (the one player slashes already hit)
@onready var attack_area: Area2D = $AttackArea

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

	if sprite:
		sprite.play("idle")

	# Shooting timer
	shoot_timer.wait_time = shoot_interval
	shoot_timer.timeout.connect(shoot)
	shoot_timer.start()

	# Strafe direction timer
	var t := Timer.new()
	t.wait_time = strafe_change_time
	t.autostart = true
	t.timeout.connect(func():
		strafe_dir *= -1
	)
	add_child(t)

# ============================================================
# MOVEMENT (non-chaser)
# ============================================================
func _physics_process(delta: float) -> void:
	if not player:
		return

	var to_player := player.global_position - global_position
	var dist := to_player.length()

	var move := Vector2.ZERO

	# Back up if too close
	if dist < preferred_distance:
		move -= to_player.normalized()

	# Strafe sideways
	var strafe := Vector2(-to_player.y, to_player.x).normalized()
	move += strafe * strafe_dir

	velocity = move.normalized() * move_speed
	move_and_slide()

# ============================================================
# SHOOTING
# ============================================================
func shoot() -> void:
	if not player or not projectile_scene:
		return

	var dist := global_position.distance_to(player.global_position)
	if dist > shoot_range:
		return

	var proj := projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)

	var dir := (player.global_position - global_position).normalized()
	proj.global_position = global_position + dir * 16
	proj.velocity = dir * projectile_speed

# ============================================================
# DAMAGE (THIS IS THE IMPORTANT PART)
# ============================================================
# This MUST match the signal connection:
# AttackArea.area_entered -> _on_attack_area_entered
# ============================================================
# TAKE DAMAGE
# ============================================================
func take_damage(amount: int, from: Vector2) -> void:
	current_health -= amount

	if current_health <= 0:
		queue_free()

func _on_attack_area_area_entered(area: Area2D) -> void:
	if area.has_method("get_damage"):
		take_damage(area.get_damage(), area.global_position)
	elif "damage" in area:
		take_damage(area.damage, area.global_position)
