extends Control

enum Mode { SAVE, LOAD }
@export var mode: Mode = Mode.LOAD

var pending_slot: int = -1

@onready var confirm_dialog: ConfirmationDialog = $SaveConfirmDialogue
@onready var delete_dialog: ConfirmationDialog = $DeleteConfirmDialogue

func _ready():
	refresh_all_slots()
	confirm_dialog.confirmed.connect(_on_overwrite_confirmed)
	delete_dialog.confirmed.connect(_on_delete_confirmed)

func refresh_all_slots():
	var grid := $ScrollContainer/GridContainer
	for child in grid.get_children():
		if child.has_method("update_ui"):
			var preview := GameSave.load_slot_preview(child.slot_id)
			child.update_ui(preview)

func slot_selected(slot: int):
	if mode == Mode.LOAD:
		if GameSave.load_game(slot):
			get_tree().change_scene_to_file("res://scenes/dialogue.tscn")
		return

	# SAVE MODE
	pending_slot = slot
	if GameSave.slot_exists(slot):
		confirm_dialog.popup_centered()
	else:
		_on_overwrite_confirmed()

func _on_overwrite_confirmed():
	if pending_slot == -1:
		return
	GameSave.save_game(pending_slot)
	pending_slot = -1
	refresh_all_slots()

func _on_delete_pressed(slot: int):
	pending_slot = slot
	delete_dialog.popup_centered()

func _on_delete_confirmed():
	if pending_slot == -1:
		return
	GameSave.delete_slot(pending_slot)
	pending_slot = -1
	refresh_all_slots()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
