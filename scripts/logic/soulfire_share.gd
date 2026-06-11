# 혼불 분배 규칙 — 노드 비의존 순수 로직.
# 무녀가 보유한 혼불을 share_radius 안의 가장 가까운 동료에게 전부 준다.
extends RefCounted


# companion_distances: 무녀→각 동료 거리 배열.
# 반환 {"index": 받는 동료 인덱스(-1=분배 없음), "given": 준 양, "stock": 남은 보유량}.
# 경계(거리 == share_radius) 포함, 동률이면 앞 인덱스.
static func distribute(stock: int, companion_distances: Array, share_radius: float) -> Dictionary:
	if stock <= 0:
		return {"index": -1, "given": 0, "stock": stock}
	var best := -1
	var best_dist := INF
	for i in companion_distances.size():
		var dist: float = companion_distances[i]
		if dist > share_radius:
			continue
		if dist < best_dist:
			best_dist = dist
			best = i
	if best == -1:
		return {"index": -1, "given": 0, "stock": stock}
	return {"index": best, "given": stock, "stock": 0}
