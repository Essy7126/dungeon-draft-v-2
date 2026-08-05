extends GutTest

const AuditRules := preload("res://tools/observatory/audit_rules.gd")


func test_run_root_invalid_duplicate_and_derived_identity_rules() -> void:
	var missing := _base_snapshot()
	assert_has(_rule_ids(AuditRules.run(missing)), "RUN.PRODUCTION_ROOT_MISSING")
	var snapshot := _base_snapshot()
	snapshot["runs"] = [_run("invalid")]
	snapshot["rooms"] = [_room("room_a", "res://same.tres"), _room("room_b", "res://same.tres")]
	var ids := _rule_ids(AuditRules.run(snapshot))
	assert_has(ids, "RUN.INVALID")
	assert_has(ids, "RUN.DUPLICATE_ROOM_REFERENCE")
	assert_has(ids, "IDENTITY.DERIVED_OBSERVATORY_ID")


func test_all_room_rules_are_distinct() -> void:
	var snapshot := _base_snapshot()
	snapshot["runs"] = [_run("valid")]
	var room := _room("room", "res://room.tres")
	room["battle_scene_path"] = ""
	room["available_wave_count"] = 0
	room["minimum_wave_count"] = 2
	room["maximum_wave_count"] = 1
	room["hero_spawn_cell_count"] = 0
	room["ultimate_reward_min_gain_per_wave"] = 9
	room["ultimate_reward_max_gain_per_wave"] = 2
	snapshot["rooms"] = [room]
	var ids := _rule_ids(AuditRules.run(snapshot))
	for rule_id in ["ROOM.MISSING_BATTLE_SCENE", "ROOM.NO_AVAILABLE_WAVE",
		"ROOM.WAVE_RANGE_INVALID", "ROOM.SPAWN_ZONE_EMPTY",
		"ROOM.ULTIMATE_REWARD_RANGE_INVALID"]:
		assert_has(ids, rule_id)


func test_all_wave_rules_and_evidence_gate() -> void:
	var snapshot := _base_snapshot()
	snapshot["runs"] = [_run("valid")]
	var wave := _wave()
	wave["validation_status"] = "invalid"
	wave["encounter_id"] = ""
	wave["enemy_health_multiplier"] = 0.0
	wave["enemy_attack_multiplier"] = 1.5
	wave["attack_multiplier_effect_status"] = "no_active_source_detected"
	wave["attack_multiplier_effect_evidence"] = "Battle -> attack_power ; aucun basic attack."
	snapshot["waves"] = [wave]
	var ids := _rule_ids(AuditRules.run(snapshot))
	for rule_id in ["WAVE.INVALID", "WAVE.MISSING_ENCOUNTER",
		"WAVE.NON_POSITIVE_MULTIPLIER",
		"WAVE.ATTACK_MULTIPLIER_NO_ACTIVE_DAMAGE_SOURCE"]:
		assert_has(ids, rule_id)
	wave["attack_multiplier_effect_status"] = "unknown"
	assert_does_not_have(
		_rule_ids(AuditRules.run(snapshot)),
		"WAVE.ATTACK_MULTIPLIER_NO_ACTIVE_DAMAGE_SOURCE",
	)
	wave["attack_multiplier_effect_status"] = "no_active_source_detected"
	wave["attack_multiplier_effect_evidence"] = ""
	assert_does_not_have(
		_rule_ids(AuditRules.run(snapshot)),
		"WAVE.ATTACK_MULTIPLIER_NO_ACTIVE_DAMAGE_SOURCE",
	)


func test_encounter_reference_formation_cap_and_budget_rules() -> void:
	var snapshot := _base_snapshot()
	snapshot["runs"] = [_run("valid")]
	var encounter := _encounter()
	encounter["validation_status"] = "invalid"
	encounter["roster_unit_entry_count"] = 2
	encounter["roster_count_entry_count"] = 1
	encounter["initial_enemy_count"] = 2
	encounter["living_enemy_cap"] = 1
	encounter["formation_profiles"] = ["unknown"]
	encounter["roster"] = [{"enemy_id": "missing", "count": 1}]
	encounter["disabled_ability_ids"] = ["missing_spell"]
	encounter["shared_normal_summon_budget"] = 1
	snapshot["encounters"] = [encounter]
	var ids := _rule_ids(AuditRules.run(snapshot))
	for rule_id in ["ENCOUNTER.INVALID", "ENCOUNTER.ROSTER_SIZE_MISMATCH",
		"ENCOUNTER.LIVING_CAP_BELOW_INITIAL", "ENCOUNTER.UNKNOWN_FORMATION",
		"ENCOUNTER.UNKNOWN_ENEMY_REFERENCE",
		"ENCOUNTER.DISABLED_ABILITY_UNRESOLVED", "SUMMON.BUDGET_WITHOUT_SUMMONER"]:
		assert_has(ids, rule_id)


