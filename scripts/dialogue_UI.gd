extends Control

@onready var bg: TextureRect = %BG
@onready var character: TextureRect = %Character
@onready var name_label: Label = %NameLabel
@onready var name_box: PanelContainer = %NameBox
@onready var dialogue_label: RichTextLabel = %DialogueLabel

@onready var choices_container: Control = %ChoicesPanel 
@onready var choices_box: VBoxContainer = %ChoicesBox

@onready var bg_fade: ColorRect = %BGFade
@onready var btn_options: Button = $HBoxContainer/options

@onready var btn_save: Button = $HBoxContainer/save
@onready var btn_load: Button = $HBoxContainer/load

@onready var options_menu: Panel = $Options
@onready var exit_confirm: ConfirmationDialog = $ExitConfirm

@export var sfx_click: AudioStreamPlayer
@export var sfx_hover: AudioStreamPlayer
@onready var bgm_player: AudioStreamPlayer = $BGM
@onready var sfx_dialogue: AudioStreamPlayer = $SFX
@onready var master_sfx: AudioStreamPlayer = $MasterSFX

@export var sfx_text_blip: AudioStreamPlayer
@export var blip_volume_db: float = -10.0

@export_group("Options Sub-Panels")
@export var video_panel: Panel
@export var audio_panel: Panel
@export var back_button: Button

@export var btn_video_settings: Button
@export var btn_audio_settings: Button

@export_group("Save/Load Scenes")
@export var save_scene: PackedScene
@export var load_scene: PackedScene

@onready var stat_notify: Label = %StatNotifyLabel
@onready var int_label: Label = %INTLabel
@onready var cha_label: Label = %CHALabel

@onready var fast_forward: Button = $HBoxContainer/fast_forward
var _is_fast_forwarding: bool = false
@onready var normal_type_speed: float = type_speed_seconds

var _busy: bool = false
var _typing: bool = false
var _skip_typing: bool = false

@export var type_speed_seconds: float = 0.02
@export var blip_every_chars: int = 2
@export var default_box_color: Color = Color("#0d5cff")

var character_box_colors: Dictionary = {
	"เมฆ": Color("#5AB9E1"),    
	"ฝน": Color("#9FA8DA"),   
	"สารวัตรธนา": Color("#006400"), 
	"เต้": Color("#B8860B"),
	"บอส": Color("#BDB76B"),
	"พีท": Color("#0000FF"),
}

const DialogueLogicScript = preload("res://scripts/dialogue_logic.gd")
var logic: DialogueLogicScript

func _ready() -> void:
	logic = DialogueLogicScript.new()
	add_child(logic)
	
	logic.display_minigame_gains_requested.connect(_display_minigame_gains)
	logic.name_box_update_requested.connect(_update_name_box)

	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	bg_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_hide_all_in_game_menus()
	_auto_setup_all_buttons(self)

	if btn_options and not btn_options.pressed.is_connected(_on_options_pressed):
		btn_options.pressed.connect(_on_options_pressed)
		
	if btn_save and not btn_save.pressed.is_connected(_on_save_pressed):
		btn_save.pressed.connect(_on_save_pressed)
		
	if btn_load and not btn_load.pressed.is_connected(_on_load_pressed):
		btn_load.pressed.connect(_on_load_pressed)

	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

	if options_menu:
		if options_menu.has_signal("video_requested") and not options_menu.video_requested.is_connected(_on_video_setting):
			options_menu.video_requested.connect(_on_video_setting)
		if options_menu.has_signal("audio_requested") and not options_menu.audio_requested.is_connected(_on_audio_setting):
			options_menu.audio_requested.connect(_on_audio_setting)
	# ---------------------------------------------------------

	if exit_confirm:
		exit_confirm.visible = false
		exit_confirm.process_mode = Node.PROCESS_MODE_ALWAYS
		if not exit_confirm.confirmed.is_connected(_on_exit_confirmed):
			exit_confirm.confirmed.connect(_on_exit_confirmed)
		if not exit_confirm.canceled.is_connected(_on_exit_canceled):
			exit_confirm.canceled.connect(_on_exit_canceled)

	if sfx_text_blip:
		sfx_text_blip.volume_db = blip_volume_db
		
	await _load_current_chapter() 

func _load_current_chapter() -> void:
	logic.load_chapter_data()
	logic.restore_from_gamesave()
	_update_stats_display()

	await _apply_restored_visuals()
	choices_container.visible = false
	await _show_current()

