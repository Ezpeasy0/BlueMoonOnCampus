extends Control

const BG_DIR: String = "res://sprites/"
const SPRITE_DIR: String = "res://sprites/"

const FULLSCREEN_BGS: Array[String] = ["pete.png"]

@onready var bg: TextureRect = %BG
@onready var character: TextureRect = %Character
@onready var name_label: Label = %NameLabel
@onready var dialogue_label: RichTextLabel = %DialogueLabel
@onready var choices_box: VBoxContainer = %ChoicesBox

@onready var bg_fade: ColorRect = %BGFade

var story_lines: Array = []
var id_to_index: Dictionary = {}

var index: int = 0
var stats: Dictionary = {"INT": 0, "CHA": 0}

var _busy: bool = false

var _current_bg: String = ""
var _current_sprite: String = ""

func _ready() -> void:
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	bg_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

	character.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var chapter: Node = preload("res://data/chapter1.gd").new()
	story_lines = chapter.lines

	for i in range(story_lines.size()):
		var line = story_lines[i]
		if typeof(line) == TYPE_DICTIONARY and line.has("id"):
			id_to_index[line["id"]] = i

	choices_box.visible = false
	_show_current()

func _input(event: InputEvent) -> void:
	if _busy:
		return

	var advance: bool = (
		event is InputEventMouseButton
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
		and (event as InputEventMouseButton).pressed
	)

	if not advance:
		return

	if choices_box.visible:
		return

	_advance()

func _advance() -> void:
	if index >= 0 and index < story_lines.size():
		var line = story_lines[index]
		if typeof(line) == TYPE_DICTIONARY:
			var skip_to: String = str(line.get("skip_to", ""))
			if skip_to != "" and id_to_index.has(skip_to):
				index = int(id_to_index[skip_to])
				_show_current()
				return

	index += 1
	_show_current()

func _show_current() -> void:
	if index >= story_lines.size():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	var line: Dictionary = story_lines[index]

	if str(line.get("type", "line")) == "choice":
		_show_choices(line.get("choices", []))
		return

	choices_box.visible = false

	if line.has("bg"):
		var new_bg: String = str(line["bg"])
		if new_bg != "" and new_bg != _current_bg:
			_current_bg = new_bg
			await _set_background(new_bg)

	if _current_bg in FULLSCREEN_BGS:
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
	dialogue_label.text = txt

func _show_choices(options: Array) -> void:
	choices_box.visible = true

	for c in choices_box.get_children():
		c.queue_free()

	for opt in options:
		var b: Button = Button.new()
		b.text = str(opt.get("label", ""))
		b.pressed.connect(func() -> void: _on_choice(opt))
		choices_box.add_child(b)

func _on_choice(opt: Dictionary) -> void:
	choices_box.visible = false

	var say: String = str(opt.get("say", ""))
	if say != "":
		name_label.text = "เมฆ"
		dialogue_label.text = say

	var effects: Dictionary = opt.get("effects", {})
	for k in effects.keys():
		if stats.has(k):
			stats[k] += int(effects[k])

	var target_id: String = str(opt.get("next", ""))
	if target_id != "" and id_to_index.has(target_id):
		index = int(id_to_index[target_id])
	else:
		index += 1

	_show_current()

func _set_background(filename: String) -> void:
	var path: String = BG_DIR + filename
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		push_warning("BG not found: " + path)
		return

	_busy = true
	await _fade_rect_alpha(bg_fade, 0.0, 1.0, 0.25) 
	bg.texture = tex
	await _fade_rect_alpha(bg_fade, 1.0, 0.0, 0.25)
	_busy = false

func _set_character_sprite(filename: String) -> void:
	var path: String = SPRITE_DIR + filename
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		push_warning("Sprite not found: " + path)
		character.visible = false
		return

	_busy = true

	character.visible = true
	await _fade_control_alpha(character, 1.0, 0.0, 0.15)

	character.texture = tex

	await _fade_control_alpha(character, 0.0, 1.0, 0.15)

	_busy = false

func _fade_rect_alpha(rect: ColorRect, from_a: float, to_a: float, duration: float) -> void:
	rect.visible = true
	var c: Color = rect.color
	c.a = from_a
	rect.color = c

	var t: float = 0.0
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

func _fade_control_alpha(ctrl: CanvasItem, from_a: float, to_a: float, duration: float) -> void:
	var t: float = 0.0
	var c: Color = ctrl.modulate
	c.a = from_a
	ctrl.modulate = c

	while t < duration:
		t += get_process_delta_time()
		var k: float = clamp(t / duration, 0.0, 1.0)
		c.a = lerp(from_a, to_a, k)
		ctrl.modulate = c
		await get_tree().process_frame

	c.a = to_a
	ctrl.modulate = c
