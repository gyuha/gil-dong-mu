# 무녀 — 플레이어 조작(WASD/방향키), 자동 주술(혼불 부적), HP, 혼불 수집·경험치,
# 오라(영역 내 적 감속 + 동료 회복), MP(자연 회복), 밀쳐내기(스페이스, MP 소비),
# 혼불 분배(보유 혼불을 근접 동료에게), 명령(1~4키 — 동료 성향 전환).
extends Node2D

const Targeting = preload("res://scripts/logic/targeting.gd")
const Experience = preload("res://scripts/logic/experience.gd")
const Aura = preload("res://scripts/logic/aura.gd")
const Mp = preload("res://scripts/logic/mp.gd")
const Command = preload("res://scripts/logic/command.gd")
const SoulfireShare = preload("res://scripts/logic/soulfire_share.gd")
const Talisman = preload("res://scripts/talisman.gd")

const RADIUS := 14.0
const SPEED := 220.0
const ATTACK_COOLDOWN := 0.7
const ATTACK_RANGE := 500.0
const PICKUP_RADIUS := 60.0
const ARENA := Vector2(1280, 720)

const AURA_RADIUS := 140.0
const AURA_SLOW_MULTIPLIER := 0.5
const AURA_LEVEL_DIFF_SCALE := 1.0  # 레벨차 정밀 보정 자리 — Non-goal, 상수만 둔다.
const AURA_HEAL_RATE := 5.0  # 오라 안 동료 초당 회복량

const SHARE_RADIUS := 90.0  # 이 거리 안 동료에게 보유 혼불을 자동 분배

const MP_REGEN_RATE := 10.0  # 초당 회복량
const REPEL_COST := 30.0
const REPEL_RADIUS := 160.0
const REPEL_DISTANCE := 120.0
const REPEL_FLASH_TIME := 0.25

var max_hp := 100
var hp := max_hp
var max_mp := 100.0
var mp := max_mp
var level := 1
var xp := 0
var command := Command.NEARBY
var soulfire_stock := 0  # 동료에게 나눠줄 보유 혼불
var _attack_timer := 0.0
var _repel_key_held := false
var _repel_flash := 0.0


func _process(delta: float) -> void:
	_move(delta)
	_auto_attack(delta)
	_collect_soulfires()
	_share_soulfires()
	_heal_companions(delta)
	mp = Mp.regen(mp, max_mp, MP_REGEN_RATE, delta)
	_handle_repel_input()
	_handle_command_input()
	if _repel_flash > 0.0:
		_repel_flash -= delta
		queue_redraw()


# 오라 — 적이 자기 위치를 넣어 이동속도 배율을 얻는다.
func aura_speed_multiplier(enemy_position: Vector2) -> float:
	return Aura.speed_multiplier(
		global_position.distance_to(enemy_position),
		AURA_RADIUS, AURA_SLOW_MULTIPLIER, AURA_LEVEL_DIFF_SCALE,
	)


# 밀쳐내기 — MP가 충분하면 소비하고 주변 적을 바깥으로 밀어낸다. 부족하면 불발(false).
func repel() -> bool:
	var result := Mp.try_spend(mp, REPEL_COST)
	mp = result["mp"]
	if not result["ok"]:
		return false
	for enemy in get_tree().get_nodes_in_group("japgwi"):
		var offset: Vector2 = Aura.repel_offset(
			global_position, enemy.global_position, REPEL_RADIUS, REPEL_DISTANCE,
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
			soulfire_stock += soulfire.xp_value
			soulfire.queue_free()


# 혼불 분배 — 보유 혼불을 SHARE_RADIUS 안 가장 가까운 동료에게 전부 준다.
func _share_soulfires() -> void:
	if soulfire_stock <= 0:
		return
	var companions := get_tree().get_nodes_in_group("companion")
	var distances: Array = []
	for companion in companions:
		distances.append(global_position.distance_to(companion.global_position))
	var result := SoulfireShare.distribute(soulfire_stock, distances, SHARE_RADIUS)
	if result["index"] == -1:
		return
	companions[result["index"]].gain_xp(result["given"])
	soulfire_stock = result["stock"]


# 오라 회복 — AURA_RADIUS 안의 동료를 초당 AURA_HEAL_RATE 만큼 회복.
func _heal_companions(delta: float) -> void:
	for companion in get_tree().get_nodes_in_group("companion"):
		if global_position.distance_to(companion.global_position) <= AURA_RADIUS:
			companion.heal(AURA_HEAL_RATE * delta)


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
	draw_circle(Vector2.ZERO, AURA_RADIUS, Color(0.5, 0.8, 1.0, 0.08))
	draw_arc(Vector2.ZERO, AURA_RADIUS, 0.0, TAU, 64, Color(0.5, 0.8, 1.0, 0.35), 2.0)
	if _repel_flash > 0.0:
		var alpha := _repel_flash / REPEL_FLASH_TIME
		draw_arc(Vector2.ZERO, REPEL_RADIUS, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, alpha), 4.0)
	draw_circle(Vector2.ZERO, RADIUS, Color(0.92, 0.95, 1.0))
