# 메인 오케스트레이션 — 무녀 배치, 잡귀 주기 스폰, HUD 갱신.
extends Node2D

const Munyeo = preload("res://scripts/munyeo.gd")
const Japgwi = preload("res://scripts/japgwi.gd")

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
	hud = Label.new()
	hud.position = Vector2(12, 8)
	add_child(hud)


func _process(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		_spawn_japgwi()
	hud.text = "HP %d/%d   Lv %d   XP %d/%d" % [
		munyeo.hp, munyeo.max_hp, munyeo.level, munyeo.xp, munyeo.xp_to_next(),
	]


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
