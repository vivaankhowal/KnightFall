extends Control

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var is_open = false
var is_flipping = false

func _ready():
	visible = false  # start hidden

func _input(event):
	if Input.is_action_just_pressed("toggle_book") and not is_open:
		open_book()

	elif Input.is_action_just_pressed("close_book") and is_open:
		close_book()

	elif Input.is_action_just_pressed("flip_page") and is_open:
		flip_page()


func open_book():
	visible = true
	is_open = true

func close_book():
	visible = false
	is_open = false

func flip_page():
	if is_flipping:
		return  # prevents spamming while flipping

	is_flipping = true

	anim.frame = 0
	anim.play("flip")

	# Wait until the animation reaches the last frame
	while anim.frame < anim.sprite_frames.get_frame_count("flip") - 1:
		await get_tree().process_frame

	is_flipping = false
