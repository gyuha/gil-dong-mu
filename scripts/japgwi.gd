# 잡귀 — 무녀를 추적하는 기본 호드 적. 접촉 피해, 사망 시 혼불 드랍.
# 어그로 반경 안에 화랑이 있으면 화랑을 우선 추적한다(근접 탱커의 어그로).
extends Node2D

const Soulfire = preload("res://scripts/soulfire.gd")
const Targeting = preload("res://scripts/logic/targeting.gd")

const RADIUS := 10.0
const SPEED := 80.0
const CONTACT_RADIUS := 26.0
const CONTACT_DAMAGE := 8
const CONTACT_INTERVAL := 0.6
const AGGRO_RADIUS := 200.0

var hp := 2
var target: Node2D
var _contact_timer := 0.0


func _ready() -> void:
	add_to_group("japgwi")
	add_to_group("enemy")  # 아군 공격·밀쳐내기가 노리는 공통 적 그룹


func _process(delta: float) -> void:
	_contact_timer -= delta
	if target == null or not is_instance_valid(target):
		return
	var chase := _chase_target()
	var to_target := chase.global_position - global_position
	if to_target.length() > CONTACT_RADIUS:
		var speed := SPEED
		if target.has_method("aura_speed_multiplier"):
			speed *= target.aura_speed_multiplier(global_position)
		position += to_target.normalized() * speed * delta
	elif _contact_timer <= 0.0:
		chase.take_damage(CONTACT_DAMAGE)
		_contact_timer = CONTACT_INTERVAL


# 어그로 반경 안의 가장 가까운 화랑, 없으면 본래 타깃(무녀).
func _chase_target() -> Node2D:
	var hwarangs := get_tree().get_nodes_in_group("hwarang")
	var positions: Array = []
	for hwarang in hwarangs:
		positions.append(hwarang.global_position)
	var idx := Targeting.nearest_index(global_position, positions, AGGRO_RADIUS)
	if idx != -1:
		return hwarangs[idx]
	return target


func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		_die()


func _die() -> void:
	var soulfire := Soulfire.new()
	soulfire.position = position
	soulfire.magnet_target = target
	get_parent().add_child(soulfire)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(0.85, 0.25, 0.25))
