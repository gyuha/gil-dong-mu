# 오라 — 영역 내/외 판정 기반 감속 계산과 밀쳐내기 오프셋. 노드 비의존 순수 로직.
extends RefCounted


# 원점에서 distance 떨어진 적의 이동속도 배율.
# 영역 밖이면 1.0, 안이면 slow_multiplier.
# level_diff_scale: 레벨차 정밀 보정 자리(Non-goal) — 1.0이면 감속 전부 적용,
# 0.0이면 무효. lerp(1.0, slow_multiplier, level_diff_scale)로 블렌드만 해 둔다.
static func speed_multiplier(
		distance: float,
		aura_radius: float,
		slow_multiplier: float,
		level_diff_scale := 1.0,
) -> float:
	if distance > aura_radius:
		return 1.0
	return lerpf(1.0, slow_multiplier, level_diff_scale)


# 밀쳐내기 — origin 기준 repel_radius 안의 pos를 바깥 방향으로 push_distance만큼
# 밀어낼 오프셋. 영역 밖이면 Vector2.ZERO, 원점과 겹치면 임의 고정 방향(RIGHT).
static func repel_offset(
		origin: Vector2,
		pos: Vector2,
		repel_radius: float,
		push_distance: float,
) -> Vector2:
	var diff := pos - origin
	if diff.length() > repel_radius:
		return Vector2.ZERO
	if diff == Vector2.ZERO:
		return Vector2.RIGHT * push_distance
	return diff.normalized() * push_distance
