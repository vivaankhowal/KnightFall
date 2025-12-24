extends Node2D

@export var swing_width := 10.0
@export var swing_speed := 12.0

var attacking := false
var t := 0.0

func _process(delta):
	if attacking:
		t += delta * swing_speed
		position.y = sin(t) * swing_width
	else:
		position.y = 0
