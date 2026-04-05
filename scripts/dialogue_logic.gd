#class_name DialogueLogic
extends Node

const BG_DIR: String = "res://sprites/scene/"
const SPRITE_DIR: String = "res://sprites/characters/"
const FULLSCREEN_BGS: Array[String] = ["pete.png"]
const BGM_PATH_DIR: String = "res://sounds/bgm/"
const SFX_PATH_DIR: String = "res://sounds/sfx/"
const MasterSFX_PATH_DIR: String = "res://sounds/master_sfx/"

var story_lines: Array = []
var id_to_index: Dictionary = {}

var index: int = 0
var stats: Dictionary = {"INT": 0, "CHA": 0}

var current_bg: String = ""
var current_sprite: String = ""
var current_bgm: String = ""
var current_master_sfx: String = ""
var waiting_for_choice_next: bool = false

signal display_minigame_gains_requested(gains: Dictionary)
signal name_box_update_requested(who: String)

func load_chapter_data() -> void:
	var chapter_num: int = 1
	if GameSave.state is Dictionary and GameSave.state.has("chapter"):
		chapter_num = int(GameSave.state["chapter"])

	var path := "res://data/chapter%d.json" % chapter_num
	if not FileAccess.file_exists(path):
		push_error("Chapter file not found: " + path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	var json_data = JSON.parse_string(text)

	if typeof(json_data) == TYPE_ARRAY:
		story_lines = json_data
	elif typeof(json_data) == TYPE_DICTIONARY:
		if json_data.has("events"):
			story_lines = json_data["events"]
		elif json_data.has("lines"):
			story_lines = json_data["lines"]
		else:
			push_error("JSON file must contain an 'events' or 'lines' array: " + path)
			return
	else:
		push_error("Failed to parse JSON from: " + path)
		return

	id_to_index.clear()
	for i in range(story_lines.size()):
		var line_any: Variant = story_lines[i]
		if line_any is Dictionary:
			var line_dict: Dictionary = line_any
			if line_dict.has("id"):
				id_to_index[line_dict["id"]] = i

func restore_from_gamesave() -> void:
	if GameSave.current_slot < 0:
		return
	if not (GameSave.state is Dictionary):
		return

	if GameSave.state.has("line_index"):
		index = int(GameSave.state["line_index"])

	if GameSave.state.has("stats") and GameSave.state["stats"] is Dictionary:
		stats = (GameSave.state["stats"] as Dictionary).duplicate(true)

	if GameSave.state.has("bg"):
		current_bg = str(GameSave.state["bg"])
	if GameSave.state.has("sprite"):
		current_sprite = str(GameSave.state["sprite"])
	if GameSave.state.has("bgm"):
		current_bgm = str(GameSave.state["bgm"])
	if GameSave.state.has("master_sfx"):
		current_master_sfx = str(GameSave.state["master_sfx"])
		
	if GameSave.state.has("minigame_return_next_id"):
		var return_id := str(GameSave.state["minigame_return_next_id"])
		if return_id != "" and id_to_index.has(return_id):
			index = int(id_to_index[return_id])
		GameSave.state.erase("minigame_return_next_id")
		GameSave.state.erase("pending_next_id")
		
	if GameSave.state.has("minigame_stat_gains"):
		var gains = GameSave.state["minigame_stat_gains"]
		if gains is Dictionary:
			emit_signal("display_minigame_gains_requested", gains)
		GameSave.state.erase("minigame_stat_gains")
		
	if GameSave.state.has("stats") and GameSave.state["stats"] is Dictionary:
		stats = (GameSave.state["stats"] as Dictionary).duplicate(true)
		
	if index < story_lines.size():
		var current_line = story_lines[index]
		if current_line is Dictionary:
			var who = str(current_line.get("name", ""))
			emit_signal("name_box_update_requested", who)

func sync_state_to_gamesave() -> void:
	if not (GameSave.state is Dictionary):
		GameSave.state = {}

	if not GameSave.state.has("chapter"):
		GameSave.state["chapter"] = 1
	if not GameSave.state.has("scene"):
		GameSave.state["scene"] = 1

	GameSave.state["line_index"] = index
	GameSave.state["stats"] = stats.duplicate(true)
	GameSave.state["bg"] = current_bg
	GameSave.state["sprite"] = current_sprite
	GameSave.state["bgm"] = current_bgm
	GameSave.state["master_sfx"] = current_master_sfx

func save_now() -> void:
	if GameSave.current_slot >= 0:
		sync_state_to_gamesave()
		GameSave.save_game(GameSave.current_slot)

func is_fullscreen_bg(bg_value: String) -> bool:
	if bg_value == "":
		return false
	var file := bg_value.get_file()
	return FULLSCREEN_BGS.has(file)

func go_to_next_chapter_or_end() -> void:
	var current_chapter: int = 1
	if GameSave.state is Dictionary and GameSave.state.has("chapter"):
		current_chapter = int(GameSave.state["chapter"])

	var next_chapter: int = current_chapter + 1
	var next_path := "res://data/chapter%d.json" % next_chapter

	if FileAccess.file_exists(next_path):
		GameSave.state["chapter"] = next_chapter
		GameSave.state["line_index"] = 0
		GameSave.state["bg"] = ""
		GameSave.state["sprite"] = ""
		GameSave.state["bgm"] = ""
		GameSave.state["master_sfx"] = ""

		get_tree().change_scene_to_file("res://scenes/dialogue.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func get_current_line() -> Variant:
	if index >= story_lines.size():
		return null
	return story_lines[index]

func evaluate_choice_condition(condition_text: String) -> bool:
	var cond := condition_text.strip_edges()
	if cond == "":
		return true

	var parts := cond.split(" ")
	if parts.size() != 3:
		return true

	var stat_name := parts[0].strip_edges()
	var op := parts[1].strip_edges()
	var value := int(parts[2].strip_edges())

	var current := int(stats.get(stat_name, 0))

	match op:
		">=": return current >= value
		">": return current > value
		"<=": return current <= value
		"<": return current < value
		"==": return current == value
		"!=": return current != value
		_: return true

func choice_is_unlocked(opt: Dictionary) -> bool:
	if opt.has("condition"):
		return evaluate_choice_condition(str(opt.get("condition", "")))
	return true
	
func choice_display_text(opt: Dictionary) -> String:
	if opt.has("label"):
		return str(opt.get("label", ""))
	if opt.has("text"):
		return str(opt.get("text", ""))
	return "Choice"

func choice_lock_text(opt: Dictionary) -> String:
	if opt.has("condition"):
		return "Locked (%s)" % str(opt.get("condition", ""))
	return "Locked"

func apply_choice_effects(opt: Dictionary) -> Dictionary:
	if not (stats is Dictionary):
		stats = {"INT": 0, "CHA": 0}

	for key in ["INT", "CHA"]:
		stats[key] = int(stats.get(key, 0))

	var effects_any: Variant = opt.get("effects", {})
	var effects: Dictionary = effects_any if effects_any is Dictionary else {}
	var stat_gains = {}

	for k in effects.keys():
		var gain = int(effects[k])
		stats[k] = int(stats.get(k, 0)) + gain
		if gain > 0:
			stat_gains[k] = gain
			
	return stat_gains

func advance_index_for_choice(opt: Dictionary) -> void:
	var target_id: String = str(opt.get("next", ""))
	if target_id != "" and id_to_index.has(target_id):
		index = int(id_to_index[target_id])
	else:
		index += 1

func ensure_flags() -> void:
	if not (GameSave.state is Dictionary):
		GameSave.state = {}
	if not GameSave.state.has("flags") or not (GameSave.state["flags"] is Dictionary):
		GameSave.state["flags"] = {}

func get_flag(flag_name: String, default_value: bool = false) -> bool:
	ensure_flags()
	return bool((GameSave.state["flags"] as Dictionary).get(flag_name, default_value))

func advance_conditional(line: Dictionary) -> bool:
	var next_id: String = ""

	if line.has("condition"):
		var condition_name: String = str(line.get("condition", ""))
		var true_next: String = str(line.get("true_next", ""))
		var false_next: String = str(line.get("false_next", ""))

		var condition_result := get_flag(condition_name, false)
		if condition_result:
			next_id = true_next
		else:
			next_id = false_next

	elif line.has("conditions"):
		var matched := false
		var conditions_any: Variant = line.get("conditions", [])

		if conditions_any is Array:
			for cond_any in conditions_any:
				if not (cond_any is Dictionary):
					continue

				var cond: Dictionary = cond_any
				var cond_name: String = str(cond.get("if", ""))
				var cond_next: String = str(cond.get("next", ""))

				if get_flag(cond_name, false):
					next_id = cond_next
					matched = true
					break

		if not matched:
			next_id = str(line.get("else", ""))

	if next_id != "" and id_to_index.has(next_id):
		index = int(id_to_index[next_id])
		return true

	push_warning("Conditional event missing valid next path: %s" % [str(line.get("id", ""))])
	return false

func start_minigame(minigame_id: String, next_id: String) -> void:
	if next_id != "" and id_to_index.has(next_id):
		index = int(id_to_index[next_id])
	else:
		index += 1
	sync_state_to_gamesave()

	match minigame_id:
		"lunchbox": 
			get_tree().change_scene_to_file("res://minigames/minigame_1_lunchbox/scenes/splash_screen.tscn")
		"minigame_2_1":
			get_tree().change_scene_to_file("res://minigames/minigame_2/room scene/minigame2_room1.tscn")
		"minigame_2_2":
			get_tree().change_scene_to_file("res://minigames/minigame_2/room scene/minigame_2_room_2.tscn")	
		_:
			push_warning("Unknown minigame_id: " + minigame_id)

func resolve_path(root: String, value: String) -> String:
	if value.strip_edges() == "":
		return ""
	if value.begins_with("res://"):
		return value

	var found := search_recursive(root, value)
	if found != "":
		return found

	var direct := root + value
	if FileAccess.file_exists(direct):
		return direct
	return ""

func search_recursive(path: String, target_file: String) -> String:
	var dir := DirAccess.open(path)
	if not dir:
		return ""

	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "":
			break

		if dir.current_is_dir():
			var found := search_recursive(path + file_name + "/", target_file)
			if found != "":
				dir.list_dir_end()
				return found
		else:
			if file_name == target_file:
				dir.list_dir_end()
				return path + file_name

	dir.list_dir_end()
	return ""

func guess_image_path(root: String, filename: String) -> String:
	if filename.get_extension() != "":
		return resolve_path(root, filename)
	
	var exts = [".png", ".jpg", ".jpeg", ".webp"]
	for ext in exts:
		var path = resolve_path(root, filename + ext)
		if path != "":
			return path
	return ""

func guess_audio_path(root: String, filename: String) -> String:
	if filename.get_extension() != "":
		var direct_path = root + filename
		if FileAccess.file_exists(direct_path):
			return direct_path
		return ""
		
	var exts = [".mp3", ".wav", ".ogg"]
	for ext in exts:
		var path = root + filename + ext
		if FileAccess.file_exists(path):
			return path
	return ""
