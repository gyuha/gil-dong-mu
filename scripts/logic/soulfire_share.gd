# 혼불 전달 규칙 — 노드 비의존 순수 로직.
# 무녀가 보유한 혼불을 share_radius 안의 가장 가까운 동료에게 전부 준다(전달 시 무녀 몫 0).
# 반경 내 동료가 없으면 absorb_delay 만큼 지난 뒤 무녀가 전량 흡수한다(absorb_tick).
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


# 지연 흡수 타이머 — 반경 내 동료가 없을 때 매 프레임 호출한다.
# 보유가 없으면 타이머 리셋, 누적이 absorb_delay 에 닿으면(경계 포함) 전량 흡수.
# 반환 {"timer": 갱신된 타이머, "absorbed": 무녀가 흡수한 양, "stock": 남은 보유량}.
static func absorb_tick(stock: int, timer: float, delta: float, absorb_delay: float) -> Dictionary:
	if stock <= 0:
		return {"timer": 0.0, "absorbed": 0, "stock": stock}
	var new_timer := timer + delta
	if new_timer < absorb_delay:
		return {"timer": new_timer, "absorbed": 0, "stock": stock}
	return {"timer": 0.0, "absorbed": stock, "stock": 0}
