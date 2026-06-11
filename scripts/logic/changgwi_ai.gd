# 창귀 타깃 선정 — 체력이 가장 낮은 동료를 우선 노린다. 노드 비의존 순수 로직.
# 동료 부재 시 무녀로 가는 폴백은 노드 코드(changgwi.gd)가 담당한다.
extends RefCounted


# hps 중 최저 체력의 인덱스. 빈 배열이면 -1, 동률이면 앞 인덱스.
static func lowest_hp_index(hps: Array) -> int:
	var best := -1
	var best_hp := INF
	for i in hps.size():
		if hps[i] < best_hp:
			best_hp = hps[i]
			best = i
	return best
