extends Control

var pending_save_id: int = -1

@onready var confirm_dialog = $SaveConfirmDialog 

@export var sfx_hover: AudioStreamPlayer2D
@export var sfx_click : AudioStreamPlayer2D

func _ready():
	refresh_all_slots()
	confirm_dialog.confirmed.connect(_on_save_confirmed)
	
	for child in $ScrollContainer/GridContainer.get_children():
		if child is Button:
			child.mouse_entered.connect(_play_hover)
			child.pressed.connect(_play_click)

func _play_hover():
	sfx_hover.play()

func _play_click():
	sfx_click.play()
	
func refresh_all_slots():
	var grid = $ScrollContainer/GridContainer
	for child in grid.get_children():
		if child.has_method("update_ui"):
			var data = load_file(child.slot_id)
			child.update_ui(data)

func slot_selected(id: int):
	pending_save_id = id 
	if FileAccess.file_exists("user://save_%d.tres" % id):
		confirm_dialog.popup_centered()
	else:
		_on_save_confirmed()

func _on_save_confirmed():
	if pending_save_id != -1:
		save_file(pending_save_id)
		pending_save_id = -1 

func save_file(id: int):
	var new_save = SaveResource.new()
	new_save.slot_name = "Slot " + str(id + 1)
	
	var dt = Time.get_datetime_dict_from_system()
	new_save.date = "%02d/%02d/%d" % [dt.day, dt.month, dt.year]
	new_save.time = "%02d:%02d" % [dt.hour, dt.minute]
	
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.resize(480, 270, Image.INTERPOLATE_LANCZOS)
	new_save.screenshot = ImageTexture.create_from_image(img)
	
	ResourceSaver.save(new_save, "user://save_%d.tres" % id)
	refresh_all_slots()

func load_file(id: int) -> SaveResource:
	var path = "user://save_%d.tres" % id
	if FileAccess.file_exists(path):
		return load(path) as SaveResource
	return null


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn") 
