extends AnimatedSprite2D

func _ready() -> void:
	play("dust")  # plays your dust animation
	connect("animation_finished", Callable(self, "_on_anim_finished"))

func _on_anim_finished() -> void:
	queue_free()  # remove dust after animation ends
