extends Area2D

@export var target_slot_name: String = "Slot1"
@export var food_id: String = ""

var dragging: bool = false
var offset: Vector2 = Vector2.ZERO
var current_slot: Area2D = null
var home_position: Vector2 = Vector2.ZERO

@onready var pick_up_audio: AudioStreamPlayer = get_parent().get_node("PickUpSound")
@onready var drop_audio: AudioStreamPlayer = get_parent().get_node("DropSound")

func _ready() -> void:
	input_pickable = true
	home_position = global_position

func _process(_delta: float) -> void:
	if dragging:
		global_position = get_global_mouse_position() - offset

func _input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			offset = get_global_mouse_position() - global_position

			if pick_up_audio:
				pick_up_audio.play()

			# If this food is currently in a slot, free that slot first
			if current_slot != null:
				current_slot.is_occupied = false
				current_slot.occupied_food_id = ""
				current_slot = null

			z_index = 100
			get_viewport().set_input_as_handled()

		else:
			if dragging:
				dragging = false
				z_index = 1
				check_drop_zone()
				get_viewport().set_input_as_handled()

func check_drop_zone() -> void:
	var areas := get_overlapping_areas()
	var target_slot: Area2D = null

	for area in areas:
		if "Slot" in area.name and area.name == target_slot_name:
			if not area.is_occupied:
				target_slot = area
				break

	if target_slot != null:
		# Snap into correct slot
		global_position = target_slot.global_position
		target_slot.is_occupied = true
		target_slot.occupied_food_id = food_id
		current_slot = target_slot

		if drop_audio:
			drop_audio.play()
	else:
		# If not dropped into a valid empty slot, go back to menu/home position
		global_position = home_position
		current_slot = null
