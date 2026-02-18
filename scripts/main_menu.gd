extends Node2D

@export var menu: VBoxContainer
@export var options: Panel
@export var video: Panel
@export var audio: Panel


@export var back_button: Button
@export var options_button: Button
@export var video_button: Button
@export var audio_button: Button

@export var sfx_hover: AudioStreamPlayer2D
@export var sfx_click: AudioStreamPlayer2D

var nav_stack: Array[Control] = []
var current_panel: Control

func _ready():
	menu.visible = false
	options.visible = false
	video.visible = false
	audio.visible = false
	
	current_panel = menu
	_show_panel(menu)
	_update_back_button()
	
	back_button.pressed.connect(_on_back_pressed)
	options_button.pressed.connect(_navigate_to.bind(options))
	video_button.pressed.connect(_navigate_to.bind(video))
	audio_button.pressed.connect(_navigate_to.bind(audio))
	
	_setup_button_sounds(self)

func _setup_button_sounds(node: Node):
	for child in node.get_children():
		if child is Button:
			child.mouse_entered.connect(_play_hover)
			child.pressed.connect(_play_click)
		
		if child.get_child_count() > 0:
			_setup_button_sounds(child)

func _play_hover():
	if sfx_hover:
		sfx_hover.play()

func _play_click():
	if sfx_click:
		sfx_click.play()

func _on_exit_pressed() -> void:
	get_tree().quit()

func _show_panel(panel: Control):
	panel.visible = true
	
func _update_back_button():
	back_button.visible = nav_stack.size() > 0

func _navigate_to(panel: Control):
	if current_panel:
		nav_stack.append(current_panel)
		current_panel.visible = false
		
	current_panel = panel
	_show_panel(current_panel)
	_update_back_button()	
	
func _on_back_pressed():
	if nav_stack.is_empty():
		return
		
	current_panel.visible = false
	current_panel = nav_stack.pop_back()
	_show_panel(current_panel)
	_update_back_button()


func _on_load_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/save_slot.tscn") 
