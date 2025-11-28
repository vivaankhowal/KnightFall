extends AnimatedSprite2D

# -------------------------------
# CONFIG
# -------------------------------
@export var fade_time: float = 0.3   # how fast it fades out after anim
@export var lifetime: float = 0.6    # total lifetime before freeing

# -------------------------------
# READY
# -------------------------------
func _ready() -> void:
	play("puff")  # make sure you have an animation called "puff"
	connect("animation_finished", Callable(self, "_on_animation_finished"))

# -------------------------------
# ANIMATION DONE → START FADE
# -------------------------------
func _on_animation_finished() -> void:
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(fade_time).timeout
	queue_free()

# -------------------------------
# SAFETY (auto cleanup)
# -------------------------------
func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
