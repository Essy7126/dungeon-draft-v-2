extends GutTest

const Validator := preload("res://tools/observatory/snapshot_validator.gd")
const Exporter := preload("res://tools/observatory/observatory_exporter.gd")
const SNAPSHOT_PATH := "res://observatory/public/data/latest.json"
const SCHEMA_PATH := "res://tools/observatory/schemas/observatory_snapshot.schema.json"


func test_snapshot_and_schema_are_parseable_objects() -> void:
	assert_true(FileAccess.file_exists(SNAPSHOT_PATH))
	assert_true(FileAccess.file_exists(SCHEMA_PATH))
	assert_true(JSON.parse_string(FileAccess.get_file_as_string(SNAPSHOT_PATH)) is Dictionary)
	var schema := JSON.parse_string(FileAccess.get_file_as_string(SCHEMA_PATH)) as Dictionary
	assert_eq(schema.get("$schema"), "https://json-schema.org/draft/2020-12/schema")


func test_snapshot_contract_versions_are_v2_1() -> void:
	var meta := (_snapshot().get("meta", {}) as Dictionary)
	assert_eq(meta.get("schema_version"), "2.1.0")
	assert_eq(meta.get("generator_version"), "2.1.0")
	assert_eq(meta.get("manifest_version"), "2.1.0")
	assert_true(meta.get("source_git_available", false))


func test_snapshot_has_all_required_sections() -> void:
	var snapshot := _snapshot()
	for section in Validator.REQUIRED_SECTIONS:
		assert_true(snapshot.has(section), "section %s" % section)
	assert_true(Validator.validate(snapshot).get("valid", false))


func test_summary_counts_match_collections() -> void:
	var snapshot := _snapshot()
	var summary := snapshot.get("summary", {}) as Dictionary
	for collection in ["characters", "disciplines", "spells", "items", "reward_pools",
		"runs", "rooms", "waves", "encounters", "enemies", "enemy_spells", "ai_profiles"]:
		assert_eq(
			int(summary.get(collection, -1)),
			(snapshot.get(collection, []) as Array).size(),
		)
	assert_eq(summary.get("runtime_facts"), (snapshot.get("runtime_facts", []) as Array).size())
	assert_eq(summary.get("authored_wave_profiles"), (snapshot.get("waves", []) as Array).size())


func test_runtime_facts_and_xp_contract_are_separated() -> void:
	var snapshot := _snapshot()
	var fact_map := _entity_map(snapshot.get("runtime_facts", []) as Array, "key")
	assert_eq(fact_map["progression.xp_per_effective_cast"].get("value"), 1)
	assert_eq(fact_map["progression.xp_per_effective_cast"].get("truth_status"), "observed")
	assert_true(fact_map.has("combat.damage_mitigation_formula"))
	var decisions := _entity_map(
		((snapshot.get("contract", {}) as Dictionary).get("decisions", []) as Array),
		"key",
	)
	assert_false(decisions.has("progression.xp_per_effective_cast"))
	assert_false(decisions.has("progression.requires_effective_cast"))
	assert_eq(decisions["progression.xp_model"].get("status"), "unknown")
	assert_eq(decisions["progression.xp_model"].get("truth_status"), "design_decision")
	assert_eq(decisions["progression.evolution_timing"].get("status"), "validated")


func test_wave_profile_summary_is_derived_from_rooms_and_waves() -> void:
	var snapshot := _snapshot()
	var summary := snapshot.get("summary", {}) as Dictionary
	var selected := 0
	for wave_value in snapshot.get("waves", []) as Array:
		selected += 1 if bool((wave_value as Dictionary).get("is_selected_by_default_seed")) else 0
	var minimum := 0
	var maximum := 0
	for room_value in snapshot.get("rooms", []) as Array:
		minimum += int((room_value as Dictionary).get("minimum_wave_count", 0))
		maximum += int((room_value as Dictionary).get("maximum_wave_count", 0))
	assert_eq(summary.get("selected_default_seed_wave_profiles"), selected)
	assert_eq(summary.get("minimum_played_wave_profiles"), minimum)
	assert_eq(summary.get("maximum_played_wave_profiles"), maximum)


