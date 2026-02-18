extends GridContainer

func _ready():
	await get_tree().process_frame
	
	_setup_grid_slots()

func _setup_grid_slots():
	var main_node = get_parent().get_parent() # Grid -> Scroll -> SaveSlot
	
	var slot_number = 1
	for child in get_children():
		if child is Button:
			if not child.pressed.is_connected(main_node._on_slot_button_pressed):
				child.pressed.connect(main_node._on_slot_button_pressed.bind(slot_number))
			
			if not child.mouse_entered.is_connected(main_node._play_hover):
				child.mouse_entered.connect(main_node._play_hover)

			_disable_children_mouse(child)
			
			slot_number += 1

func _disable_children_mouse(node: Node):
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_disable_children_mouse(child)
