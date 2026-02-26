extends Node2D

@export_group("Panels")
@export var menu: Control
@export var options_instance: Panel 
@export var video_panel: Panel      
@export var audio_panel: Panel      

@export_group("Buttons")
@export var options_button: Button
@export var back_button: Button      

@export_group("Audio")
@export var sfx_hover: AudioStreamPlayer
@export var sfx_click: AudioStreamPlayer

var save_scene = load("res://scenes/save_slot_save.tscn")
var load_scene = load("res://scenes/save_slot_load.tscn")

var nav_stack: Array[Control] = []

func _ready():
	if menu == null or options_instance == null:
		return

	options_instance.hide()
	video_panel.hide()
	audio_panel.hide()
	back_button.hide()

	if not options_button.pressed.is_connected(_on_options_pressed):
		options_button.pressed.connect(_on_options_pressed)
	
	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

	if options_instance.has_signal("video_requested"):
		if not options_instance.video_requested.is_connected(_open_sub_panel):
			options_instance.video_requested.connect(_open_sub_panel.bind(video_panel))
			
	if options_instance.has_signal("audio_requested"):
		if not options_instance.audio_requested.is_connected(_open_sub_panel):
			options_instance.audio_requested.connect(_open_sub_panel.bind(audio_panel))
	
	_setup_button_sounds(self)

func _on_options_pressed():
	_open_sub_panel(options_instance)

func _open_sub_panel(panel: Control):
	if panel == null: return
	
	if not nav_stack.is_empty():
		nav_stack.back().hide() 
	else:
		menu.hide() 
		
	panel.show()
	nav_stack.append(panel)
	back_button.show()

func _on_back_pressed():
	if nav_stack.is_empty():
		return
		
	var current = nav_stack.pop_back()
	current.hide()
	
	if nav_stack.is_empty():
		menu.show()
		back_button.hide()
	else:
		nav_stack.back().show() 

func _setup_button_sounds(node: Node):
	for child in node.get_children():
		if child is Button:
			if not child.mouse_entered.is_connected(_play_hover_sound):
				child.mouse_entered.connect(_play_hover_sound)
			if not child.pressed.is_connected(_play_click_sound):
				child.pressed.connect(_play_click_sound)
		if child.get_child_count() > 0:
			_setup_button_sounds(child)

func _play_hover_sound():
	if sfx_hover and sfx_hover.is_inside_tree():
		sfx_hover.play()

func _play_click_sound():
	if sfx_click and sfx_click.is_inside_tree():
		sfx_click.play()

func _on_exit_pressed():
	get_tree().quit()

# save
func _on_new_game_pressed() -> void:
	if save_scene:
		var save_menu = save_scene.instantiate()
		add_child(save_menu)
		move_child(save_menu, -1) 

func _on_load_pressed() -> void:
	if load_scene:
		var load_menu = load_scene.instantiate()
		add_child(load_menu)
		move_child(load_menu, -1)
