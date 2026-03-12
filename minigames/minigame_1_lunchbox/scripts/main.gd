extends Node2D

@onready var complete_button = $CompleteButton

func _ready():
	Input.set_custom_mouse_cursor(
		load("res://minigames/minigame_1_lunchbox/assets/texture/chopsticks.png")
	)
	
func _process(_delta):
	# เช็กว่า Slot ทั้ง 4 เต็มหรือยังในทุกเฟรม
	if check_all_slots_full():
		complete_button.disabled = false # เปิดให้กดปุ่มได้
	else:
		complete_button.disabled = true  # ถ้าดึงออกจนไม่ครบ ให้กดไม่ได้เหมือนเดิม

func check_all_slots_full() -> bool:
	# อ้างอิงโหนด Slot ทั้ง 4 (เช็กชื่อให้ตรงกับใน Scene Tree)
	var s1 = $BentoBox/Slot1.is_occupied
	var s2 = $BentoBox/Slot2.is_occupied
	var s3 = $BentoBox/Slot3.is_occupied
	var s4 = $BentoBox/Slot4.is_occupied
	
	# คืนค่า true ถ้าทุกช่องเป็น true (มีอาหารวางอยู่)
	return s1 and s2 and s3 and s4

func _on_complete_button_pressed():
	# เมื่อกดปุ่ม ให้พาไปหน้าสรุปผล (รูปข้าวกล่องที่เสร็จแล้ว)
	get_tree().change_scene_to_file("res://minigames/minigame_1_lunchbox/scenes/end_screen.tscn")
