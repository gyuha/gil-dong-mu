# S7 스모크 — 메인 씬을 띄우고 밤 루프 전체 사이클을 검증한다.
# (1) 밤 시간을 만료 직전으로 당겨 생존 만료 → 승리 결과 화면,
# (2) 재시작 버튼 → 새 밤(시간·무녀 리셋, 재개),
# (3) 무녀 강제 사망 → 패배 결과 화면,
# (4) 다시 재시작 → 새 밤이 정상 진행.
# 3분 실주행은 수동 플레이 검증 — 여기서는 시간을 당겨 배선만 확인한다.
# 실행: godot --headless --fixed-fps 60 --script test/smoke_s7.gd
extends SceneTree


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.add_child(Monitor.new())


class Monitor extends Node:
	const MAX_FRAMES := 7200  # 고정 60fps 기준 120 게임초

	var _frames := 0
	var _phase := "force_victory"  # → victory_restart → force_defeat → defeat_restart
	var _forced := false

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS  # 정지(드래프트·결과 화면) 중에도 동작

	func _process(_delta: float) -> void:
		_frames += 1
		if _frames > MAX_FRAMES:
			printerr("SMOKE FAIL — 제한 프레임 초과 (phase %s)" % _phase)
			get_tree().quit(1)
			return
		if get_tree().paused:
			var draft: CanvasLayer = get_node_or_null("/root/Main/DraftUI")
			if draft != null and draft.visible:
				draft.buttons[0].pressed.emit()  # 드래프트 — 첫 선택지를 골라 재개
				return
			# 결과 화면 정지 — 아래 phase 로직이 처리한다.
		var main: Node2D = get_node_or_null("/root/Main")
		var munyeo: Node2D = get_node_or_null("/root/Main/Munyeo")
		if main == null or munyeo == null:
			return
		match _phase:
			"force_victory":
				_force_victory(main)
			"victory_restart":
				_check_restart(main, munyeo, "force_defeat", "승리 후")
			"force_defeat":
				_force_defeat(main, munyeo)
			"defeat_restart":
				_check_restart(main, munyeo, "done", "패배 후")

	# 첫 처치(통계 검증용)를 기다린 뒤 밤 시간을 만료 0.5초 전으로 당기고,
	# 승리 결과 화면을 기다린다.
	func _force_victory(main: Node2D) -> void:
		if not _forced:
			if main._kills < 1:
				return  # 동료 화력이 첫 잡귀를 잡을 때까지 대기 (무녀는 공격하지 않는다)
			_forced = true
			main._night_time = 179.5
			print("첫 처치 후 밤 시간 당김 — 만료 0.5초 전 (frame %d)" % _frames)
			return
		var result := _visible_result()
		if result == null:
			return
		if not result.title.text.contains("승리"):
			printerr("SMOKE FAIL — 생존 만료인데 결과가 승리가 아님: %s" % result.title.text)
			get_tree().quit(1)
			return
		if not result.stats.text.contains("처치 %d" % main._kills):
			printerr("SMOKE FAIL — 처치 통계 불일치: %s (실제 %d)" % [
				result.stats.text, main._kills,
			])
			get_tree().quit(1)
			return
		print("승리 결과 확인 — %s / %s (frame %d)" % [
			result.title.text, result.stats.text, _frames,
		])
		_restart(result, "victory_restart")

	# 무녀를 강제 사망시키고, 패배 결과 화면을 기다린다.
	func _force_defeat(main: Node2D, munyeo: Node2D) -> void:
		if not _forced:
			_forced = true
			munyeo.take_damage(9999)
			print("무녀 강제 사망 (frame %d)" % _frames)
			return
		var result := _visible_result()
		if result == null:
			return
		if not result.title.text.contains("패배"):
			printerr("SMOKE FAIL — 무녀 HP 0인데 결과가 패배가 아님: %s" % result.title.text)
			get_tree().quit(1)
			return
		print("패배 결과 확인 — %s / %s (frame %d)" % [
			result.title.text, result.stats.text, _frames,
		])
		_restart(result, "defeat_restart")

	# 재시작 후 새 밤이 깨끗하게 시작됐는지 — 재개·시간 리셋·무녀 HP 만피.
	func _check_restart(main: Node2D, munyeo: Node2D, next_phase: String, label: String) -> void:
		if get_tree().paused or main._night_over:
			return  # 리셋은 한 프레임 미뤄진다(call_deferred)
		if main._night_time > 5.0 or munyeo.hp != munyeo.max_hp:
			printerr("SMOKE FAIL — %s 재시작인데 리셋이 안 됨 (시간 %.1f, HP %d/%d)" % [
				label, main._night_time, munyeo.hp, munyeo.max_hp,
			])
			get_tree().quit(1)
			return
		print("%s 재시작 확인 — 새 밤 진행 중 (frame %d)" % [label, _frames])
		if next_phase == "done":
			print("SMOKE OK — 승리·패배·재시작 전체 사이클 (frame %d)" % _frames)
			get_tree().quit(0)
			return
		_forced = false
		_phase = next_phase

	func _visible_result() -> CanvasLayer:
		var result: CanvasLayer = get_node_or_null("/root/Main/ResultUI")
		if result != null and result.visible and get_tree().paused:
			return result
		return null

	func _restart(result: CanvasLayer, next_phase: String) -> void:
		result.restart_button.pressed.emit()
		_phase = next_phase