func _apply_restored_visuals() -> void:
	if logic.current_bg != "":
		await _set_background(logic.current_bg)

	if logic.is_fullscreen_bg(logic.current_bg):
		character.visible = false
	else:
		if logic.current_sprite != "":
			await _set_character_sprite(logic.current_sprite)

	if logic.current_bgm != "":
		var temp_bgm = logic.current_bgm
		logic.current_bgm = "" 
		_play_bgm(temp_bgm)

	if logic.current_master_sfx != "":
		var temp_master = logic.current_master_sfx
		logic.current_master_sfx = "" 
		_play_master_sfx(temp_master)

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
	if sfx_hover: sfx_hover.play()

func _on_button_click() -> void:
	if sfx_click: sfx_click.play()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		if is_inside_tree():
			get_tree().paused = false
		_busy = false
		_hide_all_in_game_menus()
		return

	if is_inside_tree() and get_tree().paused: return
	if _busy: return

	var is_any_menu_open: bool = (options_menu and options_menu.visible) \
		or (video_panel and video_panel.visible) \
		or (audio_panel and audio_panel.visible) \
		or (exit_confirm and exit_confirm.visible)
	if is_any_menu_open:
		return

	if not (event is InputEventMouseButton): return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed: return

	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null:
		if hovered is Button or hovered is OptionButton or hovered is CheckBox or hovered is Slider:
			return

	if _typing:
		_skip_typing = true
		return

	if choices_container.visible:
		return

	_advance()

func _on_options_pressed() -> void:
	_block_dialogue_input_for_menu_open()
	get_tree().paused = true
	if options_menu: options_menu.visible = true
	if back_button: back_button.visible = true
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
	if (video_panel and video_panel.visible) or (audio_panel and audio_panel.visible):
		if video_panel: video_panel.visible = false
		if audio_panel: audio_panel.visible = false
		if options_menu: options_menu.visible = true
		if back_button: back_button.visible = true
		return
	
	_hide_all_in_game_menus()
	get_tree().paused = false
	_busy = false

func _advance() -> void:
	if logic.index >= logic.story_lines.size(): return
	
	if logic.waiting_for_choice_next:
		logic.waiting_for_choice_next = false
		await _show_current()
		return
	
	var current_line = logic.get_current_line()

	if current_line is Dictionary and current_line.get("type") == "choice":
		return 

	if current_line is Dictionary and current_line.has("next"):
		var target_id = str(current_line["next"])
		if logic.id_to_index.has(target_id):
			logic.index = logic.id_to_index[target_id] 
			await _show_current()
			return 

	logic.index += 1
	await _show_current()

func _show_current() -> void:
	if logic.index >= logic.story_lines.size():
		logic.go_to_next_chapter_or_end()
		return

	var any_line: Variant = logic.get_current_line()
	if not (any_line is Dictionary):
		logic.index += 1
		await _show_current()
		return

	var line: Dictionary = any_line

	if line.has("bgm"): _play_bgm(str(line["bgm"]))
	if line.has("sfx"): _play_sfx(str(line["sfx"]))
	if line.has("master_sfx"): _play_master_sfx(str(line["master_sfx"]))

	var line_type := str(line.get("type", "line"))

	if line_type == "choice":
		type_speed_seconds = normal_type_speed
		_show_choices(line.get("choices", []))
		return

	if line_type == "minigame":
		type_speed_seconds = normal_type_speed
		var minigame_id := str(line.get("minigame_id", ""))
		var next_id := str(line.get("next", ""))
		_busy = true
		logic.start_minigame(minigame_id, next_id)
		return

	if line_type == "conditional":
		if logic.advance_conditional(line):
			await _show_current()
		return

	choices_container.visible = false

	if line.has("bg"):
		var new_bg: String = str(line["bg"])
		if new_bg.strip_edges() != "" and new_bg != logic.current_bg:
			logic.current_bg = new_bg
			await _set_background(new_bg)

	if logic.is_fullscreen_bg(logic.current_bg):
		logic.current_sprite = ""
		character.visible = false
	else:
		if line.has("sprite"):
			var new_sprite: String = str(line["sprite"])
			if new_sprite.strip_edges() == "":
				logic.current_sprite = ""
				character.visible = false
			elif new_sprite != logic.current_sprite:
				logic.current_sprite = new_sprite
				await _set_character_sprite(new_sprite)

	var who: String = str(line.get("name", ""))
	_update_name_box(who)
	var txt: String = str(line.get("text", ""))
	if bool(line.get("thought", false)):
		txt = "(" + txt + ")"

	name_label.text = who
	if who.strip_edges() == "":
		%NameBox.modulate.a = 0.0
	else:
		%NameBox.modulate.a = 1.0

	await _type_text(txt)
	logic.sync_state_to_gamesave()
	
	if line.has("skip_to"):
		var target_id := str(line["skip_to"])
		if target_id != "" and logic.id_to_index.has(target_id):
			logic.index = int(logic.id_to_index[target_id])
			await _show_current()
			return
	
	if _is_fast_forwarding and not choices_container.visible:
		await get_tree().create_timer(0.1).timeout
		if not is_inside_tree(): return
		while get_tree().paused:
			await get_tree().process_frame
		if _is_fast_forwarding:
			_advance()

