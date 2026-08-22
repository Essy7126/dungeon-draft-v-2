@tool
class_name ArenaIntegrationGatePolicy
extends RefCounted

## Autorite unique de la disponibilite d'integration. La severite reste une
## presentation ; seul blocks_integration participe au gate.

enum Profile {
	DRAFT,
	TEST_RUN,
	PRODUCTION,
	STRICT_RELEASE,
}

const BLOCKING_DESTINATION_STATES := [
	&"FOREIGN_CONTENT", &"CORRUPT_MANIFEST", &"OWNED_DIRTY",
	&"REFERENCED_INCOMPLETE", &"UNKNOWN",
]


static func evaluate(
		validation: ArenaValidationReport,
		topology_report: Variant,
		visual_report: ArenaVisualAssemblyReport,
		automatic_smoke: Dictionary,
		destination: Dictionary,
		profile := Profile.PRODUCTION,
		options: Dictionary = {}
	) -> Dictionary:
	var gate := _empty_gate(profile)
	gate.automatic_actions.assign([
		"validation_pure",
		"topology_parity",
		"render_parity",
		"automatic_runtime_smoke",
		"destination_plan",
		"gameplay_preservation",
		"save_reload_rollback_preflight",
	])
	var accepted: Array = options.get("accepted_warnings", [])
	var fingerprint := str(options.get("arena_fingerprint", ""))
	if validation == null:
		_add_blocker(gate, &"VALIDATION_REPORT_MISSING", "Le rapport de validation est absent.", &"validation")
	else:
		for message in validation.messages:
			var issue := message.to_dict()
			issue["source"] = "validation"
			if message.blocks_integration:
				gate.blocking_errors.append(issue)
			elif message.severity == ArenaValidationMessage.Severity.WARNING:
				issue["acknowledged"] = _is_warning_accepted(
					issue, accepted, fingerprint
				)
				gate.acknowledgement_warnings.append(issue)
			else:
				gate.information.append(issue)
	_add_topology_issues(gate, _topology_dict(topology_report), profile)
	_add_visual_issues(gate, visual_report, profile)
	_add_smoke_issues(gate, automatic_smoke, profile)
	_add_runtime_scene_issues(gate, options)
	_add_destination_issues(gate, destination, profile)
	gate = apply_context(gate, options)
	_mark_accepted_warnings(gate, accepted, fingerprint)
	if profile == Profile.STRICT_RELEASE:
		_promote_strict_warnings(gate, options.get(
			"strict_blocking_warning_codes", []
		))
	return _finalize(gate)


