extends Panel

signal video_requested
signal audio_requested

@export var video_button: Button
@export var audio_button: Button

func _ready():
	video_button.pressed.connect(func(): video_requested.emit())
	audio_button.pressed.connect(func(): audio_requested.emit())
