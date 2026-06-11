# 스폰 강도 곡선 — 밤 경과 시간에 따라 스폰 주기를 줄이고 동시 스폰 수를 늘린다.
# 노드 비의존 순수 로직. 경과 시간은 램프 구간 [0, ramp_time] 에 클램프된다.
extends RefCounted

# 기준선 상수 — 적 밀도 체감 2배(S5). 플레이 판정 후 재조정 전제.
const JAPGWI_BASE_INTERVAL := 0.8
const JAPGWI_MIN_INTERVAL := 0.35
const JAPGWI_BASE_BATCH := 2
const JAPGWI_MAX_BATCH := 5
const CHANGGWI_BASE_INTERVAL := 4.0
const CHANGGWI_MIN_INTERVAL := 2.0


# 스폰 주기 — base 에서 min_interval 로 선형 감소.
static func interval(base: float, min_interval: float, elapsed: float, ramp_time: float) -> float:
	return lerpf(base, min_interval, clampf(elapsed / ramp_time, 0.0, 1.0))


# 한 번에 스폰하는 수 — base_count 에서 max_count 로 선형 증가, 소수점 내림.
static func batch_count(base_count: int, max_count: int, elapsed: float, ramp_time: float) -> int:
	var t := clampf(elapsed / ramp_time, 0.0, 1.0)
	return int(floorf(lerpf(float(base_count), float(max_count), t)))
