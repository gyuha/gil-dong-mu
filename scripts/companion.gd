# 동료 공통 — 자율 전투(타깃 선정→추적→공격), 명령 파라미터 반영, 후퇴·추종, 경험치·레벨.
# 구체 수치·공격 방식은 서브클래스(화랑/탈 쓴 퇴마사)가 정한다.
# HP 0이면 즉사 대신 쓰러짐(downed) — 전투 불능, 전투 그룹에서 빠져 적의 표적에서 제외.
# 제한 시간 안에 무녀가 근접을 유지하면 구출, 실패하면 그 밤에서 이탈한다.
# 레벨업 시 leveled_up 시그널 — main이 받아 드래프트 큐에 적재한다(S5).
extends Node2D

signal leveled_up(from_level: int, to_level: int)

const CompanionAi = preload("res://scripts/logic/companion_ai.gd")
const Command = preload("res://scripts/logic/command.gd")
const Experience = preload("res://scripts/logic/experience.gd")
const DraftPool = preload("res://scripts/logic/draft_pool.gd")
const Downed = preload("res://scripts/logic/downed.gd")

const RADIUS := 12.0
const ARENA := Vector2(1280, 720)
const HP_BAR_WIDTH := 28.0

const DOWN_TIME := 8.0  # 이 시간 안에 구출되지 않으면 그 밤에서 이탈
const RESCUE_RADIUS := 50.0  # 무녀가 이 거리 안에 머물러야 구출 진행
const RESCUE_TIME := 1.5  # 근접 유지 필요 시간
const REVIVE_HP_RATIO := 0.35  # 구출 시 회복되는 HP 비율

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
var downed := false

var _attack_timer := 0.0
var _down_state := {}


func _ready() -> void:
	for group in _combat_groups():
		add_to_group(group)
	hp = max_hp


func _process(delta: float) -> void:
	_attack_timer -= delta
	queue_redraw()  # HP·타이머 바 갱신
	if munyeo == null or not is_instance_valid(munyeo):
		return
	if downed:
		_process_downed(delta)
		return
	var params: Dictionary = Command.params(munyeo.command)
	if CompanionAi.should_retreat(hp, max_hp, params["retreat_hp_ratio"]):
		_move_toward(munyeo.global_position, params["follow_distance"], delta)
		return
	var enemies := get_tree().get_nodes_in_group("enemy")
	var positions: Array = []
	for enemy in enemies:
		positions.append(enemy.global_position)
	# 명령 강화(무녀 드래프트) — 교전·추적 범위 배율.
	var range_bonus: float = munyeo.command_range_bonus
	var idx := CompanionAi.select_target(
		global_position, munyeo.global_position, positions,
		params["engage_range"] * range_bonus, params["leash"] * range_bonus,
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


# 쓰러짐 중 소속되지 않는 전투 그룹. 서브클래스가 추가 그룹(예: "hwarang")을 더한다.
func _combat_groups() -> Array:
	return ["companion"]


func take_damage(amount: int) -> void:
	if downed:
		return  # 쓰러진 동료는 표적·피해 대상이 아니다
	hp = maxf(hp - amount, 0.0)
	if hp <= 0.0:
		_enter_downed()


func heal(amount: float) -> void:
	if downed:
		return
	hp = minf(hp + amount, max_hp)


func down_time_left() -> float:
	return _down_state.get("time_left", 0.0)


func gain_xp(amount: int) -> void:
	var result := Experience.apply_xp(level, xp, amount)
	var from_level := level
	level = result["level"]
	xp = result["xp"]
	if level > from_level:
		leveled_up.emit(from_level, level)


# 드래프트 선택 적용 — 현재 수치를 DraftPool.apply 에 통과시켜 되쓴다.
func apply_draft_option(option_id: String) -> void:
	var s := DraftPool.apply(draft_stats(), option_id)
	hp += s["max_hp"] - max_hp  # 최대 HP 증가분만큼 즉시 회복
	max_hp = s["max_hp"]
	attack_damage = s["attack_damage"]
	attack_cooldown = s["attack_cooldown"]
	speed = s["speed"]
	attack_range = s["attack_range"]


func draft_stats() -> Dictionary:
	return {
		"max_hp": max_hp, "attack_damage": attack_damage,
		"attack_cooldown": attack_cooldown, "speed": speed,
		"attack_range": attack_range,
	}


func _move_toward(dest: Vector2, stop_distance: float, delta: float) -> void:
	var to_dest := dest - global_position
	if to_dest.length() <= stop_distance:
		return
	position += to_dest.normalized() * speed * delta
	position.x = clampf(position.x, RADIUS, ARENA.x - RADIUS)
	position.y = clampf(position.y, RADIUS, ARENA.y - RADIUS)


# 쓰러짐 진입 — 전투 그룹에서 빠져 적 표적·오라 회복·혼불 분배 대상에서 제외된다.
func _enter_downed() -> void:
	downed = true
	_down_state = Downed.initial_state(DOWN_TIME)
	for group in _combat_groups():
		remove_from_group(group)
	print("%s 쓰러짐 — %0.f초 안에 구출해야 한다" % [display_name, DOWN_TIME])


# 쓰러짐 진행 — 무녀와의 거리로 구출/이탈을 판정한다(규칙은 Downed 순수 로직).
func _process_downed(delta: float) -> void:
	_down_state = Downed.step(
		_down_state, global_position.distance_to(munyeo.global_position),
		delta, RESCUE_RADIUS, RESCUE_TIME,
	)
	match _down_state["status"]:
		"rescued":
			downed = false
			hp = max_hp * REVIVE_HP_RATIO
			for group in _combat_groups():
				add_to_group(group)
			print("%s 구출 — 다시 일어선다 (HP %.0f)" % [display_name, hp])
		"lost":
			print("%s 이탈 — 구출 실패, 그 밤에서 빠진다" % display_name)
			queue_free()


func _draw() -> void:
	if downed:
		_draw_downed()
		return
	draw_circle(Vector2.ZERO, RADIUS, body_color)
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	var bar_pos := Vector2(-HP_BAR_WIDTH / 2.0, -RADIUS - 10.0)
	draw_rect(Rect2(bar_pos, Vector2(HP_BAR_WIDTH, 4.0)), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(bar_pos, Vector2(HP_BAR_WIDTH * ratio, 4.0)), Color(0.3, 0.9, 0.3))


# 쓰러짐 시각화 — 흐려진 몸체 + 남은 시간 바(노랑) + 구출 진행 호(흰색).
func _draw_downed() -> void:
	draw_circle(Vector2.ZERO, RADIUS, body_color.darkened(0.6))
	var time_ratio := clampf(down_time_left() / DOWN_TIME, 0.0, 1.0)
	var bar_pos := Vector2(-HP_BAR_WIDTH / 2.0, -RADIUS - 10.0)
	draw_rect(Rect2(bar_pos, Vector2(HP_BAR_WIDTH, 4.0)), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(bar_pos, Vector2(HP_BAR_WIDTH * time_ratio, 4.0)), Color(0.95, 0.8, 0.2))
	var progress: float = _down_state.get("rescue_progress", 0.0) / RESCUE_TIME
	if progress > 0.0:
		draw_arc(
			Vector2.ZERO, RADIUS + 5.0, -PI / 2.0, -PI / 2.0 + TAU * progress,
			32, Color(1.0, 1.0, 1.0, 0.9), 2.5,
		)
