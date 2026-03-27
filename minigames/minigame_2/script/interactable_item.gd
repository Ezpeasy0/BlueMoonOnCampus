extends Area2D

@export var key_item_flag: String = ""

var is_player_near = false
var is_dialog_open = false

func _ready():
	$Label.hide()
	$DialogUI.hide()

func _process(delta):
	if is_player_near and Input.is_action_just_pressed("interact"):
		if not is_dialog_open:
			open_dialog()
		else:
			close_dialog()

func _ensure_gamesave():
	if not (GameSave.state is Dictionary):
		GameSave.state = {}

	if not GameSave.state.has("flags") or not (GameSave.state["flags"] is Dictionary):
		GameSave.state["flags"] = {}

	if not GameSave.state.has("stats") or not (GameSave.state["stats"] is Dictionary):
		GameSave.state["stats"] = {"INT": 0, "CHA": 0}

func open_dialog():
	is_dialog_open = true
	$Label.hide()
	$DialogUI.show()
	$InteractSound.play()

	if key_item_flag.strip_edges() != "":
		_ensure_gamesave()
		GameSave.state["flags"][key_item_flag] = true

func close_dialog():
	is_dialog_open = false
	$DialogUI.hide()
	if is_player_near:
		$Label.show()

func _on_body_entered(body):
	if body.name == "player":
		is_player_near = true
		if not is_dialog_open:
			$Label.show()

func _on_body_exited(body):
	if body.name == "player":
		is_player_near = false
		$Label.hide()
		close_dialog()
