# 밤 루프 승패 판정·시간 표기 순수 로직 테스트.
# 규칙: 무녀 HP 0 = 패배(타이머 만료와 같은 틱이면 패배 우선),
# 타이머 만료 + 무녀 생존 = 승리, 그 외 진행 중.
# 동료 전멸은 패배가 아니다 — 판정 입력에 동료 상태 자체가 없다.
extends "res://test/test_case.gd"

const Night = preload("res://scripts/logic/night.gd")


func test_duration_is_three_minutes() -> void:
	assert_almost_eq(Night.DURATION, 180.0)


func test_ongoing_while_alive_and_time_remains() -> void:
	assert_eq(Night.outcome(120.0, 50), "ongoing")


func test_ongoing_at_one_hp() -> void:
	assert_eq(Night.outcome(0.1, 1), "ongoing")


func test_victory_when_timer_expires_alive() -> void:
	assert_eq(Night.outcome(0.0, 1), "victory")


func test_victory_with_negative_time_left() -> void:
	assert_eq(Night.outcome(-0.5, 100), "victory")


func test_defeat_when_munyeo_hp_zero() -> void:
	assert_eq(Night.outcome(120.0, 0), "defeat")


func test_defeat_wins_over_expiry_same_tick() -> void:
	assert_eq(Night.outcome(0.0, 0), "defeat")


func test_format_time_full() -> void:
	assert_eq(Night.format_time(180.0), "3:00")


func test_format_time_minute_seconds() -> void:
	assert_eq(Night.format_time(65.0), "1:05")


func test_format_time_ceils_partial_second() -> void:
	assert_eq(Night.format_time(0.4), "0:01")


func test_format_time_zero() -> void:
	assert_eq(Night.format_time(0.0), "0:00")


func test_format_time_negative_clamps_to_zero() -> void:
	assert_eq(Night.format_time(-3.0), "0:00")
