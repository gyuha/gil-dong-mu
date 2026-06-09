extends RefCounted
## 스탠스 = (leash 반경, 공격성 가중치) 두 숫자로 표현. 단일 FSM이 모든 스탠스를 재사용.
## leash 밖 적은 교전 대상에서 제외 → "공격적/방어적/사수"가 데이터 차이로만 표현됨.

enum Type { AGGRESSIVE, DEFENSIVE, HOLD }

## leash: 신장이 anchor(무녀)로부터 교전하러 벗어날 수 있는 최대 거리.
##   매우 큰 값 = 화면 전체(공격적), 작은 값 = 무녀 곁(사수).
## weight_distance: 타깃 점수의 거리 페널티 가중치(클수록 가까운 적 선호).
## retreat: 저HP시 무녀쪽 후퇴 여부(방어적만 true).
static func params(t: int) -> Dictionary:
	match t:
		Type.AGGRESSIVE: return {"leash": 100000.0, "weight_distance": 1.0, "retreat": false}
		Type.DEFENSIVE:  return {"leash": 240.0, "weight_distance": 1.5, "retreat": true}
		Type.HOLD:       return {"leash": 150.0, "weight_distance": 2.0, "retreat": false}
		_:               return {"leash": 100000.0, "weight_distance": 1.0, "retreat": false}

static func name_of(t: int) -> String:
	match t:
		Type.AGGRESSIVE: return "공격적"
		Type.DEFENSIVE:  return "방어적"
		Type.HOLD:       return "사수"
		_:               return "?"
