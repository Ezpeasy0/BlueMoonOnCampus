extends Button

@export var slot_id: int = 4
const DEFAULT_IMAGE = preload("res://background/No data.png")

func update_ui(data: SaveResource):
	var label_slot = $PanelContainer/HBoxContainer/VBoxContainer/slot
	var label_date = $PanelContainer/HBoxContainer/VBoxContainer/date
	var label_time = $PanelContainer/HBoxContainer/VBoxContainer/time
	var texture_rect = $PanelContainer/HBoxContainer/TextureRect 
	
	if data:
		label_slot.text = data.slot_name
		label_date.text = data.date
		label_time.text = data.time

		if data.screenshot:
			texture_rect.texture = data.screenshot
		else:
			texture_rect.texture = DEFAULT_IMAGE
	else:
		label_slot.text = "Empty Slot " + str(slot_id + 1)
		label_date.text = "--/--/--"
		label_time.text = "--:--"
		texture_rect.texture = DEFAULT_IMAGE

func _on_pressed():
	get_owner().slot_selected(slot_id)
