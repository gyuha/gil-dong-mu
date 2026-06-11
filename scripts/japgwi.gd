# 잡귀 — 무녀를 추적하는 기본 호드 적. 접촉 피해, 사망 시 혼불 드랍.
extends Node2D

const Soulfire = preload("res://scripts/soulfire.gd")

const RADIUS := 10.0
const SPEED := 80.0
const CONTACT_RADIUS := 26.0
const CONTACT_DAMAGE := 8
const CONTACT_INTERVAL := 0.6

var hp := 2
var target: Node2D
var _contact_timer := 0.0


func _ready() -> void:
	add_to_group("japgwi")


func _process(delta: float) -> void:
	_contact_timer -= delta
	if target == null or not is_instance_valid(target):
		return
	var to_target := target.global_position - global_position
	if to_target.length() > CONTACT_RADIUS:
		var speed := SPEED
		if target.has_method("aura_speed_multiplier"):
			speed *= target.aura_speed_multiplier(global_position)
		position += to_target.normalized() * speed * delta
	elif _contact_timer <= 0.0:
		target.take_damage(CONTACT_DAMAGE)
		_contact_timer = CONTACT_INTERVAL


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
