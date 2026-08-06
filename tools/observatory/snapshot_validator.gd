class_name ObservatorySnapshotValidator
extends RefCounted

const REQUIRED_SECTIONS := [
	"meta", "scope", "summary", "contract", "characters", "disciplines",
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
	for key in expected:
		if int(summary.get(key, -1)) != int(expected[key]):
			errors.append("summary.%s ne correspond pas à la collection." % key)


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
