extends Control

@onready var _play: Button = $UI/Play

func _ready() -> void:
	_play.grab_focus()

# the menu clears away and the runner drops into the storm
func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
