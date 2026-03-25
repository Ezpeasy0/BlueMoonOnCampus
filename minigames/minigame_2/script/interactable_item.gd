extends Area2D

var is_player_near = false
var is_dialog_open = false

func _ready():
	$Label.hide() # ซ่อนปุ่ม [ E ]
	$DialogUI.hide() # ซ่อนกล่องข้อความ

# ฟังก์ชันนี้ทำงานตลอดเวลา เพื่อรอรับปุ่ม E
func _process(delta):
	# ถ้าผู้เล่นอยู่ใกล้ + กดปุ่ม E + กล่องข้อมความยังไม่เปิด
	if is_player_near and Input.is_action_just_pressed("interact"):
		if not is_dialog_open:
			open_dialog()
		else:
			close_dialog()

func open_dialog():
	is_dialog_open = true
	$Label.hide() # ซ่อนปุ่ม E ตอนอ่านข้อความ
	$DialogUI.show() # โชว์กล่องข้อความ
	$InteractSound.play()

func close_dialog():
	is_dialog_open = false
	$DialogUI.hide() # ปิดกล่องข้อความ
	if is_player_near:
		$Label.show() # โชว์ปุ่ม E กลับมา

# --- ส่วนของการเชื่อมสัญญาณ (Signal) ---
func _on_body_entered(body):
	if body.name == "player": # เช็กว่าคนที่เข้ามาใกล้คือ player
		is_player_near = true
		if not is_dialog_open:
			$Label.show() # โชว์ปุ่ม [ E ]

func _on_body_exited(body):
	if body.name == "player":
		is_player_near = false
		$Label.hide() # ซ่อนปุ่ม [ E ]
		close_dialog() # ปิดข้อความถ้าเดินหนีออกมา
