extends Control

enum Mode { SAVE, LOAD }

@export var mode: Mode = Mode.LOAD

var pending_slot: int = -1

@onready var confirm_dialog: ConfirmationDialog = $SaveConfirmDialog
@onready var delete_dialog: ConfirmationDialog = $DeleteConfirmDialog

func _ready() -> void:
	refresh_all_slots()
	confirm_dialog.confirmed.connect(_on_overwrite_confirmed)
	delete_dialog.confirmed.connect(_on_delete_confirmed)

func refresh_all_slots() -> void:
	var grid: GridContainer = $ScrollContainer/GridContainer
	for child in grid.get_children():
		if child.has_method("update_ui") and "slot_id" in child:
			var preview := GameSave.load_slot_preview(child.slot_id)
			child.update_ui(preview)

func slot_selected(slot: int) -> void:
	if mode == Mode.LOAD:
		# Load only if exists, otherwise do nothing (REQ2)
		if GameSave.load_game(slot):
			get_tree().change_scene_to_file("res://scenes/dialogue.tscn") # change later to gameplay scene
		return

	# SAVE MODE (REQ1)
	pending_slot = slot
	if GameSave.slot_exists(slot):
		confirm_dialog.popup_centered()
	else:
		_on_overwrite_confirmed()

func _on_overwrite_confirmed() -> void:
	if pending_slot == -1:
		return

	# If you want "New Game creates fresh state", use new_game instead of save_game:
	GameSave.new_game(pending_slot)

	pending_slot = -1
	refresh_all_slots()

func request_delete(slot: int) -> void:
	pending_slot = slot
	delete_dialog.popup_centered()

func _on_delete_confirmed() -> void:
	if pending_slot == -1:
		return
	GameSave.delete_slot(pending_slot)
	pending_slot = -1
	refresh_all_slots()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
