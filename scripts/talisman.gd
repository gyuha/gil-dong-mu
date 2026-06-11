# 혼불 부적 — 무녀의 자동 주술 투사체. 직선 비행, 적(잡귀·창귀) 명중 시 피해.
# pierce > 0 이면 그만큼 적을 더 뚫고 지나간다(드래프트 강화).
extends Node2D

const SPEED := 420.0
const LIFETIME := 1.5
const HIT_RADIUS := 14.0
const DAMAGE := 1

var direction := Vector2.RIGHT
var pierce := 0  # 추가로 관통할 수 있는 적 수
var _age := 0.0
var _hit := {}  # instance_id → true — 관통 중 같은 적 중복 타격 방지


func _process(delta: float) -> void:
	position += direction * SPEED * delta
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if _hit.has(enemy.get_instance_id()):
			continue
		if global_position.distance_to(enemy.global_position) <= HIT_RADIUS:
			enemy.take_damage(DAMAGE)
			if pierce <= 0:
				queue_free()
				return
			pierce -= 1
			_hit[enemy.get_instance_id()] = true


func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.9, 0.4))
