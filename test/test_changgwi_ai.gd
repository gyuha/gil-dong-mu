# 창귀 타깃 선정(최저 체력 동료 우선) 순수 로직 테스트.
extends "res://test/test_case.gd"

const ChanggwiAi = preload("res://scripts/logic/changgwi_ai.gd")


func test_empty_returns_minus_one() -> void:
	assert_eq(ChanggwiAi.lowest_hp_index([]), -1)


func test_selects_lowest_hp() -> void:
	assert_eq(ChanggwiAi.lowest_hp_index([60.0, 25.0, 40.0]), 1)


func test_single_companion() -> void:
	assert_eq(ChanggwiAi.lowest_hp_index([10.0]), 0)


func test_tie_prefers_front_index() -> void:
	assert_eq(ChanggwiAi.lowest_hp_index([30.0, 30.0]), 0)
