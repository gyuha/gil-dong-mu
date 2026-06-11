# 화랑 호위병 — 근접 탱커. 높은 HP, 근접 베기. "hwarang" 그룹으로 잡귀 어그로를 끈다.
extends "res://scripts/companion.gd"


func _init() -> void:
	display_name = "화랑"
	max_hp = 60.0
	speed = 140.0
	attack_range = 34.0
	attack_damage = 2
	attack_cooldown = 0.7
	body_color = Color(0.95, 0.75, 0.25)


func _ready() -> void:
	super()
	add_to_group("hwarang")
