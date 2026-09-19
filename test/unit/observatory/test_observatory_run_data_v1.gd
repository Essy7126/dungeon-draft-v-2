extends GutTest

const Exporter := preload("res://tools/observatory/observatory_run_data_exporter.gd")
const RUN_PATH := "res://data/runs/first_run.tres"
const TEST_RUN_PATH := "res://data/runs/fixed_trio_prototype_run.tres"


func test_production_run_loads_valid_and_preserves_room_order() -> void:
	var run := load(RUN_PATH) as RunData
	assert_not_null(run)
	assert_true(run.is_valid())
	var graph := _official_graph()
	var runs := graph.get("runs", []) as Array
	assert_eq(runs.size(), 2)
	assert_eq((runs[0] as Dictionary).get("id"), "primary_run")
	assert_eq((runs[0] as Dictionary).get("authored_room_count"), run.rooms.size())
	var exported_run := runs[0] as Dictionary
	assert_eq(exported_run.get("run_kind"), "production")
	assert_eq(exported_run.get("flow_mode"), "single_encounter")
	assert_true(exported_run.get("is_primary"))
	assert_eq(exported_run.get("effective_combat_count"), run.rooms.size())
	assert_eq(exported_run.get("authored_wave_profile_count"), 0)
	assert_eq(exported_run.get("selected_default_seed_wave_profile_count"), 0)
	var room_ids := (runs[0] as Dictionary).get("room_ids", []) as Array
	for index in range(room_ids.size()):
		assert_eq(room_ids[index], "primary_run.room.%02d" % (index + 1))


func test_room_export_covers_painted_and_legacy_resources() -> void:
	var graph := _official_graph()
	var rooms := graph.get("rooms", []) as Array
	assert_true(rooms.any(func(value: Variant) -> bool:
		return str((value as Dictionary).get("map_kind")) == "painted"
	))
	assert_true(rooms.any(func(value: Variant) -> bool:
		return str((value as Dictionary).get("map_kind")) == "legacy_scene"
	))
	for value in rooms:
		var room := value as Dictionary
		if str(room.get("flow_mode", "")) == "single_encounter":
			assert_eq(room.get("wave_profile_count"), 0)
			assert_eq(room.get("resolved_default_seed_wave_count"), null)
			assert_eq(room.get("wave_resolution_status"), "not_applicable")
		assert_lte(int(room.get("minimum_wave_count", 0)), int(room.get("maximum_wave_count", 0)))
		assert_gt(int(room.get("hero_spawn_cell_count", 0)), 0)
		assert_gt(int(room.get("enemy_spawn_cell_count", 0)), 0)
		assert_false(str(room.get("battle_scene_path", "")).is_empty())


func test_wave_profiles_are_stable_mandatory_optional_and_scaled() -> void:
	var graph := _official_graph()
	var waves := graph.get("waves", []) as Array
	var ids: Array[String] = []
	var mandatory := 0
	var optional := 0
	for value in waves:
		var wave := value as Dictionary
		assert_eq(wave.get("run_id"), "test_wave_run")
		assert_eq(wave.get("run_kind"), "test")
		ids.append(str(wave.get("id", "")))
		mandatory += 1 if bool(wave.get("is_mandatory_profile", false)) else 0
		optional += 1 if bool(wave.get("is_optional_profile", false)) else 0
		assert_eq(wave.get("calculation_status"), "exact_runtime_equivalent")
		assert_not_null((wave.get("scaled_initial_totals", {}) as Dictionary).get("total_max_hp"))
	var sorted := ids.duplicate()
	sorted.sort()
	assert_eq(ids, sorted)
	assert_gt(mandatory, 0)
	assert_gt(optional, 0)


func test_single_encounter_does_not_create_a_historical_wave() -> void:
	var enemy := _enemy("fallback_enemy")
	var encounter := _encounter(enemy)
	var room := RoomData.new()
	room.room_name = "Historique"
	room.battle_scene = PackedScene.new()
	room.encounter_definition = encounter
	room.hero_spawn_zone = [Vector2i(0, 0)]
	room.enemy_spawn_zone = [Vector2i(1, 1)]
	var run := RunData.new()
	run.rooms = [room]
	var graph := Exporter.new().export_graph(run, "res://test/run.tres")
	assert_true((graph.get("waves", []) as Array).is_empty())
	assert_eq((graph.get("encounters", []) as Array).size(), 1)
	assert_eq(((graph.get("runs", []) as Array)[0] as Dictionary).get(
		"effective_combat_count"
	), 1)


func test_wave_resolver_is_deterministic_bounded_and_single_flow_returns_one() -> void:
	var primary := load(RUN_PATH) as RunData
	var primary_counts := RunWaveCountResolver.resolve_counts(primary, primary.default_seed)
	assert_eq(primary_counts.size(), primary.rooms.size())
	for count in primary_counts:
		assert_eq(count, 1)
	var run := load(TEST_RUN_PATH) as RunData
	var original_rooms := run.rooms.duplicate()
	var first := RunWaveCountResolver.resolve_counts(run, run.default_seed)
	var second := RunWaveCountResolver.resolve_counts(run, run.default_seed)
	assert_eq(first, second)
	assert_eq(run.rooms, original_rooms)
	for index in range(first.size()):
		assert_gte(first[index], run.rooms[index].get_minimum_wave_count())
		assert_lte(first[index], run.rooms[index].get_maximum_wave_count())
	var graph := Exporter.new().export_runs([{
		"id": "test_wave_run", "path": TEST_RUN_PATH, "run_kind": "test",
		"is_primary": false, "data": run,
	}])
	for index in range((graph.get("rooms", []) as Array).size()):
		var room := (graph.get("rooms", []) as Array)[index] as Dictionary
		assert_eq(room.get("resolved_default_seed_wave_count"), first[index])
		assert_eq(room.get("wave_resolution_method"), "RunWaveCountResolver.resolve_counts")


