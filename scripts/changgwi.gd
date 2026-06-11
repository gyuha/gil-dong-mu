# 창귀 — 체력이 가장 낮은 동료를 우선 노리고 돌진하는 적. 동료가 없으면 무녀를 노린다.
# 잡귀보다 빠르고 접촉 피해가 크다. 케어 시스템(쓰러짐·구출)을 압박하는 위협.
# 쓰러진 동료는 "companion" 그룹에서 빠지므로 자동으로 표적에서 제외된다.
extends Node2D

const Soulfire = preload("res://scripts/soulfire.gd")
const ChanggwiAi = preload("res://scripts/logic/changgwi_ai.gd")

const RADIUS := 11.0
const SPEED := 150.0
const CONTACT_RADIUS := 26.0
const CONTACT_DAMAGE := 12
const CONTACT_INTERVAL := 0.8
const SOULFIRE_VALUE := 2  # 잡귀보다 단단한 만큼 혼불도 크다

var hp := 4
var munyeo: Node2D
var _contact_timer := 0.0


func _ready() -> void:
	add_to_group("changgwi")
	add_to_group("enemy")


func _process(delta: float) -> void:
	_contact_timer -= delta
	var chase := _chase_target()
	if chase == null:
		return
	var to_target := chase.global_position - global_position
	if to_target.length() > CONTACT_RADIUS:
		var speed := SPEED
		if munyeo != null and is_instance_valid(munyeo):
			speed *= munyeo.aura_speed_multiplier(global_position)
		position += to_target.normalized() * speed * delta
	elif _contact_timer <= 0.0:
		chase.take_damage(CONTACT_DAMAGE)
		_contact_timer = CONTACT_INTERVAL


# 체력이 가장 낮은 동료, 동료 부재 시 무녀.
func _chase_target() -> Node2D:
	var companions := get_tree().get_nodes_in_group("companion")
	var hps: Array = []
	for companion in companions:
		hps.append(companion.hp)
	var idx := ChanggwiAi.lowest_hp_index(hps)
	if idx != -1:
		return companions[idx]
	if munyeo != null and is_instance_valid(munyeo):
		return munyeo
	return null


func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		_die()


func _die() -> void:
	var soulfire := Soulfire.new()
	soulfire.position = position
	soulfire.magnet_target = munyeo
	soulfire.xp_value = SOULFIRE_VALUE
	get_parent().add_child(soulfire)
	queue_free()


func _draw() -> void:
	# 삼각형 — 원형 잡귀와 구분되는 돌진형 실루엣.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, -RADIUS - 4.0),
			Vector2(RADIUS, RADIUS),
			Vector2(-RADIUS, RADIUS),
		]),
		Color(0.65, 0.2, 0.85),
	)
