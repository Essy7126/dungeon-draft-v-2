class_name ObservatorySnapshotValidator
extends RefCounted

const REQUIRED_SECTIONS := [
	"primary_run_id", "meta", "scope", "summary", "contract", "characters", "disciplines",
	"runtime_facts", "spells", "items", "reward_pools", "runs", "rooms", "waves", "encounters",
	"enemies", "enemy_spells", "ai_profiles", "contract_checks", "audit_results",
]


static func validate(snapshot: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	for section in REQUIRED_SECTIONS:
		if not snapshot.has(section):
			errors.append("Section racine absente : %s." % section)
	var meta := snapshot.get("meta", {}) as Dictionary
	for field in ["schema_version", "source_game_commit", "source_branch", "generated_at_utc"]:
		if str(meta.get(field, "")).strip_edges().is_empty():
			errors.append("Champ meta.%s absent." % field)
	for field in ["source_git_available", "source_worktree_dirty_before_export",
		"source_generated_from_clean_checkout"]:
		if not meta.has(field) or not (meta[field] is bool):
			errors.append("Champ booléen meta.%s absent." % field)
	_validate_primary_run(snapshot, errors)
	_validate_truth(snapshot, errors)
	_validate_summary(snapshot, errors)
	_validate_value(snapshot, "$", errors)
	return {"valid": errors.is_empty(), "errors": errors}


static func _validate_summary(snapshot: Dictionary, errors: Array[String]) -> void:
	var summary := snapshot.get("summary", {}) as Dictionary
	var expected := {
		"characters": (snapshot.get("characters", []) as Array).size(),
		"disciplines": (snapshot.get("disciplines", []) as Array).size(),
		"spells": (snapshot.get("spells", []) as Array).size(),
		"items": (snapshot.get("items", []) as Array).size(),
		"reward_pools": (snapshot.get("reward_pools", []) as Array).size(),
		"runs": (snapshot.get("runs", []) as Array).size(),
		"rooms": (snapshot.get("rooms", []) as Array).size(),
		"waves": (snapshot.get("waves", []) as Array).size(),
		"authored_wave_profiles": (snapshot.get("waves", []) as Array).size(),
		"encounters": (snapshot.get("encounters", []) as Array).size(),
		"enemies": (snapshot.get("enemies", []) as Array).size(),
		"enemy_spells": (snapshot.get("enemy_spells", []) as Array).size(),
		"ai_profiles": (snapshot.get("ai_profiles", []) as Array).size(),
		"runtime_facts": (snapshot.get("runtime_facts", []) as Array).size(),
	}
	var production_runs := 0
	var test_runs := 0
	var single_rooms := 0
	var wave_rooms := 0
	var production_combats := 0
	var test_authored_waves := 0
	var test_selected_waves := 0
	for run_value in snapshot.get("runs", []) as Array:
		var run := run_value as Dictionary
		if str(run.get("run_kind", "unknown")) == "production":
			production_runs += 1
			production_combats += int(run.get("effective_combat_count", 0))
		elif str(run.get("run_kind", "unknown")) == "test":
			test_runs += 1
			test_authored_waves += int(run.get("authored_wave_profile_count", 0))
			test_selected_waves += int(
				run.get("selected_default_seed_wave_profile_count", 0)
			)
	for room_value in snapshot.get("rooms", []) as Array:
		var room := room_value as Dictionary
		if str(room.get("flow_mode", "unknown")) == "single_encounter":
			single_rooms += 1
		elif str(room.get("flow_mode", "unknown")) == "wave_chain":
			wave_rooms += 1
	expected["production_run_count"] = production_runs
	expected["test_run_count"] = test_runs
	expected["single_encounter_room_count"] = single_rooms
	expected["wave_chain_room_count"] = wave_rooms
	expected["production_effective_combat_count"] = production_combats
	expected["test_authored_wave_profile_count"] = test_authored_waves
	expected["test_selected_wave_profile_count"] = test_selected_waves
	for key in expected:
		if int(summary.get(key, -1)) != int(expected[key]):
			errors.append("summary.%s ne correspond pas à la collection." % key)


static func _validate_primary_run(snapshot: Dictionary, errors: Array[String]) -> void:
	var primary_run_id := str(snapshot.get("primary_run_id", ""))
	var matches := (snapshot.get("runs", []) as Array).filter(func(value: Variant) -> bool:
		var run := value as Dictionary
		return str(run.get("id", "")) == primary_run_id \
			and str(run.get("run_kind", "unknown")) == "production" \
			and bool(run.get("is_primary", false))
	)
	if primary_run_id.is_empty() or matches.size() != 1:
		errors.append(
			"primary_run_id doit référencer exactement une run de production primaire."
		)


static func _validate_truth(snapshot: Dictionary, errors: Array[String]) -> void:
	var valid_truth_statuses := {
		"observed": true,
		"verified": true,
		"design_decision": true,
		"recommendation": true,
		"non_certified": true,
	}
	for fact_value in snapshot.get("runtime_facts", []) as Array:
		var fact := fact_value as Dictionary
		if not valid_truth_statuses.has(str(fact.get("truth_status", ""))):
			errors.append("runtime_facts.%s possède un truth_status invalide." % fact.get("key"))
	for audit_value in snapshot.get("audit_results", []) as Array:
		var audit := audit_value as Dictionary
		if not valid_truth_statuses.has(str(audit.get("truth_status", ""))):
			errors.append("audit_results.%s possède un truth_status invalide." % audit.get("rule_id"))
		if str(audit.get("suggested_action_truth_status", "")) != "recommendation":
			errors.append("audit_results.%s ne qualifie pas sa recommandation." % audit.get("rule_id"))


static func _validate_value(value: Variant, path: String, errors: Array[String]) -> void:
	if value is String or value is StringName:
		var text := str(value)
		if ObservatorySerializer.is_forbidden_absolute_path(text):
			errors.append("Chemin absolu interdit à %s." % path)
		if "<Object#" in text or "<Resource#" in text:
			errors.append("Marqueur Godot brut interdit à %s." % path)
		return
	if value is Array:
		var array := value as Array
		for index in range(array.size()):
			_validate_value(array[index], "%s[%d]" % [path, index], errors)
		return
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key in dictionary:
			if not (key is String or key is StringName):
				errors.append("Clé non textuelle interdite à %s." % path)
				continue
			_validate_value(dictionary[key], "%s.%s" % [path, str(key)], errors)
		return
	if value == null or value is bool or value is int or value is float:
		return
	errors.append("Type non JSON à %s : %s." % [path, type_string(typeof(value))])
