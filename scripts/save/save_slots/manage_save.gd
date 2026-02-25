# res://scripts/save/save_slots/manage_save.gd
extends Control

enum Mode { NEW_GAME, LOAD }
@export var mode: Mode = Mode.NEW_GAME

# IMPORTANT: do NOT preload dialogue.tscn here (it can cause cyclic load).
@export var gameplay_scene_path: String = "res://scenes/dialogue.tscn"

@onready var overwrite_dialog: ConfirmationDialog = $OverwriteConfirmDialog
@onready var load_dialog: ConfirmationDialog = $LoadConfirmDialog
@onready var empty_dialog: AcceptDialog = $EmptySlotDialog
@onready var delete_dialog: ConfirmationDialog = $DeleteConfirmDialog
@onready var back_button: Button = $Back

var _pending_slot: int = -1
var _pending_delete_slot: int = -1

func _ready() -> void:
	# Detect by *this instantiated scene's* path (works even when added as a child)
	var my_path: String = get_scene_file_path()
	if my_path.ends_with("save_slot_load.tscn"):
		mode = Mode.LOAD
	elif my_path.ends_with("save_slot_save.tscn"):
		mode = Mode.NEW_GAME

	if not overwrite_dialog.confirmed.is_connected(_on_overwrite_confirmed):
		overwrite_dialog.confirmed.connect(_on_overwrite_confirmed)
	if not load_dialog.confirmed.is_connected(_on_load_confirmed):
		load_dialog.confirmed.connect(_on_load_confirmed)
	if not delete_dialog.confirmed.is_connected(_on_delete_confirmed):
		delete_dialog.confirmed.connect(_on_delete_confirmed)

	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

	refresh_slots_ui()

func slot_selected(slot_id: int) -> void:
	_pending_slot = slot_id

	match mode:
		Mode.NEW_GAME:
			# Always ask overwrite (even empty slot) – your requirement
			overwrite_dialog.dialog_text = "Overwrite slot %d?" % (slot_id + 1)
			overwrite_dialog.popup_centered()

		Mode.LOAD:
			if GameSave.slot_exists(slot_id):
				load_dialog.dialog_text = "Load slot %d?" % (slot_id + 1)
				load_dialog.popup_centered()
			else:
				empty_dialog.dialog_text = "Empty slot"
				empty_dialog.popup_centered()

func request_delete(slot_id: int) -> void:
	_pending_delete_slot = slot_id
	delete_dialog.dialog_text = "Delete slot %d?" % (slot_id + 1)
	delete_dialog.popup_centered()

func _on_overwrite_confirmed() -> void:
	if _pending_slot < 0:
		return
	GameSave.new_game(_pending_slot)
	_go_to_gameplay()

func _on_load_confirmed() -> void:
	if _pending_slot < 0:
		return

	if GameSave.load_game(_pending_slot):
		_go_to_gameplay()
	else:
		empty_dialog.dialog_text = "Empty slot"
		empty_dialog.popup_centered()
		refresh_slots_ui()

func _on_delete_confirmed() -> void:
	if _pending_delete_slot < 0:
		return
	GameSave.delete_slot(_pending_delete_slot)
	refresh_slots_ui()

func _go_to_gameplay() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(gameplay_scene_path)

func refresh_slots_ui() -> void:
	var grid: GridContainer = $ScrollContainer/GridContainer
	for child in grid.get_children():
		if child.has_method("refresh"):
			child.refresh()

func _on_back_pressed() -> void:
	get_tree().paused = false
	queue_free()
