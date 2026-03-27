extends CanvasLayer

@onready var confirm_box = $ConfirmBox
@onready var fade_screen = $FadeScreen

func _ready():
	confirm_box.hide()
	fade_screen.modulate.a = 0
	fade_screen.hide()

func _ensure_gamesave():
	if not (GameSave.state is Dictionary):
		GameSave.state = {}

	if not GameSave.state.has("flags") or not (GameSave.state["flags"] is Dictionary):
		GameSave.state["flags"] = {}

	if not GameSave.state.has("stats") or not (GameSave.state["stats"] is Dictionary):
		GameSave.state["stats"] = {"INT": 0, "CHA": 0}

func _apply_minigame2_reward():
	_ensure_gamesave()

	var flags: Dictionary = GameSave.state["flags"]
	var stats: Dictionary = GameSave.state["stats"]

	var scene_path := ""
	if get_tree().current_scene:
		scene_path = str(get_tree().current_scene.scene_file_path)

	# Room 1 reward
	if scene_path.contains("minigame2_room1"):
		if not bool(flags.get("mg2_room1_reward_applied", false)):
			if bool(flags.get("mg2_room1_key_found", false)):
				stats["INT"] = int(stats.get("INT", 0)) + 2
			flags["mg2_room1_reward_applied"] = true
			flags["mg2_room1_completed"] = true

	# Room 2 reward
	elif scene_path.contains("minigame_2_room_2"):
		if not bool(flags.get("mg2_room2_reward_applied", false)):
			if bool(flags.get("mg2_room2_key_found", false)):
				stats["INT"] = int(stats.get("INT", 0)) + 2
			flags["mg2_room2_reward_applied"] = true
			flags["mg2_room2_completed"] = true

	GameSave.state["flags"] = flags
	GameSave.state["stats"] = stats

func _on_btn_complete_pressed():
	confirm_box.show()
	get_tree().paused = true

func _on_btn_no_pressed():
	confirm_box.hide()
	get_tree().paused = false

func _on_btn_yes_pressed():
	confirm_box.hide()

	_apply_minigame2_reward()

	fade_screen.show()
	var tween = get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fade_screen, "modulate:a", 1.0, 1.5)
	tween.tween_callback(finish_game)

func finish_game():
	print("จอมืดสนิทแล้ว! เตรียมกลับเกมหลัก หรือ โหลดฉากต่อไป")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/dialogue.tscn")
