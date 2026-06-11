# 무녀 — 서포트 전용 지휘자(ADR-0003), 직접 공격하지 않는다.
# 플레이어 조작(WASD/방향키), HP, 혼불 수집(보유 적립),
# 오라(영역 내 적 감속 + 동료 회복), MP(자연 회복), 밀쳐내기(스페이스, MP 소비·비살상),
# 혼불 전달(근접 동료에게 전부 — 무녀 몫 없음, 부재 시 지연 후 무녀가 흡수해 경험치),
# 명령(1~4키 — 동료 성향 전환).
# 레벨업 시 leveled_up 시그널 — main이 받아 드래프트 큐에 적재한다(S5).
extends Node2D

signal leveled_up(from_level: int, to_level: int)

const Experience = preload("res://scripts/logic/experience.gd")
const Aura = preload("res://scripts/logic/aura.gd")
const Mp = preload("res://scripts/logic/mp.gd")
const Command = preload("res://scripts/logic/command.gd")
const SoulfireShare = preload("res://scripts/logic/soulfire_share.gd")
const DraftPool = preload("res://scripts/logic/draft_pool.gd")

const RADIUS := 14.0
const PICKUP_RADIUS := 60.0
const ARENA := Vector2(1280, 720)

const AURA_SLOW_MULTIPLIER := 0.5
const AURA_LEVEL_DIFF_SCALE := 1.0  # 레벨차 정밀 보정 자리 — Non-goal, 상수만 둔다.

const SHARE_RADIUS := 90.0  # 이 거리 안 동료에게 보유 혼불을 자동 전달
const ABSORB_DELAY := 3.0  # 반경 내 동료 부재 시 이 시간 뒤 무녀가 보유 혼불을 흡수

const REPEL_COST := 30.0
const REPEL_DISTANCE := 120.0
const REPEL_FLASH_TIME := 0.25

var max_hp := 100
var hp := max_hp
var max_mp := 100.0
var mp := max_mp
var level := 1
var xp := 0
var command := Command.NEARBY
var soulfire_stock := 0  # 보유 혼불 — 근접 동료에게 전달되거나 지연 후 무녀가 흡수

# 드래프트로 강화되는 수치 — DraftPool.apply 가 다루는 키와 1:1 대응.
var speed := 220.0  # 이동속도
var repel_radius := 160.0  # 밀쳐내기 반경
var magnet_radius := 130.0  # 혼불 자석 반경 — soulfire가 magnet_target(무녀)에서 읽는다
var aura_radius := 140.0
var aura_heal_rate := 5.0  # 오라 안 동료 초당 회복량
var mp_regen_rate := 10.0  # 초당 회복량
var command_range_bonus := 1.0  # 명령 강화 — 동료 교전·추적 범위 배율

var _absorb_timer := 0.0  # 동료 부재 상태로 혼불을 보유한 누적 시간
var _repel_key_held := false
var _repel_flash := 0.0


func _process(delta: float) -> void:
	_move(delta)
	_collect_soulfires()
	_share_soulfires(delta)
	_heal_companions(delta)
	mp = Mp.regen(mp, max_mp, mp_regen_rate, delta)
	_handle_repel_input()
	_handle_command_input()
	if _repel_flash > 0.0:
		_repel_flash -= delta
		queue_redraw()


# 오라 — 적이 자기 위치를 넣어 이동속도 배율을 얻는다.
func aura_speed_multiplier(enemy_position: Vector2) -> float:
	return Aura.speed_multiplier(
		global_position.distance_to(enemy_position),
		aura_radius, AURA_SLOW_MULTIPLIER, AURA_LEVEL_DIFF_SCALE,
	)


# 밀쳐내기 — MP가 충분하면 소비하고 주변 적을 바깥으로 밀어낸다. 부족하면 불발(false).
func repel() -> bool:
	var result := Mp.try_spend(mp, REPEL_COST)
	mp = result["mp"]
	if not result["ok"]:
		return false
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var offset: Vector2 = Aura.repel_offset(
			global_position, enemy.global_position, repel_radius, REPEL_DISTANCE,
		)
		enemy.global_position += offset
	_repel_flash = REPEL_FLASH_TIME
	queue_redraw()
	return true


