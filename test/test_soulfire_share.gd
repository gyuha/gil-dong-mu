# 혼불 분배 규칙 순수 로직 테스트 — 보유 혼불을 반경 내 가장 가까운 동료에게 전부 준다.
extends "res://test/test_case.gd"

const SoulfireShare = preload("res://scripts/logic/soulfire_share.gd")


func test_zero_stock_gives_nothing() -> void:
	var result := SoulfireShare.distribute(0, [10.0], 90.0)
	assert_eq(result["index"], -1)
	assert_eq(result["given"], 0)
	assert_eq(result["stock"], 0)


func test_no_companions_keeps_stock() -> void:
	var result := SoulfireShare.distribute(5, [], 90.0)
	assert_eq(result["index"], -1)
	assert_eq(result["stock"], 5)


func test_none_in_radius_keeps_stock() -> void:
	var result := SoulfireShare.distribute(5, [120.0, 200.0], 90.0)
	assert_eq(result["index"], -1)
	assert_eq(result["stock"], 5)


func test_nearest_in_radius_gets_entire_stock() -> void:
	var result := SoulfireShare.distribute(7, [80.0, 40.0, 95.0], 90.0)
	assert_eq(result["index"], 1)
	assert_eq(result["given"], 7)
	assert_eq(result["stock"], 0)


func test_boundary_distance_inclusive() -> void:
	var result := SoulfireShare.distribute(3, [90.0], 90.0)
	assert_eq(result["index"], 0)
	assert_eq(result["given"], 3)


func test_tie_prefers_front_index() -> void:
	var result := SoulfireShare.distribute(2, [50.0, 50.0], 90.0)
	assert_eq(result["index"], 0)