func test_encounters_use_public_roster_methods_and_exact_base_totals() -> void:
	var graph := _official_graph()
	for value in graph.get("encounters", []) as Array:
		var encounter := value as Dictionary
		assert_eq(
			int(encounter.get("initial_enemy_count", -1)),
			(encounter.get("expanded_initial_enemy_ids", []) as Array).size(),
		)
		var totals := encounter.get("base_totals", {}) as Dictionary
		assert_eq(totals.get("initial_enemy_count"), encounter.get("initial_enemy_count"))
		assert_gt(int(totals.get("total_max_hp", 0)), 0)
		assert_eq(encounter.get("validation_status"), "valid")


func test_enemy_graph_deduplicates_profiles_spells_and_protects_summon_cycles() -> void:
	var first := _enemy("cycle_a")
	var second := _enemy("cycle_b")
	var summon_b := _summon_spell("summon_b", second)
	var summon_a := _summon_spell("summon_a", first)
	first.spells = [summon_b]
	second.spells = [summon_a]
	var profile := EnemyAIProfile.new()
	profile.profile_id = &"cycle_profile"
	first.ai_profile = profile
	second.ai_profile = profile
	var room := _room(_encounter(first))
	var run := RunData.new()
	run.rooms = [room]
	var graph := Exporter.new().export_graph(run, "res://test/cycle_run.tres")
	assert_eq((graph.get("enemies", []) as Array).size(), 2)
	assert_eq((graph.get("enemy_spells", []) as Array).size(), 2)
	assert_eq((graph.get("ai_profiles", []) as Array).size(), 1)
	var summon_only := (graph.get("enemies", []) as Array).filter(func(value: Variant) -> bool:
		return str((value as Dictionary).get("id")) == "cycle_b"
	)[0] as Dictionary
	assert_true(bool((summon_only.get("reachability", {}) as Dictionary).get("summon_only")))
	assert_false(_rule_ids(graph.get("audits", []) as Array).has("SUMMON.TRAVERSAL_DEPTH_LIMIT"))


func test_scaled_hp_uses_stat_rounding_per_unit_without_mutating_sources() -> void:
	var enemy := _enemy("rounding_enemy")
	enemy.max_hp = 5
	enemy.attack_power = 3
	var encounter := _encounter(enemy)
	encounter.roster_counts = PackedInt32Array([2])
	encounter.living_enemy_cap = 2
	var wave := RoomWaveData.new()
	wave.encounter_definition = encounter
	wave.enemy_health_multiplier = 1.5
	wave.enemy_attack_multiplier = 1.5
	var room := _room(encounter)
	room.waves = [wave]
	var run := RunData.new()
	run.room_flow_mode = RunData.RoomFlowMode.WAVE_CHAIN
	run.maximum_waves_per_room = 1
	run.rooms = [room]
	var graph := Exporter.new().export_graph(run, "res://test/rounding_run.tres")
	var totals := ((graph.get("waves", []) as Array)[0] as Dictionary).get(
		"scaled_initial_totals", {}
	) as Dictionary
	assert_eq(totals.get("total_max_hp"), 16)
	assert_eq(totals.get("total_attack_power"), 10)
	assert_eq(enemy.max_hp, 5)
	assert_eq(enemy.attack_power, 3)


func _official_graph() -> Dictionary:
	return Exporter.new().export_runs([
		{
			"id": "primary_run", "path": RUN_PATH, "run_kind": "production",
			"is_primary": true, "data": load(RUN_PATH) as RunData,
		},
		{
			"id": "test_wave_run", "path": TEST_RUN_PATH, "run_kind": "test",
			"is_primary": false, "data": load(TEST_RUN_PATH) as RunData,
		},
	])


func _enemy(id: String) -> UnitData:
	var enemy := UnitData.new()
	enemy.unit_id = StringName(id)
	enemy.unit_name = id
	enemy.team = 1
	return enemy


func _encounter(enemy: UnitData) -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	encounter.roster_units = [enemy]
	encounter.roster_counts = PackedInt32Array([1])
	encounter.living_enemy_cap = 1
	return encounter


func _room(encounter: EncounterDefinition) -> RoomData:
	var room := RoomData.new()
	room.room_name = "Test"
	room.battle_scene = PackedScene.new()
	room.encounter_definition = encounter
	room.hero_spawn_zone = [Vector2i(0, 0)]
	room.enemy_spawn_zone = [Vector2i(1, 1)]
	return room


func _summon_spell(id: String, target: UnitData) -> Spell:
	var spell := Spell.new()
	spell.spell_id = StringName(id)
	spell.delayed_resolution = Spell.DelayedResolution.SUMMON
	spell.summon_type = &"normal"
	spell.summon_unit_data = target
	return spell


func _rule_ids(audits: Array) -> Array[String]:
	var result: Array[String] = []
	for value in audits:
		result.append(str((value as Dictionary).get("rule_id", "")))
	return result
