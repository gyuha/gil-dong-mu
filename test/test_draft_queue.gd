# 레벨업 드래프트 큐 — 복수 레벨업 적재·FIFO 처리 규칙 테스트 (ADR-0002).
extends "res://test/test_case.gd"

const DraftQueue = preload("res://scripts/logic/draft_queue.gd")


func test_new_queue_is_empty() -> void:
	var queue := DraftQueue.new()
	assert_true(queue.is_empty())
	assert_eq(queue.size(), 0)


func test_pop_on_empty_returns_null() -> void:
	var queue := DraftQueue.new()
	assert_eq(queue.pop(), null)


func test_single_levelup_adds_one_entry() -> void:
	var queue := DraftQueue.new()
	queue.enqueue_levels("무녀", 1, 2)
	assert_eq(queue.size(), 1)
	var entry: Dictionary = queue.pop()
	assert_eq(entry["subject"], "무녀")
	assert_eq(entry["level"], 2)
	assert_true(queue.is_empty())


func test_multi_levelup_adds_entry_per_level() -> void:
	var queue := DraftQueue.new()
	queue.enqueue_levels("무녀", 1, 3)  # Lv1→3: 한 번의 획득으로 2회 레벨업
	assert_eq(queue.size(), 2)
	assert_eq(queue.pop()["level"], 2)
	assert_eq(queue.pop()["level"], 3)


func test_fifo_across_subjects() -> void:
	var queue := DraftQueue.new()
	queue.enqueue_levels("무녀", 1, 2)
	queue.enqueue_levels("화랑", 2, 4)
	assert_eq(queue.pop()["subject"], "무녀")
	var second: Dictionary = queue.pop()
	assert_eq(second["subject"], "화랑")
	assert_eq(second["level"], 3)
	assert_eq(queue.pop()["level"], 4)
	assert_true(queue.is_empty())


func test_no_gain_adds_nothing() -> void:
	var queue := DraftQueue.new()
	queue.enqueue_levels("무녀", 3, 3)
	assert_true(queue.is_empty())
