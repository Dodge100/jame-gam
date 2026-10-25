extends CharacterBody2D

## run speed, px/s
@export var speed: float = 320.0
## upward jump velocity, px/s
@export var jump_velocity: float = -700.0
## downward gravity, px/s2
@export var gravity: float = 980.0
## constant rightward scroll of the view, px/s
@export var scroll_speed: float = 220.0
## storm push strength, px/s of drift; scaled by the live storm, 0 turns it off
@export var wind_push: float = 120.0

## world y the top edge of the view is pinned to, camera only pans sideways
@export var view_top_y: float = 0.0

const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12
const MAX_FALL_SPEED := 1100.0
# how much faster than the scroll the player may run to catch up
const CATCH_UP_MARGIN := 180.0
# fraction of half a screen the view starts ahead of the player
const START_LEAD := 0.5
# grip decays over distance, the wet run makes start and stop sluggish
const SLIP_RATE := 0.0015
const SLIP_MAX := 0.65

var _coyote := 0.0
var _buffer := 0.0
var _run_vel := 0.0
var _cam: Camera2D
var _cam_x := 0.0
var _cam_left := 0.0

func _ready() -> void:
	_cam = $Camera2D
	# the view never follows the body, detach it to pan in world space
	_cam.top_level = true
	_cam.position_smoothing_enabled = false
	_cam.set_physics_process(false)
	# start the view ahead of the player so the scroll is obvious at once
	_cam_x = global_position.x + _cam.get_viewport_rect().size.x * 0.5 * START_LEAD
	_cam.global_position = Vector2(_cam_x, _view_center_y())
	_cam_left = _cam_x - _cam.get_viewport_rect().size.x * 0.5

# camera y that puts the top edge of the view at view_top_y
func _view_center_y() -> float:
	return view_top_y + _cam.get_viewport_rect().size.y * 0.5

# horizontal span of the current view in world space
func view_left() -> float:
	return _cam_left

func view_right() -> float:
	return _cam_left + _cam.get_viewport_rect().size.x

# true once the player has been left off the right edge of the screen
func is_out_of_view() -> bool:
	return global_position.x - 8.0 > view_right()

# true once the trailing edge of the view has swallowed the player
func is_behind_view() -> bool:
	return global_position.x + 8.0 < view_left()

func is_below_view() -> bool:
	return global_position.y - 8.0 > view_top_y + _cam.get_viewport_rect().size.y

func _advance_camera(delta: float) -> void:
	_cam_x += scroll_speed * delta
	_cam.global_position = Vector2(_cam_x, _view_center_y())
	_cam_left = _cam_x - _cam.get_viewport_rect().size.x * 0.5

# the sideways push on top of the run, stream lean and live strength together
func _wind_drift() -> float:
	if wind_push == 0.0:
		return 0.0
	return wind_push * signf(tan(RainWind.wind_angle)) * RainWind.intensity

# ground grip that fades as the run wears on, shared by accel and braking
func _grip() -> float:
	return 1.0 - minf(RainWind.progress_m * SLIP_RATE, SLIP_MAX)

func _physics_process(delta: float) -> void:
	_advance_camera(delta)
	var input_dir: float = Input.get_axis("move_left", "move_right")

	_coyote -= delta
	_buffer -= delta
	if is_on_floor():
		_coyote = COYOTE_TIME
	if Input.is_action_just_pressed("jump"):
		_buffer = JUMP_BUFFER

	# releasing while rising cuts the jump short
	if Input.is_action_just_released("jump") and velocity.y < -250.0:
		velocity.y = -250.0

	# jump while the buffer is fresh and coyote time is still alive
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_buffer = 0.0
		_coyote = 0.0
	else:
		velocity.y = minf(velocity.y + gravity * delta, MAX_FALL_SPEED)

	# run leans toward the input, with a margin over the scroll to catch up
	var run_target: float = speed
	if input_dir > 0.0:
		run_target = scroll_speed + CATCH_UP_MARGIN
	# keep run and drift separate so the gust can never snowball frame to frame
	# grip fades with distance, softening both the launch and the brake
	_run_vel = move_toward(_run_vel, input_dir * run_target, speed * 8.0 * _grip() * delta)
	velocity.x = _run_vel + _wind_drift()

	# face the movement direction, keep the visual scale from the scene
	if input_dir != 0.0:
		var s: float = $Visual.scale.y
		$Visual.scale.x = s * signf(input_dir)

	move_and_slide()