static func evaluate_certificate(
		certificate: ArenaProductionReadinessCertificate,
		profile := Profile.PRODUCTION
	) -> Dictionary:
	var gate := _empty_gate(profile)
	if certificate == null:
		_add_blocker(gate, &"CERTIFICATE_MISSING", "Le certificat de production est absent.", &"certificate")
		return _finalize(gate)
	gate.requires_runtime_scene = true
	if certificate.readiness_report != null \
			and certificate.readiness_report.runtime_scene_report != null:
		gate.runtime_scene_report = certificate.readiness_report.runtime_scene_report.to_dict()
	gate.runtime_bootable = certificate.runtime_bootable
	gate.automatic_actions.assign([
		"validation_pure", "topology_parity", "render_parity",
		"automatic_runtime_smoke", "destination_plan",
		"gameplay_preservation", "save_reload_rollback_preflight",
	])
	for code in certificate.validation_errors:
		_add_blocker(gate, StringName(code), "Erreur technique de validation : %s." % code, &"validation")
	if not certificate.topology_gate_valid \
			or certificate.canonical_topology_hash != certificate.temporary_topology_hash \
			or certificate.canonical_topology_hash != certificate.runtime_topology_hash:
		_add_blocker(gate, &"TOPOLOGY_MISMATCH", "La version en cours, la copie temporaire et le jeu réel n'utilisent pas la même topologie.", &"topology")
	if not certificate.removed_cells_rendered.is_empty():
		_add_blocker(gate, &"REMOVED_CELL_RENDERED", "%d case(s) retirée(s) sont encore rendues." % certificate.removed_cells_rendered.size(), &"render")
	if certificate.expected_floor_hash != certificate.rendered_floor_hash \
			or not certificate.unexpected_cells.is_empty() \
			or not certificate.missing_cells.is_empty() \
			or certificate.duplicate_tiles > 0:
		_add_blocker(gate, &"MISSING_OR_DUPLICATE_TILES", "Les ensembles exacts de dalles attendues et rendues divergent.", &"render")
	if certificate.expected_tiles != certificate.rendered_tiles \
			or certificate.expected_walls != certificate.rendered_walls:
		_add_blocker(gate, &"MISSING_OR_DUPLICATE_TILES", "Le rendu dans le jeu est incomplet ou dupliqué.", &"render")
	if not certificate.pathfinding_valid:
		_add_blocker(gate, &"GRID_BUILD_FAILED", "GridData ou Pathfinder ne garantissent pas les chemins obligatoires.", &"runtime")
	if not certificate.spawn_contract_valid:
		_add_blocker(gate, &"REQUIRED_SPAWN_INVALID", "Un spawn obligatoire est absent ou invalide.", &"runtime")
	if not certificate.coverage_gate_valid:
		_add_blocker(gate, &"SCHEMA_UNSUPPORTED", "Des champs obligatoires du jeu ne possèdent aucune politique prise en charge.", &"schema")
	if not certificate.automatic_runtime_smoke_valid:
		_add_blocker(gate, &"AUTOMATIC_RUNTIME_SMOKE_FAILED", "Le test de fumée automatique n'a pas réussi.", &"smoke")
	if not certificate.runtime_bootable:
		_add_blocker(
			gate, &"RUNTIME_SCENE_NOT_RUN",
			"La vraie scène de bataille n'a pas fourni de preuve runtime courante.",
			&"runtime_scene"
		)
	if certificate.destination_conflict_state in BLOCKING_DESTINATION_STATES:
		_add_blocker(gate, &"DESTINATION_CONFLICT", "La destination est inconnue, incomplète ou contient des fichiers étrangers.", &"destination")
	if not certificate.preview_logic_valid or not certificate.preview_art_valid \
			or not certificate.preview_game_valid:
		_add_information(gate, &"PREVIEW_NOT_VISITED", "Une ou plusieurs vues manuelles n'ont pas ete ouvertes ; elles ne bloquent pas l'intégration.", &"preview")
	if not certificate.art_alignment_confirmed:
		_add_warning(gate, &"ART_ALIGNMENT_UNCONFIRMED", "L'alignement artistique n'a pas ete confirme manuellement.", &"art")
	if not certificate.manual_test_performed:
		_add_warning(gate, &"MANUAL_TEST_NOT_PERFORMED", "Cette version n'a pas ete testee manuellement ; le smoke automatique reste l'autorite technique.", &"manual_test")
	for value in certificate.accepted_warnings:
		var accepted := (value as Dictionary).duplicate(true)
		accepted["acknowledged"] = true
		accepted["blocks_integration"] = false
		gate.acknowledgement_warnings.append(accepted)
	return _finalize(gate)