func test_enemy_action_identity_team_ai_and_spell_rules() -> void:
	var snapshot := _base_snapshot()
	snapshot["runs"] = [_run("valid")]
	var enemy := _enemy()
	enemy["id_source"] = "resource_path"
	enemy["team"] = 0
	enemy["spell_ids"] = ["missing"]
	snapshot["enemies"] = [enemy]
	var ids := _rule_ids(AuditRules.run(snapshot))
	for rule_id in ["ENEMY.MISSING_EXPLICIT_ID", "ENEMY.WRONG_TEAM",
		"ENEMY.NO_ACTION_SOURCE", "ENEMY.AI_PROFILE_MISSING",
		"ENEMY.UNKNOWN_SPELL_REFERENCE"]:
		assert_has(ids, rule_id)


func test_summon_missing_unit_is_blocking() -> void:
	var snapshot := _base_snapshot()
	snapshot["runs"] = [_run("valid")]
	snapshot["enemy_spells"] = [{
		"id": "summon", "source_path": "res://summon.tres",
		"delayed_resolution": {"name": "summon", "value": 2},
		"summon_enemy_id": "",
	}]
	assert_has(_rule_ids(AuditRules.run(snapshot)), "SUMMON.UNKNOWN_UNIT_REFERENCE")


func _base_snapshot() -> Dictionary:
	return {
		"characters": [], "disciplines": [], "spells": [], "items": [],
		"reward_pools": [], "contract_checks": [], "runs": [], "rooms": [],
		"waves": [], "encounters": [], "enemies": [], "enemy_spells": [],
		"ai_profiles": [],
	}


func _run(status: String) -> Dictionary:
	return {
		"id": "first_run", "id_source": "manifest_alias",
		"identity_stability": "derived", "source_path": "res://run.tres",
		"validation_status": status, "validation_errors": [] if status == "valid" else ["x"],
	}


func _room(id: String, source: String) -> Dictionary:
	return {
		"id": id, "id_source": "ordered_parent_index",
		"identity_stability": "derived", "source_path": source,
		"battle_scene_path": "res://battle.tscn", "available_wave_count": 1,
		"minimum_wave_count": 1, "maximum_wave_count": 1,
		"hero_spawn_cell_count": 1, "enemy_spawn_cell_count": 1,
		"ultimate_reward_min_gain_per_wave": 1,
		"ultimate_reward_max_gain_per_wave": 2,
	}


func _wave() -> Dictionary:
	return {
		"id": "first_run.room.01.wave.01", "id_source": "ordered_parent_index",
		"identity_stability": "derived", "source_path": "",
		"validation_status": "valid", "validation_errors": [],
		"encounter_id": "encounter", "enemy_health_multiplier": 1.0,
		"enemy_attack_multiplier": 1.0, "reward_multiplier": 1.0,
		"attack_multiplier_effect_status": "effective",
		"attack_multiplier_effect_evidence": "basic attack active",
	}


func _encounter() -> Dictionary:
	return {
		"id": "encounter", "source_path": "res://encounter.tres",
		"validation_status": "valid", "validation_errors": [],
		"roster_unit_entry_count": 1, "roster_count_entry_count": 1,
		"initial_enemy_count": 1, "living_enemy_cap": 1,
		"formation_profiles": ["line"], "roster": [],
		"disabled_ability_ids": [], "expanded_initial_enemy_ids": [],
		"shared_normal_summon_budget": 0, "shared_chief_summon_budget": 0,
	}


func _enemy() -> Dictionary:
	return {
		"id": "enemy", "id_source": "explicit", "source_path": "res://enemy.tres",
		"team": 1, "basic_attack_enabled": false, "spell_ids": [], "ai_profile_id": "",
	}


func _rule_ids(audits: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for audit in audits:
		result.append(str(audit.get("rule_id", "")))
	return result
