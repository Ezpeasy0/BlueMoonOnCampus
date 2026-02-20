extends Node

const SAVE_DIR := "user://saves/"
const SLOT_COUNT := 10

var current_slot: int = -1
var state: Dictionary = {}

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func get_slot_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.json" % slot

func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(get_slot_path(slot))

func new_game(slot: int) -> void:
	current_slot = slot
	state = {
		"chapter": 1,
		"scene": 1,
		"line_index": 0,
		"stats": {"INT": 0, "CHA": 0},
		"flags": {},
		"timestamp": Time.get_datetime_string_from_system()
	}
	save_game(slot)

func save_game(slot: int) -> void:
	current_slot = slot
	state["timestamp"] = Time.get_datetime_string_from_system()
	var path := get_slot_path(slot)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(state, "\t"))

func load_game(slot: int) -> bool:
	var path := get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return false

	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false

	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		current_slot = slot
		state = parsed as Dictionary
		return true

	return false

func delete_slot(slot: int) -> void:
	var json_path := get_slot_path(slot)
	if FileAccess.file_exists(json_path):
		DirAccess.remove_absolute(json_path)

	var preview_path := "user://save_%d.tres" % slot
	if FileAccess.file_exists(preview_path):
		DirAccess.remove_absolute(preview_path)

	if current_slot == slot:
		current_slot = -1
		state = {}

func load_slot_preview(slot: int) -> SaveResource:
	var path := "user://save_%d.tres" % slot
	if FileAccess.file_exists(path):
		return load(path) as SaveResource
	return null
