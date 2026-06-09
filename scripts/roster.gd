extends RefCounted
## 신장 6종 로스터 — 스탯을 데이터로 분리. 단일 FSM(companion.gd)이 전부 재사용.
## 6종은 능력이 아니라 (HP/속도/사거리/공격력/쿨다운) 숫자 차이로만 역할이 갈림.
## 근접 vs 원거리는 attack_range 하나로 표현(큰 값 = 원거리). FSM 코드 변경 0.
##
## 게이트 검증 포인트: 플레이어가 6중 3을 골라 '조합을 지휘'하는 게 재밌는가.

static func roster() -> Array:
	return [
		{"name": "검귀", "max_hp": 80.0, "speed": 160.0, "attack_range": 46.0,
			"attack_damage": 22.0, "attack_cooldown": 0.5, "radius": 13.0, "color": Color(0.30, 0.85, 0.40)},
		{"name": "궁귀", "max_hp": 45.0, "speed": 150.0, "attack_range": 220.0,
			"attack_damage": 14.0, "attack_cooldown": 0.45, "radius": 11.0, "color": Color(0.25, 0.80, 0.75)},
		{"name": "신속", "max_hp": 50.0, "speed": 235.0, "attack_range": 40.0,
			"attack_damage": 12.0, "attack_cooldown": 0.30, "radius": 10.0, "color": Color(0.70, 0.90, 0.25)},
		{"name": "방벽", "max_hp": 165.0, "speed": 110.0, "attack_range": 34.0,
			"attack_damage": 10.0, "attack_cooldown": 0.70, "radius": 16.0, "color": Color(0.35, 0.60, 0.55)},
		{"name": "술사", "max_hp": 55.0, "speed": 140.0, "attack_range": 175.0,
			"attack_damage": 26.0, "attack_cooldown": 0.90, "radius": 12.0, "color": Color(0.65, 0.40, 0.90)},
		{"name": "맹수", "max_hp": 45.0, "speed": 215.0, "attack_range": 42.0,
			"attack_damage": 30.0, "attack_cooldown": 0.55, "radius": 12.0, "color": Color(0.95, 0.55, 0.20)},
	]
