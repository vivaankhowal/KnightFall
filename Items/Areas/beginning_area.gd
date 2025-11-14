extends Node2D  # or Node, depending on your root node type

func _ready() -> void:
	get_tree().paused = false  # ✅ ensures everything unfreezes on load
