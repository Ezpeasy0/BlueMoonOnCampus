extends Control

const BG_DIR: String = "res://sprites/scene/"
const SPRITE_DIR: String = "res://sprites/characters/"
const FULLSCREEN_BGS: Array[String] = ["pete.png"]

const BGM_PATH_DIR: String = "res://sounds/bgm/"
const SFX_PATH_DIR: String = "res://sounds/sfx/"

@onready var bg: TextureRect = %BG
@onready var character: TextureRect = %Character
@onready var name_label: Label = %NameLabel
@onready var dialogue_label: RichTextLabel = %DialogueLabel
@onready var choices_box: VBoxContainer = %ChoicesBox
@onready var bg_fade: ColorRect = %BGFade
@onready var btn_options: Button = $HBoxContainer/options
@onready var options_menu: Panel = $Options
@onready var exit_confirm: ConfirmationDialog = $ExitConfirm

@export var sfx_click: AudioStreamPlayer
@export var sfx_hover: AudioStreamPlayer
@onready var bgm_player: AudioStreamPlayer = $BGM
@onready var sfx_dialogue: AudioStreamPlayer = $SFX

@export var sfx_text_blip: AudioStreamPlayer
@export var blip_volume_db: float = -10.0

@export_group("Options Sub-Panels")
@export var video_panel: Panel
@export var audio_panel: Panel
@export var back_button: Button

@export_group("Save/Load Scenes")
@export var save_scene: PackedScene
@export var load_scene: PackedScene

var story_lines: Array = []
var id_to_index: Dictionary = {}

var index: int = 0
var stats: Dictionary = {"INT": 0, "CHA": 0}

var _busy: bool = false
var _typing: bool = false
var _skip_typing: bool = false

var _current_bg: String = ""
var _current_sprite: String = ""
var _current_bgm: String = ""

@export var type_speed_seconds: float = 0.02
@export var blip_every_chars: int = 2


func _ready() -> void:
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	bg_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_hide_all_in_game_menus()

	_auto_setup_all_buttons(self)

	if btn_options and not btn_options.pressed.is_connected(_on_options_pressed):
		btn_options.pressed.connect(_on_options_pressed)

	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

	if options_menu:
		if options_menu.has_signal("video_requested") and not options_menu.video_requested.is_connected(_on_video_setting):
			options_menu.video_requested.connect(_on_video_setting)
		if options_menu.has_signal("audio_requested") and not options_menu.audio_requested.is_connected(_on_audio_setting):
			options_menu.audio_requested.connect(_on_audio_setting)

	if exit_confirm:
		exit_confirm.visible = false
		exit_confirm.process_mode = Node.PROCESS_MODE_ALWAYS
		if not exit_confirm.confirmed.is_connected(_on_exit_confirmed):
			exit_confirm.confirmed.connect(_on_exit_confirmed)
		if not exit_confirm.canceled.is_connected(_on_exit_canceled):
			exit_confirm.canceled.connect(_on_exit_canceled)

	if sfx_text_blip:
		sfx_text_blip.volume_db = blip_volume_db

	var chapter_node: Node = preload("res://data/chapter1.gd").new()
	story_lines = chapter_node.lines

	for i in range(story_lines.size()):
		var line_any: Variant = story_lines[i]
		if line_any is Dictionary:
			var line_dict: Dictionary = line_any
			if line_dict.has("id"):
				id_to_index[line_dict["id"]] = i

	_restore_from_gamesave()
	await _apply_restored_visuals()

	choices_box.visible = false
	_show_current()


func _apply_restored_visuals() -> void:
	if _current_bg != "":
		await _set_background(_current_bg)

	if _is_fullscreen_bg(_current_bg):
		character.visible = false
	else:
		if _current_sprite != "":
			await _set_character_sprite(_current_sprite)

	if _current_bgm != "":
		_play_bgm(_current_bgm)


func _is_fullscreen_bg(bg_value: String) -> bool:
	if bg_value == "":
		return false
	var file := bg_value.get_file()
	return FULLSCREEN_BGS.has(file)


