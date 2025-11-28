extends CanvasLayer

@onready var overlay: TextureRect = $Overlay
var tween: Tween

func _ready() -> void:
	# Make sure it starts fully transparent
	overlay.modulate.a = 0.0

func flash(intensity: float = 0.45, duration: float = 0.3) -> void:
	if tween:
		tween.kill()

	overlay.visible = true
	overlay.modulate.a = 0.0

	tween = create_tween()
	tween.tween_property(overlay, "modulate:a", intensity, duration * 0.25)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(overlay, "modulate:a", 0.0, duration * 0.75)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
