extends Node2D

@onready var _win: Label = $UI/WinLabel
@onready var _lose: Label = $UI/LoseLabel
@onready var _player: Node2D = $Player
@onready var _rain: Node2D = $Level/WorldRain

var _dead := false

func _ready() -> void:
	_win.visible = false
	_lose.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	# Keep rain over the visible screen, since the camera only travels right.
	_rain.global_position.x = _player.global_position.x

func _physics_process(_delta: float) -> void:
	if not _dead and (_player.is_out_of_view() or _player.is_behind_view()):
		_die()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().paused = false
		get_tree().reload_current_scene()

func _die() -> void:
	_dead = true
	_lose.visible = true
	_rain.visible = false
	get_tree().paused = true

func _on_goal_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_win.visible = true
		_dead = true
