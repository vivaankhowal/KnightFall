extends CanvasLayer

@onready var overlays := [
	$TopLeft,
	$TopRight,
	$BottomLeft,
	$BottomRight
]

var tween: Tween

func flash(intensity: float = 0.6, duration: float = 0.3) -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	for overlay in overlays:
		overlay.visible = true
		overlay.modulate.a = 0.0
		# Fade in
		tween.parallel().tween_property(overlay, "modulate:a", intensity, duration * 0.25)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Fade out
	for overlay in overlays:
		tween.parallel().tween_property(overlay, "modulate:a", 0.0, duration * 0.75)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
