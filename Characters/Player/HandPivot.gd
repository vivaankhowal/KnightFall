extends Node2D

@export var reach := 16.0
var attack_dir := Vector2.RIGHT

func update_attack_direction(dir: Vector2):
	if dir.length() > 0:
		attack_dir = dir.normalized()
		rotation = attack_dir.angle()