func _show_stat_popup(stat_name: String, amount: int) -> void:
	if not stat_notify: return 
	
	var sign_str = "+" if amount >= 0 else "" 
	stat_notify.text = "%s%d %s" % [sign_str, amount, stat_name]
	
	if stat_name == "INT":
		stat_notify.add_theme_color_override("font_color", Color("1f676d"))
	elif stat_name == "CHA":
		stat_notify.add_theme_color_override("font_color", Color("a1224e"))
	
	stat_notify.visible = true
	stat_notify.global_position = Vector2(540,300)
	stat_notify.modulate.a = 1.0
	
	var tween = create_tween()
	tween.tween_property(stat_notify, "global_position:y", stat_notify.global_position.y - 60, 0.4)\
	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.6)
	tween.tween_property(stat_notify, "modulate:a", 0.0, 0.5)
	
	await tween.finished

func _display_minigame_gains(gains: Dictionary) -> void:
	for stat_name in gains.keys():
		var amount = int(gains[stat_name])
		await _show_stat_popup(stat_name, amount)
	
func _update_stats_display() -> void:
	var current_int = logic.stats.get("INT", 0)
	var current_cha = logic.stats.get("CHA", 0)
	int_label.text = "INT: %d" % current_int
	cha_label.text = "CHA: %d" % current_cha
	
func _update_name_box(who: String) -> void:
	who = who.strip_edges()
	name_label.text = who
	
	if who == "":
		name_box.modulate.a = 0.0 
	else:
		name_box.modulate.a = 1.0 
		if character_box_colors.has(who):
			name_box.self_modulate = character_box_colors[who]
		else:
			name_box.self_modulate = default_box_color

func _type_text(full_text: String) -> void:
	_typing = true
	_skip_typing = false
	dialogue_label.text = ""

	if sfx_text_blip and sfx_text_blip.playing: sfx_text_blip.stop()

	if full_text == "":
		_typing = false
		return

	if _is_fast_forwarding:
		dialogue_label.text = full_text
		_typing = false
		return

	var char_count: int = 0
	for i in range(full_text.length()):
		if _skip_typing: break

		dialogue_label.text += full_text[i]
		char_count += 1

		if sfx_text_blip and blip_every_chars > 0 and (char_count % blip_every_chars == 0):
			if sfx_text_blip.playing: sfx_text_blip.stop()
			sfx_text_blip.play()

		await get_tree().create_timer(type_speed_seconds).timeout

	dialogue_label.text = full_text
	if sfx_text_blip and sfx_text_blip.playing: sfx_text_blip.stop()
	_typing = false

func _play_bgm(filename: String) -> void:
	if filename == "" or filename == "null":
		if bgm_player: bgm_player.stop()
		logic.current_bgm = ""
		return
	if filename == logic.current_bgm: return

	var full_path: String = logic.guess_audio_path(logic.BGM_PATH_DIR, filename)
	if full_path == "":
		return

	var stream: Resource = load(full_path)
	if stream and bgm_player:
		if stream is AudioStreamMP3: stream.loop = true
		elif stream is AudioStreamWAV: stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		elif stream is AudioStreamOggVorbis: stream.loop = true
		
		bgm_player.stream = stream
		bgm_player.play()
		logic.current_bgm = filename

func _play_sfx(filename: String) -> void:
	if filename == "" or filename == "null":
		if sfx_dialogue: sfx_dialogue.stop()
		return
	var full_path: String = logic.guess_audio_path(logic.SFX_PATH_DIR, filename)
	if full_path == "":
		return

	var stream: Resource = load(full_path)
	if stream and sfx_dialogue:
		sfx_dialogue.stream = stream
		sfx_dialogue.play()

