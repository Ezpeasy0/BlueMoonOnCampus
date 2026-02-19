extends Control

enum Mode { LOAD, SAVE }
@export var mode: Mode = Mode.LOAD   # Main menu should use LOAD

var pending_save_id: int = -1

@onready var confirm_dialog: ConfirmationDialog = $SaveConfirmDialog

@export var sfx_hover: AudioStreamPlayer2D
@export var sfx_click: AudioStreamPlayer2D

func _ready() -> void:
	refresh_all_slots()

	# IMPORTANT: only OK triggers save
	if not confirm_dialog.confirmed.is_connected(_on_save_confirmed):
		confirm_dialog.confirmed.connect(_on_save_confirmed)

	# IMPORTANT: cancel should clear pending id
	if confirm_dialog.has_signal("canceled"):
		if not confirm_dialog.canceled.is_connected(_on_save_canceled):
			confirm_dialog.canceled.connect(_on_save_canceled)

	# Hover/click sounds (safe)
	for child in $ScrollContainer/GridContainer.get_children():
		if child is Button:
			if not child.mouse_entered.is_connected(_play_hover):
				child.mouse_entered.connect(_play_hover)
			if not child.pressed.is_connected(_play_click):
				child.pressed.connect(_play_click)

func _play_hover() -> void:
	if sfx_hover:
		sfx_hover.play()

func _play_click() -> void:
	if sfx_click:
		sfx_click.play()

func refresh_all_slots() -> void:
	var grid: GridContainer = $ScrollContainer/GridContainer
	for child in grid.get_children():
		if child.has_method("update_ui"):
			var data: SaveResource = load_file(child.slot_id)
			child.update_ui(data)

# This is called by each slot button script: get_owner().slot_selected(slot_id)
func slot_selected(id: int) -> void:
	if mode == Mode.LOAD:
		_load_flow(id)
	else:
		_save_flow(id)

func _load_flow(id: int) -> void:
	var data: SaveResource = load_file(id)
	if data == null:
		# empty slot -> do nothing (or show a dialog if you want)
		return

	# TODO: Put loaded data into your game state (story index, stats, etc.)
	# For now, just go to dialogue scene:
	get_tree().change_scene_to_file("res://scenes/dialogue.tscn")

func _save_flow(id: int) -> void:
	pending_save_id = id

	var path := "user://save_%d.tres" % id
	if FileAccess.file_exists(path):
		confirm_dialog.popup_centered()
		return

	_on_save_confirmed()

func _on_save_confirmed() -> void:
	if pending_save_id == -1:
		return

	save_file(pending_save_id)
	pending_save_id = -1
	refresh_all_slots()

func _on_save_canceled() -> void:
	pending_save_id = -1

func save_file(id: int) -> void:
	var new_save := SaveResource.new()
	new_save.slot_name = "Slot " + str(id + 1)

	var dt := Time.get_datetime_dict_from_system()
	new_save.date = "%02d/%02d/%d" % [dt.day, dt.month, dt.year]
	new_save.time = "%02d:%02d" % [dt.hour, dt.minute]

	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(480, 270, Image.INTERPOLATE_LANCZOS)
	new_save.screenshot = ImageTexture.create_from_image(img)

	ResourceSaver.save(new_save, "user://save_%d.tres" % id)

func load_file(id: int) -> SaveResource:
	var path := "user://save_%d.tres" % id
	if FileAccess.file_exists(path):
		return load(path) as SaveResource
	return null

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