func _handle_repel_input() -> void:
	var pressed := Input.is_physical_key_pressed(KEY_SPACE)
	if pressed and not _repel_key_held:
		repel()
	_repel_key_held = pressed


func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)


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
	speed = s["speed"]
	repel_radius = s["repel_radius"]
	magnet_radius = s["magnet_radius"]
	aura_radius = s["aura_radius"]
	aura_heal_rate = s["aura_heal_rate"]
	max_mp = s["max_mp"]
	mp_regen_rate = s["mp_regen_rate"]
	command_range_bonus = s["command_range_bonus"]
	queue_redraw()  # 오라 반경이 바뀌었을 수 있다


func draft_stats() -> Dictionary:
	return {
		"speed": speed, "repel_radius": repel_radius,
		"magnet_radius": magnet_radius, "aura_radius": aura_radius,
		"aura_heal_rate": aura_heal_rate, "max_mp": max_mp,
		"mp_regen_rate": mp_regen_rate, "command_range_bonus": command_range_bonus,
	}


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
		position += dir.normalized() * speed * delta
		position.x = clampf(position.x, RADIUS, ARENA.x - RADIUS)
		position.y = clampf(position.y, RADIUS, ARENA.y - RADIUS)


# 혼불 수집 — 보유량 적립만 한다(무녀 경험치는 지연 흡수 때만).
func _collect_soulfires() -> void:
	for soulfire in get_tree().get_nodes_in_group("soulfire"):
		if global_position.distance_to(soulfire.global_position) <= PICKUP_RADIUS:
			soulfire_stock += soulfire.xp_value
			soulfire.queue_free()


# 혼불 전달 — SHARE_RADIUS 안 가장 가까운 동료에게 전부 준다(무녀 몫 없음).
# 반경 내 동료가 없으면 ABSORB_DELAY 뒤 무녀가 흡수해 경험치로 삼는다.
func _share_soulfires(delta: float) -> void:
	var companions := get_tree().get_nodes_in_group("companion")
	var distances: Array = []
	for companion in companions:
		distances.append(global_position.distance_to(companion.global_position))
	var transfer := SoulfireShare.distribute(soulfire_stock, distances, SHARE_RADIUS)
	if transfer["index"] != -1:
		companions[transfer["index"]].gain_xp(transfer["given"])
	soulfire_stock = transfer["stock"]
	var absorb := SoulfireShare.absorb_tick(
		soulfire_stock, _absorb_timer, delta, ABSORB_DELAY,
	)
	_absorb_timer = absorb["timer"]
	soulfire_stock = absorb["stock"]
	if absorb["absorbed"] > 0:
		gain_xp(absorb["absorbed"])


# 오라 회복 — aura_radius 안의 동료를 초당 aura_heal_rate 만큼 회복.
func _heal_companions(delta: float) -> void:
	for companion in get_tree().get_nodes_in_group("companion"):
		if global_position.distance_to(companion.global_position) <= aura_radius:
			companion.heal(aura_heal_rate * delta)


# 명령 입력 — 1:주변 2:공격적 3:방어적 4:모여라.
func _handle_command_input() -> void:
	if Input.is_physical_key_pressed(KEY_1):
		command = Command.NEARBY
	elif Input.is_physical_key_pressed(KEY_2):
		command = Command.AGGRESSIVE
	elif Input.is_physical_key_pressed(KEY_3):
		command = Command.DEFENSIVE
	elif Input.is_physical_key_pressed(KEY_4):
		command = Command.RALLY


func _draw() -> void:
	draw_circle(Vector2.ZERO, aura_radius, Color(0.5, 0.8, 1.0, 0.08))
	draw_arc(Vector2.ZERO, aura_radius, 0.0, TAU, 64, Color(0.5, 0.8, 1.0, 0.35), 2.0)
	if _repel_flash > 0.0:
		var alpha := _repel_flash / REPEL_FLASH_TIME
		draw_arc(Vector2.ZERO, repel_radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, alpha), 4.0)
	draw_circle(Vector2.ZERO, RADIUS, Color(0.92, 0.95, 1.0))
