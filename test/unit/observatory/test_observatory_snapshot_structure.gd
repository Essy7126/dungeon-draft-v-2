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


func test_snapshot_contract_versions_are_v2() -> void:
	var meta := (_snapshot().get("meta", {}) as Dictionary)
	assert_eq(meta.get("schema_version"), "2.0.0")
	assert_eq(meta.get("generator_version"), "2.0.0")
	assert_eq(meta.get("manifest_version"), "2.0.0")


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
	assert_true((result.get("errors", []) as Array).is_empty())
	return result.get("snapshot", {}) as Dictionary


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
