# 동료 자율 전투 판단 — 타깃 선정·후퇴 판정. 노드 비의존 순수 로직.
extends RefCounted


# 동료에게 가장 가까운 적의 인덱스. 단, 적이 동료에게서 engage_range 안이고
# 무녀에게서 leash 안이어야 한다(경계 포함). 없으면 -1, 동률이면 앞 인덱스.
# engage_range 0 이하 = 교전 금지(항상 -1).
static func select_target(
	companion_pos: Vector2, munyeo_pos: Vector2, enemy_positions: Array,
	engage_range: float, leash: float,
) -> int:
	if engage_range <= 0.0:
		return -1
	var best := -1
	var best_dist := INF
	for i in enemy_positions.size():
		var dist: float = companion_pos.distance_to(enemy_positions[i])
		if dist > engage_range:
			continue
		if munyeo_pos.distance_to(enemy_positions[i]) > leash:
			continue
		if dist < best_dist:
			best_dist = dist
			best = i
	return best


# HP 비율이 retreat_hp_ratio 미만이면 후퇴(경계는 후퇴하지 않음). ratio 0 = 후퇴 없음.
static func should_retreat(hp: float, max_hp: float, retreat_hp_ratio: float) -> bool:
	return hp / max_hp < retreat_hp_ratio