func _restore_from_gamesave() -> void:
	if GameSave.current_slot < 0:
		return
	if not (GameSave.state is Dictionary):
		return

	if GameSave.state.has("line_index"):
		index = int(GameSave.state["line_index"])

	if GameSave.state.has("stats") and GameSave.state["stats"] is Dictionary:
		stats = (GameSave.state["stats"] as Dictionary).duplicate(true)

	if GameSave.state.has("bg"):
		_current_bg = str(GameSave.state["bg"])
	if GameSave.state.has("sprite"):
		_current_sprite = str(GameSave.state["sprite"])
	if GameSave.state.has("bgm"):
		_current_bgm = str(GameSave.state["bgm"])


func _sync_state_to_gamesave() -> void:
	if not (GameSave.state is Dictionary):
		GameSave.state = {}

	GameSave.state["chapter"] = 1
	GameSave.state["scene"] = 1
	GameSave.state["line_index"] = index
	GameSave.state["stats"] = stats.duplicate(true)
	GameSave.state["bg"] = _current_bg
	GameSave.state["sprite"] = _current_sprite
	GameSave.state["bgm"] = _current_bgm


func _save_now() -> void:
	if GameSave.current_slot >= 0:
		_sync_state_to_gamesave()
		GameSave.save_game(GameSave.current_slot)


func _auto_setup_all_buttons(node: Node) -> void:
	if node is Button:
		_setup_button_sounds(node)
	for child in node.get_children():
		_auto_setup_all_buttons(child)


func _setup_button_sounds(btn: Button) -> void:
	if not btn.mouse_entered.is_connected(_on_button_hover):
		btn.mouse_entered.connect(_on_button_hover)
	if not btn.pressed.is_connected(_on_button_click):
		btn.pressed.connect(_on_button_click)


func _on_button_hover() -> void:
	if sfx_hover:
		sfx_hover.play()


func _on_button_click() -> void:
	if sfx_click:
		sfx_click.play()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		print("[PANIC UNLOCK]")
		if is_inside_tree():
			get_tree().paused = false
		_busy = false
		_hide_all_in_game_menus()
		return

	if is_inside_tree() and get_tree().paused:
		return

	if _busy:
		return

	var is_any_menu_open: bool = (options_menu and options_menu.visible) \
		or (video_panel and video_panel.visible) \
		or (audio_panel and audio_panel.visible) \
		or (exit_confirm and exit_confirm.visible)
	if is_any_menu_open:
		return

	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null:

		if hovered is Button or hovered is OptionButton or hovered is CheckBox or hovered is Slider:
			return

	if _typing:
		_skip_typing = true
		return

	if choices_box.visible:
		return

	_advance()

func _on_options_pressed() -> void:
	_block_dialogue_input_for_menu_open()
	get_tree().paused = true

	if options_menu:
		options_menu.visible = true
	if back_button:
		back_button.visible = true

	if options_menu and options_menu.has_method("init_settings"):
		options_menu.init_settings()


func _on_video_setting() -> void:
	if video_panel:
		video_panel.visible = true
		if options_menu: options_menu.visible = false
		if back_button: back_button.visible = true


func _on_audio_setting() -> void:
	if audio_panel:
		audio_panel.visible = true
		if options_menu: options_menu.visible = false
		if back_button: back_button.visible = true


func _on_back_pressed() -> void:
	# If we are inside sub-panels, go back to Options menu (still paused)
	if (video_panel and video_panel.visible) or (audio_panel and audio_panel.visible):
		if video_panel: video_panel.visible = false
		if audio_panel: audio_panel.visible = false
		if options_menu: options_menu.visible = true
		if back_button: back_button.visible = true
		return

	# Close Options fully
	_hide_all_in_game_menus()
	get_tree().paused = false
	_busy = false


func _advance() -> void:
	index += 1
	_show_current()
	_save_now()


