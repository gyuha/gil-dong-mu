# 드래프트 UI — 일시정지 중 3지선다 그레이박스 버튼. 표시와 선택 통지만 담당하고
# 큐 관리·업그레이드 적용은 main이 한다. 정지 중에만 동작(WHEN_PAUSED).
extends CanvasLayer

signal option_chosen(index: int)

const PANEL_MIN_WIDTH := 420.0

var options: Array = []  # 표시 중 선택지 — 스모크 검증용 공개 상태
var buttons: Array = []

var _title: Label


func _init() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(PANEL_MIN_WIDTH, 0.0)
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)
	for i in 3:
		var button := Button.new()
		button.pressed.connect(_on_button_pressed.bind(i))
		vbox.add_child(button)
		buttons.append(button)


func show_entry(title: String, new_options: Array) -> void:
	options = new_options
	_title.text = title
	for i in buttons.size():
		var has_option: bool = i < options.size()
		buttons[i].visible = has_option
		if has_option:
			buttons[i].text = "%s — %s" % [options[i]["name"], options[i]["desc"]]
	visible = true


func close() -> void:
	visible = false
	options = []


func _on_button_pressed(index: int) -> void:
	option_chosen.emit(index)
