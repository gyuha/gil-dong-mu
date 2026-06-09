extends SceneTree
## 헤드리스 테스트 러너 (GUT 애드온 의존 없음 — 일회용 게이트에 맞는 자급 테스트).
## 실행: godot --headless --path . --script res://test/test_runner.gd
## class_name 전역 등록에 의존하지 않도록 preload로 스크립트를 직접 로드해 static 호출.

const Targeting = preload("res://scripts/targeting.gd")
const Stance = preload("res://scripts/stance.gd")
const ReviveUtil = preload("res://scripts/revive_util.gd")
const Roster = preload("res://scripts/roster.gd")
const CompanionScript = preload("res://scripts/companion.gd")

var _pass := 0
var _fail := 0

func _ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		printerr("  FAIL: ", msg)

func _initialize() -> void:
	print("=== gil-dong-mu 게이트 결정로직 테스트 ===")

	# --- targeting: 빈 후보 → -1 ---
	_ok(Targeting.select_target(Vector2.ZERO, Vector2.ZERO, [], Stance.params(Stance.Type.AGGRESSIVE), -1) == -1,
		"빈 후보 배열은 -1")

	# --- targeting: 가장 가까운 적 선택 ---
	var cands := [
		{"id": 1, "pos": Vector2(100, 0)},
		{"id": 2, "pos": Vector2(50, 0)},   # 더 가까움
		{"id": 3, "pos": Vector2(300, 0)},
	]
	var aggr := Stance.params(Stance.Type.AGGRESSIVE)
	_ok(Targeting.select_target(Vector2.ZERO, Vector2.ZERO, cands, aggr, -1) == 2,
		"공격적: 가장 가까운 적(id=2) 선택")

	# --- targeting: leash 밖 적 제외 (사수 스탠스, anchor 원점) ---
	var hold := Stance.params(Stance.Type.HOLD)  # leash 150
	var far_cands := [
		{"id": 10, "pos": Vector2(500, 0)},  # leash 밖
		{"id": 11, "pos": Vector2(120, 0)},  # leash 안
	]
	_ok(Targeting.select_target(Vector2(120, 0), Vector2.ZERO, far_cands, hold, -1) == 11,
		"사수: leash 밖(id=10) 제외, leash 안(id=11) 선택")
	_ok(Targeting.select_target(Vector2(500, 0), Vector2.ZERO, [{"id": 10, "pos": Vector2(500, 0)}], hold, -1) == -1,
		"사수: leash 밖 적만 있으면 -1")

	# --- targeting: 히스테리시스 — 미세 우위로는 전환 안 함 ---
	# 현재 타깃 id=1 (거리 100). 새 후보 id=2 (거리 95) = 5%만 가까움 → 유지해야 함
	var hyst_cands := [
		{"id": 1, "pos": Vector2(100, 0)},
		{"id": 2, "pos": Vector2(95, 0)},
	]
	_ok(Targeting.select_target(Vector2.ZERO, Vector2.ZERO, hyst_cands, aggr, 1) == 1,
		"히스테리시스: 5% 우위로는 현재 타깃(id=1) 유지")

	# --- targeting: 히스테리시스 — 유의미한 우위면 전환 ---
	# 현재 id=1 (거리 100). 새 후보 id=2 (거리 50) = 50% 가까움 → 전환해야 함
	var hyst_cands2 := [
		{"id": 1, "pos": Vector2(100, 0)},
		{"id": 2, "pos": Vector2(50, 0)},
	]
	_ok(Targeting.select_target(Vector2.ZERO, Vector2.ZERO, hyst_cands2, aggr, 1) == 2,
		"히스테리시스: 50% 우위면 새 타깃(id=2)으로 전환")

	# --- targeting: 현재 타깃이 leash 밖으로 이탈 → 드롭 후 재선정 ---
	var drop_cands := [
		{"id": 1, "pos": Vector2(500, 0)},  # 현재 타깃, leash 밖
		{"id": 2, "pos": Vector2(100, 0)},  # leash 안
	]
	_ok(Targeting.select_target(Vector2(100, 0), Vector2.ZERO, drop_cands, hold, 1) == 2,
		"현재 타깃 leash 이탈 시 leash 안 적(id=2)으로 재선정")

	# --- stance: 3종이 서로 다른 leash ---
	_ok(Stance.params(Stance.Type.AGGRESSIVE)["leash"] > Stance.params(Stance.Type.DEFENSIVE)["leash"]
		and Stance.params(Stance.Type.DEFENSIVE)["leash"] > Stance.params(Stance.Type.HOLD)["leash"],
		"스탠스 leash: 공격적 > 방어적 > 사수")

	# --- revive: 반경 경계 ---
	_ok(ReviveUtil.can_revive(Vector2.ZERO, Vector2(40, 0), 50.0) == true, "부활: 반경 안=true")
	_ok(ReviveUtil.can_revive(Vector2.ZERO, Vector2(60, 0), 50.0) == false, "부활: 반경 밖=false")
	_ok(ReviveUtil.can_revive(Vector2.ZERO, Vector2(50, 0), 50.0) == true, "부활: 경계 정확히=true")

	# --- roster: 6종 + 스탯 주입 (단일 FSM이 데이터로 6종 표현) ---
	var rs := Roster.roster()
	_ok(rs.size() == 6, "로스터 6종")
	var comp = CompanionScript.new()
	comp.setup(null, null, Stance.Type.AGGRESSIVE, rs[3])  # 방벽
	_ok(comp.max_hp == 165.0, "스탯 주입: 방벽 HP 165")
	_ok(comp.display_name == "방벽" and comp.attack_range == 34.0, "스탯 주입: 이름/사거리")
	comp.free()

	print("=== 통과 %d / 실패 %d ===" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
