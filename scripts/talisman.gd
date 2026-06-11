# 혼불 부적 — 무녀의 자동 주술 투사체. 직선 비행, 잡귀 명중 시 피해.
extends Node2D

const SPEED := 420.0
const LIFETIME := 1.5
const HIT_RADIUS := 14.0
const DAMAGE := 1

var direction := Vector2.RIGHT
var _age := 0.0


func _process(delta: float) -> void:
	position += direction * SPEED * delta
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	for enemy in get_tree().get_nodes_in_group("japgwi"):
		if global_position.distance_to(enemy.global_position) <= HIT_RADIUS:
			enemy.take_damage(DAMAGE)
			queue_free()
			return


func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.9, 0.4))
