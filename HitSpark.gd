extends Node2D

func _ready():
	$Timer.timeout.connect(_on_timeout)

func _on_timeout():
	queue_free()
