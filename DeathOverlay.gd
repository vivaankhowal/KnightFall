extends CanvasLayer

@onready var rect: ColorRect = $Control/ColorRect

# Make sure this CanvasLayer is in group "death_overlay"
# and Process Mode = ALWAYS (so it works even when paused)

func _ready() -> void:
	# Ensure overlay starts invisible
	rect.modulate.a = 0.0
	visible = true

# Smooth fade to black, used on player death
func fade_to_black(duration: float = 2.0) -> void:
	print("🕳️ Fading to black...")
	rect.modulate.a = 0.0
	visible = true

	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 1.0, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	print("✅ Fade complete.")
