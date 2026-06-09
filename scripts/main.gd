extends Node2D
## 게이트 프로토타입 오케스트레이터.
## 드래프트(6중3) → 월드 + 적 스폰 + HUD + 런 타이머(3분) + 입력 + 텔레메트리.
##
## 조작:
##   WASD       무녀 이동
##   1/2/3      스탠스: 공격적 / 방어적 / 사수
##   F1         디버그 시각화 토글
##   TAB        직접조종 대조군 토글(클릭 지점으로 신장 이동) — 검증용 baseline
##   R          런 재시작(드래프트부터)

const CompanionScript = preload("res://scripts/companion.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const PlayerScript = preload("res://scripts/player.gd")
const Stance = preload("res://scripts/stance.gd")
const Roster = preload("res://scripts/roster.gd")

const RUN_TIME := 180.0          # 3분 압축 루프
const SPAWN_INTERVAL := 1.1
const SPAWN_BATCH := 2
const ENEMY_CAP := 70
const DRAFT_PICK := 3            # 6중 3
const GRACE_TIME := 8.0          # 전 신장 KO 후 이 시간 내 1기 부활 못하면 패배

# --- 전역 플래그 (엔티티가 읽음) ---
var debug_show := true
var direct_control := false
var direct_target := Vector2.ZERO

# --- 텔레메트리: "유닛이 멍청하다"를 일화에서 데이터로 ---
var telemetry := {
	"stance_changes": 0,
	"target_switches": 0,
	"revive_count": 0,
	"ko_count": 0,
	"kills": 0,
}

var player: Node2D
var _companions: Array = []
var _current_stance: int = Stance.Type.AGGRESSIVE
var _time_left := RUN_TIME
var _over := false
var _drafting := true
var _grace := 0.0
var _hud: Label
var _banner: Label
var _draft_layer: CanvasLayer
var _draft_buttons: Array = []
var _start_btn: Button
var _selected: Array = []
var _spawn_timer: Timer

func _ready() -> void:
	_build_player()
	_build_hud()
	_build_draft()

func _build_player() -> void:
	player = Node2D.new()
	player.set_script(PlayerScript)
	player.position = get_viewport_rect().size * 0.5
	player.add_to_group("player")
	add_child(player)
	player.setup(self)
	var cam := Camera2D.new()
	player.add_child(cam)
	cam.make_current()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(12, 8)
	_hud.add_theme_font_size_override("font_size", 16)
	layer.add_child(_hud)
	_banner = Label.new()
	_banner.position = Vector2(0, 300)
	_banner.size = Vector2(1280, 120)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 44)
	_banner.visible = false
	layer.add_child(_banner)

func _build_draft() -> void:
	_draft_layer = CanvasLayer.new()
	add_child(_draft_layer)
	var box := VBoxContainer.new()
	box.position = Vector2(420, 90)
	box.custom_minimum_size = Vector2(440, 0)
	_draft_layer.add_child(box)
	var title := Label.new()
	title.text = "신장 %d기를 선택하라 (6중 %d) — 조합을 지휘하라" % [DRAFT_PICK, DRAFT_PICK]
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	var roster: Array = Roster.roster()
	for i in roster.size():
		var b := Button.new()
		b.toggle_mode = true
		b.text = _roster_label(roster[i])
		b.custom_minimum_size = Vector2(440, 40)
		b.toggled.connect(_on_draft_toggle.bind(i))
		box.add_child(b)
		_draft_buttons.append(b)
	_start_btn = Button.new()
	_start_btn.text = "시작 (3기 선택 필요)"
	_start_btn.disabled = true
	_start_btn.custom_minimum_size = Vector2(440, 48)
	_start_btn.pressed.connect(_start_run)
	box.add_child(_start_btn)

func _roster_label(s: Dictionary) -> String:
	var role := "원거리" if s["attack_range"] >= 120.0 else "근접"
	return "%s  [%s]  HP %d · 속도 %d · 사거리 %d · 공격 %d" % [
		s["name"], role, int(s["max_hp"]), int(s["speed"]), int(s["attack_range"]), int(s["attack_damage"])]

