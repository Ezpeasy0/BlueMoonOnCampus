extends Node2D

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_tree().change_scene_to_file("res://scenes/dialogue.tscn")

	if event is InputEventKey and event.pressed:
		get_tree().change_scene_to_file("res://scenes/dialogue.tscn")
