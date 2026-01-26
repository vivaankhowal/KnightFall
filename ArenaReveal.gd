extends TileMap

@export var reveal_radius := 12    # MUST be big enough to see something
@export var expand_amount := 4

@export var wall_h_source: int
@export var wall_h_atlas: Vector2i

@export var wall_left_source: int
@export var wall_left_atlas: Vector2i

@export var wall_right_source: int
@export var wall_right_atlas: Vector2i

@export var wall_tl_source: int
@export var wall_tl_atlas: Vector2i

@export var wall_tr_source: int
@export var wall_tr_atlas: Vector2i

@export var wall_bl_source: int
@export var wall_bl_atlas: Vector2i

@export var wall_br_source: int
@export var wall_br_atlas: Vector2i

var center: Vector2i
var original_tiles := {}

func _ready():
	center = local_to_map(Vector2.ZERO)

	# Cache all painted tiles
	for cell in get_used_cells(0):
		original_tiles[cell] = {
			"source": get_cell_source_id(0, cell),
			"atlas": get_cell_atlas_coords(0, cell)
		}

	update_reveal()

func update_reveal():
	for cell in original_tiles.keys():
		var dx = abs(cell.x - center.x)
		var dy = abs(cell.y - center.y)
		var dist = max(dx, dy)

		if dist <= reveal_radius:
			set_cell(
				0,
				cell,
				original_tiles[cell].source,
				original_tiles[cell].atlas
			)
		else:
			set_cell(0, cell, -1)

	rebuild_walls()

func expand():
	reveal_radius += expand_amount
	update_reveal()

func rebuild_walls():
	clear_layer(1)
	var r = reveal_radius

	# Top & Bottom (horizontal, excluding corners)
	for x in range(-r + 1, r):
		set_cell(1, Vector2i(x, -r), wall_h_source, wall_h_atlas)
		set_cell(1, Vector2i(x,  r), wall_h_source, wall_h_atlas)

	# Left wall
	for y in range(-r + 1, r):
		set_cell(1, Vector2i(-r, y), wall_left_source, wall_left_atlas)

	# Right wall
	for y in range(-r + 1, r):
		set_cell(1, Vector2i( r, y), wall_right_source, wall_right_atlas)

	# Corners
	set_cell(1, Vector2i(-r, -r), wall_tl_source, wall_tl_atlas)
	set_cell(1, Vector2i( r, -r), wall_tr_source, wall_tr_atlas)
	set_cell(1, Vector2i(-r,  r), wall_bl_source, wall_bl_atlas)
	set_cell(1, Vector2i( r,  r), wall_br_source, wall_br_atlas)
