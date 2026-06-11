# 메인 오케스트레이션 — 무녀·동료 배치(밤 시작 시), 잡귀·창귀 주기 스폰, HUD 갱신,
# 레벨업 드래프트(일시정지 + 3지선다 + 큐 일괄 처리, ADR-0002),
# 밤 루프(3분 타이머 + 시간 경과 스폰 강도 상승 + 승패 판정 + 결과 화면·재시작, S7).
extends Node2D

const Munyeo = preload("res://scripts/munyeo.gd")
const Japgwi = preload("res://scripts/japgwi.gd")
const Changgwi = preload("res://scripts/changgwi.gd")
const Hwarang = preload("res://scripts/hwarang.gd")
const Archer = preload("res://scripts/archer.gd")
const Command = preload("res://scripts/logic/command.gd")
const DraftPool = preload("res://scripts/logic/draft_pool.gd")
const DraftQueue = preload("res://scripts/logic/draft_queue.gd")
const SpawnCurve = preload("res://scripts/logic/spawn_curve.gd")
const Night = preload("res://scripts/logic/night.gd")
const DraftUi = preload("res://scripts/draft_ui.gd")
const ResultUi = preload("res://scripts/result_ui.gd")

# 스폰 곡선 — 밤이 깊어질수록 주기가 줄고(잡귀는 수도 늘어) 압박이 세진다.
const JAPGWI_BASE_INTERVAL := 1.5
const JAPGWI_MIN_INTERVAL := 0.6
const JAPGWI_BASE_BATCH := 1
const JAPGWI_MAX_BATCH := 3
const CHANGGWI_FIRST_DELAY := 10.0  # 첫 창귀까지 여유 — 초반에 전선이 자리잡을 시간
const CHANGGWI_BASE_INTERVAL := 8.0
const CHANGGWI_MIN_INTERVAL := 4.0
const SPAWN_MARGIN := 40.0
const ARENA := Vector2(1280, 720)
const DRAFT_CHOICES := 3

var munyeo: Node2D
var hud: Label
var _companions: Array = []  # HUD·생존 통계용 — 쓰러진 동료는 그룹에서 빠지므로 직접 추적
var draft_ui: CanvasLayer
var result_ui: CanvasLayer
var _spawn_timer := 0.0
var _changgwi_timer := CHANGGWI_FIRST_DELAY
var _night_time := 0.0  # 밤 경과 시간 — 드래프트 정지 중에는 흐르지 않는다
var _night_over := false
var _kills := 0
var _draft_queue := DraftQueue.new()
var _current_subject: Node2D
var _current_options: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_setup_night()


# 한 밤의 모든 노드를 만든다 — 재시작 시 _restart_night 가 비우고 다시 부른다.
func _setup_night() -> void:
	munyeo = Munyeo.new()
	munyeo.name = "Munyeo"
	munyeo.position = ARENA / 2.0
	munyeo.leveled_up.connect(_on_leveled_up.bind(munyeo))
	add_child(munyeo)
	_spawn_companion(Hwarang, Vector2(-80, 0))
	_spawn_companion(Archer, Vector2(80, 0))
	hud = Label.new()
	hud.position = Vector2(12, 8)
	add_child(hud)
	draft_ui = DraftUi.new()
	draft_ui.name = "DraftUI"
	draft_ui.option_chosen.connect(_on_draft_option_chosen)
	add_child(draft_ui)
	result_ui = ResultUi.new()
	result_ui.name = "ResultUI"
	result_ui.restart_requested.connect(_on_restart_requested)
	add_child(result_ui)


func _process(delta: float) -> void:
	if _night_over:
		return
	_night_time += delta
	var outcome := Night.outcome(Night.DURATION - _night_time, munyeo.hp)
	if outcome != Night.ONGOING:
		_end_night(outcome == Night.VICTORY)
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SpawnCurve.interval(
			JAPGWI_BASE_INTERVAL, JAPGWI_MIN_INTERVAL, _night_time, Night.DURATION,
		)
		var batch := SpawnCurve.batch_count(
			JAPGWI_BASE_BATCH, JAPGWI_MAX_BATCH, _night_time, Night.DURATION,
		)
		for i in batch:
			_spawn_japgwi()
	_changgwi_timer -= delta
	if _changgwi_timer <= 0.0:
		_changgwi_timer = SpawnCurve.interval(
			CHANGGWI_BASE_INTERVAL, CHANGGWI_MIN_INTERVAL, _night_time, Night.DURATION,
		)
		_spawn_changgwi()
	var text := "남은 시간 %s   HP %d/%d   MP %d/%d   Lv %d   XP %d/%d   혼불 %d   명령[1~4] %s" % [
		Night.format_time(Night.DURATION - _night_time),
		munyeo.hp, munyeo.max_hp, int(munyeo.mp), int(munyeo.max_mp),
		munyeo.level, munyeo.xp, munyeo.xp_to_next(),
		munyeo.soulfire_stock, Command.NAMES[munyeo.command],
	]
	for companion in _companions:
		if not is_instance_valid(companion):
			continue  # 구출 실패로 이탈한 동료
		if companion.downed:
			text += "\n%s   쓰러짐! %.1f초 — 근접해 구출하라" % [
				companion.display_name, companion.down_time_left(),
			]
		else:
			text += "\n%s   Lv %d   XP %d   HP %d/%d" % [
				companion.display_name, companion.level, companion.xp,
				int(companion.hp), int(companion.max_hp),
			]
	hud.text = text


