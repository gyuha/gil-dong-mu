extends RefCounted
## 근접 발동 부활 판정 — 순수 함수. 무녀가 쓰러진 신장에게 물리적으로 다가가야 부활.

static func can_revive(player_pos: Vector2, ko_pos: Vector2, radius: float) -> bool:
	return player_pos.distance_to(ko_pos) <= radius
