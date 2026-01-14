extends Node2D

func _process(_delta):
	var dir := get_global_mouse_position() - global_position
	if dir.length() > 0:
		rotation = dir.angle()
