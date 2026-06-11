# MP — 자연 회복과 소비 규칙. 노드 비의존 순수 로직.
extends RefCounted


# 자연 회복: rate(초당 회복량) * delta 만큼 회복, max_mp 클램프.
static func regen(mp: float, max_mp: float, rate: float, delta: float) -> float:
	return minf(mp + rate * delta, max_mp)


# 소비 시도: 부족하면 불발(ok=false, mp 유지), 충분하면 차감. 정확히 cost만큼 있어도 성공.
static func try_spend(mp: float, cost: float) -> Dictionary:
	if mp < cost:
		return {"ok": false, "mp": mp}
	return {"ok": true, "mp": mp - cost}
