extends Control

# ---------- Paths ----------
const BG_DIR: String = "res://sprites/scene/"
const SPRITE_DIR: String = "res://sprites/characters/"
const FULLSCREEN_BGS: Array[String] = ["pete.png"]
const BGM_PATH_DIR: String = "res://sounds/bgm/"
const SFX_PATH_DIR: String = "res://sounds/sfx/"

# ---------- UI ----------
@onready var bg: TextureRect = %BG
@onready var character: TextureRect = %Character
@onready var name_label: Label = %NameLabel
@onready var dialogue_label: RichTextLabel = %DialogueLabel
@onready var choices_box: VBoxContainer = %ChoicesBox
@onready var bg_fade: ColorRect = %BGFade
@onready var btn_options: Button = $HBoxContainer/options
@onready var options_menu: Panel = $Options
@onready var exit_confirm: ConfirmationDialog = $ExitConfirm

# ---------- Audio ----------
@export var sfx_click: AudioStreamPlayer
@export var sfx_hover: AudioStreamPlayer
@export var sfx_text_blip: AudioStreamPlayer
@onready var bgm_player: AudioStreamPlayer = $BGM
@onready var sfx_dialogue: AudioStreamPlayer = $SFX

# ---------- Options sub-panels ----------
@export var video_panel: Panel
@export var audio_panel: Panel
@export var back_button: Button

# ---------- Save/Load ----------
var save_scene: PackedScene = preload("res://scenes/save_slot_save.tscn")
var load_scene: PackedScene = preload("res://scenes/save_slot_load.tscn")

# ---------- Story ----------
var story_lines: Array = []
var id_to_index: Dictionary = {}
var index: int = 0
var stats: Dictionary = {"INT": 0, "CHA": 0}

# ---------- Flow ----------
var _busy: bool = false
var _typing: bool = false
var _skip_typing: bool = false
var _current_bg: String = ""
var _current_sprite: String = ""
var _current_bgm: String = ""

# ---------- Typing config ----------
@export var type_speed_seconds: float = 0.02
@export var blip_interval_seconds: float = 0.05
@export var blip_volume_db: float = -18.0
var _blip_timer: Timer = null

# ================= READY =================
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if options_menu: options_menu.visible = false
	if video_panel: video_panel.visible = false
	if audio_panel: audio_panel.visible = false
	if back_button: back_button.visible = false
	if exit_confirm: exit_confirm.visible = false

	_auto_setup_all_buttons(self)

	if btn_options and not btn_options.pressed.is_connected(_on_options_pressed):
		btn_options.pressed.connect(_on_options_pressed)
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

	if exit_confirm:
		if not exit_confirm.confirmed.is_connected(_on_exit_confirmed):
			exit_confirm.confirmed.connect(_on_exit_confirmed)
		if not exit_confirm.canceled.is_connected(_on_exit_canceled):
			exit_confirm.canceled.connect(_on_exit_canceled)

	# Load chapter data
	var chapter: Node = preload("res://data/chapter1.gd").new()
	story_lines = chapter.lines

	# Build id map
	for i in range(story_lines.size()):
		var v: Variant = story_lines[i]
		var d: Dictionary = v as Dictionary
		if d.size() > 0 and d.has("id"):
			id_to_index[d["id"]] = i

	_restore_from_gamesave()
	await _apply_restored_visuals()

	choices_box.visible = false
	_show_current()

# ================= SAVE =================
func _sync_state_to_gamesave() -> void:
	if not (GameSave.state is Dictionary):
		GameSave.state = {}

	GameSave.state["chapter"] = 1
	GameSave.state["line_index"] = index
	GameSave.state["stats"] = stats.duplicate(true)
	GameSave.state["bg"] = _current_bg
	GameSave.state["sprite"] = _current_sprite
	GameSave.state["bgm"] = _current_bgm

func _save_now() -> void:
	if GameSave.current_slot >= 0:
		_sync_state_to_gamesave()
		GameSave.save_game(GameSave.current_slot)

