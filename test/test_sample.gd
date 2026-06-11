# 러너 동작 확인용 샘플 테스트.
extends "res://test/test_case.gd"


func test_assert_helpers() -> void:
	assert_eq(1 + 1, 2)
	assert_ne(1, 2)
	assert_true(true)
	assert_false(false)
	assert_almost_eq(0.1 + 0.2, 0.3)
