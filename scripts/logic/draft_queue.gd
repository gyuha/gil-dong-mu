# 레벨업 드래프트 큐 — 쌓인 레벨업을 한 번의 정지에서 연속 처리하기 위한 FIFO (ADR-0002).
# 항목은 {"subject": Variant, "level": int} — 레벨업 1회당 1항목.
extends RefCounted

var _entries: Array = []


# from_level → to_level 로 오른 레벨업을 레벨당 1항목씩 적재한다.
func enqueue_levels(subject, from_level: int, to_level: int) -> void:
	for level in range(from_level + 1, to_level + 1):
		_entries.append({"subject": subject, "level": level})


# 가장 먼저 쌓인 항목을 꺼낸다. 비어 있으면 null.
func pop():
	if _entries.is_empty():
		return null
	return _entries.pop_front()


func is_empty() -> bool:
	return _entries.is_empty()


func size() -> int:
	return _entries.size()
