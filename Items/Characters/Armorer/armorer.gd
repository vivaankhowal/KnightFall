extends Node2D

@export var dialogue_lines: Array[String] = [
	"Welcome to my armor shop!",
	"I can strengthen your armor for the right price.",
	"Come back when you're ready for an upgrade."
]

var player_in_range: bool = false
var talking: bool = false
var dialogue_index: int = 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var outline_sprite: AnimatedSprite2D = $OutlineSprite
@onready var dialogue_box: Node2D = $DialogueBox
@onready var dialogue_label: Label = $DialogueBox/Panel/Label

func _ready():
	sprite.play("idle")
	dialogue_box.visible = false

func _process(_delta):
	outline_sprite.animation = sprite.animation
	outline_sprite.frame = sprite.frame
	if player_in_range and Input.is_action_just_pressed("interact"):
		if not talking:
			start_dialogue()
		else:
			next_line()

func start_dialogue():
	talking = true
	dialogue_index = 0
	dialogue_box.visible = true
	dialogue_label.text = dialogue_lines[dialogue_index]

func next_line():
	dialogue_index += 1
	if dialogue_index < dialogue_lines.size():
		dialogue_label.text = dialogue_lines[dialogue_index]
	else:
		end_dialogue()

func end_dialogue():
	dialogue_box.visible = false
	talking = false
	dialogue_index = 0

func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		outline_sprite.visible = true   # show outline

func _on_area_2d_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		outline_sprite.visible = false  # hide outline

func _set_outline(enabled: bool):
	var mat = sprite.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("outline_size", 2.0 if enabled else 0.0)
