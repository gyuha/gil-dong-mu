# 밤 루프 규칙 — 3분 타이머의 승패 판정과 남은 시간 표기. 노드 비의존 순수 로직.
# 무녀 HP 0 = 패배(만료와 같은 틱이면 패배 우선), 만료 + 생존 = 승리.
# 동료 전멸은 패배가 아니다 — 판정 입력에 동료 상태를 받지 않는 것으로 강제한다.
extends RefCounted

const DURATION := 180.0  # 한 밤 = 3분

const ONGOING := "ongoing"
const VICTORY := "victory"
const DEFEAT := "defeat"


static func outcome(time_left: float, munyeo_hp: int) -> String:
	if munyeo_hp <= 0:
		return DEFEAT
	if time_left <= 0.0:
		return VICTORY
	return ONGOING


# 남은 시간 "분:초" 표기 — 올림(0.4초 남음 = "0:01"), 음수는 0으로 클램프.
static func format_time(time_left: float) -> String:
	var total := int(ceilf(maxf(time_left, 0.0)))
	return "%d:%02d" % [total / 60, total % 60]
