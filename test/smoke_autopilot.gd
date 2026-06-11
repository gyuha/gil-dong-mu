# 스모크용 자동 조종 — 키 입력(WASD)을 주입해 무녀를 가장 가까운 혼불로 보낸다.
# 무녀가 Lv 2에 도달하면 성공(종료코드 0), 제한 프레임 초과 시 실패(1).
extends Node

const MAX_FRAMES := 7200  # 고정 60fps 기준 120 게임초
const DEADZONE := 8.0

var _frames := 0
var _held := {}  # physical keycode → pressed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 드래프트 일시정지 중에도 동작


func _process(_delta: float) -> void:
	_frames += 1
	var munyeo: Node2D = get_node_or_null("/root/Main/Munyeo")
	if munyeo == null:
		return
	if munyeo.level >= 2:
		print("SMOKE OK — Lv %d (frame %d, xp %d, hp %d)" % [
			munyeo.level, _frames, munyeo.xp, munyeo.hp,
		])
		get_tree().quit(0)
		return
	if _frames > MAX_FRAMES:
		printerr("SMOKE FAIL — Lv 2 미도달 (xp %d)" % munyeo.xp)
		get_tree().quit(1)
		return
	if get_tree().paused:  # 드래프트(S5) — 첫 선택지를 골라 재개
		_resolve_draft()
		return
	_steer(munyeo)


func _resolve_draft() -> void:
	var ui: CanvasLayer = get_node_or_null("/root/Main/DraftUI")
	if ui != null and ui.visible:
		ui.buttons[0].pressed.emit()


func _steer(munyeo: Node2D) -> void:
	var soulfires := get_tree().get_nodes_in_group("soulfire")
	var dir := Vector2.ZERO
	if not soulfires.is_empty():
		var nearest: Node2D = soulfires[0]
		for s in soulfires:
			var closer := munyeo.global_position.distance_to(s.global_position) \
					< munyeo.global_position.distance_to(nearest.global_position)
			if closer:
				nearest = s
		dir = nearest.global_position - munyeo.global_position
	_set_key(KEY_A, dir.x < -DEADZONE)
	_set_key(KEY_D, dir.x > DEADZONE)
	_set_key(KEY_W, dir.y < -DEADZONE)
	_set_key(KEY_S, dir.y > DEADZONE)


func _set_key(keycode: Key, pressed: bool) -> void:
	if _held.get(keycode, false) == pressed:
		return
	_held[keycode] = pressed
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)