func test_audits_keep_raw_occurrences_and_truth_metadata() -> void:
	var audits := _snapshot().get("audit_results", []) as Array
	var multiplier_occurrences := audits.filter(func(value: Variant) -> bool:
		return str((value as Dictionary).get("rule_id", "")) \
			== "WAVE.ATTACK_MULTIPLIER_NO_ACTIVE_DAMAGE_SOURCE"
	)
	assert_eq(multiplier_occurrences.size(), 54)
	for audit_value in audits:
		var audit := audit_value as Dictionary
		assert_true(audit.has("truth_status"))
		assert_eq(audit.get("suggested_action_truth_status"), "recommendation")
		assert_true(audit.get("affected_entity_ids") is Array)


func test_snapshot_contains_no_raw_godot_value_or_absolute_path() -> void:
	var errors: Array[String] = []
	_scan(_snapshot(), "$", errors)
	assert_true(errors.is_empty(), "\n".join(errors))


func test_primary_character_references_resolve() -> void:
	var snapshot := _snapshot()
	var spell_ids := _id_map(snapshot.get("spells", []) as Array)
	var discipline_ids := _id_map(snapshot.get("disciplines", []) as Array)
	for character_value in snapshot.get("characters", []) as Array:
		var character := character_value as Dictionary
		for spell_id in character.get("spell_ids", []) as Array:
			assert_true(spell_ids.has(str(spell_id)))
		for discipline_id in character.get("discipline_ids", []) as Array:
			assert_true(discipline_ids.has(str(discipline_id)))


func test_run_graph_references_resolve() -> void:
	var snapshot := _snapshot()
	var room_ids := _id_map(snapshot.get("rooms", []) as Array)
	var wave_ids := _id_map(snapshot.get("waves", []) as Array)
	var encounter_ids := _id_map(snapshot.get("encounters", []) as Array)
	var enemy_ids := _id_map(snapshot.get("enemies", []) as Array)
	var enemy_spell_ids := _id_map(snapshot.get("enemy_spells", []) as Array)
	var profile_ids := _id_map(snapshot.get("ai_profiles", []) as Array)
	for run_value in snapshot.get("runs", []) as Array:
		for room_id in (run_value as Dictionary).get("room_ids", []) as Array:
			assert_true(room_ids.has(str(room_id)))
	for room_value in snapshot.get("rooms", []) as Array:
		for wave_id in (room_value as Dictionary).get("wave_ids", []) as Array:
			assert_true(wave_ids.has(str(wave_id)))
	for wave_value in snapshot.get("waves", []) as Array:
		assert_true(encounter_ids.has(str((wave_value as Dictionary).get("encounter_id", ""))))
	for encounter_value in snapshot.get("encounters", []) as Array:
		for enemy_id in (encounter_value as Dictionary).get("expanded_initial_enemy_ids", []) as Array:
			assert_true(enemy_ids.has(str(enemy_id)))
	for enemy_value in snapshot.get("enemies", []) as Array:
		var enemy := enemy_value as Dictionary
		for spell_id in enemy.get("spell_ids", []) as Array:
			assert_true(enemy_spell_ids.has(str(spell_id)))
		if not str(enemy.get("ai_profile_id", "")).is_empty():
			assert_true(profile_ids.has(str(enemy.get("ai_profile_id"))))


func _snapshot() -> Dictionary:
	var result := Exporter.new().build_snapshot()
	_handle_known_gameplay_uid_warning()
	assert_true((result.get("errors", []) as Array).is_empty())
	return result.get("snapshot", {}) as Dictionary


func _entity_map(values: Array, key_name: String = "id") -> Dictionary:
	var result := {}
	for value in values:
		var entity := value as Dictionary
		result[str(entity.get(key_name, ""))] = entity
	return result


func _handle_known_gameplay_uid_warning() -> void:
	for error in get_errors():
		if error.contains_text("invalid UID: uid://0flkpto1jkby"):
			error.handled = true


func _id_map(entities: Array) -> Dictionary:
	var result := {}
	for entity_value in entities:
		result[str((entity_value as Dictionary).get("id", ""))] = true
	return result


func _scan(value: Variant, path: String, errors: Array[String]) -> void:
	if value is String:
		var text := str(value)
		if (text.length() >= 3 and text[1] == ":" and text[2] in ["/", "\\"]) \
				or "<Object#" in text or "<Resource#" in text:
			errors.append(path)
	elif value is Array:
		for index in range((value as Array).size()):
			_scan((value as Array)[index], "%s[%d]" % [path, index], errors)
	elif value is Dictionary:
		for key in value:
			_scan((value as Dictionary)[key], "%s.%s" % [path, key], errors)
