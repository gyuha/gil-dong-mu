# 혼불 전달 규칙 순수 로직 테스트 — 보유 혼불을 반경 내 가장 가까운 동료에게 전부 주고(전달 시
# 무녀 몫 0), 반경 내 동료가 없으면 지연(absorb_delay) 후 무녀가 전량 흡수한다.
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


# --- 지연 흡수(absorb_tick) — 반경 내 동료 부재 시 absorb_delay 후 무녀가 전량 흡수 ---


func test_absorb_zero_stock_resets_timer() -> void:
	var result := SoulfireShare.absorb_tick(0, 2.5, 0.1, 3.0)
	assert_almost_eq(result["timer"], 0.0)
	assert_eq(result["absorbed"], 0)
	assert_eq(result["stock"], 0)


func test_absorb_timer_accumulates_before_delay() -> void:
	var result := SoulfireShare.absorb_tick(5, 1.0, 0.5, 3.0)
	assert_almost_eq(result["timer"], 1.5)
	assert_eq(result["absorbed"], 0)
	assert_eq(result["stock"], 5)


func test_absorb_at_delay_boundary_absorbs_all() -> void:
	var result := SoulfireShare.absorb_tick(5, 2.9, 0.1, 3.0)
	assert_eq(result["absorbed"], 5)
	assert_eq(result["stock"], 0)
	assert_almost_eq(result["timer"], 0.0)


func test_absorb_past_delay_absorbs_all() -> void:
	var result := SoulfireShare.absorb_tick(7, 3.5, 0.5, 3.0)
	assert_eq(result["absorbed"], 7)
	assert_eq(result["stock"], 0)
	assert_almost_eq(result["timer"], 0.0)


# 전달한 몫은 무녀에게 절대 남지 않는다 — 전달 직후(stock 0) 흡수가 일어나지 않는다.
func test_transfer_then_no_absorb_for_munyeo() -> void:
	var transfer := SoulfireShare.distribute(6, [40.0], 90.0)
	assert_eq(transfer["given"], 6)
	assert_eq(transfer["stock"], 0)
	var absorb := SoulfireShare.absorb_tick(transfer["stock"], 10.0, 0.1, 3.0)
	assert_eq(absorb["absorbed"], 0)
	assert_almost_eq(absorb["timer"], 0.0)
