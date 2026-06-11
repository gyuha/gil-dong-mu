# 타깃 선정 — 노드 비의존 순수 로직.
extends RefCounted


# origin에서 가장 가까운 위치의 인덱스를 돌려준다.
# 후보가 없거나 전부 max_range 밖이면 -1. 동률이면 앞 인덱스 우선.
static func nearest_index(origin: Vector2, positions: Array, max_range: float = INF) -> int:
	var best := -1
	var best_dist := INF
	for i in positions.size():
		var dist: float = origin.distance_to(positions[i])
		if dist > max_range:
			continue
		if dist < best_dist:
			best_dist = dist
			best = i
	return best


# 부적 다발 발사 방향 — base를 중심으로 count발을 step 라디안 간격 부채꼴로 펼친다.
static func spread_directions(base: Vector2, count: int, step: float = 0.15) -> Array:
	var dirs := []
	var center := (count - 1) / 2.0
	for i in count:
		dirs.append(base.normalized().rotated((i - center) * step))
	return dirs
