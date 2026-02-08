extends Node2D

# ======================================================
# ==================== CONFIG ==========================
# ======================================================

@export var enemy_pool: Array[PackedScene]
@export var enemy_weights: Array[int] = []  # MUST match enemy_pool order
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

# ======================================================
# ==================== READY ===========================
# ======================================================

func _ready():
	randomize()
	_validate_weights()
	start_wave()

# ======================================================
# ==================== WAVES ===========================
# ======================================================

func start_wave():
	finished = false

	var total_to_spawn: int = enemies_per_wave[current_wave]
	alive = total_to_spawn

	for i in total_to_spawn:
		var scene := _pick_weighted_enemy()
		if scene:
			_spawn_enemy(scene)

func _spawn_enemy(enemy_scene: PackedScene):
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

# ======================================================
# =================== WEIGHTED PICK ====================
# ======================================================

func _pick_weighted_enemy() -> PackedScene:
	var total := 0
	for w in enemy_weights:
		if w > 0:
			total += w

	if total <= 0:
		return null

	var roll := randi_range(1, total)
	var acc := 0

	for i in enemy_pool.size():
		if enemy_weights[i] <= 0:
			continue

		acc += enemy_weights[i]
		if roll <= acc:
			return enemy_pool[i]

	return null

# ======================================================
# ================= VALIDATION + DEBUG =================
# ======================================================

func _validate_weights() -> void:
	if enemy_pool.is_empty():
		push_warning("enemy_pool is empty")
		return

	if enemy_weights.size() != enemy_pool.size():
		push_warning("enemy_weights size != enemy_pool size. Resizing and defaulting to 1.")
		enemy_weights.resize(enemy_pool.size())

	# IMPORTANT:
	# 0 = disabled
	# 1+ = enabled
	for i in enemy_weights.size():
		if enemy_weights[i] < 0:
			enemy_weights[i] = 0

	_print_weight_debug()

func _print_weight_debug() -> void:
	var total := 0
	for w in enemy_weights:
		if w > 0:
			total += w

	print("--- Enemy Pool + Weights ---")
	for i in enemy_pool.size():
		var scene := enemy_pool[i]
		var name := scene.resource_path.get_file()
		var w := enemy_weights[i]

		if w > 0 and total > 0:
			var pct := (float(w) / float(total)) * 100.0
			print(i, ": ", name, "  weight=", w, " (~", snapped(pct, 0.1), "%)")
		else:
			print(i, ": ", name, "  DISABLED")
	print("----------------------------")

# ======================================================
# =================== SPAWN POSITION ===================
# ======================================================

func get_spawn_position() -> Vector2:
	var inner_r = arena.reveal_radius - 2
	var player_pos = player.global_position

	for _attempt in 15:
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

	return arena.map_to_local(Vector2i(inner_r, inner_r))
