extends Node2D

const BRANCH_SCENE: PackedScene = preload("res://scenes/Branch.tscn")
const BRANCH_SCALE := Vector2(1.7, 1.7)
const START_X := -400.0
const START_WIDTH := 1300.0
const START_Y := 600.0
const MIN_SURFACE_Y := 380.0
const MAX_SURFACE_Y := 600.0
const BOTTOM_Y := 760.0
const GENERATE_AHEAD := 1400.0
const KEEP_BEHIND := 400.0
# storm debris: rain-born leaves fall into fresh spans and swing in the wind
const LEAF_SCENE := preload("res://scenes/Leaf.tscn")
const LEAF_LIFT_MIN := 200.0
const LEAF_LIFT_MAX := 300.0
# leaves kept alive at once, spawned only when the storm thins the field
const LEAF_COUNT := 7
# new leaves drop in past the right edge, never in sight, one per lane
const LEAF_OFFSCREEN_MARGIN := 60.0
const LEAF_SLOT_SPACING := 320.0
# x of the next leaf slot, pushed past the right edge so drops never overlap
var _next_slot_x := -INF

var _rng := RandomNumberGenerator.new()
var _segments: Array[StaticBody2D] = []
var _branches: Array[StaticBody2D] = []
var _leaves: Array[Node2D] = []
var _next_x := START_X + START_WIDTH
var _last_y := START_Y

func _ready() -> void:
	_rng.randomize()
	_add_segment(START_X, START_Y, START_WIDTH)
	_add_branch(Vector2(390, 245))

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
		if _rng.randf() < 0.6:
			_add_branch(Vector2(_next_x + _rng.randf_range(-120.0, 220.0), _rng.randf_range(170.0, 310.0)))
		var width := _rng.randf_range(280.0, 560.0)
		_add_segment(_next_x, surface_y, width)
		_next_x += width
		_last_y = surface_y

	while not _segments.is_empty() and float(_segments[0].get_meta("right")) < view_left - KEEP_BEHIND:
		var old_segment: StaticBody2D = _segments.pop_front()
		old_segment.queue_free()

	while not _branches.is_empty() and _branches[0].position.x + 340.0 < view_left - KEEP_BEHIND:
		_branches.pop_front().queue_free()

	# leaves drift both ways, sweep the whole tracked list every call
	for i in range(_leaves.size() - 1, -1, -1):
		var leaf: Node2D = _leaves[i]
		if not is_instance_valid(leaf):
			_leaves.remove_at(i)
		elif leaf.position.x < view_left - KEEP_BEHIND or leaf.position.x > view_right + GENERATE_AHEAD:
			leaf.queue_free()
			_leaves.remove_at(i)

	# hold a steady field: replace what drifted off or died on the ground
	while _leaves.size() < LEAF_COUNT:
		_spawn_leaf_burst(view_right)

func _add_branch(at: Vector2) -> void:
	var branch: StaticBody2D = BRANCH_SCENE.instantiate()
	branch.position = at
	branch.scale = BRANCH_SCALE
	add_child(branch)
	_branches.append(branch)

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

# loose debris dropped past the right edge, landing wherever it is blown to
func _spawn_leaf_burst(view_right: float) -> void:
	var surface_y := _rng.randf_range(MIN_SURFACE_Y, MAX_SURFACE_Y)
	# step the slot on every drop so leaves queue up instead of stacking; the
	# cursor resets when it runs past the strip being watched
	if _next_slot_x > view_right + GENERATE_AHEAD * 0.5:
		_next_slot_x = -INF
	var x := maxf(view_right + LEAF_OFFSCREEN_MARGIN, _next_slot_x)
	_next_slot_x = x + LEAF_SLOT_SPACING
	var leaf: Node2D = LEAF_SCENE.instantiate()
	leaf.position = Vector2(x + _rng.randf_range(0.0, LEAF_SLOT_SPACING * 0.4), surface_y - _rng.randf_range(LEAF_LIFT_MIN, LEAF_LIFT_MAX))
	# may settle anywhere within reach of its drift before it fades out
	leaf.setup(surface_y, x - 300.0, x + 900.0)
	add_child(leaf)
	_leaves.append(leaf)
