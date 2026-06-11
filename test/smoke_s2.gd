# S2 스모크 — 메인 씬을 띄우고 자동 조종으로
# "동료가 잡귀 처치 → 무녀가 혼불 수집 → 동료 반경 밖 도주 → 지연 흡수 → 레벨업"
# 전 경로를 헤드리스로 검증한다(무녀는 공격하지 않는다 — ADR-0003).
# 실행: godot --headless --fixed-fps 60 --script test/smoke_s2.gd
# (test_runner가 수집하는 test_*.gd 가 아니므로 단위 테스트에는 포함되지 않는다.)
extends SceneTree


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var pilot: Node = load("res://test/smoke_autopilot.gd").new()
	root.add_child(pilot)
