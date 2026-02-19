extends Control

# === Paths ===
const BG_DIR := "res://background/"
const SPRITE_DIR := "res://sprites/"

# === UI nodes (use Unique Name in Owner in the editor) ===
@onready var bg: TextureRect = %BG
@onready var character: TextureRect = %Character
@onready var name_label: Label = %NameLabel
@onready var dialogue_label: RichTextLabel = %DialogueLabel
@onready var choices_box: VBoxContainer = %ChoicesBox

# Fade layers
@onready var bg_fade: ColorRect = %BGFade
@onready var sprite_fade: ColorRect = %SpriteFade

var story_lines: Array = []
var id_to_index: Dictionary = {}

var index: int = 0
var stats := {"INT": 0, "CHA": 0}

var _busy: bool = false

func _ready() -> void:
	# Load chapter data (you will create chapter1.gd next)
	var chapter = preload("res://data/chapter1.gd").new()
	story_lines = chapter.lines

	for i in range(story_lines.size()):
		var line = story_lines[i]
		if typeof(line) == TYPE_DICTIONARY and line.has("id"):
			id_to_index[line["id"]] = i

	choices_box.visible = false
	_show_current()

func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return

	var advance: bool = (event is InputEventMouseButton and event.pressed) or event.is_action_pressed("ui_accept")
	if not advance:
		return

	if choices_box.visible:
		return

	index += 1
	_show_current()


func _show_current() -> void:
	if index >= story_lines.size():
		# End of chapter: go back to menu for now
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	var line: Dictionary = story_lines[index]

	# Choice line
	if line.get("type", "line") == "choice":
		_show_choices(line.get("choices", []))
		return

	choices_box.visible = false

	# Background change (optional)
	if line.has("bg"):
		await _set_background(str(line["bg"]))

	# Character sprite change (optional)
	if line.has("sprite"):
		await _set_character_sprite(str(line["sprite"]))

	# Name + text
	var who := str(line.get("name", ""))
	var txt := str(line.get("text", ""))

	if line.get("thought", false):
		txt = "(" + txt + ")"

	name_label.text = who
	dialogue_label.text = txt

func _show_choices(options: Array) -> void:
	choices_box.visible = true

	for c in choices_box.get_children():
		c.queue_free()

	for opt in options:
		var b := Button.new()
		b.text = str(opt.get("label", ""))
		b.pressed.connect(func(): _on_choice(opt))
		choices_box.add_child(b)

func _on_choice(opt: Dictionary) -> void:
	choices_box.visible = false

	# Show immediate "say" line (optional)
	var say := str(opt.get("say", ""))
	if say != "":
		name_label.text = "ฝน"
		dialogue_label.text = say

	# Apply effects
	var effects: Dictionary = opt.get("effects", {})
	for k in effects.keys():
		if stats.has(k):
			stats[k] += int(effects[k])

	# Jump
	var target_id: String = str(opt.get("next", ""))
	if target_id != "" and id_to_index.has(target_id):
		index = int(id_to_index[target_id])
	else:
		index += 1

	_show_current()

# ======================
# Background fade to black
# ======================
func _set_background(filename: String) -> void:
	var path := BG_DIR + filename
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		push_warning("BG not found: " + path)
		return

	_busy = true
	await _fade(bg_fade, 0.0, 1.0, 0.25) # fade to black
	bg.texture = tex
	await _fade(bg_fade, 1.0, 0.0, 0.25) # fade in
	_busy = false

# ======================
# Character sprite fade
# ======================
func _set_character_sprite(filename: String) -> void:
	if filename.strip_edges() == "":
		character.visible = false
		return

	var path := SPRITE_DIR + filename
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		push_warning("Sprite not found: " + path)
		character.visible = false
		return

	_busy = true
	await _fade(sprite_fade, 0.0, 1.0, 0.15)
	character.texture = tex
	character.visible = true
	await _fade(sprite_fade, 1.0, 0.0, 0.15)
	_busy = false

func _fade(rect: ColorRect, from_a: float, to_a: float, duration: float) -> void:
	rect.visible = true
	var c := rect.color
	c.a = from_a
	rect.color = c

	var t := 0.0
	while t < duration:
		t += get_process_delta_time()
		var k: float = clamp(t / duration, 0.0, 1.0)
		c.a = lerp(from_a, to_a, k)
		rect.color = c
		await get_tree().process_frame

	c.a = to_a
	rect.color = c
	if to_a <= 0.001:
		rect.visible = false
