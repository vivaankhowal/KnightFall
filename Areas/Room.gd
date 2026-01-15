extends Node2D

# =====================
# CONSTANTS
# =====================

# Room types
const ROOM_NORMAL := 1
const ROOM_START := 2
const ROOM_BOSS := 3

# Area types
const AREA_EARLY := 1
const AREA_MID := 2
const AREA_LATE := 3


# =====================
# EXPORTED DATA
# =====================

@export var room_type: int = ROOM_NORMAL
@export var area_type: int = AREA_EARLY


# =====================
# NODES
# =====================

@onready var label: Label = $Label
@onready var tilemap: TileMap = $TileMap


# =====================
# READY
# =====================

func _ready() -> void:
	update_label()


# =====================
# VISUAL DEBUG
# =====================

func update_label() -> void:
	match room_type:
		ROOM_START:
			label.text = "START"
		ROOM_BOSS:
			label.text = "BOSS"
		_:
			label.text = "ROOM"

func get_door_position(direction: Vector2) -> Vector2:
	var room_size := Vector2(144, 144)  # match your room_spacing

	if direction == Vector2.RIGHT:
		return Vector2(room_size.x, room_size.y / 2)
	if direction == Vector2.LEFT:
		return Vector2(0, room_size.y / 2)
	if direction == Vector2.DOWN:
		return Vector2(room_size.x / 2, room_size.y)
	if direction == Vector2.UP:
		return Vector2(room_size.x / 2, 0)

	return Vector2.ZERO