static func apply_context(gate: Dictionary, options: Dictionary) -> Dictionary:
	var result := gate.duplicate(true)
	if bool(options.get("external_source_conflict", false)):
		_add_blocker(result, &"EXTERNAL_SOURCE_CONFLICT", "La salle a change sur disque depuis son ouverture.", &"source")
	if bool(options.get("run_conflict", false)):
		_add_blocker(result, &"EXTERNAL_SOURCE_CONFLICT", "La partie ciblée contient des modifications concurrentes non sauvegardées.", &"run")
	var destination_conflicts: Array = options.get("destination_conflicts", [])
	if not destination_conflicts.is_empty():
		_add_blocker(result, &"DESTINATION_CONFLICT", "%d fichier(s) de destination ne sont pas attribues au Studio." % destination_conflicts.size(), &"destination")
	if not bool(options.get("attachment_ok", true)):
		_add_blocker(result, &"DESTINATION_CONFLICT", str(options.get("attachment_error", "Le plan de rattachement est invalide.")), &"attachment")
	for error in options.get("run_validation_errors", []):
		_add_blocker(result, &"RUN_ISOLATION_VIOLATION", str(error), &"run")
	if not bool(options.get("field_coverage_ok", true)) \
			or not bool(options.get("target_coverage_ok", true)):
		_add_blocker(result, &"SCHEMA_UNSUPPORTED", "Une propriété de salle ne possède aucune politique d'intégration.", &"schema")
	if not bool(options.get("gameplay_preserved", true)) \
			and bool(options.get("gameplay_preservation_required", false)):
		_add_blocker(result, &"ROOM_GAMEPLAY_DRIFT", "Cette mise a jour modifierait rencontre, vagues ou récompenses.", &"gameplay")
	if not bool(options.get("rollback_available", true)):
		_add_blocker(result, &"ROLLBACK_UNAVAILABLE", "La transaction ne possède aucun rollback verifiable.", &"transaction")
	var dirty_domains: Array = options.get("unrelated_dirty_domains", [])
	if not dirty_domains.is_empty():
		_add_information(result, &"UNRELATED_DOCUMENTS_DIRTY", "D'autres documents restent modifies mais sont hors de cette transaction : %s." % ", ".join(dirty_domains), &"workspace")
	if not bool(options.get("manual_test_performed", false)) \
			and int(result.get("profile", Profile.PRODUCTION)) != Profile.DRAFT \
			and not _has_issue(result.acknowledgement_warnings, &"MANUAL_TEST_NOT_PERFORMED"):
		_add_warning(result, &"MANUAL_TEST_NOT_PERFORMED", "Cette version n'a pas été testée manuellement. Le test de fumée automatique doit toutefois réussir.", &"manual_test")
	if not bool(options.get("art_alignment_confirmed", true)) \
			and not _has_issue(result.acknowledgement_warnings, &"ART_ALIGNMENT_UNCONFIRMED"):
		_add_warning(result, &"ART_ALIGNMENT_UNCONFIRMED", "L'alignement artistique reste a juger visuellement.", &"art")
	return _finalize(result)


static func warning_key(issue: Dictionary) -> String:
	return "%s|%s|%s" % [
		str(issue.get("code", "warning")),
		JSON.stringify(issue.get("cell", null)),
		str(issue.get("subject_id", "")),
	]


static func profile_name(profile: int) -> String:
	return ["BROUILLON", "RUN_DE_TEST", "PRODUCTION", "RELEASE_STRICTE"][clampi(
		profile, Profile.DRAFT, Profile.STRICT_RELEASE
	)]


static func _empty_gate(profile: int) -> Dictionary:
	return {
		"profile": clampi(profile, Profile.DRAFT, Profile.STRICT_RELEASE),
		"profile_name": profile_name(profile),
		"blocking_errors": [],
		"acknowledgement_warnings": [],
		"information": [],
		"automatic_actions": [],
		"ready_to_integrate": false,
		"ready_to_produce": false,
		"ready_to_test": false,
		"runtime_bootable": false,
		"requires_runtime_scene": false,
		"runtime_scene_report": {},
		"requires_warning_acknowledgement": false,
		"unacknowledged_warning_count": 0,
		"summary": "",
	}


static func _topology_dict(value: Variant) -> Dictionary:
	if value is ArenaTopologyParityReport:
		return (value as ArenaTopologyParityReport).to_dict()
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _add_topology_issues(gate: Dictionary, parity: Dictionary, profile: int) -> void:
	if profile == Profile.DRAFT:
		return
	if parity.is_empty():
		_add_blocker(gate, &"TOPOLOGY_MISMATCH", "Le rapport de parite topologique est absent.", &"topology")
		return
	var removed: Array = parity.get("removed_cells_rendered", [])
	var missing: Array = parity.get("missing_cells", [])
	var unexpected: Array = parity.get("unexpected_cells", [])
	var duplicates: Array = parity.get("duplicate_cells", [])
	if not removed.is_empty():
		_add_blocker(gate, &"REMOVED_CELL_RENDERED", "%d case(s) retirée(s) sont encore rendues." % removed.size(), &"topology", removed)
	if not missing.is_empty() or not unexpected.is_empty() or not duplicates.is_empty():
		_add_blocker(gate, &"MISSING_OR_DUPLICATE_TILES", "Dalles manquantes : %d ; inattendues : %d ; dupliquées : %d." % [missing.size(), unexpected.size(), duplicates.size()], &"render", missing + unexpected + duplicates)
	if not bool(parity.get("valid", false)) and removed.is_empty() \
			and missing.is_empty() and unexpected.is_empty() and duplicates.is_empty():
		_add_blocker(gate, &"TOPOLOGY_MISMATCH", "Les hashes ou ensembles topologiques divergent.", &"topology")


