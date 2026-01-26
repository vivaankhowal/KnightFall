extends Node2D

@export var enemy_scene: PackedScene
@export var enemies_per_wave := [2, 3, 4, 5, 6, 7, 8]

@onready var enemies_node := get_parent().get_node("Enemies")
@onready var arena := get_parent().get_node("ArenaTileMap")

@export var min_spawn_distance := 4  # tiles from player

var current_wave := 0
var alive := 0
var finished := false

func _ready():
	start_wave()

func start_wave():
	finished = false
	alive = enemies_per_wave[current_wave]

	for i in alive:
		spawn_enemy()

func spawn_enemy():
	var enemy = enemy_scene.instantiate()
	enemy.global_position = get_spawn_position()
	enemies_node.add_child(enemy)
	enemy.tree_exited.connect(on_enemy_died)

func on_enemy_died():
	alive -= 1
	if alive <= 0 and not finished:
		finished = true
		end_wave()

func end_wave():
	arena.expand()
	current_wave += 1

	if current_wave < enemies_per_wave.size():
		start_wave()
	else:
		print("ALL WAVES COMPLETE")
		# later: boss / exit / level complete

func get_spawn_position() -> Vector2:
	var inner_r = arena.reveal_radius - 2
	var player_pos = get_parent().get_node("Player").global_position

	for attempt in 15:
		var x = randi_range(-inner_r, inner_r)
		var y = randi_range(-inner_r, inner_r)
		var cell = Vector2i(x, y)

		# Must have floor tile
		if arena.get_cell_source_id(0, cell) == -1:
			continue

		var world_pos = arena.map_to_local(cell)

		# Enforce minimum distance from player
		if world_pos.distance_to(player_pos) < min_spawn_distance * arena.tile_set.tile_size.x:
			continue

		return world_pos

	# Safe fallback (opposite side of room)
	return arena.map_to_local(Vector2i(inner_r, inner_r))
