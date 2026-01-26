extends CharacterBody2D

@export var max_health := 30
@export var projectile_scene: PackedScene
@export var shoot_interval := 1.2
@export var projectile_speed := 500.0
@export var shoot_range := 800.0

var current_health := max_health
var player: Node2D

@onready var shoot_timer: Timer = $ShootTimer

func _ready():
	player = get_tree().get_first_node_in_group("player")
	shoot_timer.wait_time = shoot_interval
	shoot_timer.start()
	shoot_timer.timeout.connect(shoot)

func shoot():
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

func take_damage(amount: int, from: Vector2):
	current_health -= amount
	if current_health <= 0:
		queue_free()
