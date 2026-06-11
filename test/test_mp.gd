# MP 소비·자연 회복 규칙 순수 로직 테스트.
extends "res://test/test_case.gd"

const Mp = preload("res://scripts/logic/mp.gd")


# --- regen: 자연 회복 ---

func test_regen_adds_rate_times_delta() -> void:
	assert_almost_eq(Mp.regen(50.0, 100.0, 10.0, 0.5), 55.0)


func test_regen_clamps_at_max() -> void:
	assert_almost_eq(Mp.regen(99.0, 100.0, 10.0, 1.0), 100.0)


func test_regen_at_max_stays() -> void:
	assert_almost_eq(Mp.regen(100.0, 100.0, 10.0, 1.0), 100.0)


# --- try_spend: 소비, 부족 시 불발 ---

func test_spend_success() -> void:
	var result := Mp.try_spend(100.0, 30.0)
	assert_true(result["ok"])
	assert_almost_eq(result["mp"], 70.0)


func test_spend_insufficient_fails_and_keeps_mp() -> void:
	var result := Mp.try_spend(20.0, 30.0)
	assert_false(result["ok"])
	assert_almost_eq(result["mp"], 20.0)


func test_spend_exact_cost_succeeds() -> void:
	var result := Mp.try_spend(30.0, 30.0)
	assert_true(result["ok"])
	assert_almost_eq(result["mp"], 0.0)
