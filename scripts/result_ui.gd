# 결과 화면 — 밤 종료(승리/패배)와 간단 통계(처치 수·생존 동료), 재시작 버튼.
# 표시와 재시작 통지만 담당하고 밤 리셋은 main이 한다. 정지 중에만 동작(WHEN_PAUSED).
extends CanvasLayer

signal restart_requested

const PANEL_MIN_WIDTH := 420.0

# 스모크 검증용 공개 상태 — draft_ui 의 buttons/options 와 같은 패턴.
var title: Label
var stats: Label
var restart_button: Button


func _init() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	layer = 2  # 드래프트 UI(기본 1)보다 위
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(PANEL_MIN_WIDTH, 0.0)
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	stats = Label.new()
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats)
	restart_button = Button.new()
	restart_button.text = "새 밤 시작"
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	vbox.add_child(restart_button)


func show_result(victory: bool, kills: int, survivors: int, total_companions: int) -> void:
	title.text = "승리 — 밤을 버텨냈다" if victory else "패배 — 무녀가 쓰러졌다"
	stats.text = "처치 %d   생존 동료 %d/%d" % [kills, survivors, total_companions]
	visible = true
