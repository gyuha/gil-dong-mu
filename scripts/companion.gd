extends Node2D
## 신장(Companion) — 자율 전투 유닛. 행동 FSM + leash 스탠스 + 근접부활 KO.
##
##   ┌──────┐ target!=null  ┌───────┐  in range   ┌────────┐
##   │SELECT├──────────────►│ CHASE ├────────────►│ ATTACK │
##   └──▲───┘               └───┬───┘  out range  └───┬────┘
##      │ target lost           │◄────────────────────┘
##      │                       │ hp<=0
##      │      revived          ▼
##      └──────────────────── ┌────┐
##                            │ KO │ (무녀 근접 시 부활)
##                            └────┘
##
## 이동: 물리충돌 없음. 타깃쪽 조향 + 동료 간 분리(separation)만. (VS류 [Layer 1])
## 타깃 선정은 scripts/targeting.gd(순수함수, 테스트됨)에 위임 — 0.25초 주기 + 히스테리시스.

const Targeting = preload("res://scripts/targeting.gd")
const Stance = preload("res://scripts/stance.gd")
const ReviveUtil = preload("res://scripts/revive_util.gd")

enum State { SELECT, CHASE, ATTACK, KO }

@export var max_hp := 60.0
@export var speed := 170.0
@export var attack_range := 46.0
@export var attack_damage := 18.0
@export var attack_cooldown := 0.5
@export var radius := 12.0

const REEVAL_INTERVAL := 0.25
const SEPARATION_RADIUS := 34.0
const REVIVE_TIME := 1.0  # 무녀가 근접 유지해야 하는 시간

var hp := max_hp
var stance: int = Stance.Type.AGGRESSIVE
var state: int = State.SELECT
var anchor: Node2D            # 무녀
var main: Node                # 텔레메트리/전역 플래그 접근
var color := Color(0.3, 0.85, 0.4)
var display_name := "신장"

var _target: Node2D = null
var _target_id := -1
var _reeval := 0.0
var _atk := 0.0
var _flash := 0.0             # 공격 순간 타깃 선 표시(원거리 가독성)
var revive_progress := 0.0    # 0~1, 무녀가 채워줌

## stats(Dictionary)로 6종 차이를 데이터 주입. 비면 @export 기본값 사용.
func setup(p_anchor: Node2D, p_main: Node, p_stance: int, stats: Dictionary = {}) -> void:
	anchor = p_anchor
	main = p_main
	stance = p_stance
	if not stats.is_empty():
		display_name = stats.get("name", display_name)
		max_hp = stats.get("max_hp", max_hp)
		speed = stats.get("speed", speed)
		attack_range = stats.get("attack_range", attack_range)
		attack_damage = stats.get("attack_damage", attack_damage)
		attack_cooldown = stats.get("attack_cooldown", attack_cooldown)
		radius = stats.get("radius", radius)
		color = stats.get("color", color)
	hp = max_hp

func is_ko() -> bool:
	return state == State.KO

func _physics_process(delta: float) -> void:
	if state == State.KO:
		queue_redraw()
		return

	# 직접조종 대조군 모드: FSM 우회, 마우스 클릭 지점으로 이동
	if main and main.direct_control:
		_move_toward(main.direct_target, delta)
		state = State.CHASE
		queue_redraw()
		return

	_reeval -= delta
	if _reeval <= 0.0:
		_reeval = REEVAL_INTERVAL
		_reselect_target()

	_atk = maxf(0.0, _atk - delta)
	_flash = maxf(0.0, _flash - delta)

	if is_instance_valid(_target):
		var d := global_position.distance_to(_target.global_position)
		if d > attack_range:
			state = State.CHASE
			_move_toward(_target.global_position, delta)
		else:
			state = State.ATTACK
			_apply_separation(delta)  # 붙어서도 서로 안 겹치게
			if _atk <= 0.0:
				_target.take_damage(attack_damage)
				_atk = attack_cooldown
				_flash = 0.09  # 공격 순간 표시(특히 원거리 신장 가독성)
	else:
		# 타깃 없음 → 무녀 곁으로 복귀(idle)
		state = State.SELECT
		_target = null
		_target_id = -1
		if anchor and global_position.distance_to(anchor.global_position) > 60.0:
			_move_toward(anchor.global_position, delta)
		else:
			_apply_separation(delta)

	queue_redraw()

