extends CharacterBody2D

@export var speed: float = 320.0
@export var jump_velocity: float = -700.0
@export var gravity: float = 980.0

const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12
const MAX_FALL_SPEED := 1100.0

var _coyote: float = 0.0
var _buffer: float = 0.0

func _physics_process(delta: float) -> void:
	var input_dir: float = Input.get_axis("move_left", "move_right")

	_coyote -= delta
	_buffer -= delta
	if is_on_floor():
		_coyote = COYOTE_TIME
	if Input.is_action_just_pressed("jump"):
		_buffer = JUMP_BUFFER

	# Variable jump height: releasing while rising cuts the jump short.
	if Input.is_action_just_released("jump") and velocity.y < -250.0:
		velocity.y = -250.0

	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_buffer = 0.0
		_coyote = 0.0
	else:
		velocity.y = minf(velocity.y + gravity * delta, MAX_FALL_SPEED)

	# Accelerate horizontally for slightly weightier feel.
	velocity.x = move_toward(velocity.x, input_dir * speed, speed * 8.0 * delta)

	# Face the movement direction (preserve the visual scale from the scene).
	if input_dir != 0.0:
		var s: float = $Visual.scale.y
		$Visual.scale.x = s * signf(input_dir)

	move_and_slide()
