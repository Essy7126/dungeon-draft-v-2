extends GutTest

const Exporter := preload("res://tools/observatory/observatory_exporter.gd")


func test_exporter_loads_the_three_production_heroes() -> void:
	var snapshot := _snapshot()
	var ids: Array[String] = []
	for character_value in snapshot.get("characters", []) as Array:
		ids.append(str((character_value as Dictionary).get("id", "")))
	assert_eq(ids, ["elf", "mage", "warrior"])


func test_exporter_traverses_spells_and_disciplines_from_heroes() -> void:
	var snapshot := _snapshot()
	assert_gt((snapshot.get("spells", []) as Array).size(), 0)
	assert_gt((snapshot.get("disciplines", []) as Array).size(), 0)
	for character_value in snapshot.get("characters", []) as Array:
		var character := character_value as Dictionary
		assert_eq((character.get("spell_ids", []) as Array).size(), 4)
		assert_eq((character.get("discipline_ids", []) as Array).size(), 4)


func test_exporter_uses_non_empty_production_catalog() -> void:
	var snapshot := _snapshot()
	assert_gt((snapshot.get("items", []) as Array).size(), 0)
	assert_eq(
		(snapshot.get("summary", {}) as Dictionary).get("items"),
		(snapshot.get("items", []) as Array).size(),
	)


func test_exporter_builds_generic_and_equipment_pools() -> void:
	var snapshot := _snapshot()
	var kinds: Array[String] = []
	for pool_value in snapshot.get("reward_pools", []) as Array:
		kinds.append(str((pool_value as Dictionary).get("kind", "")))
	assert_has(kinds, "generic_declared")
	assert_has(kinds, "equipment_first_run")


func test_export_order_is_stable_and_sorted() -> void:
	var first := _without_volatile_meta(_snapshot())
	var second := _without_volatile_meta(_snapshot())
	assert_eq(JSON.stringify(first), JSON.stringify(second))
	for collection in ["characters", "disciplines", "spells", "items", "runs", "rooms",
		"waves", "encounters", "enemies", "enemy_spells", "ai_profiles"]:
		var ids: Array[String] = []
		for entity_value in first.get(collection, []) as Array:
			ids.append(str((entity_value as Dictionary).get("id", "")))
		var sorted := ids.duplicate()
		sorted.sort()
		assert_eq(ids, sorted, "%s doit être trié" % collection)


func _snapshot() -> Dictionary:
	var result := Exporter.new().build_snapshot()
	assert_true((result.get("errors", []) as Array).is_empty())
	return result.get("snapshot", {}) as Dictionary


func _without_volatile_meta(snapshot: Dictionary) -> Dictionary:
	var copy := snapshot.duplicate(true)
	(copy.get("meta", {}) as Dictionary).erase("generated_at_utc")
	return copy