func _restore_from_gamesave() -> void:
	if GameSave.current_slot < 0:
		return
	if not (GameSave.state is Dictionary):
		return

	index = int(GameSave.state.get("line_index", 0))

	var st: Variant = GameSave.state.get("stats", {"INT": 0, "CHA": 0})
	if st is Dictionary:
		stats = (st as Dictionary).duplicate(true)
	else:
		stats = {"INT": 0, "CHA": 0}

	_current_bg = str(GameSave.state.get("bg", ""))
	_current_sprite = str(GameSave.state.get("sprite", ""))
	_current_bgm = str(GameSave.state.get("bgm", ""))

func _apply_restored_visuals() -> void:
	if _current_bg != "":
		await _set_background(_current_bg)

	if _current_bg in FULLSCREEN_BGS:
		character.visible = false
	else:
		if _current_sprite != "":
			await _set_character_sprite(_current_sprite)

	if _current_bgm != "":
		_play_bgm(_current_bgm)

# ================= INPUT =================
func _input(event: InputEvent) -> void:
	if _busy:
		return

	var is_any_menu_open: bool = (options_menu and options_menu.visible) \
		or (video_panel and video_panel.visible) \
		or (audio_panel and audio_panel.visible) \
		or get_tree().paused

	if is_any_menu_open:
		return

	if _typing:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_skip_typing = true
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not choices_box.visible:
			_advance()

func _advance() -> void:
	index += 1
	_show_current()
	_save_now()

# ================= STORY =================
func _show_current() -> void:
	if index >= story_lines.size():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	var v: Variant = story_lines[index]
	var line: Dictionary = v as Dictionary

	# Choice block
	if str(line.get("type", "line")) == "choice":
		var opts: Variant = line.get("choices", [])
		_show_choices(opts as Array)
		return

	# Background
	if line.has("bg"):
		var new_bg: String = str(line.get("bg", ""))
		if new_bg != "":
			_current_bg = new_bg
			await _set_background(_current_bg)

	# Character sprite
	if _current_bg in FULLSCREEN_BGS:
		_current_sprite = ""
		character.visible = false
	else:
		if line.has("sprite"):
			var spr: String = str(line.get("sprite", ""))
			if spr.strip_edges() == "":
				_current_sprite = ""
				character.visible = false
			else:
				_current_sprite = spr
				await _set_character_sprite(_current_sprite)

	# BGM / SFX
	if line.has("bgm"):
		_play_bgm(str(line.get("bgm", "")))
	if line.has("sfx"):
		_play_sfx(str(line.get("sfx", "")))

	# Text
	var who: String = str(line.get("name", ""))
	var txt: String = str(line.get("text", ""))

	name_label.text = who
	await _type_text(txt)

# ================= CHOICES =================
func _show_choices(list: Array) -> void:
	choices_box.visible = true
	for c in choices_box.get_children():
		c.queue_free()

	for ov in list:
		var opt: Dictionary = (ov as Dictionary)
		var b: Button = Button.new()
		b.text = str(opt.get("label", ""))
		_setup_button_sounds(b)
		b.pressed.connect(func() -> void:
			_on_choice(opt)
		)
		choices_box.add_child(b)

func _on_choice(opt: Dictionary) -> void:
	choices_box.visible = false

	# effects
	var eff_v: Variant = opt.get("effects", {})
	if eff_v is Dictionary:
		var eff: Dictionary = eff_v as Dictionary
		for k in eff.keys():
			var key: String = str(k)
			if not stats.has(key):
				stats[key] = 0
			stats[key] = int(stats[key]) + int(eff[k])

	# say
	var say_text: String = str(opt.get("say", "")).strip_edges()
	if say_text != "":
		name_label.text = "เมฆ"
		await _type_text(say_text)

	# jump
	var next_id: String = str(opt.get("next", ""))
	if next_id != "" and id_to_index.has(next_id):
		index = int(id_to_index[next_id])
	else:
		index += 1

	_save_now()
	_show_current()

