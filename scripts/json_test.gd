extends Control

@onready var bg: TextureRect = $BG
@onready var character: TextureRect = $Character
@onready var name_label: Label = $NameLabel
@onready var dialogue_label: RichTextLabel = $DialogueLabel
@onready var choices_box: VBoxContainer = $ChoicesBox

var events_by_id: Dictionary = {}
var current_event_id: String = ""
var current_bg_name: String = ""
var current_sprite_name: String = ""

const BG_BASE := "res://sprites/scene/"
const SPRITE_BASE := "res://sprites/characters/"

func _ready() -> void:
	load_story("res://data/chapter1.json")
	show_current_event()

func load_story(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open JSON: " + path)
		return

	var text := file.get_as_text()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Invalid JSON root")
		return

	events_by_id.clear()
	for e in data.get("events", []):
		events_by_id[str(e["id"])] = e

	current_event_id = str(data.get("start", ""))

func show_current_event() -> void:
	for child in choices_box.get_children():
		child.queue_free()

	if not events_by_id.has(current_event_id):
		return

	var event: Dictionary = events_by_id[current_event_id]
	var event_type := str(event.get("type", "dialogue"))

	if event.has("bg"):
		var bg_value := str(event.get("bg", ""))
		if bg_value == "":
			bg.texture = null
			current_bg_name = ""
		else:
			current_bg_name = bg_value
			var bg_path := resolve_bg(bg_value)
			if bg_path != "":
				bg.texture = load(bg_path)

	if event.has("sprite"):
		var sprite_value := str(event.get("sprite", ""))
		if sprite_value == "":
			character.texture = null
			character.visible = false
			current_sprite_name = ""
		else:
			current_sprite_name = sprite_value
			var sprite_path := resolve_sprite(sprite_value)
			if sprite_path != "":
				character.texture = load(sprite_path)
				character.visible = true
			else:
				character.texture = null
				character.visible = false

	name_label.text = str(event.get("name", ""))
	dialogue_label.text = str(event.get("text", ""))

	if event_type == "choice":
		var choices: Array = event.get("choices", [])
		for i in range(choices.size()):
			var choice: Dictionary = choices[i]
			var btn := Button.new()
			btn.text = str(choice.get("label", ""))
			btn.pressed.connect(func(): on_choice_pressed(i))
			choices_box.add_child(btn)

func on_choice_pressed(choice_index: int) -> void:
	if not events_by_id.has(current_event_id):
		return

	var event: Dictionary = events_by_id[current_event_id]
	var choices: Array = event.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return

	var choice: Dictionary = choices[choice_index]

	# for test: show "say" immediately as one dialogue step before jumping
	var say_text := str(choice.get("say", ""))
	var next_id := str(choice.get("next", ""))

	if say_text != "":
		name_label.text = "เมฆ"
		dialogue_label.text = say_text

		for child in choices_box.get_children():
			child.queue_free()

		var continue_btn := Button.new()
		continue_btn.text = "Continue"
		continue_btn.pressed.connect(func():
			apply_choice_effects(choice.get("effects", {}))
			current_event_id = next_id
			show_current_event()
		)
		choices_box.add_child(continue_btn)
	else:
		apply_choice_effects(choice.get("effects", {}))
		current_event_id = next_id
		show_current_event()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if choices_box.get_child_count() > 0:
			return
		go_next()

	if event.is_action_pressed("ui_accept"):
		if choices_box.get_child_count() > 0:
			return
		go_next()

func go_next() -> void:
	if not events_by_id.has(current_event_id):
		return

	var event: Dictionary = events_by_id[current_event_id]
	if str(event.get("type", "dialogue")) != "dialogue":
		return

	var next_id := str(event.get("next", ""))
	if next_id != "":
		current_event_id = next_id
		show_current_event()

func apply_choice_effects(effects: Dictionary) -> void:
	if not (GameSave.state is Dictionary):
		GameSave.state = {}

	if not GameSave.state.has("stats") or not (GameSave.state["stats"] is Dictionary):
		GameSave.state["stats"] = {"INT": 0, "CHA": 0}

	var stats: Dictionary = GameSave.state["stats"]

	for key in effects.keys():
		stats[key] = int(stats.get(key, 0)) + int(effects[key])

	GameSave.state["stats"] = stats
	print("Updated stats: ", GameSave.state["stats"])

func resolve_bg(name: String) -> String:
	var path := BG_BASE + name + ".png"
	if ResourceLoader.exists(path):
		return path

	path = BG_BASE + name + ".jpg"
	if ResourceLoader.exists(path):
		return path

	path = BG_BASE + name + ".jpeg"
	if ResourceLoader.exists(path):
		return path

	print("BG not found: ", name)
	return ""

func resolve_sprite(name: String) -> String:
	var found := search_recursive(SPRITE_BASE, name + ".png")
	if found != "":
		return found

	found = search_recursive(SPRITE_BASE, name + ".jpg")
	if found != "":
		return found

	found = search_recursive(SPRITE_BASE, name + ".jpeg")
	if found != "":
		return found

	print("Sprite not found: ", name)
	return ""

func search_recursive(path: String, target_file: String) -> String:
	var dir := DirAccess.open(path)
	if dir == null:
		return ""

	dir.list_dir_begin()
	while true:
		var item := dir.get_next()
		if item == "":
			break
		if item == "." or item == "..":
			continue

		var full_path := path.path_join(item)

		if dir.current_is_dir():
			var found := search_recursive(full_path, target_file)
			if found != "":
				dir.list_dir_end()
				return found
		else:
			if item == target_file:
				dir.list_dir_end()
				return full_path

	dir.list_dir_end()
	return ""
