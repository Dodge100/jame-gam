extends Node

# storm lean in radians that every layer follows; 0 straight down, +right, -left
# applied to shaders and drops every frame so gusts shift things mid-air

var wind_angle := -0.24
# storm intensity, scales rain visibility and the push on the player
var intensity := 1.0
# self-driven weather wandering; false hands both values back to you
var gust_enabled := true
# how far the lean may roam at first, and how it deepens with distance
const LEAN_LIMIT := 0.45
const LEAN_RISE := 0.001
const LEAN_MAX_RISE := 0.55
# storm intensity bounds at the start of a run, and how far they may rise
const START_LOW := 0.35
const START_HIGH := 1.3
const STORM_RISE := 0.002
const STORM_MAX_RISE := 1.1
# px counted as one meter of distance, same rate as the hud label
const METER_PX := 50.0
# the floor for how fast a gust may snap in, and the odds of such a snap
const GUST_FLOOR := 0.1
const SNAP_CHANCE := 0.12

var _rng := RandomNumberGenerator.new()
var _from_angle := 0.0
var _to_angle := -0.24
var _from_strength := 1.0
var _to_strength := 1.0
var _gust_t := 0.0
var _gust_dur := 5.0
# net meters of forward run, the farther you go the harsher the storm
var progress_m := 0.0
var _player = null
var _last_x := 0.0
var _progress_prime := false

var _streak_mats: Array = []   # streak layer materials
var _streak_bases: Array[float] = []
var _rain_color := Color.WHITE
# bound identities; base values recapture only when the device set changes
var _streak_bound: Array = []
var _particle_bound = null
var _particle_mat = null       # world rain material
var _patch_mat = null          # blur patch material

# patches sit slightly in front of the lens, they slide faster than the world
const PARALLAX_FACTOR := 1.18
# cell count the patch hash repeats after, keep in sync with blurpatch shader
const CELL_PERIOD := 1024.0
var _parallax_uv := Vector2.ZERO
var _cam_prev := Vector2.ZERO
var _cam_prev_valid := false

func _ready() -> void:
	_rng.randomize()
	_start_gust()

# set the lean from degrees instead
func set_wind_degrees(deg: float) -> void:
	wind_angle = deg_to_rad(deg)

func get_wind_degrees() -> float:
	return rad_to_deg(wind_angle)

# rain lean in px of drift per px of fall, positive right
func _wind_slope() -> float:
	return tan(wind_angle)

# lean bound grows with distance, the storm tips harder the farther you go
func _lean_limit() -> float:
	return LEAN_LIMIT + minf(progress_m * LEAN_RISE, LEAN_MAX_RISE)

# pick the next gust target: most ease over ~5s, rare snaps hit the 0.1s floor
func _start_gust() -> void:
	_from_angle = wind_angle
	_from_strength = intensity
	var lim := _lean_limit()
	_to_angle = clampf(wind_angle + _rng.randf_range(-0.3, 0.3), -lim, lim)
	# the farther you run the harsher the storm, both bounds climb together
	var rise := minf(progress_m * STORM_RISE, STORM_MAX_RISE)
	_to_strength = _rng.randf_range(START_LOW + rise, START_HIGH + rise)
	if _rng.randf() < SNAP_CHANCE:
		_gust_dur = randf_range(GUST_FLOOR, 1.2)
	else:
		_gust_dur = _rng.randf_range(2.5, 7.5)
	_gust_dur = maxf(_gust_dur, GUST_FLOOR)
	_gust_t = 0.0

func _update_gust(delta: float) -> void:
	_gust_t += delta
	var t := clampf(_gust_t / _gust_dur, 0.0, 1.0)
	var e := smoothstep(0.0, 1.0, t)
	wind_angle = lerpf(_from_angle, _to_angle, e)
	intensity = lerpf(_from_strength, _to_strength, e)
	if t >= 1.0:
		_start_gust()

# forward steps only, teleport-like jumps never smear the distance
func _update_progress() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var x: float = _player.global_position.x
	if _progress_prime:
		var step := x - _last_x
		if step > 0.0 and step < 1000.0:
			progress_m += step / METER_PX
	else:
		_progress_prime = true
	_last_x = x

