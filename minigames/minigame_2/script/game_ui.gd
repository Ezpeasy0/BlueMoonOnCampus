extends CanvasLayer

@onready var confirm_box = $ConfirmBox
@onready var fade_screen = $FadeScreen

func _ready():
	confirm_box.hide()
	
	# เตรียมหน้าจอดำให้โปร่งใส 100% ตั้งแต่เริ่ม
	fade_screen.modulate.a = 0 
	fade_screen.hide()

# --- ฟังก์ชันเหล่านี้จะได้มาจากการเชื่อม Signal ในขั้นตอนต่อไป ---

func _on_btn_complete_pressed():
	confirm_box.show()
	get_tree().paused = true # สั่งหยุดเกม (ตัวละครจะเดินไม่ได้)

func _on_btn_no_pressed():
	confirm_box.hide()
	get_tree().paused = false # สั่งเล่นเกมต่อ

func _on_btn_yes_pressed():
	confirm_box.hide()
	
	# โค้ดส่วนของการทำ Fade จอดำแบบค่อยๆ มืด
	fade_screen.show()
	var tween = get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # ให้ Fade ทำงานได้แม้เกม Pause อยู่
	# สั่งให้ค่าความทึบ (Alpha หรือตัว a) เพิ่มเป็น 1.0 (ทึบ 100%) ภายใน 1.5 วินาที
	tween.tween_property(fade_screen, "modulate:a", 1.0, 1.5)
	
	# เมื่อ Fade เสร็จแล้วให้ไปเรียกฟังก์ชัน finish_game
	tween.tween_callback(finish_game) 

func finish_game():
	print("จอมืดสนิทแล้ว! เตรียมกลับเกมหลัก หรือ โหลดฉากต่อไป")
	# ถ้าจะโหลดฉากถัดไปให้ลบคอมเมนต์ด้านล่าง แล้วใส่ชื่อไฟล์ฉาก
	# get_tree().paused = false 
	# get_tree().change_scene_to_file("res://ชื่อฉากเกมหลัก.tscn")
