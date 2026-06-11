# 동료 타깃 선정 + 후퇴 판정 순수 로직 테스트.
extends "res://test/test_case.gd"

const CompanionAi = preload("res://scripts/logic/companion_ai.gd")


# --- select_target: 동료 기준 가장 가까운 적, engage_range·leash 제약 ---

func test_empty_enemies_returns_minus_one() -> void:
	assert_eq(CompanionAi.select_target(Vector2.ZERO, Vector2.ZERO, [], 300.0, 300.0), -1)


func test_selects_nearest_enemy() -> void:
	var enemies := [Vector2(200, 0), Vector2(50, 0), Vector2(100, 0)]
	assert_eq(CompanionAi.select_target(Vector2.ZERO, Vector2.ZERO, enemies, 300.0, 300.0), 1)


func test_enemy_beyond_engage_range_excluded() -> void:
	var enemies := [Vector2(250, 0)]
	assert_eq(CompanionAi.select_target(Vector2.ZERO, Vector2.ZERO, enemies, 200.0, 999.0), -1)


func test_enemy_beyond_leash_excluded_even_if_close_to_companion() -> void:
	# 동료는 적 바로 옆이지만, 적이 무녀에게서 leash 밖이면 쫓지 않는다.
	var companion := Vector2(500, 0)
	var munyeo := Vector2.ZERO
	var enemies := [Vector2(520, 0)]
	assert_eq(CompanionAi.select_target(companion, munyeo, enemies, 300.0, 200.0), -1)


func test_leash_filters_to_farther_but_allowed_enemy() -> void:
	# 가까운 적이 leash 밖이면, leash 안의 더 먼 적을 고른다.
	var companion := Vector2(300, 0)
	var munyeo := Vector2.ZERO
	var enemies := [Vector2(350, 0), Vector2(200, 0)]
	assert_eq(CompanionAi.select_target(companion, munyeo, enemies, 400.0, 250.0), 1)


func test_zero_engage_range_never_targets() -> void:
	var enemies := [Vector2.ZERO]
	assert_eq(CompanionAi.select_target(Vector2.ZERO, Vector2.ZERO, enemies, 0.0, 300.0), -1)


func test_tie_prefers_front_index() -> void:
	var enemies := [Vector2(100, 0), Vector2(-100, 0)]
	assert_eq(CompanionAi.select_target(Vector2.ZERO, Vector2.ZERO, enemies, 300.0, 300.0), 0)


func test_boundary_distances_inclusive() -> void:
	# engage_range와 leash 경계값은 포함.
	var enemies := [Vector2(200, 0)]
	assert_eq(CompanionAi.select_target(Vector2.ZERO, Vector2.ZERO, enemies, 200.0, 200.0), 0)


# --- should_retreat: HP 비율이 기준 미만이면 후퇴 ---

func test_retreat_below_ratio() -> void:
	assert_true(CompanionAi.should_retreat(10.0, 100.0, 0.25))


func test_no_retreat_at_exact_ratio() -> void:
	assert_false(CompanionAi.should_retreat(25.0, 100.0, 0.25))


func test_no_retreat_with_zero_ratio() -> void:
	assert_false(CompanionAi.should_retreat(1.0, 100.0, 0.0))


func test_no_retreat_at_full_hp() -> void:
	assert_false(CompanionAi.should_retreat(100.0, 100.0, 0.5))
