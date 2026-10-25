extends AnimatableBody2D

# storm debris: swings back and forth in the gusts and drifts with the lean

const SINK_MIN := 26.0
const SINK_MAX := 44.0
const SWAY_MIN := 60.0
const SWAY_MAX := 140.0
const RATE_MIN := 1.3
const RATE_MAX := 2.4
# leaf size against the runner, every leaf rolls its own, doubled
const SIZE_LOW := 4.4
const SIZE_HIGH := 6.0
const REST_DEPTH := 10.0
const DRIFT_BASE := 110.0
const LOST_FADE := 0.8
const DEEP_DIE := 1000.0

var _rng := RandomNumberGenerator.new()
var _phase := 0.0
var _seed := 0.0
var _rate := 1.8
var _sway := 90.0
var _sink := 34.0
var _size := 5.2
var _floor_y := 600.0
var _span_l := 0.0
var _span_r := 0.0
var _anchor_x := 0.0
var _landed := false
var _lost_t := 0.0

# remember the ground line and span this leaf may settle into
func setup(floor_y: float, span_l: float, span_r: float) -> void:
	_floor_y = floor_y
	_span_l = span_l
	_span_r = span_r

func _ready() -> void:
	_rng.randomize()
	_rate = _rng.randf_range(RATE_MIN, RATE_MAX)
	_sway = _rng.randf_range(SWAY_MIN, SWAY_MAX)
	_sink = _rng.randf_range(SINK_MIN, SINK_MAX)
	_size = _rng.randf_range(SIZE_LOW, SIZE_HIGH)
	# sync bodies may not be scaled, size the visuals and the shape directly
	for c in get_children():
		if c is Polygon2D or c is Line2D:
			c.scale = Vector2(_size, _size)
	var col: CollisionShape2D = $Col
	var circle := CircleShape2D.new()
	circle.radius = 9.0 * _size
	col.shape = circle
	_phase = _rng.randf_range(0.0, TAU)
	_seed = _rng.randf_range(0.0, TAU)
	# preload the swing so the leaf leaves smoothly from its spawn spot
	_anchor_x = position.x - sin(_phase + _seed) * _sway * clampf(RainWind.intensity, 0.3, 2.5)

func _physics_process(delta: float) -> void:
	if _landed:
		return
	var strength := clampf(RainWind.intensity, 0.3, 2.5)
	# lean direction as a sign so steep gusts never fling at tan speed
	var drift := signf(tan(RainWind.wind_angle)) * DRIFT_BASE * strength
	_phase += _rate * delta
	_anchor_x += drift * delta
	# one position write per frame, the sync pipeline eats any extra writes
	var nx := _anchor_x + sin(_phase + _seed) * _sway * strength
	var ny := position.y + _sink * delta
	var rest_y := _floor_y - REST_DEPTH * _size
	if ny >= rest_y and nx > _span_l and nx < _span_r:
		ny = rest_y
		_landed = true
	position = Vector2(nx, ny)
	if _landed:
		return
	# flap the artwork only, the collider stays level for riders
	var flap := sin(_phase * 0.5 + _seed) * 0.7
	for c in get_children():
		if c is Polygon2D or c is Line2D:
			c.rotation = flap
	# swept off its own span: fade out like it was lost to the storm
	if ny > _floor_y + 16.0:
		_lost_t += delta
		modulate.a = clampf(1.0 - _lost_t / LOST_FADE, 0.0, 1.0)
		if _lost_t >= LOST_FADE:
			queue_free()
			return
	if ny > DEEP_DIE:
		queue_free()
