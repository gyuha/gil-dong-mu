# 스모크용 자동 조종 — 키 입력(WASD)을 주입해 무녀를 조종한다.
# 무녀는 공격하지 않으므로(ADR-0003) 킬은 동료 화력이 낸다.
# 시나리오: 동료가 잡귀를 잡아 떨어뜨린 혼불을 무녀가 수집(보유)한 뒤,
# 동료에게서 SHARE_RADIUS(90px) 밖으로 도주해 지연 흡수(3초)로 경험치를 얻는다.
# 무녀가 Lv 2에 도달하면 성공(종료코드 0), 제한 프레임 초과 시 실패(1).
extends Node

const MAX_FRAMES := 18000  # 고정 60fps 기준 300 게임초
const DEADZONE := 8.0
const SAFE_MARGIN := 30.0  # 수집 대상 혼불은 동료에게서 SHARE_RADIUS+이만큼 떨어진 것 우선

var _frames := 0
var _held := {}  # physical keycode → pressed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 드래프트 일시정지 중에도 동작


func _process(_delta: float) -> void:
	_frames += 1
	var munyeo: Node2D = get_node_or_null("/root/Main/Munyeo")
	if munyeo == null:
		return
	if munyeo.level >= 2:
		print("SMOKE OK — Lv %d (frame %d, xp %d, hp %d)" % [
			munyeo.level, _frames, munyeo.xp, munyeo.hp,
		])
		get_tree().quit(0)
		return
	if _frames > MAX_FRAMES:
		printerr("SMOKE FAIL — Lv 2 미도달 (xp %d, stock %d)" % [
			munyeo.xp, munyeo.soulfire_stock,
		])
		get_tree().quit(1)
		return
	if get_tree().paused:  # 드래프트(무녀·동료 모두 가능) — 첫 선택지를 골라 재개
		_resolve_draft()
		return
	_steer(munyeo)


func _resolve_draft() -> void:
	var ui: CanvasLayer = get_node_or_null("/root/Main/DraftUI")
	if ui != null and ui.visible:
		ui.buttons[0].pressed.emit()


# 보유가 없으면 혼불을 주우러 가고, 보유 중이면 동료 반경 밖으로 도주해 흡수를 기다린다.
func _steer(munyeo: Node2D) -> void:
	var dest := Vector2.ZERO
	var has_dest := false
	if munyeo.soulfire_stock > 0:
		dest = _flee_corner(munyeo)
		has_dest = true
	else:
		var soulfire := _target_soulfire(munyeo)
		if soulfire != null:
			dest = soulfire.global_position
			has_dest = true
	var dir := Vector2.ZERO
	if has_dest:
		dir = dest - munyeo.global_position
	_set_key(KEY_A, dir.x < -DEADZONE)
	_set_key(KEY_D, dir.x > DEADZONE)
	_set_key(KEY_W, dir.y < -DEADZONE)
	_set_key(KEY_S, dir.y > DEADZONE)


# 동료에게서 충분히 떨어진 혼불 중 가장 가까운 것. 없으면 그냥 가장 가까운 것.
func _target_soulfire(munyeo: Node2D) -> Node2D:
	var companions := get_tree().get_nodes_in_group("companion")
	var safe_dist: float = munyeo.SHARE_RADIUS + SAFE_MARGIN
	var best: Node2D = null
	var best_safe: Node2D = null
	var best_dist := INF
	var best_safe_dist := INF
	for soulfire in get_tree().get_nodes_in_group("soulfire"):
		var dist: float = munyeo.global_position.distance_to(soulfire.global_position)
		if dist < best_dist:
			best_dist = dist
			best = soulfire
		var near_companion := false
		for companion in companions:
			if soulfire.global_position.distance_to(companion.global_position) < safe_dist:
				near_companion = true
				break
		if not near_companion and dist < best_safe_dist:
			best_safe_dist = dist
			best_safe = soulfire
	return best_safe if best_safe != null else best


# 가장 가까운 동료에게서 가장 먼 구석 — 90px 밖을 3초 유지해 지연 흡수를 노린다.
func _flee_corner(munyeo: Node2D) -> Vector2:
	var corners := [
		Vector2(40, 40), Vector2(1240, 40), Vector2(40, 680), Vector2(1240, 680),
	]
	var threat := munyeo.global_position
	var threat_dist := INF
	for companion in get_tree().get_nodes_in_group("companion"):
		var dist: float = munyeo.global_position.distance_to(companion.global_position)
		if dist < threat_dist:
			threat_dist = dist
			threat = companion.global_position
	var best: Vector2 = corners[0]
	var best_dist := -1.0
	for corner in corners:
		var dist: float = threat.distance_to(corner)
		if dist > best_dist:
			best_dist = dist
			best = corner
	return best


func _set_key(keycode: Key, pressed: bool) -> void:
	if _held.get(keycode, false) == pressed:
		return
	_held[keycode] = pressed
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)
