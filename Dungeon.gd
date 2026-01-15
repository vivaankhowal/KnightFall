extends Node2D

const ROOM_EMPTY := 0
const ROOM_NORMAL := 1
const ROOM_START := 2
const ROOM_BOSS := 3

const AREA_START := 0
const AREA_EARLY := 1
const AREA_MID := 2
const AREA_LATE := 3

@export var room_scene: PackedScene
@export var grid_size := Vector2i(6, 6)
@export var room_count := 10
@export var room_spacing := Vector2(520, 320)
@export var corridor_scene: PackedScene

var grid: Array = []  # 2D array: grid[y][x]
var area_grid: Array = []  # same size as grid
var room_nodes := {}

func _ready() -> void:
	generate()

func generate() -> void:
	randomize()
	# Clear old rooms (if you re-run generate later)
	for c in get_children():
		c.queue_free()

	init_grid()
	place_rooms(room_count)
	assign_start_and_boss()
	assign_areas()
	spawn_rooms()
	spawn_corridors()


func init_grid() -> void:
	grid.clear()
	area_grid.clear()

	for y in range(grid_size.y):
		var row := []
		var area_row := []

		for x in range(grid_size.x):
			row.append(ROOM_EMPTY)
			area_row.append(AREA_START)

		grid.append(row)
		area_grid.append(area_row)


func place_rooms(count: int) -> void:
	var x := 0
	var y := 0

	grid[y][x] = ROOM_NORMAL
	var placed := 1

	while placed < count:
		var dir := randi_range(0, 3)

		match dir:
			0: x += 1  # right
			1: x -= 1  # left
			2: y += 1  # down
			3: y -= 1  # up

		# Clamp inside grid
		x = clamp(x, 0, grid_size.x - 1)
		y = clamp(y, 0, grid_size.y - 1)

		if grid[y][x] == ROOM_EMPTY:
			grid[y][x] = ROOM_NORMAL
			placed += 1


func assign_start_and_boss() -> void:
	# Force start at (0,0)
	grid[0][0] = ROOM_START

	# Boss = last normal room found scanning from bottom-right
	for y in range(grid_size.y - 1, -1, -1):
		for x in range(grid_size.x - 1, -1, -1):
			if grid[y][x] == ROOM_NORMAL:
				grid[y][x] = ROOM_BOSS
				return

func spawn_rooms() -> void:
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var t: int = grid[y][x]
			if t == ROOM_EMPTY:
				continue

			var room := room_scene.instantiate()
			room.position = Vector2(x, y) * room_spacing
			room.room_type = t
			room.area_type = area_grid[y][x]
			add_child(room)

			room_nodes[Vector2i(x, y)] = room


func assign_areas() -> void:
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if grid[y][x] == ROOM_EMPTY:
				continue

			var distance: int = abs(x) + abs(y)

			if distance <= 2:
				area_grid[y][x] = AREA_EARLY
			elif distance <= 4:
				area_grid[y][x] = AREA_MID
			else:
				area_grid[y][x] = AREA_LATE

func has_room(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= grid_size.x or y >= grid_size.y:
		return false
	return grid[y][x] != ROOM_EMPTY

func spawn_corridors() -> void:
	for pos in room_nodes.keys():
		var room = room_nodes[pos]
		var world_pos = room.position

		# Right
		if has_room(pos.x + 1, pos.y):
			var neighbor = room_nodes[Vector2i(pos.x + 1, pos.y)]
			create_corridor(
				room,
				neighbor,
				Vector2.RIGHT
			)

		# Down
		if has_room(pos.x, pos.y + 1):
			var neighbor = room_nodes[Vector2i(pos.x, pos.y + 1)]
			create_corridor(
				room,
				neighbor,
				Vector2.DOWN
			)

func create_corridor(from_room, to_room, direction: Vector2) -> void:
	var corridor = corridor_scene.instantiate()

	var start = from_room.position + from_room.get_door_position(direction)
	var end = to_room.position + to_room.get_door_position(-direction)

	corridor.position = start

	if direction == Vector2.RIGHT:
		corridor.scale.x = (end.x - start.x) / 48.0
	elif direction == Vector2.DOWN:
		corridor.rotation = PI / 2
		corridor.scale.x = (end.y - start.y) / 48.0

	add_child(corridor)
