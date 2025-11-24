extends Camera2D

# ============================
# CONFIG
# ============================
@export var shake_intensity: float = 8.0
@export var shake_duration: float = 0.2

@export var mouse_look_strength: float = 0.5     # how strongly mouse pulls the camera
@export var max_x_offset: float = 50.0
@export var max_y_offset: float = 50.0

@export var follow_smoothness: float = 8.0        # smoothing speed

# ============================
# SHAKE STATE
# ============================
var shake_timer: float = 0.0
var current_shake_intensity: float = 0.0

# ============================
# API: CALL THIS TO SHAKE
# ============================
func shake(intensity: float = shake_intensity, duration: float = shake_duration) -> void:
	shake_timer = duration
	current_shake_intensity = intensity

# ============================
# MAIN PROCESS
# ============================
func _process(delta: float) -> void:
	var player := get_parent()    # camera is a child of Player
	
	if player == null:
		return   # safety

	# --- 1. Base player follow ---
	var target_pos = player.global_position

	# --- 2. Mouse-based offset (Gungeon style) ---
	var mouse_offset = (get_global_mouse_position() - player.global_position) * mouse_look_strength
	
	mouse_offset.x = clamp(mouse_offset.x, -max_x_offset, max_x_offset)
	mouse_offset.y = clamp(mouse_offset.y, -max_y_offset,  max_y_offset)
	
	target_pos += mouse_offset

	# --- 3. Smooth follow ---
	global_position = global_position.lerp(target_pos, delta * follow_smoothness)

	# --- 4. Camera Shake (additive) ---
	if shake_timer > 0:
		shake_timer -= delta
		var shake_strength := current_shake_intensity * (shake_timer / shake_duration)
		offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
	else:
		offset = Vector2.ZERO
