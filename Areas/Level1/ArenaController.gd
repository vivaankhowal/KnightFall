extends Node

@export var arena_size := 256.0
@export var expand_amount := 128.0
@export var expand_time := 0.6

@onready var walls := get_parent().get_node("Walls")

func _ready():
	update_walls()

func update_walls():
	walls.get_node("Wall_Top").position.y = -arena_size
	walls.get_node("Wall_Bottom").position.y = arena_size
	walls.get_node("Wall_Left").position.x = -arena_size
	walls.get_node("Wall_Right").position.x = arena_size

func expand():
	arena_size += expand_amount
	var tween = create_tween()
	tween.tween_callback(update_walls)
