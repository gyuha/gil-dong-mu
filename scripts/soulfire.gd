# 혼불 — 잡귀 사망 시 드랍되는 경험치 자원. 무녀가 근접하면 빨려가 수집된다.
# 자석 반경은 magnet_target(무녀)의 magnet_radius — 드래프트(혼불 자석)로 커진다.
extends Node2D

const MAGNET_SPEED := 260.0

var xp_value := 1
var magnet_target: Node2D


func _ready() -> void:
	add_to_group("soulfire")


func _process(delta: float) -> void:
	if magnet_target == null or not is_instance_valid(magnet_target):
		return
	var to_target := magnet_target.global_position - global_position
	if to_target.length() <= magnet_target.magnet_radius:
		position += to_target.normalized() * MAGNET_SPEED * delta


func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color(0.45, 0.75, 1.0))