func _show_current() -> void:
	if index >= story_lines.size():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	var any_line: Variant = story_lines[index]
	if not (any_line is Dictionary):
		index += 1
		_show_current()
		return

	var line: Dictionary = any_line

	if line.has("bgm"):
		_play_bgm(str(line["bgm"]))
	if line.has("sfx"):
		_play_sfx(str(line["sfx"]))

	if str(line.get("type", "line")) == "choice":
		_show_choices(line.get("choices", []))
		return

	choices_box.visible = false

	if line.has("bg"):
		var new_bg: String = str(line["bg"])
		if new_bg.strip_edges() != "" and new_bg != _current_bg:
			_current_bg = new_bg
			await _set_background(new_bg)

	if _is_fullscreen_bg(_current_bg):
		_current_sprite = ""
		character.visible = false
	else:
		if line.has("sprite"):
			var new_sprite: String = str(line["sprite"])
			if new_sprite.strip_edges() == "":
				_current_sprite = ""
				character.visible = false
			elif new_sprite != _current_sprite:
				_current_sprite = new_sprite
				await _set_character_sprite(new_sprite)

	var who: String = str(line.get("name", ""))
	var txt: String = str(line.get("text", ""))
	if bool(line.get("thought", false)):
		txt = "(" + txt + ")"

	name_label.text = who
	if who.strip_edges() == "":
		%NameBox.modulate.a = 0.0
	else:
		%NameBox.modulate.a = 1.0

	await _type_text(txt)
	_sync_state_to_gamesave()

	if line.has("skip_to"):
		var target_id := str(line["skip_to"])
		if target_id != "" and id_to_index.has(target_id):
			index = int(id_to_index[target_id])
			_show_current()
			return


func _type_text(full_text: String) -> void:
	_typing = true
	_skip_typing = false
	dialogue_label.text = ""

	if sfx_text_blip and sfx_text_blip.playing:
		sfx_text_blip.stop()

	if full_text == "":
		_typing = false
		return

	var char_count: int = 0
	for i in range(full_text.length()):
		if _skip_typing:
			break

		dialogue_label.text += full_text[i]
		char_count += 1

		if sfx_text_blip and blip_every_chars > 0 and (char_count % blip_every_chars == 0):
			if sfx_text_blip.playing:
				sfx_text_blip.stop()
			sfx_text_blip.play()

		await get_tree().create_timer(type_speed_seconds).timeout

	dialogue_label.text = full_text

	if sfx_text_blip and sfx_text_blip.playing:
		sfx_text_blip.stop()

	_typing = false


func _play_bgm(filename: String) -> void:
	if filename == "" or filename == "null":
		if bgm_player:
			bgm_player.stop()
		_current_bgm = ""
		return
	if filename == _current_bgm:
		return

	var full_path: String = BGM_PATH_DIR + filename
	if not FileAccess.file_exists(full_path):
		return

	var stream: Resource = load(full_path)
	if stream and bgm_player:
		bgm_player.stream = stream
		bgm_player.play()
		_current_bgm = filename


func _play_sfx(filename: String) -> void:
	if filename == "" or filename == "null":
		if sfx_dialogue:
			sfx_dialogue.stop()
		return

	var full_path: String = SFX_PATH_DIR + filename
	if not FileAccess.file_exists(full_path):
		return

	var stream: Resource = load(full_path)
	if stream and sfx_dialogue:
		sfx_dialogue.stream = stream
		sfx_dialogue.play()


func _show_choices(options_list: Array) -> void:
	choices_box.visible = true
	for c in choices_box.get_children():
		c.queue_free()

	for opt_any in options_list:
		if not (opt_any is Dictionary):
			continue
		var opt: Dictionary = opt_any

		var b: Button = Button.new()
		b.text = str(opt.get("label", ""))
		_setup_button_sounds(b)
		b.pressed.connect(func() -> void: _on_choice(opt))
		choices_box.add_child(b)


func _on_choice(opt: Dictionary) -> void:
	choices_box.visible = false

	var effects_any: Variant = opt.get("effects", {})
	var effects: Dictionary = effects_any if effects_any is Dictionary else {}

	if not (stats is Dictionary):
		stats = {"INT": 0, "CHA": 0}
	if not stats.has("INT"): stats["INT"] = 0
	if not stats.has("CHA"): stats["CHA"] = 0

	for k in effects.keys():
		stats[k] = int(stats.get(k, 0)) + int(effects[k])

	print("[STATS] INT =", stats.get("INT", 0), " | CHA =", stats.get("CHA", 0))

	var say_text: String = str(opt.get("say", "")).strip_edges()
	if say_text != "":
		name_label.text = "เมฆ"
		%NameBox.modulate.a = 1.0
		await _type_text(say_text)

	var target_id: String = str(opt.get("next", ""))
	if target_id != "" and id_to_index.has(target_id):
		index = int(id_to_index[target_id])
	else:
		index += 1

	_sync_state_to_gamesave()
	_save_now()
	_show_current()