func _play_master_sfx(filename: String) -> void:
	if filename == "" or filename == "null":
		if master_sfx: master_sfx.stop()
		logic.current_master_sfx = ""
		return
	if filename == logic.current_master_sfx: return

	var full_path: String = logic.guess_audio_path(logic.MasterSFX_PATH_DIR, filename)
	if full_path == "":
		return

	var stream: Resource = load(full_path)
	if stream and master_sfx:
		if stream is AudioStreamMP3: stream.loop = true
		elif stream is AudioStreamWAV: stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		elif stream is AudioStreamOggVorbis: stream.loop = true
			
		master_sfx.stream = stream
		master_sfx.play()
		logic.current_master_sfx = filename
	
func _show_choices(options_list: Array) -> void:
	choices_container.visible = true

	for c in choices_box.get_children():
		c.queue_free()

	var my_style = load("res://sprites/choices/MyButtonStyle.tres")
	var my_style_hover = load("res://sprites/choices/MyButtonStyle_Hover.tres")
	var my_style_disabled = my_style.duplicate()
	var btn_font = load("res://fonts/LayijiMahaniyomV1_61.ttf")

	for opt_any in options_list:
		if not (opt_any is Dictionary): continue

		var opt: Dictionary = opt_any
		var unlocked := logic.choice_is_unlocked(opt)

		var b := Button.new()
		b.text = logic.choice_display_text(opt)

		if btn_font:
			b.add_theme_font_override("font", btn_font)
			b.add_theme_font_size_override("font_size", 24)

		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_focus_color", Color.WHITE)
		b.add_theme_color_override("font_disabled_color", Color(0.65, 0.65, 0.65, 1.0))

		b.add_theme_stylebox_override("normal", my_style)
		b.add_theme_stylebox_override("hover", my_style_hover)
		b.add_theme_stylebox_override("disabled", my_style_disabled)
		
		b.custom_minimum_size = Vector2(520, 50)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		b.clip_text = false
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT

		b.disabled = not unlocked
		
		if not unlocked: b.modulate.a = 0.7
		_setup_button_sounds(b)

		if unlocked:
			b.pressed.connect(func() -> void: _on_choice(opt))

		choices_box.add_child(b)

func _on_choice(opt: Dictionary) -> void:
	_busy = true
	choices_container.visible = false

	var stat_gains = logic.apply_choice_effects(opt)
	for k in stat_gains.keys():
		_show_stat_popup(k, stat_gains[k])
	_update_stats_display()

	logic.advance_index_for_choice(opt)
	var say_text: String = str(opt.get("say", "")).strip_edges()

	if say_text != "":
		_update_name_box("เมฆ")
		type_speed_seconds = 0.001 if _is_fast_forwarding else normal_type_speed
		await _type_text(say_text)

		_busy = false
		_typing = false
		logic.sync_state_to_gamesave()

		logic.waiting_for_choice_next = true

		if _is_fast_forwarding: _advance()
		return

	_busy = false
	logic.sync_state_to_gamesave()
	await _show_current()

func _set_background(value: String) -> void:
	var full_path := logic.guess_image_path(logic.BG_DIR, value)
	if full_path == "":
		return

	var tex := load(full_path) as Texture2D
	if tex == null:
		return

	_busy = true
	await _fade_rect_alpha(bg_fade, 0.0, 1.0, 0.25)
	bg.texture = tex
	await _fade_rect_alpha(bg_fade, 1.0, 0.0, 0.25)
	_busy = false

func _set_character_sprite(value: String) -> void:
	var full_path := logic.guess_image_path(logic.SPRITE_DIR, value)
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
	if to_a <= 0.001: rect.visible = false

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

func _on_fast_forward_toggled(button_pressed: bool) -> void:
	_is_fast_forwarding = button_pressed
	
	if _is_fast_forwarding:
		type_speed_seconds = 0.001 
		if _typing: _skip_typing = true
		if not _busy and not choices_container.visible: _advance()
	else:
		type_speed_seconds = normal_type_speed

func _on_save_pressed() -> void:
	_block_dialogue_input_for_menu_open()
	_hide_all_in_game_menus()
	logic.sync_state_to_gamesave()
	var tree := get_tree()
	tree.paused = true
	if save_scene:
		var save_menu: Node = save_scene.instantiate()
		save_menu.set("mode", 2)
		save_menu.tree_exited.connect(func():
			if is_instance_valid(tree): tree.paused = false
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
			if is_instance_valid(tree): tree.paused = false
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
	if _typing: _skip_typing = true
	if fast_forward: fast_forward.set_pressed_no_signal(false)
		
	_is_fast_forwarding = false
	type_speed_seconds = normal_type_speed
