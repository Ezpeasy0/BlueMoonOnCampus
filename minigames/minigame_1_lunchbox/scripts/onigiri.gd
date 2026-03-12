extends Area2D

# --- ส่วนสำคัญ: เพิ่ม @export เพื่อให้เลือก Slot ใน Inspector ได้ ---
@export var target_slot_name: String = "Slot1" 

var dragging = false
var offset = Vector2.ZERO
var current_slot = null         
var starting_position = Vector2.ZERO 

# อ้างอิงโหนดเสียง (อิงตามชื่อในรูป image_4e59ed.png)
@onready var pick_up_audio = $"../PickUpSound"
@onready var drop_audio = $"../DropSound"
	
func _process(_delta):
	if dragging:
		global_position = get_global_mouse_position() - offset

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			starting_position = global_position 
			offset = get_global_mouse_position() - global_position
			
			# เล่นเสียงตอนคีบ
			if pick_up_audio: pick_up_audio.play()
			
			if current_slot != null:
				current_slot.is_occupied = false
				current_slot = null
			z_index = 10
		else:
			if dragging:
				dragging = false
				z_index = 1 
				check_drop_zone()

func check_drop_zone():
	var areas = get_overlapping_areas()
	var target_slot = null
	var is_hovering_invalid_slot = false 

	for area in areas:
		if "Slot" in area.name:
			# ใช้ชื่อจาก Inspector ในการเช็ก
			if area.name == target_slot_name:
				if area.get("is_occupied") == false:
					target_slot = area
					break
			else:
				is_hovering_invalid_slot = true

	if target_slot != null:
		global_position = target_slot.global_position
		target_slot.is_occupied = true
		current_slot = target_slot
		# เล่นเสียงตอนวางสำเร็จ
		if drop_audio: drop_audio.play()
	elif is_hovering_invalid_slot or is_on_any_occupied_slot(areas, target_slot_name):
		global_position = starting_position
		re_occupy_if_needed()
	else:
		current_slot = null 

func is_on_any_occupied_slot(areas, slot_name):
	for area in areas:
		if area.name == slot_name and area.get("is_occupied") == true:
			return true
	return false

func re_occupy_if_needed():
	var areas = get_overlapping_areas()
	for area in areas:
		if area.name == target_slot_name and area.get("is_occupied") == false:
			area.is_occupied = true
			current_slot = area
			return