static func _add_visual_issues(gate: Dictionary, visual: ArenaVisualAssemblyReport, profile: int) -> void:
	if profile == Profile.DRAFT:
		return
	if visual == null:
		_add_blocker(gate, &"GRID_BUILD_FAILED", "Le rapport d'assemblage visuel est absent.", &"render")
		return
	if visual.valid:
		_add_information(gate, &"RENDER_PARITY_OK", "Rendu : %d / %d dalles." % [visual.rendered_terrain_node_count, visual.expected_terrain_cell_count], &"render")
		return
	var missing_asset := not visual.missing_terrain_assets.is_empty() \
		or not visual.missing_wall_assets.is_empty()
	_add_blocker(
		gate,
		&"REQUIRED_ASSET_MISSING" if missing_asset else &"MISSING_OR_DUPLICATE_TILES",
		"L'assemblage visuel runtime est incomplet.",
		&"render"
	)


static func _add_smoke_issues(gate: Dictionary, smoke: Dictionary, profile: int) -> void:
	if profile == Profile.DRAFT:
		return
	if smoke.is_empty():
		_add_blocker(gate, &"AUTOMATIC_RUNTIME_SMOKE_FAILED", "Le test de fumée automatique est absent.", &"smoke")
		return
	if bool(smoke.get("ok", false)):
		_add_information(gate, &"AUTOMATIC_RUNTIME_SMOKE_OK", "Le test de fumée automatique a réussi.", &"smoke")
		return
	var blocker_count_before := (gate.blocking_errors as Array).size()
	var errors: Array = smoke.get("errors", [])
	if errors.any(func(value): return str(value).contains("grid_build") or str(value).contains("pathfinder")):
		_add_blocker(gate, &"GRID_BUILD_FAILED", "GridData ou Pathfinder ne peuvent pas être construits.", &"smoke")
	if not (smoke.get("required_spawn_errors", []) as Array).is_empty():
		_add_blocker(gate, &"REQUIRED_SPAWN_INVALID", "Un spawn obligatoire est invalide dans la copie runtime.", &"smoke")
	if not (smoke.get("required_objective_errors", []) as Array).is_empty():
		_add_blocker(gate, &"REQUIRED_OBJECTIVE_INVALID", "Un objectif obligatoire est invalide dans la copie runtime.", &"smoke")
	if not bool(smoke.get("fingerprints_identical", false)):
		_add_blocker(gate, &"SAVE_OR_RELOAD_FAILED", "La copie temporaire rechargée diffère de la version en cours.", &"smoke")
	if not bool(smoke.get("topology_hashes_identical", false)):
		_add_blocker(gate, &"TOPOLOGY_MISMATCH", "La copie temporaire et le jeu réel divergent de la version en cours.", &"smoke")
	if (gate.blocking_errors as Array).size() == blocker_count_before:
		_add_blocker(gate, &"AUTOMATIC_RUNTIME_SMOKE_FAILED", "Le test de fumée automatique a échoué : %s." % ", ".join(errors), &"smoke")


static func _add_runtime_scene_issues(
		gate: Dictionary,
		options: Dictionary
	) -> void:
	var required := bool(options.get("requires_runtime_scene", false))
	gate.requires_runtime_scene = required
	var source: Variant = options.get("runtime_scene_result", {})
	var report := ArenaReadinessService.runtime_scene_section(null, source)
	gate.runtime_scene_report = report.to_dict()
	gate.runtime_bootable = report.runtime_contract_satisfied()
	if gate.runtime_bootable:
		_add_information(
			gate, &"RUNTIME_SCENE_BOOTABLE",
			"La vraie scène de bataille a atteint runtime_ready.",
			&"runtime_scene"
		)
		return
	if not required:
		_add_information(
			gate, &"RUNTIME_SCENE_NOT_REQUIRED_FOR_PRODUCTION",
			"La production peut être préparée sans promouvoir le smoke de projection en preuve runtime.",
			&"runtime_scene"
		)
		return
	var code := &"RUNTIME_SCENE_NOT_RUN" \
		if report.state == ArenaReadinessSection.State.NOT_RUN \
		else &"RUNTIME_SCENE_BOOT_FAILED"
	_add_blocker(
		gate, code,
		"La vraie scène de bataille doit être vérifiée avec la version en cours.",
		&"runtime_scene"
	)


