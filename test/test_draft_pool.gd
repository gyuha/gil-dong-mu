# 드래프트 선택지 풀 — 추첨(한 드래프트 안 중복 금지)·업그레이드 적용 수치 테스트.
extends "res://test/test_case.gd"

const DraftPool = preload("res://scripts/logic/draft_pool.gd")


func test_pool_ids_are_unique_across_pools() -> void:
	var ids := {}
	for option in DraftPool.munyeo_pool() + DraftPool.companion_pool():
		assert_false(ids.has(option["id"]), "중복 id: " + str(option["id"]))
		ids[option["id"]] = true


func test_options_have_id_name_desc() -> void:
	for option in DraftPool.munyeo_pool() + DraftPool.companion_pool():
		assert_true(option.has("id") and option["id"] != "")
		assert_true(option.has("name") and option["name"] != "")
		assert_true(option.has("desc") and option["desc"] != "")


func test_pools_can_fill_a_draft() -> void:
	assert_true(DraftPool.munyeo_pool().size() >= 3)
	assert_true(DraftPool.companion_pool().size() >= 3)


func test_roll_returns_three_distinct_options() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var picked: Array = DraftPool.roll(DraftPool.munyeo_pool(), 3, rng)
	assert_eq(picked.size(), 3)
	var ids := {}
	for option in picked:
		ids[option["id"]] = true
	assert_eq(ids.size(), 3, "한 드래프트 안에 같은 선택지가 중복됐다")


func test_roll_distinct_over_many_seeds() -> void:
	var rng := RandomNumberGenerator.new()
	for seed_value in range(50):
		rng.seed = seed_value
		var picked: Array = DraftPool.roll(DraftPool.companion_pool(), 3, rng)
		var ids := {}
		for option in picked:
			ids[option["id"]] = true
		assert_eq(ids.size(), 3, "seed %d 에서 중복 추첨" % seed_value)


func test_roll_clamps_to_pool_size() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var pool := [{"id": "a"}, {"id": "b"}]
	assert_eq(DraftPool.roll(pool, 3, rng).size(), 2)


func test_roll_deterministic_for_same_seed() -> void:
	var ids_a := _roll_ids(7)
	var ids_b := _roll_ids(7)
	assert_eq(ids_a, ids_b)


func _roll_ids(seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ids := []
	for option in DraftPool.roll(DraftPool.munyeo_pool(), 3, rng):
		ids.append(option["id"])
	return ids


# --- 무녀 풀 서포트 전용(ADR-0003) ---


func test_munyeo_pool_is_support_only_seven() -> void:
	var pool := DraftPool.munyeo_pool()
	assert_eq(pool.size(), 7)
	var allowed := {
		"repel_radius": true, "soulfire_magnet": true, "move_speed": true,
		"aura_radius": true, "aura_heal": true,
		"mp_mastery": true, "command_range": true,
	}
	for option in pool:
		assert_true(allowed.has(option["id"]),
				"무녀 풀에 서포트 외 선택지: " + str(option["id"]))


# --- 업그레이드 적용 수치 ---


func test_apply_repel_radius() -> void:
	var stats := DraftPool.apply({"repel_radius": 160.0}, "repel_radius")
	assert_almost_eq(stats["repel_radius"], 200.0)


func test_apply_soulfire_magnet() -> void:
	var stats := DraftPool.apply({"magnet_radius": 130.0}, "soulfire_magnet")
	assert_almost_eq(stats["magnet_radius"], 169.0)


func test_apply_move_speed() -> void:
	var stats := DraftPool.apply({"speed": 220.0}, "move_speed")
	assert_almost_eq(stats["speed"], 242.0)


func test_apply_aura_radius() -> void:
	var stats := DraftPool.apply({"aura_radius": 140.0}, "aura_radius")
	assert_almost_eq(stats["aura_radius"], 168.0)


func test_apply_aura_heal() -> void:
	var stats := DraftPool.apply({"aura_heal_rate": 5.0}, "aura_heal")
	assert_almost_eq(stats["aura_heal_rate"], 8.0)


func test_apply_mp_mastery() -> void:
	var stats := DraftPool.apply({"max_mp": 100.0, "mp_regen_rate": 10.0}, "mp_mastery")
	assert_almost_eq(stats["max_mp"], 130.0)
	assert_almost_eq(stats["mp_regen_rate"], 12.0)


func test_apply_command_range() -> void:
	var stats := DraftPool.apply({"command_range_bonus": 1.0}, "command_range")
	assert_almost_eq(stats["command_range_bonus"], 1.25)


func test_apply_comp_max_hp() -> void:
	var stats := DraftPool.apply({"max_hp": 60.0}, "comp_max_hp")
	assert_almost_eq(stats["max_hp"], 75.0)


func test_apply_comp_damage() -> void:
	assert_eq(DraftPool.apply({"attack_damage": 2}, "comp_damage")["attack_damage"], 3)


func test_apply_comp_attack_speed() -> void:
	var stats := DraftPool.apply({"attack_cooldown": 0.8}, "comp_attack_speed")
	assert_almost_eq(stats["attack_cooldown"], 0.68)


func test_apply_comp_speed() -> void:
	var stats := DraftPool.apply({"speed": 150.0}, "comp_speed")
	assert_almost_eq(stats["speed"], 172.5)


func test_apply_comp_range() -> void:
	var stats := DraftPool.apply({"attack_range": 320.0}, "comp_range")
	assert_almost_eq(stats["attack_range"], 368.0)


func test_apply_does_not_mutate_input() -> void:
	var input := {"repel_radius": 160.0}
	DraftPool.apply(input, "repel_radius")
	assert_almost_eq(input["repel_radius"], 160.0)


func test_apply_every_pool_option_changes_default_stats() -> void:
	var munyeo_stats := {
		"repel_radius": 160.0, "magnet_radius": 130.0, "speed": 220.0,
		"aura_radius": 140.0, "aura_heal_rate": 5.0,
		"max_mp": 100.0, "mp_regen_rate": 10.0, "command_range_bonus": 1.0,
	}
	for option in DraftPool.munyeo_pool():
		assert_ne(DraftPool.apply(munyeo_stats, option["id"]), munyeo_stats,
				"무녀 선택지 %s 가 아무 수치도 바꾸지 않는다" % option["id"])
	var comp_stats := {
		"max_hp": 60.0, "attack_damage": 2, "attack_cooldown": 0.8,
		"speed": 150.0, "attack_range": 320.0,
	}
	for option in DraftPool.companion_pool():
		assert_ne(DraftPool.apply(comp_stats, option["id"]), comp_stats,
				"동료 선택지 %s 가 아무 수치도 바꾸지 않는다" % option["id"])
