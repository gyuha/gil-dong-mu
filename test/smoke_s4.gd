# S4 스모크 — 메인 씬을 띄우고 자동 조종으로
# (1) 혼불 수집→동료 근접 분배로 동료가 Lv 2에 오르는지,
# (2) 탈 쓴 퇴마사가 광역 베기로 다수 적을 동시 타격하고 화랑이 근접 교전하는지,
# (3) 모여라(키 4) 명령에 동료들이 무녀 곁으로 집결하는지 헤드리스로 검증한다.
# 실행: godot --headless --fixed-fps 60 --script test/smoke_s4.gd
# (test_runner가 수집하는 test_*.gd 가 아니므로 단위 테스트에는 포함되지 않는다.)
extends SceneTree


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.add_child(Monitor.new())


class Monitor extends Node:
	const Command = preload("res://scripts/logic/command.gd")

	const MAX_FRAMES := 18000  # 고정 60fps 기준 300 게임초
	const DEADZONE := 8.0
	const RALLY_MARGIN := 20.0

	var _frames := 0
	var _phase := "level_companion"  # level_companion → rally → check_rally
	var _held := {}
	var _sweep_seen := false
	var _melee_seen := false
	var _rally_frames := 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS  # 드래프트 일시정지 중에도 동작

	func _process(_delta: float) -> void:
		_frames += 1
		if _frames > MAX_FRAMES:  # pause 분기보다 먼저 — 결과 화면(S7) 정지에서 행 방지
			printerr("SMOKE FAIL — 제한 프레임 초과 (phase %s, sweep %s, melee %s)" % [
				_phase, str(_sweep_seen), str(_melee_seen),
			])
			get_tree().quit(1)
			return
		if get_tree().paused:  # 드래프트(S5) — 첫 선택지를 골라 재개
			var ui: CanvasLayer = get_node_or_null("/root/Main/DraftUI")
			if ui != null and ui.visible:
				ui.buttons[0].pressed.emit()
			return
		var munyeo: Node2D = get_node_or_null("/root/Main/Munyeo")
		if munyeo == null:
			return
		var companions := get_tree().get_nodes_in_group("companion")
		if companions.size() < 2:
			printerr("SMOKE FAIL — 동료가 %d명 (2명이어야 함, frame %d)" % [
				companions.size(), _frames,
			])
			get_tree().quit(1)
			return
		_observe_traits(companions)
		match _phase:
			"level_companion":
				_level_companion(munyeo, companions)
			"rally":
				_start_rally(munyeo)
			"check_rally":
				_check_rally(munyeo, companions)

	# 성향 관찰 — 퇴마사의 광역 베기 다중 타격(한 베기에 2마리 이상), 화랑의 근접 교전.
	func _observe_traits(companions: Array) -> void:
		if not _sweep_seen:
			for companion in companions:
				if companion.get("last_sweep_hits") != null \
						and companion.last_sweep_hits >= 2:
					_sweep_seen = true
					print("광역 베기 확인 — %s 동시 %d타 (frame %d)" % [
						companion.display_name, companion.last_sweep_hits, _frames,
					])
					break
		if _melee_seen:
			return
		for hwarang in get_tree().get_nodes_in_group("hwarang"):
			for japgwi in get_tree().get_nodes_in_group("japgwi"):
				if hwarang.global_position.distance_to(japgwi.global_position) \
						<= hwarang.attack_range:
					_melee_seen = true
					return

	# 혼불을 주워(보유) 동료에게 다가가 분배 — 아무 동료나 Lv 2 도달까지.
	# 성향(광역 베기·근접 교전)까지 관찰돼야 모여라 단계로 넘어간다(모여라 후엔 교전 안 함).
	func _level_companion(munyeo: Node2D, companions: Array) -> void:
		for companion in companions:
			if companion.level >= 2 and _sweep_seen and _melee_seen:
				print("분배 확인 — %s Lv %d (frame %d, sweep/melee 관찰됨)" % [
					companion.display_name, companion.level, _frames,
				])
				_release_all()
				_phase = "rally"
				return
		var dest := Vector2.ZERO
		var has_dest := false
		if munyeo.soulfire_stock > 0:
			dest = _nearest_in_group(munyeo, "companion")
			has_dest = true
		else:
			var soulfires := get_tree().get_nodes_in_group("soulfire")
			if not soulfires.is_empty():
				dest = _nearest_in_group(munyeo, "soulfire")
				has_dest = true
		if has_dest:
			_steer(munyeo, dest)
		else:
			_release_all()

	func _start_rally(munyeo: Node2D) -> void:
		_set_key(KEY_4, true)
		if munyeo.command == Command.RALLY:
			_set_key(KEY_4, false)
			_phase = "check_rally"

	func _check_rally(munyeo: Node2D, companions: Array) -> void:
		var rally_distance: float = Command.params(Command.RALLY)["follow_distance"] \
				+ RALLY_MARGIN
		for companion in companions:
			if munyeo.global_position.distance_to(companion.global_position) > rally_distance:
				return
		_rally_frames += 1
		if _rally_frames < 10:  # 우연한 통과 방지 — 10프레임 유지 확인
			return
		print("SMOKE OK — 분배 레벨업 + 모여라 집결 + 광역 베기/근접 성향 (frame %d)" % _frames)
		get_tree().quit(0)

	func _nearest_in_group(origin: Node2D, group: String) -> Vector2:
		var nearest := Vector2.ZERO
		var best := INF
		for node in get_tree().get_nodes_in_group(group):
			var dist: float = origin.global_position.distance_to(node.global_position)
			if dist < best:
				best = dist
				nearest = node.global_position
		return nearest

	func _steer(munyeo: Node2D, dest: Vector2) -> void:
		var dir := dest - munyeo.global_position
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
