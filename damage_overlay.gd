extends CanvasLayer

@onready var overlay: TextureRect = $TextureRect

func flash() -> void:
	overlay.modulate.a = 0.8
	var tw = create_tween()
	tw.tween_property(overlay, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
