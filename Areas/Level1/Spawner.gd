extends Node2D

# ======================================================
# ==================== CONFIG ==========================
# ======================================================

@export var enemy_pool: Array[PackedScene]

# Must match enemy_pool order
# Higher number = more common
@export var enemy_weights: Array[int] = []

@export var enemies_per_wave := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
@export var min_spawn_distance := 4  # tiles from player

@onready var enemies_node := get_parent().get_node("Enemies")
@onready var arena := get_parent().get_node("ArenaTileMap")
@onready var player := get_parent().get_node("Player")

# ======================================================
# ==================== STATE ===========================
# ======================================================

var current_wave := 0
var alive := 0
var finished := false

var spawn_queue: Array[PackedScene] = []

# ======================================================
# ==================== READY ===========================
# ======================================================

func _ready():
	assert(enemy_pool.size() == enemy_weights.size(),
		"enemy_pool and enemy_weights must be the same size")

	start_wave()

# ======================================================
# ==================== WAVES ===========================
# ======================================================

func start_wave():
	finished = false
	spawn_queue.clear()

	var total_to_spawn = enemies_per_wave[current_wave]

	# --------------------------------------------------
	# Phase 1: GUARANTEE each enemy spawns once
	# --------------------------------------------------
	var guaranteed = enemy_pool.duplicate()
	guaranteed.shuffle()

	for scene in guaranteed:
		if spawn_queue.size() < total_to_spawn:
			spawn_queue.append(scene)

	# --------------------------------------------------
	# Phase 2: WEIGHTED RANDOM spawns
	# --------------------------------------------------
	while spawn_queue.size() < total_to_spawn:
		spawn_queue.append(pick_weighted_enemy())

	spawn_queue.shuffle()
	alive = spawn_queue.size()

	for scene in spawn_queue:
		spawn_enemy(scene)

# ======================================================
# ==================== SPAWNING ========================
# ======================================================

func spawn_enemy(enemy_scene: PackedScene):
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

# ======================================================
# ==================== RANDOM ==========================
# ======================================================

func pick_weighted_enemy() -> PackedScene:
	var total := 0
	for w in enemy_weights:
		total += w

	var roll = randi_range(1, total)
	var acc := 0

	for i in enemy_pool.size():
		acc += enemy_weights[i]
		if roll <= acc:
			return enemy_pool[i]

	# Safety fallback
	return enemy_pool.pick_random()

# ======================================================
# ==================== SPAWN POS =======================
# ======================================================

func get_spawn_position() -> Vector2:
	var inner_r = arena.reveal_radius - 2
	var player_pos = player.global_position

	for _i in 15:
		var x = randi_range(-inner_r, inner_r)
		var y = randi_range(-inner_r, inner_r)
		var cell = Vector2i(x, y)

		# Must be valid floor tile
		if arena.get_cell_source_id(0, cell) == -1:
			continue

		var world_pos = arena.map_to_local(cell)

		# Enforce minimum distance from player
		if world_pos.distance_to(player_pos) < min_spawn_distance * arena.tile_set.tile_size.x:
			continue

		return world_pos

	# Fallback (corner of arena)
	return arena.map_to_local(Vector2i(inner_r, inner_r))
