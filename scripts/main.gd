# 메인 오케스트레이션 — 무녀·동료 배치(밤 시작 시), 잡귀 주기 스폰, HUD 갱신.
extends Node2D

const Munyeo = preload("res://scripts/munyeo.gd")
const Japgwi = preload("res://scripts/japgwi.gd")
const Hwarang = preload("res://scripts/hwarang.gd")
const Archer = preload("res://scripts/archer.gd")
const Command = preload("res://scripts/logic/command.gd")

const SPAWN_INTERVAL := 1.5
const SPAWN_MARGIN := 40.0
const ARENA := Vector2(1280, 720)

var munyeo: Node2D
var hud: Label
var _spawn_timer := 0.0


func _ready() -> void:
	munyeo = Munyeo.new()
	munyeo.name = "Munyeo"
	munyeo.position = ARENA / 2.0
	add_child(munyeo)
	_spawn_companion(Hwarang, Vector2(-80, 0))
	_spawn_companion(Archer, Vector2(80, 0))
	hud = Label.new()
	hud.position = Vector2(12, 8)
	add_child(hud)


func _process(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		_spawn_japgwi()
	var text := "HP %d/%d   MP %d/%d   Lv %d   XP %d/%d   혼불 %d   명령[1~4] %s" % [
		munyeo.hp, munyeo.max_hp, int(munyeo.mp), int(munyeo.max_mp),
		munyeo.level, munyeo.xp, munyeo.xp_to_next(),
		munyeo.soulfire_stock, Command.NAMES[munyeo.command],
	]
	for companion in get_tree().get_nodes_in_group("companion"):
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
	add_child(companion)


func _spawn_japgwi() -> void:
	var japgwi := Japgwi.new()
	japgwi.target = munyeo
	japgwi.position = _random_edge_position()
	add_child(japgwi)


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
