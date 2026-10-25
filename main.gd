extends Node2D

@onready var _distance_label: Label = $UI/DistanceLabel
@onready var _over: Control = $UI/GameOver
@onready var _over_distance: Label = $UI/GameOver/Center/Card/Rows/Distance
@onready var _replay_button: Button = $UI/GameOver/Center/Card/Rows/Replay
@onready var _level: Node2D = $Level
@onready var _player: Node2D = $Player
@onready var _rain: GPUParticles2D = $Level/WorldRain
@onready var _rain_material: ParticleProcessMaterial = _rain.process_material

var _dead := false
var _distance := 0

func _ready() -> void:
	_over.visible = false
	_distance_label.text = "0 m"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	_level.process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(_delta: float) -> void:
	# keep the emitter fixed so its collision transform stays stable
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
		_replay()

# the menu clears away and the runner drops into the storm
func _on_replay_pressed() -> void:
	_replay()

func _replay() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _die() -> void:
	_dead = true
	_rain.visible = false
	_over_distance.text = "%d m" % _distance
	_over.visible = true
	_replay_button.grab_focus()
	get_tree().paused = true
