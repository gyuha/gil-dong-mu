extends RefCounted
## 신장 타깃 선정 — 순수 함수(노드 의존 없음 → 헤드리스 테스트 가능).
## 이 모듈이 게이트의 치명 버그 클래스("멍청해 보임")를 봉인한다.
##
## 규칙:
##  1) leash: anchor(무녀)로부터 stance.leash 반경 밖의 적은 후보에서 제외.
##  2) 점수 = -거리 * weight_distance (가까울수록 높음). 최고점이 후보.
##  3) 히스테리시스: 현재 타깃이 leash 안에 유효하면, 새 후보가 현재보다
##     HYSTERESIS_MARGIN 이상 '유의미하게' 가까울 때만 전환. 매프레임 깜빡임 방지.

const HYSTERESIS_MARGIN := 0.15  # 새 후보가 15% 이상 가까워야 전환

## candidates: Array of { "id": int, "pos": Vector2 }
## current_id: 현재 타깃 id(-1이면 없음)
## 반환: 선택된 적 id, 후보 없으면 -1
static func select_target(self_pos: Vector2, anchor_pos: Vector2, candidates: Array, stance: Dictionary, current_id: int) -> int:
	var leash: float = stance.get("leash", 100000.0)
	var wd: float = stance.get("weight_distance", 1.0)
	var best_id := -1
	var best_score := -INF
	var current_score := -INF  # 현재 타깃이 후보 안에 있을 때만 채워짐

	for c in candidates:
		var pos: Vector2 = c["pos"]
		if anchor_pos.distance_to(pos) > leash:
			continue  # leash 밖 → 교전 안 함
		var score := -self_pos.distance_to(pos) * wd
		if int(c["id"]) == current_id:
			current_score = score
		if score > best_score:
			best_score = score
			best_id = int(c["id"])

	# 현재 타깃이 여전히 유효하면 히스테리시스로 깜빡임 방지
	if current_id != -1 and current_score != -INF and best_id != current_id:
		var improvement := best_score - current_score          # >0 이면 best가 더 가까움
		var threshold := absf(current_score) * HYSTERESIS_MARGIN
		if improvement < threshold:
			return current_id  # 유의미하게 낫지 않으면 현재 유지
	return best_id
