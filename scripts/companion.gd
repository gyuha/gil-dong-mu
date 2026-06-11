# 동료 공통 — 자율 전투(타깃 선정→추적→공격), 명령 파라미터 반영, 후퇴·추종, 경험치·레벨.
# 구체 수치·공격 방식은 서브클래스(화랑/활잡이)가 정한다.
# 쓰러짐(downed)·구출은 S6 — 여기서는 HP 0이면 그 밤에서 이탈(소멸)한다.
extends Node2D

const CompanionAi = preload("res://scripts/logic/companion_ai.gd")
const Command = preload("res://scripts/logic/command.gd")
const Experience = preload("res://scripts/logic/experience.gd")

const RADIUS := 12.0
const ARENA := Vector2(1280, 720)
const HP_BAR_WIDTH := 28.0

var munyeo: Node2D
var display_name := "동료"
var max_hp := 40.0
var hp := max_hp
var level := 1
var xp := 0
var speed := 150.0
var attack_range := 34.0
var attack_damage := 2
var attack_cooldown := 0.8
var body_color := Color(0.8, 0.8, 0.8)

var _attack_timer := 0.0


func _ready() -> void:
	add_to_group("companion")
	hp = max_hp


func _process(delta: float) -> void:
	_attack_timer -= delta
	queue_redraw()  # HP 바 갱신
	if munyeo == null or not is_instance_valid(munyeo):
		return
	var params: Dictionary = Command.params(munyeo.command)
	if CompanionAi.should_retreat(hp, max_hp, params["retreat_hp_ratio"]):
		_move_toward(munyeo.global_position, params["follow_distance"], delta)
		return
	var enemies := get_tree().get_nodes_in_group("japgwi")
	var positions: Array = []
	for enemy in enemies:
		positions.append(enemy.global_position)
	var idx := CompanionAi.select_target(
		global_position, munyeo.global_position, positions,
		params["engage_range"], params["leash"],
	)
	if idx == -1:
		_move_toward(munyeo.global_position, params["follow_distance"], delta)
		return
	var target: Node2D = enemies[idx]
	if global_position.distance_to(target.global_position) > attack_range:
		_move_toward(target.global_position, attack_range * 0.9, delta)
	elif _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		_attack(target)


# 기본은 근접 타격. 원거리 동료는 재정의한다.
func _attack(enemy: Node2D) -> void:
	enemy.take_damage(attack_damage)


func take_damage(amount: int) -> void:
	hp = maxf(hp - amount, 0.0)
	if hp <= 0.0:
		_die()


func heal(amount: float) -> void:
	hp = minf(hp + amount, max_hp)


func gain_xp(amount: int) -> void:
	var result := Experience.apply_xp(level, xp, amount)
	if result["level"] > level:
		print("%s 레벨 업! Lv %d" % [display_name, result["level"]])
	level = result["level"]
	xp = result["xp"]


func _move_toward(dest: Vector2, stop_distance: float, delta: float) -> void:
	var to_dest := dest - global_position
	if to_dest.length() <= stop_distance:
		return
	position += to_dest.normalized() * speed * delta
	position.x = clampf(position.x, RADIUS, ARENA.x - RADIUS)
	position.y = clampf(position.y, RADIUS, ARENA.y - RADIUS)


func _die() -> void:
	print("%s 이탈 — 그 밤에서 빠진다 (쓰러짐·구출은 S6)" % display_name)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, body_color)
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	var bar_pos := Vector2(-HP_BAR_WIDTH / 2.0, -RADIUS - 10.0)
	draw_rect(Rect2(bar_pos, Vector2(HP_BAR_WIDTH, 4.0)), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(bar_pos, Vector2(HP_BAR_WIDTH * ratio, 4.0)), Color(0.3, 0.9, 0.3))
