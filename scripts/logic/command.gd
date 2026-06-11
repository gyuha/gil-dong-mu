# 명령(Command) — 동료 전체의 전투 성향을 전환하는 지시. 노드 비의존 순수 로직.
# 주변(NEARBY)/공격적(AGGRESSIVE)/방어적(DEFENSIVE)/모여라(RALLY) 4종.
extends RefCounted

const NEARBY := 0
const AGGRESSIVE := 1
const DEFENSIVE := 2
const RALLY := 3

const NAMES := {
	NEARBY: "주변",
	AGGRESSIVE: "공격적",
	DEFENSIVE: "방어적",
	RALLY: "모여라",
}


# 명령별 동료 행동 파라미터.
# leash: 적이 무녀에게서 이 거리 밖이면 쫓지 않는다.
# engage_range: 동료가 적을 탐지·교전하는 최대 거리. 0이면 교전 금지.
# retreat_hp_ratio: HP 비율이 이 값 미만이면 무녀에게 후퇴.
# follow_distance: 교전 대상이 없을 때 무녀 곁에 서는 거리.
static func params(command: int) -> Dictionary:
	match command:
		AGGRESSIVE:
			return {
				"leash": 1500.0, "engage_range": 800.0,
				"retreat_hp_ratio": 0.0, "follow_distance": 160.0,
			}
		DEFENSIVE:
			return {
				"leash": 170.0, "engage_range": 220.0,
				"retreat_hp_ratio": 0.5, "follow_distance": 100.0,
			}
		RALLY:
			return {
				"leash": 60.0, "engage_range": 0.0,
				"retreat_hp_ratio": 0.0, "follow_distance": 60.0,
			}
		_:  # NEARBY가 기본값
			return {
				"leash": 260.0, "engage_range": 340.0,
				"retreat_hp_ratio": 0.25, "follow_distance": 120.0,
			}
