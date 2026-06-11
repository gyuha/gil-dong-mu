# S3 스모크 — 메인 씬을 띄우고 (1) 오라 안 잡귀가 기본 속도보다 느리게 움직이는지,
# (2) 스페이스 밀쳐내기가 MP를 소비하며 잡귀를 바깥으로 밀어내는지 헤드리스로 검증한다.
# 실행: godot --headless --fixed-fps 60 --script test/smoke_s3.gd
# (test_runner가 수집하는 test_*.gd 가 아니므로 단위 테스트에는 포함되지 않는다.)
extends SceneTree


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.add_child(Monitor.new())


class Monitor extends Node:
	const MAX_FRAMES := 18000  # 고정 60fps 기준 300 게임초 — 잡귀가 오라까지 살아오는 데 운이 필요
	const MEASURE_FRAMES := 20

	var _frames := 0
	var _phase := "wait_aura"  # wait_aura → measure_slow → repel → check_repel
	var _tracked: Node2D
	var _last_pos := Vector2.ZERO
	var _moves: Array[float] = []
	var _mp_before := 0.0
	var _dist_before := 0.0
	var _slow_ok := false
	var _check_wait := 0

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
			"wait_aura":
				_wait_aura(munyeo)
			"measure_slow":
				_measure_slow(munyeo)
			"repel":
				_do_repel(munyeo)
			"check_repel":
				_check_repel(munyeo)

	func _wait_aura(munyeo: Node2D) -> void:
		for enemy in get_tree().get_nodes_in_group("japgwi"):
			var dist: float = munyeo.global_position.distance_to(enemy.global_position)
			# 접촉 정지 전·오라 안 구간에서 추적 시작
			if dist <= munyeo.AURA_RADIUS and dist > 60.0:
				_tracked = enemy
				_last_pos = enemy.global_position
				_moves.clear()
				_phase = "measure_slow"
				return

	func _measure_slow(munyeo: Node2D) -> void:
		if not is_instance_valid(_tracked):
			_phase = "wait_aura"  # 부적에 죽음 — 다음 잡귀로 재시도
			return
		_moves.append(_tracked.global_position.distance_to(_last_pos))
		_last_pos = _tracked.global_position
		if _moves.size() < MEASURE_FRAMES:
			return
		var avg := 0.0
		for m in _moves:
			avg += m
		avg /= _moves.size()
		var base_per_frame: float = _tracked.SPEED / 60.0
		var expected: float = base_per_frame * munyeo.AURA_SLOW_MULTIPLIER
		print("slow check — avg %.3f px/frame (base %.3f, expected %.3f)" % [
			avg, base_per_frame, expected,
		])
		if avg > base_per_frame * 0.75:
			printerr("SMOKE FAIL — 오라 안 잡귀가 느려지지 않음")
			get_tree().quit(1)
			return
		_slow_ok = true
		_phase = "repel"

	func _do_repel(munyeo: Node2D) -> void:
		if not is_instance_valid(_tracked):
			_phase = "wait_aura"
			return
		_mp_before = munyeo.mp
		_dist_before = munyeo.global_position.distance_to(_tracked.global_position)
		_press_space(true)
		_phase = "check_repel"

	func _check_repel(munyeo: Node2D) -> void:
		_press_space(false)
		if not is_instance_valid(_tracked):
			printerr("SMOKE FAIL — 밀쳐내기 확인 전에 추적 잡귀 소멸")
			get_tree().quit(1)
			return
		var dist_after: float = munyeo.global_position.distance_to(_tracked.global_position)
		var mp_spent: float = _mp_before - munyeo.mp
		if mp_spent < munyeo.REPEL_COST * 0.9:
			# 입력 주입이 아직 반영되지 않았을 수 있다 — 몇 프레임 대기
			_check_wait += 1
			if _check_wait > 10:
				printerr("SMOKE FAIL — 밀쳐내기가 MP를 소비하지 않음")
				get_tree().quit(1)
			return
		print("repel check — dist %.1f → %.1f, MP %.1f → %.1f" % [
			_dist_before, dist_after, _mp_before, munyeo.mp,
		])
		if dist_after < _dist_before + munyeo.REPEL_DISTANCE * 0.5:
			printerr("SMOKE FAIL — 잡귀가 밀려나지 않음")
			get_tree().quit(1)
			return
		print("SMOKE OK — 감속 %s + 밀쳐내기 (frame %d)" % [str(_slow_ok), _frames])
		get_tree().quit(0)

	func _press_space(pressed: bool) -> void:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_SPACE
		ev.pressed = pressed
		Input.parse_input_event(ev)
