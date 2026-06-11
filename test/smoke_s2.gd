# S2 스모크 — 메인 씬을 띄우고 자동 조종으로 무녀를 혼불까지 걷게 해
# "잡귀 처치 → 혼불 수집 → 레벨업" 전 경로를 헤드리스로 검증한다.
# 실행: godot --headless --fixed-fps 60 --script test/smoke_s2.gd
# (test_runner가 수집하는 test_*.gd 가 아니므로 단위 테스트에는 포함되지 않는다.)
extends SceneTree


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var pilot: Node = load("res://test/smoke_autopilot.gd").new()
	root.add_child(pilot)
