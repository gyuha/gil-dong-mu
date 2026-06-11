# 탈 쓴 퇴마사 — 근접 광역 딜러. 중간 HP, 베기 한 번에 주변 적을 동시 타격한다.
# 화랑(고HP 단일 타깃 탱커)과 역할 차별화 — 퇴마사는 광역 청소 담당.
extends "res://scripts/companion.gd"

const Targeting = preload("res://scripts/logic/targeting.gd")

const SWEEP_BONUS := 16.0  # 베기 반경 = attack_range + 보너스 — 트리거 타깃 주변까지 휩쓴다

var last_sweep_hits := 0  # 마지막 베기의 동시 타격 수 — HUD 없이도 관찰 가능(스모크용)


func _init() -> void:
	display_name = "탈 쓴 퇴마사"
	max_hp = 40.0
	speed = 150.0
	attack_range = 38.0
	attack_damage = 2
	attack_cooldown = 0.9
	body_color = Color(0.85, 0.25, 0.2)  # 붉은 탈


# 광역 베기 — 트리거 타깃 하나가 아니라 베기 반경 안 모든 적을 동시 타격(다중 타격).
func _attack(_enemy: Node2D) -> void:
	var enemies := get_tree().get_nodes_in_group("enemy")
	var positions: Array = []
	for enemy in enemies:
		positions.append(enemy.global_position)
	var hits := Targeting.indices_within(
		global_position, positions, attack_range + SWEEP_BONUS,
	)
	last_sweep_hits = hits.size()
	for i in hits:
		enemies[i].take_damage(attack_damage)
