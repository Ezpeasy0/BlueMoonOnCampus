extends Node2D

@export var save_slot_button: Button
@export var sfx_hover: AudioStreamPlayer2D
@export var sfx_click: AudioStreamPlayer2D
@export_file("*.tscn") var game_scene_path: String = "res://scenes/game.tscn"

@onready var texture_rect = $PanelContainer/HBoxContainer/TextureRect
@onready var slot_name_label = $PanelContainer/HBoxContainer/VBoxContainer/slot
@onready var date_label = $PanelContainer/HBoxContainer/VBoxContainer/date
@onready var time_label = $PanelContainer/HBoxContainer/VBoxContainer/time

var slot_index: int = 1 
enum Mode { SAVE, LOAD }
var current_mode = Mode.LOAD 

signal slot_clicked(index: int, mode: Mode)

func _ready():
	if not save_slot_button:
		save_slot_button = _find_button_recursive(self)
	
	if save_slot_button:
		if save_slot_button.pressed.is_connected(_on_button_pressed):
			save_slot_button.pressed.disconnect(_on_button_pressed)
		save_slot_button.pressed.connect(_on_button_pressed)
		
		if save_slot_button.mouse_entered.is_connected(_play_hover):
			save_slot_button.mouse_entered.disconnect(_play_hover)
		save_slot_button.mouse_entered.connect(_play_hover)
		
		save_slot_button.mouse_filter = Control.MOUSE_FILTER_STOP
		save_slot_button.z_index = 1

	_fix_mouse_interference(get_tree().root) 
	refresh_display()

func _find_button_recursive(node: Node) -> Button:
	for child in node.get_children():
		if child is Button:
			return child
		var found = _find_button_recursive(child)
		if found: return found
	return null

func _fix_mouse_interference(node: Node):
	for child in node.get_children():
		if child is Control and not child is Button:
			if child.is_ancestor_of(save_slot_button) or save_slot_button.is_ancestor_of(child):
				child.mouse_filter = Control.MOUSE_FILTER_PASS
			else:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE
				
		if child.get_child_count() > 0:
			_fix_mouse_interference(child)

func setup_slot(index: int, mode: Mode):
	slot_index = index
	current_mode = mode
	if slot_name_label:
		slot_name_label.text = "Slot %d" % slot_index
	refresh_display()

func refresh_display():
	var save_path = "user://save_%d.dat" % slot_index
	if not date_label: return

	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		var content = file.get_as_text()
		var data = JSON.parse_string(content)
		if data:
			date_label.text = str(data.get("date", "No Date"))
			time_label.text = str(data.get("time", "00:00"))
			
			var img_path = "user://save_%d.png" % slot_index
			if FileAccess.file_exists(img_path):
				var img = Image.load_from_file(img_path)
				if img:
					texture_rect.texture = ImageTexture.create_from_image(img)
	else:
		date_label.text = "Empty Slot"
		time_label.text = "--:--"
		texture_rect.texture = load("res://background/Empty slot.png")

func _on_button_pressed():
	print("!!! [", name, "] CLICKED SUCCESS | Slot: ", slot_index, " !!!")
	_play_click()
	slot_clicked.emit(slot_index, current_mode)
	
	if current_mode == Mode.LOAD:
		_load_game_and_change_scene()
	else:
		_save_game_logic()

func _load_game_and_change_scene():
	var save_path = "user://save_%d.dat" % slot_index
	if FileAccess.file_exists(save_path):
		get_tree().change_scene_to_file(game_scene_path)
	else:
		print("Empty slot - cannot load")

func _save_game_logic():
	print("Saving to slot ", slot_index)

func _play_hover():
	if sfx_hover: sfx_hover.play()

func _play_click():
	if sfx_click: sfx_click.play()
