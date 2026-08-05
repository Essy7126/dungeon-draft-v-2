extends GutTest

const Validator := preload("res://tools/observatory/snapshot_validator.gd")
const SNAPSHOT_PATH := "res://observatory/public/data/latest.json"
const SCHEMA_PATH := "res://tools/observatory/schemas/observatory_snapshot.schema.json"


func test_snapshot_and_schema_are_parseable_objects() -> void:
	assert_true(FileAccess.file_exists(SNAPSHOT_PATH))
	assert_true(FileAccess.file_exists(SCHEMA_PATH))
	assert_true(JSON.parse_string(FileAccess.get_file_as_string(SNAPSHOT_PATH)) is Dictionary)
	assert_true(JSON.parse_string(FileAccess.get_file_as_string(SCHEMA_PATH)) is Dictionary)


func test_snapshot_has_all_required_sections() -> void:
	var snapshot := _snapshot()
	for section in Validator.REQUIRED_SECTIONS:
		assert_true(snapshot.has(section), "section %s" % section)
	assert_true(Validator.validate(snapshot).get("valid", false))


func test_summary_counts_match_collections() -> void:
	var snapshot := _snapshot()
	var summary := snapshot.get("summary", {}) as Dictionary
	for collection in ["characters", "disciplines", "spells", "items", "reward_pools"]:
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


func _snapshot() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(SNAPSHOT_PATH)) as Dictionary


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
