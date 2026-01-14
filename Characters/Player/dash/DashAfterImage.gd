extends Node2D

@export var fade_time := 0.18
var timer := 0.0

@onready var sprite := $Sprite2D

func _ready():
	timer = fade_time

func _process(delta):
	timer -= delta
	sprite.modulate.a = timer / fade_time

	if timer <= 0:
		queue_free()
