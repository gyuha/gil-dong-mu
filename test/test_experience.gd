# 경험치 → 레벨 곡선 순수 로직 테스트.
extends "res://test/test_case.gd"

const Experience = preload("res://scripts/logic/experience.gd")


func test_required_curve_values() -> void:
	assert_eq(Experience.xp_required(1), 5)
	assert_eq(Experience.xp_required(2), 8)
	assert_eq(Experience.xp_required(3), 11)


func test_required_curve_monotonic() -> void:
	for level in range(1, 10):
		assert_true(Experience.xp_required(level + 1) > Experience.xp_required(level))


func test_gain_without_level_up() -> void:
	var r := Experience.apply_xp(1, 0, 4)
	assert_eq(r["level"], 1)
	assert_eq(r["xp"], 4)


func test_exact_threshold_levels_up_with_zero_remainder() -> void:
	var r := Experience.apply_xp(1, 4, 1)
	assert_eq(r["level"], 2)
	assert_eq(r["xp"], 0)


func test_multi_level_up_in_one_gain() -> void:
	# Lv1→2 에 5, Lv2→3 에 8 필요. 14 획득 → Lv3, 잔여 1.
	var r := Experience.apply_xp(1, 0, 14)
	assert_eq(r["level"], 3)
	assert_eq(r["xp"], 1)


func test_zero_gain_is_noop() -> void:
	var r := Experience.apply_xp(2, 3, 0)
	assert_eq(r["level"], 2)
	assert_eq(r["xp"], 3)
