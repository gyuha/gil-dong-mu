# 명령 4종(주변/공격적/방어적/모여라)별 행동 파라미터 순수 로직 테스트.
extends "res://test/test_case.gd"

const Command = preload("res://scripts/logic/command.gd")

const REQUIRED_KEYS := ["leash", "engage_range", "retreat_hp_ratio", "follow_distance"]


func test_all_commands_have_required_keys() -> void:
	for cmd in [Command.NEARBY, Command.AGGRESSIVE, Command.DEFENSIVE, Command.RALLY]:
		var p := Command.params(cmd)
		for key in REQUIRED_KEYS:
			assert_true(p.has(key), "command %d missing key %s" % [cmd, key])


func test_leash_order_aggressive_widest_defensive_narrow() -> void:
	var nearby := Command.params(Command.NEARBY)
	var aggressive := Command.params(Command.AGGRESSIVE)
	var defensive := Command.params(Command.DEFENSIVE)
	assert_true(aggressive["leash"] > nearby["leash"], "공격적 leash가 주변보다 넓어야 함")
	assert_true(nearby["leash"] > defensive["leash"], "주변 leash가 방어적보다 넓어야 함")


func test_engage_range_order_aggressive_nearby_defensive() -> void:
	var nearby: float = Command.params(Command.NEARBY)["engage_range"]
	var aggressive: float = Command.params(Command.AGGRESSIVE)["engage_range"]
	var defensive: float = Command.params(Command.DEFENSIVE)["engage_range"]
	assert_true(aggressive > nearby, "공격적 engage_range가 주변보다 넓어야 함")
	assert_true(nearby > defensive, "주변 engage_range가 방어적보다 넓어야 함")


func test_nearby_default_charges_far_enemies() -> void:
	# 기본 '주변에서 싸워'부터 적극 돌격 — 화면 절반 이상을 탐지·추격한다.
	var nearby := Command.params(Command.NEARBY)
	assert_almost_eq(nearby["engage_range"], 700.0)
	assert_almost_eq(nearby["leash"], 900.0)


func test_aggressive_leash_covers_whole_arena() -> void:
	# 공격적 = 사실상 무제한 추격. 경기장 대각선(약 1469)을 넉넉히 넘는다.
	var aggressive := Command.params(Command.AGGRESSIVE)
	assert_true(aggressive["leash"] >= 1500.0, "공격적 leash는 경기장 전체를 덮어야 함")
	assert_true(aggressive["engage_range"] >= 1500.0,
		"공격적 engage_range는 경기장 전체를 덮어야 함")


func test_defensive_is_old_nearby_level() -> void:
	# 방어적 = 종전 '주변' 수준의 소극 교전.
	var defensive := Command.params(Command.DEFENSIVE)
	assert_almost_eq(defensive["engage_range"], 340.0)
	assert_almost_eq(defensive["leash"], 260.0)


func test_rally_disables_engagement() -> void:
	assert_almost_eq(Command.params(Command.RALLY)["engage_range"], 0.0)


func test_rally_follow_distance_is_smallest() -> void:
	var rally: float = Command.params(Command.RALLY)["follow_distance"]
	for cmd in [Command.NEARBY, Command.AGGRESSIVE, Command.DEFENSIVE]:
		assert_true(rally < Command.params(cmd)["follow_distance"],
			"모여라 follow_distance가 command %d 보다 작아야 함" % cmd)


func test_retreat_ratio_defensive_highest_aggressive_zero() -> void:
	var nearby: float = Command.params(Command.NEARBY)["retreat_hp_ratio"]
	var defensive: float = Command.params(Command.DEFENSIVE)["retreat_hp_ratio"]
	assert_true(defensive > nearby, "방어적 후퇴 기준이 주변보다 높아야 함")
	assert_almost_eq(Command.params(Command.AGGRESSIVE)["retreat_hp_ratio"], 0.0)


func test_unknown_command_falls_back_to_nearby() -> void:
	assert_eq(Command.params(99), Command.params(Command.NEARBY))