static func _add_destination_issues(gate: Dictionary, destination: Dictionary, profile: int) -> void:
	if profile == Profile.DRAFT:
		return
	if destination.is_empty():
		_add_blocker(gate, &"DESTINATION_CONFLICT", "Le prevol de destination est absent.", &"destination")
		return
	var state := StringName(destination.get("state", &"UNKNOWN"))
	if state in BLOCKING_DESTINATION_STATES:
		_add_blocker(gate, &"DESTINATION_CONFLICT", "État de destination bloquant : %s." % state, &"destination")
	else:
		_add_information(gate, &"DESTINATION_VERIFIED", "Destination vérifiée : %s." % state, &"destination")


static func _promote_strict_warnings(gate: Dictionary, codes: Variant) -> void:
	var promoted := PackedStringArray()
	for value in codes:
		promoted.append(str(value))
	for warning in gate.acknowledgement_warnings.duplicate(true):
		if promoted.has(str((warning as Dictionary).get("code", ""))):
			var blocker := (warning as Dictionary).duplicate(true)
			blocker["blocks_integration"] = true
			blocker["source"] = "strict_release"
			gate.blocking_errors.append(blocker)


static func _is_warning_accepted(
		issue: Dictionary,
		accepted: Array,
		fingerprint: String
	) -> bool:
	var key := warning_key(issue)
	for value in accepted:
		var record := value as Dictionary
		if not fingerprint.is_empty() and str(record.get("arena_fingerprint", "")) != fingerprint:
			continue
		if str(record.get("warning_key", "")) == key:
			return true
	return false


static func _mark_accepted_warnings(
		gate: Dictionary,
		accepted: Array,
		fingerprint: String
	) -> void:
	for value in gate.acknowledgement_warnings:
		var issue := value as Dictionary
		issue["arena_fingerprint"] = fingerprint
		issue["acknowledged"] = _is_warning_accepted(
			issue, accepted, fingerprint
		)


static func _add_blocker(
		gate: Dictionary,
		code: StringName,
		message: String,
		source: StringName,
		cells: Variant = []
	) -> void:
	if _has_issue(gate.blocking_errors, code):
		return
	gate.blocking_errors.append(_issue(code, message, source, true, cells))


static func _add_warning(
		gate: Dictionary,
		code: StringName,
		message: String,
		source: StringName
	) -> void:
	if _has_issue(gate.acknowledgement_warnings, code):
		return
	gate.acknowledgement_warnings.append(_issue(code, message, source, false))


static func _add_information(
		gate: Dictionary,
		code: StringName,
		message: String,
		source: StringName
	) -> void:
	if _has_issue(gate.information, code):
		return
	gate.information.append(_issue(code, message, source, false))


static func _issue(
		code: StringName,
		message: String,
		source: StringName,
		blocks: bool,
		cells: Variant = []
	) -> Dictionary:
	return {
		"code": str(code),
		"message": message,
		"source": str(source),
		"cells": ArenaTopologySignatureService.normalized_keys(cells),
		"cell": null,
		"subject_id": "",
		"blocks_integration": blocks,
		"acknowledged": false,
		"auto_fix_available": false,
	}


static func _has_issue(issues: Array, code: StringName) -> bool:
	return issues.any(func(value):
		return str((value as Dictionary).get("code", "")) == str(code)
	)


static func _finalize(gate: Dictionary) -> Dictionary:
	var unacknowledged := 0
	for warning in gate.acknowledgement_warnings:
		if not bool((warning as Dictionary).get("acknowledged", false)):
			unacknowledged += 1
	gate.unacknowledged_warning_count = unacknowledged
	gate.requires_warning_acknowledgement = unacknowledged > 0
	var non_runtime_blocker_count := 0
	var validation_blocked := false
	for value in gate.blocking_errors:
		var source := str((value as Dictionary).get("source", ""))
		if source != "runtime_scene":
			non_runtime_blocker_count += 1
		if source == "validation":
			validation_blocked = true
	gate.ready_to_produce = non_runtime_blocker_count == 0
	gate.ready_to_test = bool(gate.get("runtime_bootable", false)) \
		and not validation_blocked
	gate.ready_to_integrate = gate.blocking_errors.is_empty() \
		and (not bool(gate.get("requires_runtime_scene", false)) \
			or bool(gate.get("runtime_bootable", false)))
	gate.summary = "ARÈNE PRÊTE À INTÉGRER" if gate.ready_to_integrate \
		else "INTÉGRATION IMPOSSIBLE"
	return gate
