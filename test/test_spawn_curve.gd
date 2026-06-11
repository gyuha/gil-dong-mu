# 스폰 강도 곡선 순수 로직 테스트.
# 규칙: 밤 경과 시간에 따라 스폰 주기는 base→min 으로 선형 감소,
# 한 번에 스폰하는 수는 base→max 로 선형 증가(소수점 내림).
# 경과 시간은 램프 구간 [0, ramp_time] 에 클램프된다.
# 기준선(밀도 체감 2배, S5): 잡귀 0.8→0.35s·2→5마리, 창귀 4→2s.
extends "res://test/test_case.gd"

const SpawnCurve = preload("res://scripts/logic/spawn_curve.gd")

const RAMP := 180.0


# --- 기준선 상수 (plan: 적 밀도 체감 2배) ---


func test_japgwi_baseline_constants() -> void:
	assert_almost_eq(SpawnCurve.JAPGWI_BASE_INTERVAL, 0.8)
	assert_almost_eq(SpawnCurve.JAPGWI_MIN_INTERVAL, 0.35)
	assert_eq(SpawnCurve.JAPGWI_BASE_BATCH, 2)
	assert_eq(SpawnCurve.JAPGWI_MAX_BATCH, 5)


func test_changgwi_baseline_constants() -> void:
	assert_almost_eq(SpawnCurve.CHANGGWI_BASE_INTERVAL, 4.0)
	assert_almost_eq(SpawnCurve.CHANGGWI_MIN_INTERVAL, 2.0)


# --- 잡귀 스폰 주기 곡선 ---


func test_interval_at_start_is_base() -> void:
	assert_almost_eq(
		SpawnCurve.interval(
			SpawnCurve.JAPGWI_BASE_INTERVAL, SpawnCurve.JAPGWI_MIN_INTERVAL, 0.0, RAMP,
		),
		0.8,
	)


func test_interval_at_ramp_end_is_min() -> void:
	assert_almost_eq(
		SpawnCurve.interval(
			SpawnCurve.JAPGWI_BASE_INTERVAL, SpawnCurve.JAPGWI_MIN_INTERVAL, RAMP, RAMP,
		),
		0.35,
	)


func test_interval_midpoint_is_average() -> void:
	assert_almost_eq(
		SpawnCurve.interval(
			SpawnCurve.JAPGWI_BASE_INTERVAL, SpawnCurve.JAPGWI_MIN_INTERVAL, 90.0, RAMP,
		),
		0.575,
	)


func test_interval_clamps_beyond_ramp() -> void:
	assert_almost_eq(
		SpawnCurve.interval(
			SpawnCurve.JAPGWI_BASE_INTERVAL, SpawnCurve.JAPGWI_MIN_INTERVAL, 999.0, RAMP,
		),
		0.35,
	)


func test_interval_clamps_negative_elapsed() -> void:
	assert_almost_eq(
		SpawnCurve.interval(
			SpawnCurve.JAPGWI_BASE_INTERVAL, SpawnCurve.JAPGWI_MIN_INTERVAL, -10.0, RAMP,
		),
		0.8,
	)


# --- 창귀 스폰 주기 곡선 ---


func test_changgwi_interval_at_start_is_base() -> void:
	assert_almost_eq(
		SpawnCurve.interval(
			SpawnCurve.CHANGGWI_BASE_INTERVAL, SpawnCurve.CHANGGWI_MIN_INTERVAL, 0.0, RAMP,
		),
		4.0,
	)


func test_changgwi_interval_at_ramp_end_is_min() -> void:
	assert_almost_eq(
		SpawnCurve.interval(
			SpawnCurve.CHANGGWI_BASE_INTERVAL, SpawnCurve.CHANGGWI_MIN_INTERVAL, RAMP, RAMP,
		),
		2.0,
	)


func test_changgwi_interval_midpoint_is_average() -> void:
	assert_almost_eq(
		SpawnCurve.interval(
			SpawnCurve.CHANGGWI_BASE_INTERVAL, SpawnCurve.CHANGGWI_MIN_INTERVAL, 90.0, RAMP,
		),
		3.0,
	)


# --- 잡귀 동시 스폰 수 곡선 ---


func test_batch_count_at_start_is_base() -> void:
	assert_eq(
		SpawnCurve.batch_count(
			SpawnCurve.JAPGWI_BASE_BATCH, SpawnCurve.JAPGWI_MAX_BATCH, 0.0, RAMP,
		),
		2,
	)


func test_batch_count_at_ramp_end_is_max() -> void:
	assert_eq(
		SpawnCurve.batch_count(
			SpawnCurve.JAPGWI_BASE_BATCH, SpawnCurve.JAPGWI_MAX_BATCH, RAMP, RAMP,
		),
		5,
	)


func test_batch_count_midpoint_floors() -> void:
	# lerp(2, 5, 0.5) = 3.5 — 내림으로 3
	assert_eq(
		SpawnCurve.batch_count(
			SpawnCurve.JAPGWI_BASE_BATCH, SpawnCurve.JAPGWI_MAX_BATCH, 90.0, RAMP,
		),
		3,
	)


func test_batch_count_just_before_ramp_end_floors() -> void:
	# lerp(2, 5, 179/180) ≈ 4.98 — 내림으로 4
	assert_eq(
		SpawnCurve.batch_count(
			SpawnCurve.JAPGWI_BASE_BATCH, SpawnCurve.JAPGWI_MAX_BATCH, 179.0, RAMP,
		),
		4,
	)


func test_batch_count_clamps_beyond_ramp() -> void:
	assert_eq(
		SpawnCurve.batch_count(
			SpawnCurve.JAPGWI_BASE_BATCH, SpawnCurve.JAPGWI_MAX_BATCH, 999.0, RAMP,
		),
		5,
	)
