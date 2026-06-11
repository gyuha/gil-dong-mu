# 쓰러짐(downed) 타이머·구출 판정 순수 로직 테스트.
# 규칙: 제한 시간이 다 되면 이탈(lost), 무녀가 구출 반경 안에 머무르면
# 진행도가 쌓여 구출(rescued), 반경을 벗어나면 진행도는 초기화된다.
extends "res://test/test_case.gd"

const Downed = preload("res://scripts/logic/downed.gd")

const RADIUS := 50.0
const RESCUE_TIME := 1.5


func test_initial_state() -> void:
	var s := Downed.initial_state(8.0)
	assert_almost_eq(s["time_left"], 8.0)
	assert_almost_eq(s["rescue_progress"], 0.0)


func test_timer_decreases_outside_radius() -> void:
	var s := Downed.step(Downed.initial_state(8.0), 999.0, 1.0, RADIUS, RESCUE_TIME)
	assert_almost_eq(s["time_left"], 7.0)
	assert_eq(s["status"], "downed")


func test_progress_accumulates_within_radius() -> void:
	var s := Downed.step(Downed.initial_state(8.0), 30.0, 0.5, RADIUS, RESCUE_TIME)
	assert_almost_eq(s["rescue_progress"], 0.5)
	assert_eq(s["status"], "downed")


func test_radius_boundary_inclusive() -> void:
	var s := Downed.step(Downed.initial_state(8.0), 50.0, 0.5, RADIUS, RESCUE_TIME)
	assert_almost_eq(s["rescue_progress"], 0.5)


func test_progress_resets_when_leaving_radius() -> void:
	var s := {"time_left": 6.0, "rescue_progress": 1.0}
	var next := Downed.step(s, 51.0, 0.5, RADIUS, RESCUE_TIME)
	assert_almost_eq(next["rescue_progress"], 0.0)
	assert_eq(next["status"], "downed")


func test_rescued_when_progress_reaches_rescue_time() -> void:
	var s := {"time_left": 6.0, "rescue_progress": 1.4}
	var next := Downed.step(s, 0.0, 0.1, RADIUS, RESCUE_TIME)
	assert_eq(next["status"], "rescued")


func test_lost_when_timer_expires_and_clamped_to_zero() -> void:
	var s := {"time_left": 0.05, "rescue_progress": 0.0}
	var next := Downed.step(s, 999.0, 0.1, RADIUS, RESCUE_TIME)
	assert_eq(next["status"], "lost")
	assert_almost_eq(next["time_left"], 0.0)


func test_rescue_wins_over_timeout_same_tick() -> void:
	var s := {"time_left": 0.05, "rescue_progress": 1.45}
	var next := Downed.step(s, 10.0, 0.1, RADIUS, RESCUE_TIME)
	assert_eq(next["status"], "rescued")


func test_input_state_not_mutated() -> void:
	var s := {"time_left": 6.0, "rescue_progress": 0.5}
	Downed.step(s, 10.0, 0.1, RADIUS, RESCUE_TIME)
	assert_almost_eq(s["time_left"], 6.0)
	assert_almost_eq(s["rescue_progress"], 0.5)
