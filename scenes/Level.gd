extends Node2D

const START_X := -400.0
const START_WIDTH := 1300.0
const START_Y := 600.0
const MIN_SURFACE_Y := 380.0
const MAX_SURFACE_Y := 600.0
const BOTTOM_Y := 760.0
const GENERATE_AHEAD := 1400.0
const KEEP_BEHIND := 400.0

var _rng := RandomNumberGenerator.new()
var _segments: Array[StaticBody2D] = []
var _next_x := START_X + START_WIDTH
var _last_y := START_Y

func _ready() -> void:
	_rng.randomize()
	_add_segment(START_X, START_Y, START_WIDTH)

func stream_to(view_left: float, view_right: float) -> void:
	while _next_x < view_right + GENERATE_AHEAD:
		var surface_y := clampf(
			_last_y + _rng.randf_range(-80.0, 110.0),
			MIN_SURFACE_Y,
			MAX_SURFACE_Y
		)
		var gap := _rng.randf_range(80.0, 170.0)
		if surface_y < _last_y:
			gap = minf(gap, 120.0)
		_next_x += gap
		var width := _rng.randf_range(280.0, 560.0)
		_add_segment(_next_x, surface_y, width)
		_next_x += width
		_last_y = surface_y

	while not _segments.is_empty() and float(_segments[0].get_meta("right")) < view_left - KEEP_BEHIND:
		var old_segment: StaticBody2D = _segments.pop_front()
		old_segment.queue_free()

func _add_segment(x: float, y: float, width: float) -> void:
	var segment := StaticBody2D.new()
	segment.position = Vector2(x, y)
	segment.set_meta("right", x + width)

	var depth := BOTTOM_Y - y
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, depth)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(width * 0.5, depth * 0.5)
	segment.add_child(collision)

	var visual := ColorRect.new()
	visual.size = shape.size
	visual.color = Color(0.07, 0.08, 0.11, 1.0)
	segment.add_child(visual)

	var top_line := ColorRect.new()
	top_line.size = Vector2(width, 3.0)
	top_line.color = Color(0.3, 0.36, 0.46, 0.3)
	segment.add_child(top_line)

	add_child(segment)
	_segments.append(segment)
