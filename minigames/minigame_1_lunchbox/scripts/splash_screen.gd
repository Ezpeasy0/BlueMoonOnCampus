extends Control

func _ready():
	# เมื่อ Timer นับจนครบเวลาที่ตั้งไว้ ให้เรียกฟังก์ชันเปลี่ยนฉาก
	$Timer.timeout.connect(_on_timer_timeout)

func _on_timer_timeout():
	# เปลี่ยนไปยังหน้าเกมหลักของคุณ
	get_tree().change_scene_to_file("res://minigames/minigame_1_lunchbox/scenes/main.tscn")
