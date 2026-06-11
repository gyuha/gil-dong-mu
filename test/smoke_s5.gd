# S5 스모크 — 메인 씬을 띄우고 레벨업 드래프트(ADR-0002)를 헤드리스로 검증한다.
# (1) 플레이(혼불 수집) 레벨업 → 일시정지 + 3지선다 표시 → 선택 → 수치 적용 + 재개,
# (2) 한 번에 2레벨 상승 → 한 번의 정지 안에서 큐로 2회 연속 선택 후 일괄 재개,
# (3) 동료 레벨업 → 동료 풀 드래프트 → 선택 → 수치 적용 + 재개.
# 실행: godot --headless --fixed-fps 60 --script test/smoke_s5.gd
# (test_runner가 수집하는 test_*.gd 가 아니므로 단위 테스트에는 포함되지 않는다.)
extends SceneTree


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.add_child(Monitor.new())


class Monitor extends Node:
	const DraftPool = preload("res://scripts/logic/draft_pool.gd")
	const Experience = preload("res://scripts/logic/experience.gd")

	const MAX_FRAMES := 9000  # 고정 60fps 기준 150 게임초
	const DEADZONE := 8.0

	var _frames := 0
	var _phase := "play_levelup"
	var _held := {}
	var _subject: Node2D
	var _expected := {}

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS  # 일시정지 중에도 동작해야 한다

	func _process(_delta: float) -> void:
		_frames += 1
		if _frames > MAX_FRAMES:
			printerr("SMOKE FAIL — 제한 프레임 초과 (phase %s)" % _phase)
			get_tree().quit(1)
			return
		var munyeo: Node2D = get_node_or_null("/root/Main/Munyeo")
		if munyeo == null:
			return
		match _phase:
			"play_levelup":
				_play_levelup(munyeo)
			"verify_apply":
				_verify_apply()
			"queue_double":
				_queue_double(munyeo)
			"queue_pick1":
				_queue_pick(true, "queue_pick2")
			"queue_pick2":
				_queue_pick(true, "queue_done")
			"queue_done":
				_queue_done(munyeo)
			"companion":
				_companion_draft()
			"companion_done":
				_companion_done()

	# (1) 혼불을 주워 자연 레벨업 → 정지 + 3지선다 확인 → 첫 선택지를 고른다.
	func _play_levelup(munyeo: Node2D) -> void:
		if not get_tree().paused:
			_steer(munyeo)
			return
		_release_all()
		var ui := _draft_ui()
		if not ui.visible:
			printerr("SMOKE FAIL — 정지됐는데 드래프트 UI가 보이지 않음")
			get_tree().quit(1)
			return
		var visible_buttons := 0
		for button in ui.buttons:
			if button.visible:
				visible_buttons += 1
		var ids := {}
		for option in ui.options:
			ids[option["id"]] = true
		if visible_buttons != 3 or ids.size() != 3:
			printerr("SMOKE FAIL — 3지선다가 아님 (버튼 %d, 고유 선택지 %d)" % [
				visible_buttons, ids.size(),
			])
			get_tree().quit(1)
			return
		_subject = get_node("/root/Main")._current_subject
		_expected = DraftPool.apply(_subject.draft_stats(), ui.options[0]["id"])
		print("드래프트 정지 확인 — %s (frame %d)" % [ui.options[0]["id"], _frames])
		ui.buttons[0].pressed.emit()
		_phase = "verify_apply"

	# 선택한 업그레이드 수치가 실제 반영됐는지 확인하고, 남은 큐가 있으면 비운다.
	func _verify_apply() -> void:
		if _subject.draft_stats() != _expected:
			printerr("SMOKE FAIL — 업그레이드 수치 미반영: %s != %s" % [
				str(_subject.draft_stats()), str(_expected),
			])
			get_tree().quit(1)
			return
		if get_tree().paused:  # 같은 정지에 쌓인 추가 드래프트 — 비운다
			_draft_ui().buttons[0].pressed.emit()
			return
		print("정지→선택→수치 적용→재개 확인 (frame %d)" % _frames)
		_phase = "queue_double"

	# (2) 한 번의 획득으로 정확히 2레벨 상승 → 즉시 정지돼야 한다.
	func _queue_double(munyeo: Node2D) -> void:
		if get_tree().paused:  # 자연 레벨업과 겹침 — 먼저 비운다
			_draft_ui().buttons[0].pressed.emit()
			return
		var before_level: int = munyeo.level
		var needed: int = (munyeo.xp_to_next() - munyeo.xp) \
				+ Experience.xp_required(munyeo.level + 1)
		munyeo.gain_xp(needed)
		if not get_tree().paused or munyeo.level != before_level + 2:
			printerr("SMOKE FAIL — 2레벨 상승 즉시 정지 안 됨 (paused %s, Lv %d→%d)" % [
				str(get_tree().paused), before_level, munyeo.level,
			])
			get_tree().quit(1)
			return
		_phase = "queue_pick1"

	# 정지가 유지된 채 선택을 한 번 수행 — 두 번째 선택까지 같은 정지여야 한다(ADR-0002).
	func _queue_pick(expect_paused: bool, next_phase: String) -> void:
		if get_tree().paused != expect_paused:
			printerr("SMOKE FAIL — %s 에서 paused=%s 기대, 실제 %s" % [
				_phase, str(expect_paused), str(get_tree().paused),
			])
			get_tree().quit(1)
			return
		_draft_ui().buttons[0].pressed.emit()
		_phase = next_phase

	func _queue_done(munyeo: Node2D) -> void:
		if get_tree().paused:
			printerr("SMOKE FAIL — 큐 2회 선택 후에도 재개되지 않음")
			get_tree().quit(1)
			return
		print("한 번의 정지에서 2연속 선택 + 일괄 재개 확인 (Lv %d, frame %d)" % [
			munyeo.level, _frames,
		])
		_phase = "companion"

	# (3) 동료 레벨업 → 동료 풀 드래프트가 뜨는지, 선택이 적용되는지.
	func _companion_draft() -> void:
		if get_tree().paused:  # 자연 레벨업과 겹침 — 먼저 비운다
			_draft_ui().buttons[0].pressed.emit()
			return
		var companions := get_tree().get_nodes_in_group("companion")
		if companions.is_empty():
			printerr("SMOKE FAIL — 동료가 없음")
			get_tree().quit(1)
			return
		var companion: Node2D = companions[0]
		companion.gain_xp(Experience.xp_required(companion.level) - companion.xp)
		if not get_tree().paused:
			printerr("SMOKE FAIL — 동료 레벨업에 정지가 발생하지 않음")
			get_tree().quit(1)
			return
		var ui := _draft_ui()
		for option in ui.options:
			if not String(option["id"]).begins_with("comp_"):
				printerr("SMOKE FAIL — 동료 드래프트에 무녀 선택지: %s" % option["id"])
				get_tree().quit(1)
				return
		_subject = companion
		_expected = DraftPool.apply(companion.draft_stats(), ui.options[0]["id"])
		ui.buttons[0].pressed.emit()
		_phase = "companion_done"

	func _companion_done() -> void:
		if get_tree().paused:
			_draft_ui().buttons[0].pressed.emit()  # 같은 정지에 쌓인 추가 드래프트
			return
		if _subject.draft_stats() != _expected:
			printerr("SMOKE FAIL — 동료 업그레이드 미반영: %s != %s" % [
				str(_subject.draft_stats()), str(_expected),
			])
			get_tree().quit(1)
			return
		print("SMOKE OK — 정지·선택·재개 + 큐 연속 선택 + 동료 드래프트 (frame %d)" % _frames)
		get_tree().quit(0)

	func _draft_ui() -> CanvasLayer:
		return get_node("/root/Main/DraftUI")

	func _steer(munyeo: Node2D) -> void:
		var soulfires := get_tree().get_nodes_in_group("soulfire")
		if soulfires.is_empty():
			_release_all()
			return
		var nearest: Node2D = soulfires[0]
		for soulfire in soulfires:
			if munyeo.global_position.distance_to(soulfire.global_position) \
					< munyeo.global_position.distance_to(nearest.global_position):
				nearest = soulfire
		var dir: Vector2 = nearest.global_position - munyeo.global_position
		_set_key(KEY_A, dir.x < -DEADZONE)
		_set_key(KEY_D, dir.x > DEADZONE)
		_set_key(KEY_W, dir.y < -DEADZONE)
		_set_key(KEY_S, dir.y > DEADZONE)

	func _release_all() -> void:
		for keycode in [KEY_A, KEY_D, KEY_W, KEY_S]:
			_set_key(keycode, false)

	func _set_key(keycode: Key, pressed: bool) -> void:
		if _held.get(keycode, false) == pressed:
			return
		_held[keycode] = pressed
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		ev.pressed = pressed
		Input.parse_input_event(ev)
