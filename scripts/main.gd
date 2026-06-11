# 메인 오케스트레이션 — 무녀·동료 배치(밤 시작 시), 잡귀·창귀 주기 스폰, HUD 갱신,
# 레벨업 드래프트(일시정지 + 3지선다 + 큐 일괄 처리, ADR-0002).
extends Node2D

const Munyeo = preload("res://scripts/munyeo.gd")
const Japgwi = preload("res://scripts/japgwi.gd")
const Changgwi = preload("res://scripts/changgwi.gd")
const Hwarang = preload("res://scripts/hwarang.gd")
const Archer = preload("res://scripts/archer.gd")
const Command = preload("res://scripts/logic/command.gd")
const DraftPool = preload("res://scripts/logic/draft_pool.gd")
const DraftQueue = preload("res://scripts/logic/draft_queue.gd")
const DraftUi = preload("res://scripts/draft_ui.gd")

const SPAWN_INTERVAL := 1.5
const CHANGGWI_FIRST_DELAY := 10.0  # 첫 창귀까지 여유 — 초반에 전선이 자리잡을 시간
const CHANGGWI_INTERVAL := 8.0
const SPAWN_MARGIN := 40.0
const ARENA := Vector2(1280, 720)
const DRAFT_CHOICES := 3

var munyeo: Node2D
var hud: Label
var _companions: Array = []  # HUD용 — 쓰러진 동료는 그룹에서 빠지므로 직접 추적
var draft_ui: CanvasLayer
var _spawn_timer := 0.0
var _changgwi_timer := CHANGGWI_FIRST_DELAY
var _draft_queue := DraftQueue.new()
var _current_subject: Node2D
var _current_options: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
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


func _process(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		_spawn_japgwi()
	_changgwi_timer -= delta
	if _changgwi_timer <= 0.0:
		_changgwi_timer = CHANGGWI_INTERVAL
		_spawn_changgwi()
	var text := "HP %d/%d   MP %d/%d   Lv %d   XP %d/%d   혼불 %d   명령[1~4] %s" % [
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
	add_child(japgwi)


func _spawn_changgwi() -> void:
	var changgwi := Changgwi.new()
	changgwi.munyeo = munyeo
	changgwi.position = _random_edge_position()
	add_child(changgwi)


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
