extends GutTest

const AuditRules := preload("res://tools/observatory/audit_rules.gd")


func test_missing_and_duplicate_ids_are_blocking() -> void:
	var snapshot := _base_snapshot()
	snapshot["characters"] = [
		_character("", 6, 3, 4, 4, 4),
		_character("elf", 6, 3, 4, 4, 4),
		_character("elf", 6, 3, 4, 4, 4),
	]
	var ids := _rule_ids(AuditRules.run(snapshot))
	assert_has(ids, "IDENTITY.MISSING_EXPLICIT_ID")
	assert_has(ids, "IDENTITY.DUPLICATE_ID")


func test_missing_required_hero_is_reported() -> void:
	var snapshot := _base_snapshot()
	snapshot["characters"] = [_character("elf", 6, 3, 4, 4, 4)]
	assert_has(_rule_ids(AuditRules.run(snapshot)), "PARTY.REQUIRED_HERO_MISSING")


func test_character_contract_mismatches_are_distinct() -> void:
	var snapshot := _base_snapshot()
	snapshot["characters"] = [
		_character("elf", 5, 2, 3, 3, 3),
		_character("mage", 6, 3, 4, 4, 4),
		_character("warrior", 6, 3, 4, 4, 4),
	]
	var ids := _rule_ids(AuditRules.run(snapshot))
	assert_has(ids, "PARTY.BASE_AP_MISMATCH")
	assert_has(ids, "PARTY.BASE_MP_MISMATCH")
	assert_has(ids, "PARTY.ACTIVE_SPELL_SLOT_MISMATCH")
	assert_has(ids, "PARTY.STARTING_SPELL_COUNT_MISMATCH")
	assert_has(ids, "PARTY.DISCIPLINE_COUNT_MISMATCH")


func test_universal_item_is_compatible_with_production_party() -> void:
	var snapshot := _base_snapshot()
	snapshot["items"] = [_item("universal", [])]
	assert_does_not_have(
		_rule_ids(AuditRules.run(snapshot)),
		"ITEM.NO_COMPATIBLE_PRODUCTION_HERO",
	)


func test_restricted_item_without_production_hero_is_reported() -> void:
	var snapshot := _base_snapshot()
	snapshot["items"] = [_item("outsider", ["unknown_hero"])]
	assert_has(
		_rule_ids(AuditRules.run(snapshot)),
		"ITEM.NO_COMPATIBLE_PRODUCTION_HERO",
	)


func test_equipment_pool_of_zero_or_one_is_too_small() -> void:
	for ids in [[], ["item_a"]]:
		var snapshot := _base_snapshot()
		snapshot["items"] = [_item("item_a", [])]
		snapshot["reward_pools"] = [_equipment_pool(ids)]
		assert_has(_rule_ids(AuditRules.run(snapshot)), "REWARD.EQUIPMENT_POOL_TOO_SMALL")


func test_equipment_pool_of_two_is_large_enough() -> void:
	var snapshot := _base_snapshot()
	snapshot["items"] = [_item("item_a", []), _item("item_b", [])]
	snapshot["reward_pools"] = [_equipment_pool(["item_a", "item_b"])]
	assert_does_not_have(
		_rule_ids(AuditRules.run(snapshot)),
		"REWARD.EQUIPMENT_POOL_TOO_SMALL",
	)


func test_unknown_pool_reference_is_blocking() -> void:
	var snapshot := _base_snapshot()
	snapshot["items"] = [_item("item_a", [])]
	snapshot["reward_pools"] = [_equipment_pool(["item_a", "missing"])]
	assert_has(_rule_ids(AuditRules.run(snapshot)), "REWARD.UNKNOWN_ITEM_REFERENCE")


func _base_snapshot() -> Dictionary:
	return {
		"characters": [
			_character("elf", 6, 3, 4, 4, 4),
			_character("mage", 6, 3, 4, 4, 4),
			_character("warrior", 6, 3, 4, 4, 4),
		],
		"disciplines": [],
		"spells": [],
		"items": [],
		"reward_pools": [],
		"contract_checks": [],
	}


func _character(
		id: String,
		ap: int,
		mp: int,
		slots: int,
		spell_count: int,
		discipline_count: int
	) -> Dictionary:
	var spell_ids: Array[String] = []
	var discipline_ids: Array[String] = []
	for index in range(spell_count):
		spell_ids.append("%s_spell_%d" % [id, index])
	for index in range(discipline_count):
		discipline_ids.append("%s_discipline_%d" % [id, index])
	return {"id": id, "max_ap": ap, "max_mp": mp, "active_spell_slots": slots,
		"spell_ids": spell_ids, "discipline_ids": discipline_ids,
		"source_path": "res://test/%s.tres" % id}


func _item(id: String, compatible_ids: Array) -> Dictionary:
	return {"id": id, "valid": true, "compatible_character_ids": compatible_ids,
		"source_path": "res://test/%s.tres" % id}


func _equipment_pool(ids: Array) -> Dictionary:
	return {"id": "pool", "kind": "equipment_first_run", "minimum_options": 2,
		"item_ids": ids, "rewards": [], "source_path": "res://test/pool.gd"}


func _rule_ids(audits: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for audit in audits:
		result.append(str(audit.get("rule_id", "")))
	return result
