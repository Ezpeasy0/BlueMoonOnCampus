extends Button

@export var slot_id: int = 1
const DEFAULT_IMAGE := preload("res://sprites/save&load/no_data.png")

@onready var label_slot: Label = $PanelContainer/HBoxContainer/VBoxContainer/slot
@onready var label_date: Label = $PanelContainer/HBoxContainer/VBoxContainer/date
@onready var label_time: Label = $PanelContainer/HBoxContainer/VBoxContainer/time
@onready var texture_rect: TextureRect = $PanelContainer/HBoxContainer/TextureRect

func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	refresh()

func refresh() -> void:
	# Prefer preview if it exists
	var data: SaveResource = GameSave.load_slot_preview(slot_id)
	if data:
		update_ui_preview(data)
		return

	# If no preview, still show JSON info if the slot exists
	if GameSave.slot_exists(slot_id):
		var info := _read_slot_json_info(slot_id)
		update_ui_json(info)
	else:
		update_ui_empty()

func update_ui_preview(data: SaveResource) -> void:
	label_slot.text = data.slot_name
	label_date.text = data.date
	label_time.text = data.time
	texture_rect.texture = data.screenshot if data.screenshot else DEFAULT_IMAGE

func update_ui_json(info: Dictionary) -> void:
	label_slot.text = "Slot " + str(slot_id + 1)

	var ts := str(info.get("timestamp", ""))
	if ts != "":
		# leave it as-is; Godot timestamp string format varies by Time.get_datetime_string_from_system()
		label_date.text = ts
		label_time.text = ""
	else:
		label_date.text = "--/--/--"
		label_time.text = "--:--"

	texture_rect.texture = DEFAULT_IMAGE

func update_ui_empty() -> void:
	label_slot.text = "Empty Slot " + str(slot_id + 1)
	label_date.text = "--/--/--"
	label_time.text = "--:--"
	texture_rect.texture = DEFAULT_IMAGE

func _read_slot_json_info(id: int) -> Dictionary:
	var path := GameSave.get_slot_path(id)
	if not FileAccess.file_exists(path):
		return {}

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}

	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}

func _on_pressed() -> void:
	get_owner().slot_selected(slot_id)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		get_owner().request_delete(slot_id)
