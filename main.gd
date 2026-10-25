extends Node2D

@onready var _distance_label: Label = $UI/DistanceLabel
@onready var _lose: Label = $UI/LoseLabel
@onready var _level: Node2D = $Level
@onready var _player: Node2D = $Player
@onready var _rain: GPUParticles2D = $Level/WorldRain
@onready var _rain_material: ParticleProcessMaterial = _rain.process_material

var _dead := false
var _distance := 0

func _ready() -> void:
	_lose.visible = false
	_distance_label.text = "0 m"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	_level.process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(_delta: float) -> void:
	# Keep the emitter fixed so its collision transform stays stable.
	var offset: float = (_player.view_left() + _player.view_right()) * 0.5 - _rain.global_position.x
	_rain_material.emission_shape_offset.x = offset
	_rain.visibility_rect.position.x = offset - 1200.0

func _physics_process(_delta: float) -> void:
	if _dead:
		return
	_level.stream_to(_player.view_left(), _player.view_right())
	_distance = maxi(_distance, int((_player.global_position.x - 150.0) / 50.0))
	_distance_label.text = "%d m" % _distance
	if _player.is_out_of_view() or _player.is_behind_view() or _player.is_below_view():
		_die()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().paused = false
		get_tree().reload_current_scene()

func _die() -> void:
	_dead = true
	_lose.text = "LOST IN THE RAIN\n%d m\nPRESS R TO TRY AGAIN" % _distance
	_lose.visible = true
	_rain.visible = false
	get_tree().paused = true
