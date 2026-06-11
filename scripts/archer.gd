# 활잡이 — 원거리 딜러. 낮은 HP, 먼 거리에서 화살을 쏜다.
extends "res://scripts/companion.gd"

const Arrow = preload("res://scripts/arrow.gd")


func _init() -> void:
	display_name = "활잡이"
	max_hp = 25.0
	speed = 160.0
	attack_range = 320.0
	attack_damage = 2
	attack_cooldown = 1.1
	body_color = Color(0.35, 0.85, 0.5)


func _attack(enemy: Node2D) -> void:
	var arrow := Arrow.new()
	arrow.position = position
	arrow.direction = (enemy.global_position - global_position).normalized()
	arrow.damage = attack_damage
	get_parent().add_child(arrow)
