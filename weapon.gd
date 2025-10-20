extends Node2D

@export var spin_speed: float = 1800.0   # degrees per second
@export var cooldown_time: float = 1.0   # seconds between spins

var facing_right: bool = true
var spinning: bool = false
var on_cooldown: bool = false
var spin_angle: float = 0.0
var attack_held: bool = false
var cooldown_timer: float = 0.0


func _input(event):
	if event.is_action_pressed("attack"):
		attack_held = true
	elif event.is_action_released("attack"):
		attack_held = false


func _process(delta: float) -> void:
	# Handle active spin
	if spinning:
		var dir: int = -1 if facing_right else 1
		var step: float = spin_speed * delta
		spin_angle += step
		rotation = deg_to_rad(spin_angle * dir)

		# finish full circle
		if spin_angle >= 360.0:
			finish_spin()

	# Handle cooldown timer
	elif on_cooldown:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			on_cooldown = false
			# start next spin automatically if still holding
			if attack_held:
				start_spin()

	# Idle: start spin if held and ready
	elif attack_held and not on_cooldown and not spinning:
		start_spin()


func start_spin() -> void:
	# absolute lock
	if spinning or on_cooldown:
		return

	spinning = true
	spin_angle = 0.0


func finish_spin() -> void:
	spinning = false
	spin_angle = 0.0
	rotation = 0.0
	start_cooldown()


func start_cooldown() -> void:
	on_cooldown = true
	cooldown_timer = cooldown_time
