# 무녀 — 플레이어 조작(WASD/방향키), 자동 주술(혼불 부적), HP, 혼불 수집·경험치.
extends Node2D

const Targeting = preload("res://scripts/logic/targeting.gd")
const Experience = preload("res://scripts/logic/experience.gd")
const Talisman = preload("res://scripts/talisman.gd")

const RADIUS := 14.0
const SPEED := 220.0
const ATTACK_COOLDOWN := 0.7
const ATTACK_RANGE := 500.0
const PICKUP_RADIUS := 60.0
const ARENA := Vector2(1280, 720)

var max_hp := 100
var hp := max_hp
var level := 1
var xp := 0
var _attack_timer := 0.0


func _process(delta: float) -> void:
	_move(delta)
	_auto_attack(delta)
	_collect_soulfires()


func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)


func gain_xp(amount: int) -> void:
	var result := Experience.apply_xp(level, xp, amount)
	if result["level"] > level:
		print("레벨 업! Lv %d" % result["level"])
	level = result["level"]
	xp = result["xp"]


func xp_to_next() -> int:
	return Experience.xp_required(level)


func _move(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		position += dir.normalized() * SPEED * delta
		position.x = clampf(position.x, RADIUS, ARENA.x - RADIUS)
		position.y = clampf(position.y, RADIUS, ARENA.y - RADIUS)


func _auto_attack(delta: float) -> void:
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	var enemies := get_tree().get_nodes_in_group("japgwi")
	var positions: Array = []
	for enemy in enemies:
		positions.append(enemy.global_position)
	var idx := Targeting.nearest_index(global_position, positions, ATTACK_RANGE)
	if idx == -1:
		return
	_attack_timer = ATTACK_COOLDOWN
	var talisman := Talisman.new()
	talisman.position = position
	talisman.direction = (positions[idx] - global_position).normalized()
	get_parent().add_child(talisman)


func _collect_soulfires() -> void:
	for soulfire in get_tree().get_nodes_in_group("soulfire"):
		if global_position.distance_to(soulfire.global_position) <= PICKUP_RADIUS:
			gain_xp(soulfire.xp_value)
			soulfire.queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(0.92, 0.95, 1.0))