func _resolve_path(root: String, value: String) -> String:
	if value.strip_edges() == "":
		return ""
	if value.begins_with("res://"):
		return value

	var found := _search_recursive(root, value)
	if found != "":
		return found

	var direct := root + value
	if FileAccess.file_exists(direct):
		return direct

	return ""


func _search_recursive(path: String, target_file: String) -> String:
	var dir := DirAccess.open(path)
	if not dir:
		return ""

	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "":
			break

		if dir.current_is_dir():
			var found := _search_recursive(path + file_name + "/", target_file)
			if found != "":
				dir.list_dir_end()
				return found
		else:
			if file_name == target_file:
				dir.list_dir_end()
				return path + file_name

	dir.list_dir_end()
	return ""


func _set_background(value: String) -> void:
	var full_path := _resolve_path(BG_DIR, value)
	if full_path == "":
		print("[BG] Not found:", value, " (searched under ", BG_DIR, ")")
		return

	var tex := load(full_path) as Texture2D
	if tex == null:
		print("[BG] Failed to load:", full_path)
		return

	_busy = true
	await _fade_rect_alpha(bg_fade, 0.0, 1.0, 0.25)
	bg.texture = tex
	await _fade_rect_alpha(bg_fade, 1.0, 0.0, 0.25)
	_busy = false


func _set_character_sprite(value: String) -> void:
	var full_path := _resolve_path(SPRITE_DIR, value)
	if full_path == "":
		character.visible = false
		return

	var tex := load(full_path) as Texture2D
	if tex == null:
		character.visible = false
		return

	_busy = true
	character.visible = true
	await _fade_control_alpha(character, character.modulate.a, 0.0, 0.15)
	character.texture = tex
	await _fade_control_alpha(character, 0.0, 1.0, 0.15)
	_busy = false


func _fade_rect_alpha(rect: ColorRect, from_a: float, to_a: float, duration: float) -> void:
	rect.visible = true
	var t: float = 0.0
	while t < duration:
		t += get_process_delta_time()
		rect.color.a = lerp(from_a, to_a, clamp(t / duration, 0.0, 1.0))
		await get_tree().process_frame
	rect.color.a = to_a
	if to_a <= 0.001:
		rect.visible = false


func _fade_control_alpha(ctrl: CanvasItem, from_a: float, to_a: float, duration: float) -> void:
	var t: float = 0.0
	while t < duration:
		t += get_process_delta_time()
		ctrl.modulate.a = lerp(from_a, to_a, clamp(t / duration, 0.0, 1.0))
		await get_tree().process_frame
	ctrl.modulate.a = to_a


func _on_quit_pressed() -> void:
	if exit_confirm:
		_block_dialogue_input_for_menu_open()
		get_tree().paused = true
		exit_confirm.popup_centered()


func _on_exit_confirmed() -> void:
	get_tree().paused = false
	_busy = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_exit_canceled() -> void:
	get_tree().paused = false
	_busy = false
	_hide_all_in_game_menus()


func _on_save_pressed() -> void:
	_block_dialogue_input_for_menu_open()
	_hide_all_in_game_menus()

	_sync_state_to_gamesave()
	_save_now()

	var tree := get_tree()
	tree.paused = true

	if save_scene:
		var save_menu: Node = save_scene.instantiate()
		save_menu.set("mode", 2)

		save_menu.tree_exited.connect(func():

			if is_instance_valid(tree):
				tree.paused = false
			_busy = false
		)

		add_child(save_menu)
		move_child(save_menu, -1)
	else:
		tree.paused = false
		_busy = false


func _on_load_pressed() -> void:
	_block_dialogue_input_for_menu_open()
	_hide_all_in_game_menus()

	var tree := get_tree()
	tree.paused = true

	if load_scene:
		var load_menu: Node = load_scene.instantiate()

		load_menu.tree_exited.connect(func():
			if is_instance_valid(tree):
				tree.paused = false
			_busy = false
		)

		add_child(load_menu)
		move_child(load_menu, -1)
	else:
		tree.paused = false
		_busy = false


func _hide_all_in_game_menus() -> void:
	if options_menu: options_menu.visible = false
	if video_panel: video_panel.visible = false
	if audio_panel: audio_panel.visible = false
	if back_button: back_button.visible = false
	if exit_confirm: exit_confirm.visible = false


func _block_dialogue_input_for_menu_open() -> void:
	_busy = true
	if _typing:
		_skip_typing = true
