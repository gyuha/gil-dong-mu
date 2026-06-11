# 드래프트(Draft) 선택지 풀 — 추첨과 업그레이드 적용 수치. 노드 비의존 순수 로직.
# 무녀 풀: 주술(부적 수/관통/쿨다운), 오라, MP, 명령 강화. 동료 풀: 해당 동료의 스탯 강화.
# 선택지는 {id, name, desc} 사전. id는 두 풀을 통틀어 유일하다.
extends RefCounted


static func munyeo_pool() -> Array:
	return [
		{"id": "talisman_count", "name": "부적 추가", "desc": "부적 +1발"},
		{"id": "talisman_pierce", "name": "부적 관통", "desc": "관통 +1"},
		{"id": "talisman_cooldown", "name": "주술 가속", "desc": "부적 쿨다운 -15%"},
		{"id": "aura_radius", "name": "오라 확장", "desc": "오라 반경 +20%"},
		{"id": "aura_heal", "name": "오라 정화", "desc": "오라 회복 +3/s"},
		{"id": "mp_mastery", "name": "내공 수양", "desc": "최대 MP +30, 회복 +2/s"},
		{"id": "command_range", "name": "명령 강화", "desc": "동료 교전·추적 범위 +25%"},
	]


static func companion_pool() -> Array:
	return [
		{"id": "comp_max_hp", "name": "체력 단련", "desc": "최대 HP +25%"},
		{"id": "comp_damage", "name": "공격 강화", "desc": "공격력 +1"},
		{"id": "comp_attack_speed", "name": "공격 가속", "desc": "공격 쿨다운 -15%"},
		{"id": "comp_speed", "name": "날랜 발", "desc": "이동속도 +15%"},
		{"id": "comp_range", "name": "긴 팔", "desc": "사거리 +15%"},
	]


# 풀에서 count개를 중복 없이 추첨한다. 풀이 작으면 풀 크기만큼.
static func roll(pool: Array, count: int, rng: RandomNumberGenerator) -> Array:
	var indices := range(pool.size())
	# Fisher-Yates 부분 셔플 — 앞 count칸만 확정하면 된다.
	var take: int = mini(count, pool.size())
	for i in range(take):
		var j := rng.randi_range(i, indices.size() - 1)
		var tmp: int = indices[i]
		indices[i] = indices[j]
		indices[j] = tmp
	var picked := []
	for i in range(take):
		picked.append(pool[indices[i]])
	return picked


# 선택지 id를 스탯 사전에 적용한 새 사전을 돌려준다. 입력은 바꾸지 않는다.
static func apply(stats: Dictionary, option_id: String) -> Dictionary:
	var s := stats.duplicate()
	match option_id:
		"talisman_count":
			s["talisman_count"] = s["talisman_count"] + 1
		"talisman_pierce":
			s["talisman_pierce"] = s["talisman_pierce"] + 1
		"talisman_cooldown":
			s["attack_cooldown"] = s["attack_cooldown"] * 0.85
		"aura_radius":
			s["aura_radius"] = s["aura_radius"] * 1.2
		"aura_heal":
			s["aura_heal_rate"] = s["aura_heal_rate"] + 3.0
		"mp_mastery":
			s["max_mp"] = s["max_mp"] + 30.0
			s["mp_regen_rate"] = s["mp_regen_rate"] + 2.0
		"command_range":
			s["command_range_bonus"] = s["command_range_bonus"] * 1.25
		"comp_max_hp":
			s["max_hp"] = s["max_hp"] * 1.25
		"comp_damage":
			s["attack_damage"] = s["attack_damage"] + 1
		"comp_attack_speed":
			s["attack_cooldown"] = s["attack_cooldown"] * 0.85
		"comp_speed":
			s["speed"] = s["speed"] * 1.15
		"comp_range":
			s["attack_range"] = s["attack_range"] * 1.15
	return s