func _update_parallax() -> void:
	if _patch_mat == null or not is_instance_valid(_patch_mat):
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var center: Vector2 = cam.get_screen_center_position()
	if not _cam_prev_valid:
		_cam_prev = center
		_cam_prev_valid = true
		return
	var delta: Vector2 = center - _cam_prev
	_cam_prev = center
	if delta.length() > 600.0:
		return  # scene reload or teleport, keep the field intact
	var ps: Vector2 = _patch_mat.get_shader_parameter("pixel_size")
	_parallax_uv += delta * PARALLAX_FACTOR * ps
	# wrap at the hash period so the endless scroll never pops
	var grid: Vector2 = _patch_mat.get_shader_parameter("grid")
	var period := Vector2(CELL_PERIOD / grid.x, CELL_PERIOD / grid.y)
	_parallax_uv.x = wrapf(_parallax_uv.x, -period.x * 0.5, period.x * 0.5)
	_parallax_uv.y = wrapf(_parallax_uv.y, -period.y * 0.5, period.y * 0.5)
	_patch_mat.set_shader_parameter("parallax", _parallax_uv)

func _process(delta: float) -> void:
	_locate_devices()
	_update_progress()
	_update_parallax()
	if gust_enabled:
		_update_gust(delta)
	var slope := _wind_slope()
	# the shader x axis spans 1.7778 screen heights, convert px slope to it
	var slant := slope * 0.5625
	for m in _streak_mats:
		m.set_shader_parameter("slant", slant)
	# alive rain scales the scene's authored brightness and drop opacity
	for i in _streak_mats.size():
		_streak_mats[i].set_shader_parameter("intensity", _streak_bases[i] * intensity)
	if _particle_mat != null:
		_particle_mat.color = Color(
			_rain_color.r, _rain_color.g, _rain_color.b, _rain_color.a * intensity)

	if _particle_mat != null:
		var g: Vector3 = _particle_mat.gravity
		_particle_mat.direction = Vector3(slope, 1.0, 0.0)
		# aim the fall force along the drift so drops keep their angle
		_particle_mat.gravity = Vector3(g.y * slope, g.y, 0.0)
		# negative angle leans the streak top right, matching a '/' storm
		var lean_deg := rad_to_deg(atan(slope))
		_particle_mat.angle_min = lean_deg
		_particle_mat.angle_max = lean_deg

func _locate_devices() -> void:
	var found := _streak_mats.size() == 2 \
		and is_instance_valid(_streak_mats[0]) \
		and is_instance_valid(_particle_mat) \
		and is_instance_valid(_patch_mat) \
		and is_instance_valid(_player)
	if found:
		return
	_streak_mats.clear()
	_particle_mat = null
	_patch_mat = null
	var scene := get_tree().current_scene
	if scene == null:
		return
	var vr = scene.find_child("ViewportRain", true, false)
	if vr != null:
		for layer_name in ["StreakMist", "StreakNear"]:
			var c = vr.get_node_or_null(layer_name)
			if c != null and c.material is ShaderMaterial:
				_streak_mats.append(c.material)
		var bp = vr.get_node_or_null("BlurPatches")
		if bp != null and bp.material is ShaderMaterial:
			_patch_mat = bp.material
	var wr = scene.find_child("WorldRain", true, false)
	if wr != null and wr.process_material != null \
		and (wr.process_material is ParticleProcessMaterial \
			or wr.process_material.get_class() == "ParticlesMaterial"):
		_particle_mat = wr.process_material
	var pr = scene.find_child("Player", true, false)
	if pr != null and pr is Node2D and pr != _player:
		# a different player node means a fresh run, storm progress resets
		_player = pr
		progress_m = 0.0
		_progress_prime = false
	# remember the authored values so gusts can scale them without drift
	# only fresh binds may capture; rereading mutated values compounds gusts
	if _streak_mats != _streak_bound:
		_streak_bound = _streak_mats.duplicate()
		_streak_bases.clear()
		for m in _streak_mats:
			_streak_bases.append(float(m.get_shader_parameter("intensity")))
	if _particle_mat != null and _particle_mat != _particle_bound:
		_particle_bound = _particle_mat
		_rain_color = _particle_mat.color
