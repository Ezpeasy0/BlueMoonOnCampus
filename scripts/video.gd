extends Panel

@export var resolution_option : OptionButton
@export var fullscreen_check : CheckBox
@export var borderless_check : CheckBox

func _ready():
	resolution_option.clear()
	var resolutions = [
		Vector2i(1920, 1080),
		Vector2i(1600, 900),
		Vector2i(1366, 768),
		Vector2i(1280, 720),
	]
	
	for res in resolutions:
		resolution_option.add_item("%dx%d" % [res.x, res.y])
		
	load_current_settings()
	
	resolution_option.item_selected.connect(_on_resolution_selected)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	borderless_check.toggled.connect(_on_borderless_toggled)

func load_current_settings():
	var mode = DisplayServer.window_get_mode()
	var is_fullscreen = mode == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_check.button_pressed = is_fullscreen
	
	if is_fullscreen:
		borderless_check.button_pressed = false
	else:
		if OS.is_debug_build():
			borderless_check.button_pressed = false
		else:
			borderless_check.button_pressed = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
	
	var window_size = DisplayServer.window_get_size()
	var found = false
	for i in range(resolution_option.item_count):
		var res_text = resolution_option.get_item_text(i)
		var parts = res_text.split("x")
		if parts.size() == 2:
			var w = int(parts[0])
			var h = int(parts[1])
			if abs(window_size.x - w) <= 2 and abs(window_size.y - h) <= 2:
				resolution_option.select(i)
				found = true
				break
	if not found:
		resolution_option.select(0)

func _on_resolution_selected(index: int):
	var text = resolution_option.get_item_text(index)
	var parts = text.split("x")
	if parts.size() == 2:
		var target_size = Vector2i(int(parts[0]), int(parts[1]))
		
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			fullscreen_check.button_pressed = false
		
		DisplayServer.window_set_size(target_size)
		
		var screen = DisplayServer.window_get_current_screen()
		var screen_rect = DisplayServer.screen_get_usable_rect(screen)
		DisplayServer.window_set_position(screen_rect.position + (screen_rect.size - target_size) / 2)

func _on_fullscreen_toggled(enabled: bool):
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		borderless_check.button_pressed = false
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_on_resolution_selected(resolution_option.selected)

func _on_borderless_toggled(enabled: bool):
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, enabled)
