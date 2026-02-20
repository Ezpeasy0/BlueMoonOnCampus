extends Button

@export var slot_id: int = 7
const DEFAULT_IMAGE := preload("res://sprites/no_data.png")

@onready var label_slot: Label = $PanelContainer/HBoxContainer/VBoxContainer/slot
@onready var label_date: Label = $PanelContainer/HBoxContainer/VBoxContainer/date
@onready var label_time: Label = $PanelContainer/HBoxContainer/VBoxContainer/time
@onready var texture_rect: TextureRect = $PanelContainer/HBoxContainer/TextureRect

func _ready() -> void:
	# Makes sure left-click works even if the signal wasn't connected in editor
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	refresh()

func refresh() -> void:
	var data: SaveResource = GameSave.load_slot_preview(slot_id)
	update_ui(data)

func update_ui(data: SaveResource) -> void:
	if data:
		label_slot.text = data.slot_name
		label_date.text = data.date
		label_time.text = data.time
		texture_rect.texture = data.screenshot if data.screenshot else DEFAULT_IMAGE
	else:
		label_slot.text = "Empty Slot " + str(slot_id + 1)
		label_date.text = "--/--/--"
		label_time.text = "--:--"
		texture_rect.texture = DEFAULT_IMAGE

func _on_pressed() -> void:
	get_owner().slot_selected(slot_id)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		get_owner().request_delete(slot_id)