func _on_draft_toggle(pressed: bool, idx: int) -> void:
	if pressed:
		if _selected.size() >= DRAFT_PICK:
			_draft_buttons[idx].set_pressed_no_signal(false)  # 3개 초과 차단
			return
		_selected.append(idx)
	else:
		_selected.erase(idx)
	_start_btn.disabled = _selected.size() != DRAFT_PICK
	_start_btn.text = "시작!" if _selected.size() == DRAFT_PICK else "시작 (%d/%d 선택)" % [_selected.size(), DRAFT_PICK]

func _start_run() -> void:
	if _selected.size() != DRAFT_PICK:
		return
	var roster: Array = Roster.roster()
	for n in _selected.size():
		var idx: int = _selected[n]
		var c := Node2D.new()
		c.set_script(CompanionScript)
		c.position = player.position + Vector2.from_angle(TAU * n / DRAFT_PICK) * 55.0
		c.add_to_group("companions")
		add_child(c)
		c.setup(player, self, _current_stance, roster[idx])
		_companions.append(c)
	_draft_layer.queue_free()
	_drafting = false
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = SPAWN_INTERVAL
	_spawn_timer.autostart = true
	_spawn_timer.timeout.connect(_on_spawn)
	add_child(_spawn_timer)

func _process(delta: float) -> void:
	if _drafting or _over:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_win()
		return
	if direct_control:
		direct_target = player.get_global_mouse_position()
	_check_grace(delta)
	_update_hud()

## 전 신장 동시 KO → 그레이스 타이머. 시간 내 1기라도 부활 못하면 패배.
func _check_grace(delta: float) -> void:
	var any_alive := false
	for c in _companions:
		if is_instance_valid(c) and not c.is_ko():
			any_alive = true
			break
	if any_alive:
		_grace = 0.0
	else:
		_grace += delta
		if _grace >= GRACE_TIME:
			_finish("패배 — 전 신장 쓰러짐")

func _update_hud() -> void:
	var ko := 0
	for c in _companions:
		if is_instance_valid(c) and c.is_ko():
			ko += 1
	var t := telemetry
	var grace_txt := ""
	if _grace > 0.0:
		grace_txt = "   ⚠ 전멸까지 %.1f초" % maxf(0.0, GRACE_TIME - _grace)
	_hud.text = "시간 %d초   스탠스: %s   신장 KO %d/%d   처치 %d%s\n%s\n스탠스변경 %d · 타깃전환 %d · 부활 %d · KO누적 %d" % [
		ceili(_time_left), Stance.name_of(_current_stance), ko, _companions.size(), t["kills"], grace_txt,
		("[직접조종 ON]" if direct_control else "[지휘 모드]") + ("  디버그:" + ("ON" if debug_show else "OFF")),
		t["stance_changes"], t["target_switches"], t["revive_count"], t["ko_count"],
	]

func _on_spawn() -> void:
	if _over:
		return
	if get_tree().get_nodes_in_group("enemies").size() >= ENEMY_CAP:
		return
	for i in SPAWN_BATCH:
		var e := Node2D.new()
		e.set_script(EnemyScript)
		var ang := randf() * TAU
		e.position = player.global_position + Vector2.from_angle(ang) * randf_range(620.0, 760.0)
		e.add_to_group("enemies")
		add_child(e)
		e.setup(self)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _set_stance(Stance.Type.AGGRESSIVE)
			KEY_2: _set_stance(Stance.Type.DEFENSIVE)
			KEY_3: _set_stance(Stance.Type.HOLD)
			KEY_F1: debug_show = not debug_show
			KEY_TAB: direct_control = not direct_control
			KEY_R: get_tree().reload_current_scene()

func _set_stance(t: int) -> void:
	if _drafting or t == _current_stance:
		return
	_current_stance = t
	telemetry["stance_changes"] += 1
	for c in _companions:
		if is_instance_valid(c):
			c.stance = t

func on_player_dead() -> void:
	_finish("패배 — 무녀 사망")

func _win() -> void:
	_finish("생존 성공! (3분)")

func _finish(msg: String) -> void:
	if _over:
		return
	_over = true
	_banner.text = msg + "\n\nR: 재시작"
	_banner.visible = true
	_dump_telemetry()

func _dump_telemetry() -> void:
	print("=== RUN 종료 텔레메트리 ===")
	for k in telemetry:
		print("  %s: %d" % [k, telemetry[k]])
