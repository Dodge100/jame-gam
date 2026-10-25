extends CharacterBody2D

@export var speed: float = 320.0
@export var jump_velocity: float = -700.0
@export var gravity: float = 980.0
## Constant rightward scroll of the view, in pixels per second.
@export var scroll_speed: float = 220.0
## World-space Y that the TOP edge of the view is pinned to. The camera only
## pans sideways, so this is what frames the level vertically. Kept at 0 to
## match the level's original framing (which came from the old limit_top = 0).
@export var view_top_y: float = 0.0

const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12
const MAX_FALL_SPEED := 1100.0
## How much faster than the scroll the player may run to catch up.
const CATCH_UP_MARGIN := 180.0
## Fraction of half a screen the view starts ahead of the player.
const START_LEAD := 0.5

var _coyote: float = 0.0
var _buffer: float = 0.0
var _cam: Camera2D
var _cam_x: float = 0.0
var _cam_left: float = 0.0

func _ready() -> void:
	_cam = $Camera2D
	# Auto-scrolling: the view never follows the body, so take it over.
	# Detach it from the player's transform so its y is world-space instead of
	# being dragged around by where the body happens to be.
	_cam.top_level = true
	_cam.position_smoothing_enabled = false
	_cam.set_physics_process(false)
	# Start with the player already inside the left third of the view so the
	# scroll is obvious from frame one instead of running out of room.
	_cam_x = global_position.x + _cam.get_viewport_rect().size.x * 0.5 * START_LEAD
	_cam.global_position = Vector2(_cam_x, _view_center_y())
	_cam_left = _cam_x - _cam.get_viewport_rect().size.x * 0.5

## Camera Y that puts the top edge of the view at view_top_y.
func _view_center_y() -> float:
	return view_top_y + _cam.get_viewport_rect().size.y * 0.5

## Horizontal span of the current view in world space.
func view_left() -> float:
	return _cam_left

func view_right() -> float:
	return _cam_left + _cam.get_viewport_rect().size.x

## True once the player has been left off the right edge of the screen.
func is_out_of_view() -> bool:
	return global_position.x - 8.0 > view_right()

## True once the trailing edge of the view has swallowed the player.
func is_behind_view() -> bool:
	return global_position.x + 8.0 < view_left()

func _advance_camera(delta: float) -> void:
	_cam_x += scroll_speed * delta
	_cam.global_position = Vector2(_cam_x, _view_center_y())
	_cam_left = _cam_x - _cam.get_viewport_rect().size.x * 0.5

func _physics_process(delta: float) -> void:
	_advance_camera(delta)
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

	# Accelerate horizontally for slightly weightier feel. Running right gets
	# a margin over the scroll so the player can win back ground.
	var run_target: float = speed
	if input_dir > 0.0:
		run_target = scroll_speed + CATCH_UP_MARGIN
	velocity.x = move_toward(velocity.x, input_dir * run_target, speed * 8.0 * delta)

	# Face the movement direction (preserve the visual scale from the scene).
	if input_dir != 0.0:
		var s: float = $Visual.scale.y
		$Visual.scale.x = s * signf(input_dir)

	move_and_slide()
