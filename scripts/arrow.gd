# 화살 — 활잡이의 원거리 투사체. 직선 비행, 잡귀 명중 시 피해.
extends Node2D

const SPEED := 480.0
const LIFETIME := 1.2
const HIT_RADIUS := 12.0

var direction := Vector2.RIGHT
var damage := 2
var _age := 0.0


func _ready() -> void:
	add_to_group("arrow")


func _process(delta: float) -> void:
	position += direction * SPEED * delta
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	for enemy in get_tree().get_nodes_in_group("japgwi"):
		if global_position.distance_to(enemy.global_position) <= HIT_RADIUS:
			enemy.take_damage(damage)
			queue_free()
			return


func _draw() -> void:
	draw_line(-direction * 8.0, direction * 8.0, Color(0.75, 0.55, 0.3), 2.0)
