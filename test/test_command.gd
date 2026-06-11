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


func test_engage_range_aggressive_wider_than_nearby() -> void:
	assert_true(
		Command.params(Command.AGGRESSIVE)["engage_range"]
		> Command.params(Command.NEARBY)["engage_range"],
	)


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
