extends Node2D

@export var attack_cooldown: float = 0.3
@export var slash_scene: PackedScene
var can_attack: bool = true

func attack(direction: Vector2):
	if not can_attack:
		return
	can_attack = false

	# Spawn slash projectile
	var slash = slash_scene.instantiate()
	slash.global_position = global_position
	slash.direction = direction.normalized()
	get_tree().current_scene.add_child(slash)

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true
