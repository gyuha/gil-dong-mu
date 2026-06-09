extends Node2D
## 무녀(Player) — 지휘 70 / 전투 30. 직접 딜은 약한 주술 오라뿐.
## 핵심 동사: 이동 + 스탠스 명령(main 처리) + 근접 부활.

@export var max_hp := 100.0
@export var speed := 220.0
@export var revive_radius := 56.0
@export var aura_radius := 70.0      # 약한 주술 오라(30% 전투)
@export var aura_damage := 6.0
@export var aura_cooldown := 0.7
@export var radius := 13.0

var hp := max_hp
var main: Node
var _aura := 0.0
var _reviving: Node2D = null   # 디버그 표시용

func setup(p_main: Node) -> void:
	main = p_main
	hp = max_hp

func _physics_process(delta: float) -> void:
	# WASD 이동 (입력맵 없이 직접 키 폴링)
	var dir := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	if dir.length() > 0.01:
		global_position += dir.normalized() * speed * delta

	# 근접 부활: 반경 안 가장 가까운 KO 신장 1기를 채워줌
	_reviving = _nearest_ko_in_range()
	if is_instance_valid(_reviving):
		_reviving.feed_revive(delta)

	# 약한 주술 오라 (무녀가 완전 무력하지 않도록)
	_aura = maxf(0.0, _aura - delta)
	if _aura <= 0.0:
		_aura = aura_cooldown
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and global_position.distance_to(e.global_position) <= aura_radius:
				e.take_damage(aura_damage)

	queue_redraw()

func _nearest_ko_in_range() -> Node2D:
	const ReviveUtil = preload("res://scripts/revive_util.gd")
	var best: Node2D = null
	var best_d := INF
	for c in get_tree().get_nodes_in_group("companions"):
		if is_instance_valid(c) and c.is_ko():
			if ReviveUtil.can_revive(global_position, c.global_position, revive_radius):
				var d := global_position.distance_to(c.global_position)
				if d < best_d:
					best_d = d
					best = c
	return best

func take_damage(d: float) -> void:
	hp -= d
	if hp <= 0.0:
		hp = 0.0
		if main:
			main.on_player_dead()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.35, 0.55, 1.0))
	# HP 바
	var w := radius * 2.0
	draw_rect(Rect2(-radius, -radius - 9, w, 4), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(-radius, -radius - 9, w * (hp / max_hp), 4), Color.SKY_BLUE)

	if not (main and main.debug_show):
		return
	draw_arc(Vector2.ZERO, revive_radius, 0, TAU, 40, Color(0, 1, 1, 0.2), 1.0)
	draw_arc(Vector2.ZERO, aura_radius, 0, TAU, 40, Color(0.6, 0.4, 1, 0.15), 1.0)
	if is_instance_valid(_reviving):
		draw_line(Vector2.ZERO, to_local(_reviving.global_position), Color.CYAN, 2.0)
