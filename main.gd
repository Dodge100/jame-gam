extends Node2D

@onready var _win: Label = $UI/WinLabel

func _ready() -> void:
	_win.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()

func _on_goal_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_win.visible = true
