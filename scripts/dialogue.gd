extends Control

const CHAPTER_SCRIPT_PATH: String = "res://data/chapter1.gd"
const SPRITE_DIR: String = "res://sprites/"

# const SFX_MAP := {
	# "fan": "res://sound/fan.wav",
	# "rain": "res://sound/rain.wav"
# }

@onready var name_label: Label = %NameLabel
@onready var dialogue_label: RichTextLabel = %DialogueLabel
@onready var choices_box: VBoxContainer = %ChoicesBox
@onready var portrait: TextureRect = %Portrait
@onready var sfx_player: AudioStreamPlayer = %SfxPlayer

var story_lines: Array = []
var id_to_index: Dictionary = {}

var index: int = 0
var stats: Dictionary = {"INT": 0, "CHA": 0}

var waiting_choice_advance: bool = false

func _ready() -> void:
	choices_box.visible = false

	_load_chapter()
	_build_id_index()

	_show_current()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		if choices_box.visible:
			return

		if waiting_choice_advance:
			waiting_choice_advance = false
			_show_current()
			return

		index += 1
		_show_current()

func _load_chapter() -> void:
	var scr = load(CHAPTER_SCRIPT_PATH)
	if scr == null:
		push_error("Dialogue: Chapter script not found: " + CHAPTER_SCRIPT_PATH)
		story_lines = []
		return

	var chapter = scr.new()
	if chapter == null or not chapter.has("lines"):
		push_error("Dialogue: Chapter script has no 'lines' array.")
		story_lines = []
		return

	story_lines = chapter.lines

func _build_id_index() -> void:
	id_to_index.clear()
	for i in range(story_lines.size()):
		var line = story_lines[i]
		if typeof(line) == TYPE_DICTIONARY and line.has("id"):
			id_to_index[line["id"]] = i

func _show_current() -> void:
	if index < 0:
		index = 0

	if index >= story_lines.size():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	var line: Dictionary = story_lines[index]

	if line.get("type", "line") == "choice":
		_show_choices(line.get("choices", []))
		return

	choices_box.visible = false
	_clear_choices()

	var who: String = str(line.get("name", ""))
	var txt: String = str(line.get("text", ""))

	if bool(line.get("thought", false)):
		txt = "(" + txt + ")"

	name_label.text = who
	dialogue_label.text = txt

	if line.has("sprite"):
		_set_portrait(str(line["sprite"]))

	if line.has("sfx"):
		_play_sfx(str(line["sfx"]))

func _set_portrait(filename: String) -> void:
	if filename.strip_edges() == "":
		portrait.visible = false
		return

	var path := SPRITE_DIR + filename
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		# Don't crash; just hide if not found
		push_warning("Dialogue: sprite not found: " + path)
		portrait.visible = false
		return

	portrait.texture = tex
	portrait.visible = true

func _play_sfx(key: String) -> void:
	var path: String = ""
	# if SFX_MAP.has(key):
		# path = str(SFX_MAP[key])
	# else:
		# if key.begins_with("res://") and key.ends_with(".wav") or key.ends_with(".mp3") or key.ends_with(".ogg"):
			# path = key

	if path == "":
		return

	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_warning("Dialogue: SFX not found: " + path)
		return

	sfx_player.stream = stream
	sfx_player.play()

func _show_choices(options: Array) -> void:
	choices_box.visible = true
	_clear_choices()

	for opt_any in options:
		if typeof(opt_any) != TYPE_DICTIONARY:
			continue
		var opt: Dictionary = opt_any

		var b := Button.new()
		b.text = str(opt.get("label", "Choice"))
		b.pressed.connect(_on_choice_pressed.bind(opt))
		choices_box.add_child(b)

func _clear_choices() -> void:
	for c in choices_box.get_children():
		c.queue_free()

func _on_choice_pressed(opt: Dictionary) -> void:
	name_label.text = "เมฆ"
	dialogue_label.text = str(opt.get("say", ""))

	var effects_any = opt.get("effects", {})
	if typeof(effects_any) == TYPE_DICTIONARY:
		var effects: Dictionary = effects_any
		for k in effects.keys():
			var key := str(k)
			if stats.has(key):
				stats[key] = int(stats[key]) + int(effects[key])

	var target_id: String = str(opt.get("next", ""))
	if target_id != "" and id_to_index.has(target_id):
		index = int(id_to_index[target_id])
	else:
		index += 1

	choices_box.visible = false
	_clear_choices()

	waiting_choice_advance = true
