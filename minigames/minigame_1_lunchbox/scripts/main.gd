extends Node2D

@onready var complete_button = $CompleteButton

func _ready():
	var cursor_tex = load("res://minigames/minigame_1_lunchbox/assets/texture/chopsticks.png")
	Input.set_custom_mouse_cursor(cursor_tex, Input.CURSOR_ARROW, Vector2(20, 100))

func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)

func _process(_delta):
	if check_all_slots_full():
		complete_button.disabled = false
	else:
		complete_button.disabled = true

func check_all_slots_full() -> bool:
	var s1 = $BentoBox/Slot1.is_occupied
	var s2 = $BentoBox/Slot2.is_occupied
	var s3 = $BentoBox/Slot3.is_occupied
	var s4 = $BentoBox/Slot4.is_occupied
	return s1 and s2 and s3 and s4

func _is_perfect_menu() -> bool:
	var slot1_food = $BentoBox/Slot1.occupied_food_id
	var slot2_food = $BentoBox/Slot2.occupied_food_id
	var slot3_food = $BentoBox/Slot3.occupied_food_id
	var slot4_food = $BentoBox/Slot4.occupied_food_id

	return (
		slot1_food == "korean_chicken"
		and slot2_food == "papaya_salad"
		and slot3_food == "sushi_salmon"
		and slot4_food == "fried_rice_sausage"
	)

func _get_food_cha(food_id: String) -> int:
	match food_id:
		"fried_rice_sausage":
			return 1
		"korean_chicken":
			return 1
		"papaya_salad":
			return 1
		"sushi_salmon":
			return 1

		"fried_rice_seafood":
			return 0
		"kfc":
			return 0
		"onigiri":
			return 0

		"fried_rice_gourami":
			return -1
		"pork_chop":
			return -1
		"salad":
			return -1
		"sushi_sweet_egg":
			return -1

		_:
			return 0


func _get_minigame_cha_gain() -> int:
	var slot1_food = str($BentoBox/Slot1.occupied_food_id)
	var slot2_food = str($BentoBox/Slot2.occupied_food_id)
	var slot3_food = str($BentoBox/Slot3.occupied_food_id)
	var slot4_food = str($BentoBox/Slot4.occupied_food_id)

	return (
		_get_food_cha(slot1_food)
		+ _get_food_cha(slot2_food)
		+ _get_food_cha(slot3_food)
		+ _get_food_cha(slot4_food)
	)

func _save_minigame_result() -> void:
	if not (GameSave.state is Dictionary):
		GameSave.state = {}

	if not GameSave.state.has("flags") or not (GameSave.state["flags"] is Dictionary):
		GameSave.state["flags"] = {}

	if not GameSave.state.has("stats") or not (GameSave.state["stats"] is Dictionary):
		GameSave.state["stats"] = {"INT": 0, "CHA": 0}

	var flags: Dictionary = GameSave.state["flags"]
	var stats: Dictionary = GameSave.state["stats"]

	var perfect := _is_perfect_menu()
	var cha_gain := _get_minigame_cha_gain()

	var old_cha_gain := int(flags.get("minigame_1_cha_gain", 0))

	stats["INT"] = int(stats.get("INT", 0))
	stats["CHA"] = int(stats.get("CHA", 0)) - old_cha_gain + cha_gain

	flags["minigame_1_perfect"] = perfect
	flags["minigame_1_cha_gain"] = cha_gain

	GameSave.state["flags"] = flags
	GameSave.state["stats"] = stats

	var next_id := str(GameSave.state.get("pending_next_id", ""))
	GameSave.state["minigame_return_next_id"] = next_id

func _on_complete_button_pressed():
	_save_minigame_result()
	get_tree().change_scene_to_file("res://minigames/minigame_1_lunchbox/scenes/end_screen.tscn")
