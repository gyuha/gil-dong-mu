extends Node2D
## 적(요괴 좀비) — 경로탐색 없음. 가장 가까운 대상(무녀/신장)으로 조향 + 적끼리 분리. [Layer 1]

@export var max_hp := 30.0
@export var speed := 85.0
@export var touch_damage := 8.0
@export var touch_cooldown := 0.6
@export var radius := 10.0

const SEPARATION_RADIUS := 26.0
const CONTACT := 22.0

var hp := max_hp
var main: Node
var _touch := 0.0

func setup(p_main: Node) -> void:
	main = p_main
	hp = max_hp

func _physics_process(delta: float) -> void:
	_touch = maxf(0.0, _touch - delta)

	var target := _nearest_target()
	var dir := Vector2.ZERO
	if is_instance_valid(target):
		dir = (target.global_position - global_position)
		if dir.length() > 1.0:
			dir = dir.normalized()
		# 접촉 시 데미지
		if global_position.distance_to(target.global_position) <= CONTACT and _touch <= 0.0:
			if target.has_method("take_damage"):
				target.take_damage(touch_damage)
			_touch = touch_cooldown

	var sep := _separation_vector()
	var vel := (dir + sep * 0.7)
	if vel.length() > 0.01:
		global_position += vel.normalized() * speed * delta
	queue_redraw()

## 무녀 + 살아있는 신장 중 최근접. 신장이 적을 끌어들여 무녀를 보호 → 지휘가 의미를 가짐.
func _nearest_target() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	var candidates: Array = []
	candidates.append_array(get_tree().get_nodes_in_group("player"))
	for c in get_tree().get_nodes_in_group("companions"):
		if is_instance_valid(c) and not c.is_ko():
			candidates.append(c)
	for t in candidates:
		if not is_instance_valid(t):
			continue
		var d := global_position.distance_to(t.global_position)
		if d < best_d:
			best_d = d
			best = t
	return best

func _separation_vector() -> Vector2:
	var push := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other):
			continue
		var diff: Vector2 = global_position - other.global_position
		var dist := diff.length()
		if dist < SEPARATION_RADIUS and dist > 0.01:
			push += diff.normalized() * (1.0 - dist / SEPARATION_RADIUS)
	return push

func take_damage(d: float) -> void:
	hp -= d
	if hp <= 0.0:
		if main:
			main.telemetry["kills"] += 1
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.85, 0.25, 0.25))
	if hp < max_hp:
		var w := radius * 2.0
		draw_rect(Rect2(-radius, -radius - 6, w, 2), Color(0.2, 0.2, 0.2))
		draw_rect(Rect2(-radius, -radius - 6, w * (hp / max_hp), 2), Color.ORANGE_RED)