# ================= TYPING =================
func _ensure_blip_timer() -> void:
	if _blip_timer != null:
		return
	_blip_timer = Timer.new()
	_blip_timer.one_shot = false
	add_child(_blip_timer)
	_blip_timer.timeout.connect(_on_blip_timeout)

func _on_blip_timeout() -> void:
	if _typing and sfx_text_blip:
		sfx_text_blip.volume_db = blip_volume_db
		# restart = crisp tick but still synced to timer
		if sfx_text_blip.playing:
			sfx_text_blip.stop()
		sfx_text_blip.play()

func _type_text(txt: String) -> void:
	_typing = true
	_skip_typing = false
	dialogue_label.text = ""

	if txt == "":
		_typing = false
		return

	_ensure_blip_timer()
	_blip_timer.wait_time = blip_interval_seconds
	_blip_timer.start()

	var i: int = 0
	while i < txt.length():
		if _skip_typing:
			break
		dialogue_label.text += txt[i]
		i += 1
		await get_tree().create_timer(type_speed_seconds).timeout

	# finish
	dialogue_label.text = txt

	if _blip_timer:
		_blip_timer.stop()
	if sfx_text_blip and sfx_text_blip.playing:
		sfx_text_blip.stop()

	_typing = false

# ================= AUDIO =================
func _play_bgm(file: String) -> void:
	var filename: String = str(file).strip_edges()
	if filename == "" or filename == "null":
		if bgm_player:
			bgm_player.stop()
		_current_bgm = ""
		return

	if filename == _current_bgm:
		return

	var p: String = BGM_PATH_DIR + filename
	if not FileAccess.file_exists(p):
		print("BGM not found: ", p)
		return

	var stream: AudioStream = load(p) as AudioStream
	if stream and bgm_player:
		bgm_player.stream = stream
		bgm_player.play()
		_current_bgm = filename

func _play_sfx(file: String) -> void:
	var filename: String = str(file).strip_edges()
	if filename == "" or filename == "null":
		return

	var p: String = SFX_PATH_DIR + filename
	if not FileAccess.file_exists(p):
		print("SFX not found: ", p)
		return

	var stream: AudioStream = load(p) as AudioStream
	if stream and sfx_dialogue:
		sfx_dialogue.stream = stream
		sfx_dialogue.play()

# ================= VISUAL =================
func _set_background(file: String) -> void:
	var filename: String = str(file).strip_edges()
	var p: String = BG_DIR + filename
	var tex: Texture2D = load(p) as Texture2D
	if tex == null:
		print("BG not found: ", p)
		return
	bg.texture = tex

func _set_character_sprite(file: String) -> void:
	var filename: String = str(file).strip_edges()
	if filename == "":
		character.visible = false
		return
	var p: String = SPRITE_DIR + filename
	var tex: Texture2D = load(p) as Texture2D
	if tex == null:
		print("Sprite not found: ", p)
		character.visible = false
		return
	character.texture = tex
	character.visible = true

# ================= UI =================
func _on_options_pressed() -> void:
	get_tree().paused = true
	if options_menu: options_menu.visible = true
	if back_button: back_button.visible = true

func _on_back_pressed() -> void:
	get_tree().paused = false
	if options_menu: options_menu.visible = false
	if video_panel: video_panel.visible = false
	if audio_panel: audio_panel.visible = false
	if back_button: back_button.visible = false

func _on_exit_confirmed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_exit_canceled() -> void:
	get_tree().paused = false

func _auto_setup_all_buttons(node: Node) -> void:
	if node is Button:
		_setup_button_sounds(node as Button)
	for c in node.get_children():
		_auto_setup_all_buttons(c)

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

# ================= Save/Load Menus =================
func _on_save_pressed() -> void:
	_save_now()
	get_tree().paused = true
	var m: Node = save_scene.instantiate()
	add_child(m)
	move_child(m, -1)

func _on_load_pressed() -> void:
	get_tree().paused = true
	var m: Node = load_scene.instantiate()
	add_child(m)
	move_child(m, -1)