# 밤 종료 — 정지 후 결과 화면. 쓰러진 채 버틴 동료도 이탈하지 않았으면 생존으로 센다.
func _end_night(victory: bool) -> void:
	_night_over = true
	get_tree().paused = true
	var survivors := 0
	for companion in _companions:
		if is_instance_valid(companion):
			survivors += 1
	result_ui.show_result(victory, _kills, survivors, _companions.size())


func _on_restart_requested() -> void:
	# 결과 화면 버튼 시그널 안에서 UI를 free 하면 위험 — 한 프레임 미뤄 리셋한다.
	_restart_night.call_deferred()


# 새 밤 — 모든 자식(무녀·동료·적·투사체·혼불·UI)을 비우고 상태를 초기화해 다시 만든다.
func _restart_night() -> void:
	get_tree().paused = false
	for child in get_children():
		child.free()
	_companions.clear()
	_draft_queue = DraftQueue.new()
	_current_subject = null
	_current_options = []
	_spawn_timer = 0.0
	_changgwi_timer = CHANGGWI_FIRST_DELAY
	_night_time = 0.0
	_night_over = false
	_kills = 0
	_setup_night()


# 동료는 밤 시작 시 무녀 곁에 배치된다(구출 이벤트 연출은 Non-goal).
func _spawn_companion(script: GDScript, offset: Vector2) -> void:
	var companion: Node2D = script.new()
	companion.munyeo = munyeo
	companion.position = munyeo.position + offset
	companion.leveled_up.connect(_on_leveled_up.bind(companion))
	add_child(companion)
	_companions.append(companion)


# 레벨업 드래프트 — 레벨업마다 큐에 적재하고, 정지 중이 아니면 정지 후 첫 드래프트를 연다.
# 정지 중에 쌓인 레벨업은 같은 정지 안에서 연속 선택된다(ADR-0002).
func _on_leveled_up(from_level: int, to_level: int, who: Node2D) -> void:
	if _night_over:
		return  # 결과 화면 위로 드래프트가 끼어들지 않게
	_draft_queue.enqueue_levels(who, from_level, to_level)
	if not get_tree().paused:
		get_tree().paused = true
		_show_next_draft()


func _show_next_draft() -> void:
	while true:
		var entry = _draft_queue.pop()
		if entry == null:
			draft_ui.close()
			get_tree().paused = false
			return
		if not is_instance_valid(entry["subject"]):
			continue  # 드래프트 전에 이탈한 동료 — 건너뛴다
		_current_subject = entry["subject"]
		var is_munyeo := _current_subject == munyeo
		var pool: Array = DraftPool.munyeo_pool() if is_munyeo else DraftPool.companion_pool()
		_current_options = DraftPool.roll(pool, DRAFT_CHOICES, _rng)
		var who_name: String = "무녀" if is_munyeo else _current_subject.display_name
		draft_ui.show_entry("%s Lv %d 드래프트" % [who_name, entry["level"]], _current_options)
		return


func _on_draft_option_chosen(index: int) -> void:
	if is_instance_valid(_current_subject):
		_current_subject.apply_draft_option(_current_options[index]["id"])
	_show_next_draft()


func _spawn_japgwi() -> void:
	var japgwi := Japgwi.new()
	japgwi.target = munyeo
	japgwi.position = _random_edge_position()
	japgwi.died.connect(_on_enemy_died)
	add_child(japgwi)


func _spawn_changgwi() -> void:
	var changgwi := Changgwi.new()
	changgwi.munyeo = munyeo
	changgwi.position = _random_edge_position()
	changgwi.died.connect(_on_enemy_died)
	add_child(changgwi)


func _on_enemy_died() -> void:
	_kills += 1


func _random_edge_position() -> Vector2:
	match randi_range(0, 3):
		0:
			return Vector2(randf_range(0.0, ARENA.x), -SPAWN_MARGIN)
		1:
			return Vector2(randf_range(0.0, ARENA.x), ARENA.y + SPAWN_MARGIN)
		2:
			return Vector2(-SPAWN_MARGIN, randf_range(0.0, ARENA.y))
		_:
			return Vector2(ARENA.x + SPAWN_MARGIN, randf_range(0.0, ARENA.y))
