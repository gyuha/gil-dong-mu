# 오라 감속 계산 + 밀쳐내기 오프셋 순수 로직 테스트.
extends "res://test/test_case.gd"

const Aura = preload("res://scripts/logic/aura.gd")


# --- speed_multiplier: 영역 내/외 판정 + 감속률 ---

func test_inside_aura_returns_slow_multiplier() -> void:
	assert_almost_eq(Aura.speed_multiplier(50.0, 140.0, 0.5), 0.5)


func test_outside_aura_returns_one() -> void:
	assert_almost_eq(Aura.speed_multiplier(200.0, 140.0, 0.5), 1.0)


func test_boundary_is_inside() -> void:
	assert_almost_eq(Aura.speed_multiplier(140.0, 140.0, 0.5), 0.5)


func test_zero_distance_inside() -> void:
	assert_almost_eq(Aura.speed_multiplier(0.0, 140.0, 0.3), 0.3)


# --- level_diff_scale: 레벨차 보정 자리(Non-goal, 기본 1.0) ---

func test_level_diff_scale_zero_disables_slow() -> void:
	assert_almost_eq(Aura.speed_multiplier(50.0, 140.0, 0.5, 0.0), 1.0)


func test_level_diff_scale_half_blends() -> void:
	assert_almost_eq(Aura.speed_multiplier(50.0, 140.0, 0.5, 0.5), 0.75)


# --- repel_offset: 밀쳐내기 — 원점 반대 방향으로 밀어냄 ---

func test_repel_outside_radius_is_zero() -> void:
	assert_eq(Aura.repel_offset(Vector2.ZERO, Vector2(200, 0), 160.0, 120.0), Vector2.ZERO)


func test_repel_pushes_outward() -> void:
	var offset := Aura.repel_offset(Vector2.ZERO, Vector2(100, 0), 160.0, 120.0)
	assert_eq(offset, Vector2(120, 0))


func test_repel_direction_away_from_origin() -> void:
	var offset := Aura.repel_offset(Vector2(100, 100), Vector2(100, 50), 160.0, 80.0)
	assert_eq(offset, Vector2(0, -80))


func test_repel_boundary_inclusive() -> void:
	var offset := Aura.repel_offset(Vector2.ZERO, Vector2(160, 0), 160.0, 120.0)
	assert_eq(offset, Vector2(120, 0))


func test_repel_same_position_still_pushes() -> void:
	var offset := Aura.repel_offset(Vector2.ZERO, Vector2.ZERO, 160.0, 120.0)
	assert_almost_eq(offset.length(), 120.0)
