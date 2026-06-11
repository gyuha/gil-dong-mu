# 경험치 → 레벨 곡선 — 노드 비의존 순수 로직.
extends RefCounted

const BASE_REQUIRED := 5
const STEP := 3


# level → level+1 에 필요한 경험치. 레벨은 1부터 시작.
static func xp_required(level: int) -> int:
	return BASE_REQUIRED + STEP * (level - 1)


# 현재 (level, xp)에 gain을 더한 결과를 {"level": int, "xp": int}로 돌려준다.
# 한 번의 획득으로 복수 레벨업이 가능하다.
static func apply_xp(level: int, xp: int, gain: int) -> Dictionary:
	var new_level := level
	var new_xp := xp + gain
	while new_xp >= xp_required(new_level):
		new_xp -= xp_required(new_level)
		new_level += 1
	return {"level": new_level, "xp": new_xp}