func _reselect_target() -> void:
	var anchor_pos: Vector2 = anchor.global_position if anchor else global_position
	var candidates: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			candidates.append({"id": e.get_instance_id(), "pos": e.global_position})
	var stance_params := Stance.params(stance)
	var chosen := Targeting.select_target(global_position, anchor_pos, candidates, stance_params, _target_id)
	if chosen != _target_id:
		if main and chosen != -1:
			main.telemetry["target_switches"] += 1
		_target_id = chosen
	_target = instance_from_id(chosen) as Node2D if chosen != -1 else null

func _move_toward(point: Vector2, delta: float) -> void:
	var dir := (point - global_position)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var sep := _separation_vector()
	var vel := (dir + sep * 0.8).normalized() * speed if (dir + sep * 0.8).length() > 0.01 else Vector2.ZERO
	global_position += vel * delta

func _apply_separation(delta: float) -> void:
	global_position += _separation_vector() * speed * 0.5 * delta

func _separation_vector() -> Vector2:
	var push := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("companions"):
		if other == self or not is_instance_valid(other):
			continue
		var diff: Vector2 = global_position - other.global_position
		var dist := diff.length()
		if dist < SEPARATION_RADIUS and dist > 0.01:
			push += diff.normalized() * (1.0 - dist / SEPARATION_RADIUS)
	return push

func take_damage(d: float) -> void:
	if state == State.KO:
		return
	hp -= d
	if hp <= 0.0:
		hp = 0.0
		state = State.KO
		revive_progress = 0.0
		_target = null
		_target_id = -1
		if main:
			main.telemetry["ko_count"] += 1

## 무녀가 근접 유지 시 호출. 충분히 채워지면 부활.
func feed_revive(delta: float) -> bool:
	if state != State.KO:
		return false
	revive_progress += delta / REVIVE_TIME
	if revive_progress >= 1.0:
		state = State.SELECT
		hp = max_hp * 0.5
		revive_progress = 0.0
		if main:
			main.telemetry["revive_count"] += 1
		return true
	return false

func _draw() -> void:
	if state == State.KO:
		# KO: 회색 + X, 부활 게이지
		draw_circle(Vector2.ZERO, radius, Color(0.45, 0.45, 0.45))
		draw_line(Vector2(-7, -7), Vector2(7, 7), Color.WHITE, 2.0)
		draw_line(Vector2(-7, 7), Vector2(7, -7), Color.WHITE, 2.0)
		if revive_progress > 0.0:
			draw_arc(Vector2.ZERO, radius + 6, -PI / 2, -PI / 2 + TAU * revive_progress, 24, Color.CYAN, 3.0)
		return

	draw_circle(Vector2.ZERO, radius, color)
	# HP 바
	var w := radius * 2.0
	draw_rect(Rect2(-radius, -radius - 8, w, 3), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(-radius, -radius - 8, w * (hp / max_hp), 3), Color.LIME_GREEN)

	# 공격 플래시 — 타깃까지 선(근접/원거리 모두 "지금 친다"가 보임)
	if _flash > 0.0 and is_instance_valid(_target):
		draw_line(Vector2.ZERO, to_local(_target.global_position), Color(1, 1, 0.6, 0.9), 2.0)

	if not (main and main.debug_show):
		return
	# --- 디버그 시각화 (튜닝의 눈) ---
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-12, radius + 16), _state_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	# leash 반경(무녀 기준이라 무녀-상대 좌표로 그림)
	if anchor:
		var leash: float = Stance.params(stance)["leash"]
		if leash < 2000.0:
			draw_arc(to_local(anchor.global_position), leash, 0, TAU, 48, Color(1, 1, 0, 0.25), 1.0)
	# 현재 타깃 선
	if is_instance_valid(_target):
		draw_line(Vector2.ZERO, to_local(_target.global_position), Color(1, 0.3, 0.3, 0.6), 1.5)

func _state_name() -> String:
	match state:
		State.SELECT: return "SELECT"
		State.CHASE: return "CHASE"
		State.ATTACK: return "ATTACK"
		State.KO: return "KO"
		_: return "?"
