extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func setup_from_player(
	player_sprite: AnimatedSprite2D,
	trail_dir: Vector2,
	index: int
) -> void:
	# ------------------------------------------------
	# COPY PLAYER VISUAL STATE
	# ------------------------------------------------
	sprite.sprite_frames = player_sprite.sprite_frames
	sprite.animation = player_sprite.animation
	sprite.frame = player_sprite.frame
	sprite.flip_h = player_sprite.flip_h
	sprite.stop()  # freeze on current frame

	# ------------------------------------------------
	# FORCE WHITE SILHOUETTE (SAFE DUPLICATION)
	# ------------------------------------------------
	if player_sprite.material:
		sprite.material = player_sprite.material.duplicate()
		sprite.material.set_shader_parameter("silhouette", true)
		sprite.material.set_shader_parameter("damage_flash", false)

	# ------------------------------------------------
	# TRAIL DIRECTION (SAFE FALLBACK)
	# ------------------------------------------------
	var dir: Vector2 = trail_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	# ------------------------------------------------
	# SCALE-AWARE OFFSET  (CRITICAL FIX)
	# ------------------------------------------------
	# This keeps spacing identical across scenes
	var scale_factor: float = player_sprite.global_scale.length() * 0.5

	# Tight spacing = fast-looking dash
	var offset_distance := 3.0 + index * 2.5

	# Small grounding bias for better feel
	var vertical_bias: Vector2 = Vector2(0.0, 3.0) * scale_factor

	global_position = (
		player_sprite.global_position
		- dir * offset_distance * scale_factor
		+ vertical_bias
	)

	# ------------------------------------------------
	# TRANSFORM + DEPTH
	# ------------------------------------------------
	global_rotation = player_sprite.global_rotation
	global_scale = player_sprite.global_scale * (1.0 - float(index) * 0.025)
	z_index = player_sprite.z_index - 1

	# ------------------------------------------------
	# PROGRESSIVE TRANSPARENCY (NO SOLID STACKING)
	# ------------------------------------------------
	var base_alpha := 0.10
	var alpha: float = max(base_alpha - float(index) * 0.03, 0.04)
	sprite.modulate = Color(1.0, 1.0, 1.0, alpha)

	# ------------------------------------------------
	# FAST FADE = SPEED FEEL
	# ------------------------------------------------
	var lifetime: float = 0.13

	var tween: Tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(sprite, "modulate:a", 0.0, lifetime)
	tween.parallel().tween_property(
		self,
		"scale",
		global_scale * 0.9,
		lifetime
	)

	tween.tween_callback(queue_free)
