# 스폰 강도 곡선 순수 로직 테스트.
# 규칙: 밤 경과 시간에 따라 스폰 주기는 base→min 으로 선형 감소,
# 한 번에 스폰하는 수는 base→max 로 선형 증가(소수점 내림).
# 경과 시간은 램프 구간 [0, ramp_time] 에 클램프된다.
extends "res://test/test_case.gd"

const SpawnCurve = preload("res://scripts/logic/spawn_curve.gd")

const RAMP := 180.0


func test_interval_at_start_is_base() -> void:
	assert_almost_eq(SpawnCurve.interval(1.5, 0.5, 0.0, RAMP), 1.5)


func test_interval_at_ramp_end_is_min() -> void:
	assert_almost_eq(SpawnCurve.interval(1.5, 0.5, RAMP, RAMP), 0.5)


func test_interval_midpoint_is_average() -> void:
	assert_almost_eq(SpawnCurve.interval(1.5, 0.5, 90.0, RAMP), 1.0)


func test_interval_clamps_beyond_ramp() -> void:
	assert_almost_eq(SpawnCurve.interval(1.5, 0.5, 999.0, RAMP), 0.5)


func test_interval_clamps_negative_elapsed() -> void:
	assert_almost_eq(SpawnCurve.interval(1.5, 0.5, -10.0, RAMP), 1.5)


func test_batch_count_at_start_is_base() -> void:
	assert_eq(SpawnCurve.batch_count(1, 3, 0.0, RAMP), 1)


func test_batch_count_at_ramp_end_is_max() -> void:
	assert_eq(SpawnCurve.batch_count(1, 3, RAMP, RAMP), 3)


func test_batch_count_midpoint_floors() -> void:
	# lerp(1, 3, 0.5) = 2.0 — 내림으로 2
	assert_eq(SpawnCurve.batch_count(1, 3, 90.0, RAMP), 2)


func test_batch_count_just_before_ramp_end_floors() -> void:
	# lerp(1, 3, 179/180) ≈ 2.99 — 내림으로 2
	assert_eq(SpawnCurve.batch_count(1, 3, 179.0, RAMP), 2)


func test_batch_count_clamps_beyond_ramp() -> void:
	assert_eq(SpawnCurve.batch_count(1, 3, 999.0, RAMP), 3)
