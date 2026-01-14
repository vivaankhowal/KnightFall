extends Node2D

var attack_dir := Vector2.RIGHT

func update_attack_direction(dir: Vector2):
	if dir.length() > 0:
		attack_dir = dir.normalized()
