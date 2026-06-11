# 타깃 선정(가장 가까운 적·광역 범위 내 다수) 순수 로직 테스트.
extends "res://test/test_case.gd"

const Targeting = preload("res://scripts/logic/targeting.gd")


func test_empty_returns_minus_one() -> void:
	assert_eq(Targeting.nearest_index(Vector2.ZERO, []), -1)


func test_single_candidate() -> void:
	assert_eq(Targeting.nearest_index(Vector2.ZERO, [Vector2(10, 0)]), 0)


func test_nearest_among_many() -> void:
	var positions := [Vector2(100, 0), Vector2(5, 5), Vector2(-30, 0)]
	assert_eq(Targeting.nearest_index(Vector2.ZERO, positions), 1)


func test_tie_picks_first_index() -> void:
	var positions := [Vector2(10, 0), Vector2(-10, 0)]
	assert_eq(Targeting.nearest_index(Vector2.ZERO, positions), 0)


func test_max_range_excludes_far_targets() -> void:
	assert_eq(Targeting.nearest_index(Vector2.ZERO, [Vector2(100, 0)], 50.0), -1)


func test_max_range_boundary_inclusive() -> void:
	assert_eq(Targeting.nearest_index(Vector2.ZERO, [Vector2(50, 0)], 50.0), 0)


func test_origin_offset() -> void:
	var positions := [Vector2(0, 0), Vector2(190, 0)]
	assert_eq(Targeting.nearest_index(Vector2(200, 0), positions), 1)


# --- indices_within — 광역 베기(다중 타격)의 범위 내 대상 선정 ---


func test_within_empty_returns_empty() -> void:
	assert_eq(Targeting.indices_within(Vector2.ZERO, [], 50.0), [])


func test_within_collects_all_in_radius() -> void:
	var positions := [Vector2(10, 0), Vector2(0, 20), Vector2(-30, 0)]
	assert_eq(Targeting.indices_within(Vector2.ZERO, positions, 50.0), [0, 1, 2])


func test_within_excludes_outside_radius() -> void:
	var positions := [Vector2(10, 0), Vector2(100, 0), Vector2(0, 40)]
	assert_eq(Targeting.indices_within(Vector2.ZERO, positions, 50.0), [0, 2])


func test_within_boundary_inclusive() -> void:
	assert_eq(Targeting.indices_within(Vector2.ZERO, [Vector2(50, 0)], 50.0), [0])


func test_within_none_in_radius_returns_empty() -> void:
	assert_eq(Targeting.indices_within(Vector2.ZERO, [Vector2(100, 0)], 50.0), [])


func test_within_origin_offset() -> void:
	var positions := [Vector2(0, 0), Vector2(190, 0)]
	assert_eq(Targeting.indices_within(Vector2(200, 0), positions, 30.0), [1])
