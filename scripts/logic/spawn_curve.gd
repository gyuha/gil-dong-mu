# 스폰 강도 곡선 — 밤 경과 시간에 따라 스폰 주기를 줄이고 동시 스폰 수를 늘린다.
# 노드 비의존 순수 로직. 경과 시간은 램프 구간 [0, ramp_time] 에 클램프된다.
extends RefCounted


# 스폰 주기 — base 에서 min_interval 로 선형 감소.
static func interval(base: float, min_interval: float, elapsed: float, ramp_time: float) -> float:
	return lerpf(base, min_interval, clampf(elapsed / ramp_time, 0.0, 1.0))


# 한 번에 스폰하는 수 — base_count 에서 max_count 로 선형 증가, 소수점 내림.
static func batch_count(base_count: int, max_count: int, elapsed: float, ramp_time: float) -> int:
	var t := clampf(elapsed / ramp_time, 0.0, 1.0)
	return int(floorf(lerpf(float(base_count), float(max_count), t)))
