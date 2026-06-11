# S6 스모크 — 메인 씬을 띄우고 자동 조종으로
# (1) 창귀가 스폰되어 체력이 가장 낮은 동료를 노리는지,
# (2) 쓰러진 화랑에 무녀가 근접을 유지하면 구출되는지,
# (3) 쓰러진 활잡이를 방치(멀리 이탈)하면 제한 시간 후 그 밤에서 빠지는지 검증한다.
# 쓰러짐 자체는 take_damage(공개 API)로 강제한다 — 창귀 압박의 자연 발생은 수동 플레이 검증.
# 실행: godot --headless --fixed-fps 60 --script test/smoke_s6.gd
extends SceneTree


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.add_child(Monitor.new())


class Monitor extends Node:
	const MAX_FRAMES := 18000  # 고정 60fps 기준 300 게임초
	const DEADZONE := 8.0

	var _frames := 0
	var _phase := "observe_changgwi"  # → rescue_success → rescue_fail
	var _held := {}
	var _hwarang: Node2D
	var _archer: Node2D
	var _captured := false
	var _forced := false

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS  # 드래프트 일시정지 중에도 동작

	func _process(_delta: float) -> void:
		_frames += 1
		if _frames > MAX_FRAMES:  # pause 분기보다 먼저 — 결과 화면(S7) 정지에서 행 방지
			printerr("SMOKE FAIL — 제한 프레임 초과 (phase %s)" % _phase)
			get_tree().quit(1)
			return
		if get_tree().paused:  # 드래프트 — 첫 선택지를 골라 재개
			var ui: CanvasLayer = get_node_or_null("/root/Main/DraftUI")
			if ui != null and ui.visible:
				ui.buttons[0].pressed.emit()
			return
		var munyeo: Node2D = get_node_or_null("/root/Main/Munyeo")
		if munyeo == null:
			return
		_capture_companions()
		if not _captured:
			return
		match _phase:
			"observe_changgwi":
				_observe_changgwi()
			"rescue_success":
				_rescue_success(munyeo)
			"rescue_fail":
				_rescue_fail(munyeo)

	# 첫 프레임에 동료 직접 참조 확보 — 쓰러지면 그룹에서 빠지므로 그룹 조회로는 못 쫓는다.
	# (freed 객체는 == null 비교가 true가 되므로, 확보 여부는 플래그로 기억한다.)
	func _capture_companions() -> void:
		if _captured:
			return
		for companion in get_tree().get_nodes_in_group("companion"):
			if companion.display_name == "화랑":
				_hwarang = companion
			elif companion.display_name == "활잡이":
				_archer = companion
		_captured = _hwarang != null and _archer != null

	# 창귀가 등장하면, 그 순간 체력이 더 낮은 동료를 노리는지 확인한다.
	func _observe_changgwi() -> void:
		var changgwis := get_tree().get_nodes_in_group("changgwi")
		if changgwis.is_empty():
			return
		if _hwarang.downed or _archer.downed:
			return  # 둘 다 서 있을 때만 판정
		if is_equal_approx(_hwarang.hp, _archer.hp):
			return  # 동률은 다음 프레임에 재판정
		var expected: Node2D = _archer if _archer.hp < _hwarang.hp else _hwarang
		var chase: Node2D = changgwis[0]._chase_target()
		if chase != expected:
			printerr("SMOKE FAIL — 창귀가 최저 체력 동료(%s)가 아닌 %s를 노림" % [
				expected.display_name, str(chase),
			])
			get_tree().quit(1)
			return
		print("창귀 타깃 확인 — 최저 체력 동료 %s (frame %d)" % [
			expected.display_name, _frames,
		])
		_phase = "rescue_success"

	# 화랑을 강제로 쓰러뜨리고 무녀를 붙여 구출 성공을 확인한다.
	func _rescue_success(munyeo: Node2D) -> void:
		if not _forced:
			_forced = true
			_hwarang.take_damage(9999)
			if not _hwarang.downed:
				printerr("SMOKE FAIL — HP 0인데 쓰러짐 상태가 아님")
				get_tree().quit(1)
				return
			print("화랑 강제 쓰러짐 — 무녀가 구출하러 간다 (frame %d)" % _frames)
		if not is_instance_valid(_hwarang):
			printerr("SMOKE FAIL — 구출 도착 전에 화랑이 이탈함")
			get_tree().quit(1)
			return
		if _hwarang.downed:
			_steer(munyeo, _hwarang.global_position)
			return
		if _hwarang.hp <= 0.0:
			printerr("SMOKE FAIL — 구출됐는데 HP가 0")
			get_tree().quit(1)
			return
		print("구출 성공 — 화랑 HP %.0f (frame %d)" % [_hwarang.hp, _frames])
		_release_all()
		_forced = false
		_phase = "rescue_fail"

	# 활잡이를 강제로 쓰러뜨리고 무녀를 멀리 보내 구출 실패(이탈)를 확인한다.
	func _rescue_fail(munyeo: Node2D) -> void:
		if not _forced:
			_forced = true
			_archer.take_damage(9999)
			print("활잡이 강제 쓰러짐 — 방치해 이탈을 기다린다 (frame %d)" % _frames)
		if is_instance_valid(_archer) and _archer.downed:
			_steer(munyeo, _far_corner(_archer.global_position))
			return
		if is_instance_valid(_archer):
			printerr("SMOKE FAIL — 방치했는데 활잡이가 구출돼버림")
			get_tree().quit(1)
			return
		print("SMOKE OK — 창귀 타깃 + 구출 성공 + 구출 실패 이탈 (frame %d)" % _frames)
		get_tree().quit(0)

	func _far_corner(from: Vector2) -> Vector2:
		var corners := [
			Vector2(40, 40), Vector2(1240, 40), Vector2(40, 680), Vector2(1240, 680),
		]
		var best: Vector2 = corners[0]
		var best_dist := -1.0
		for corner in corners:
			var dist: float = from.distance_to(corner)
			if dist > best_dist:
				best_dist = dist
				best = corner
		return best

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
