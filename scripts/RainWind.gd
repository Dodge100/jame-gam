extends Node

## Global wind/angle control for ALL rain layers.
##
## Set it from your own systems (player script, weather controller, etc.):
##
##     RainWind.wind_angle = 0.25      # radians, rain drifts to the RIGHT
##     RainWind.wind_degrees = -15.0   # degrees, rain drifts to the LEFT
##
## 0 = straight down. Positive leans right, negative leans left.
## The value is applied every frame to the screen-streak shaders ("slant")
## and the world particle material ("direction"/"gravity"/"angle"), so drops
## already in the air bend along too — good for wind gusts.

var wind_angle := -0.24

func set_wind_degrees(deg: float) -> void:
	wind_angle = deg_to_rad(deg)

func get_wind_degrees() -> float:
	return rad_to_deg(wind_angle)

## slope = horizontal px per vertical px; +right, -left
func _wind_slope() -> float:
	return tan(wind_angle)

var _streak_mats: Array = []          # StreakMist + StreakNear ShaderMaterials
var _particle_mat = null              # ParticleProcessMaterial (dynamic for safety)

func _process(_delta: float) -> void:
	_locate_devices()
	var slope := _wind_slope()
	# The shader's x axis spans 1.7778 screen-heights, so convert px slope.
	var slant := slope * 0.5625

	for m in _streak_mats:
		m.set_shader_parameter("slant", slant)

	if _particle_mat != null:
		var g: Vector3 = _particle_mat.gravity
		_particle_mat.direction = Vector3(slope, 1.0, 0.0)
		# Align the fall force with the drift so drops keep their angle.
		_particle_mat.gravity = Vector3(g.y * slope, g.y, 0.0)
		# Align the vertical streak texture with the lean. angle_min/max are
		# in DEGREES, and canvas rotation is positive clockwise, so a lean
		# right of the streak line (top toward the right) turns the texture
		# counterclockwise.
		var lean_deg := -rad_to_deg(atan(slope))
		_particle_mat.angle = Vector2(lean_deg, lean_deg)

func _locate_devices() -> void:
	var mats_ok := _streak_mats.size() == 2 and is_instance_valid(_streak_mats[0])
	if mats_ok and is_instance_valid(_particle_mat):
		return

	_streak_mats.clear()
	_particle_mat = null
	var scene := get_tree().current_scene
	if scene == null:
		return

	var vr = scene.find_child("ViewportRain", true, false)
	if vr != null:
		for layer_name in ["StreakMist", "StreakNear"]:
			var c = vr.get_node_or_null(layer_name)
			if c != null and c.material is ShaderMaterial:
				_streak_mats.append(c.material)

	var wr = scene.find_child("WorldRain", true, false)
	if wr != null and wr.process_material != null and (wr.process_material is ParticleProcessMaterial or wr.process_material.get_class() == "ParticlesMaterial"):
		_particle_mat = wr.process_material
