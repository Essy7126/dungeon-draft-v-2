@tool
class_name ArenaReadinessService
extends RefCounted

## Adapte les rapports existants vers les domaines de readiness. Ce service ne
## lance jamais de scene : un runtime_scene_report absent reste NOT_RUN.


static func build(
		arena: ArenaDefinition,
		sources: Dictionary = {}
	) -> ArenaReadinessReport:
	var report := ArenaReadinessReport.new()
	var data_source: Variant = sources.get("data_report", null)
	if data_source == null and arena != null:
		data_source = ArenaValidator.validate(arena, false)
	report.data_report = data_section(data_source)

	var topology_source: Variant = sources.get("topology_report", null)
	if topology_source == null and arena != null:
		var runtime_state: ArenaRuntimeState = ArenaRuntimeProjectionService.build(arena)
		if runtime_state != null:
			topology_source = ArenaRuntimeProjectionService.parity_report(
				arena, runtime_state
			)
	report.topology_report = topology_section(topology_source)

	var visual_source: Variant = sources.get("visual_report", null)
	if visual_source == null and arena != null:
		visual_source = ArenaVisualAssembler.inspect(arena)
	report.visual_report = visual_section(visual_source)

	var runtime_source: Variant = sources.get(
		"runtime_scene_report", sources.get("runtime_test_result", null)
	)
	report.runtime_scene_report = runtime_scene_section(arena, runtime_source)
	report.production_report = production_section(sources.get(
		"production_report", sources.get("production_plan", null)
	))
	report.integration_report = integration_section(sources.get(
		"integration_report", sources.get("integration_plan", null)
	))
	return report.recompute()


static func data_section(value: Variant) -> ArenaReadinessSection:
	if value is ArenaReadinessSection:
		return value as ArenaReadinessSection
	var section := ArenaReadinessSection.new()
	if not value is ArenaValidationReport:
		return _outcome(
			section, ArenaReadinessSection.State.NOT_RUN, &"DATA_NOT_RUN",
			"La validation des donnees Arena n'a pas ete executee."
		)
	var validation: ArenaValidationReport = value as ArenaValidationReport
	for message in validation.messages:
		var line := "%s: %s" % [message.code, message.message]
		match message.severity:
			ArenaValidationMessage.Severity.ERROR:
				section.errors.append(line)
			ArenaValidationMessage.Severity.WARNING:
				section.warnings.append(line)
			_:
				section.information.append(line)
	section.details = validation.to_dict()
	if not validation.is_valid():
		return _outcome(
			section, ArenaReadinessSection.State.FAIL, &"DATA_INVALID",
			"Les donnees Arena contiennent des erreurs bloquantes."
		)
	if not section.warnings.is_empty():
		return _outcome(
			section, ArenaReadinessSection.State.PASS_WITH_WARNINGS,
			&"DATA_VALID_WITH_WARNINGS",
			"Les donnees Arena sont valides avec des avertissements de conception."
		)
	return _outcome(
		section, ArenaReadinessSection.State.PASS, &"DATA_VALID",
		"Les donnees Arena sont valides."
	)


static func topology_section(value: Variant) -> ArenaReadinessSection:
	if value is ArenaReadinessSection:
		return value as ArenaReadinessSection
	var section := ArenaReadinessSection.new()
	var payload: Dictionary = {}
	if value is ArenaTopologyParityReport:
		payload = (value as ArenaTopologyParityReport).to_dict()
	elif value is Dictionary:
		payload = (value as Dictionary).duplicate(true)
	if payload.is_empty():
		return _outcome(
			section, ArenaReadinessSection.State.NOT_RUN, &"TOPOLOGY_NOT_RUN",
			"La parite topologique n'a pas ete executee."
		)
	section.details = payload.duplicate(true)
	section.errors = _strings(payload.get("errors", []))
	section.warnings = _strings(payload.get("warnings", []))
	var single_error := str(payload.get("error", ""))
	if not single_error.is_empty() and not section.errors.has(single_error):
		section.errors.append(single_error)
	var valid := bool(payload.get("valid", payload.get("ok", false)))
	if not valid:
		if section.errors.is_empty():
			section.errors.append("topology_mismatch")
		return _outcome(
			section, ArenaReadinessSection.State.FAIL, &"TOPOLOGY_INVALID",
			"La topologie Arena et sa projection divergent."
		)
	return _passed_outcome(
		section, &"TOPOLOGY_VALID", "La parite topologique est valide."
	)


static func visual_section(value: Variant) -> ArenaReadinessSection:
	if value is ArenaReadinessSection:
		return value as ArenaReadinessSection
	var section := ArenaReadinessSection.new()
	var payload: Dictionary = {}
	if value is ArenaVisualAssemblyReport:
		payload = (value as ArenaVisualAssemblyReport).to_dict()
	elif value is Dictionary:
		payload = (value as Dictionary).duplicate(true)
	if payload.is_empty():
		return _outcome(
			section, ArenaReadinessSection.State.NOT_RUN, &"VISUAL_NOT_RUN",
			"La verification du rendu Arena n'a pas ete executee."
		)
	section.details = payload.duplicate(true)
	section.errors = _strings(payload.get("errors", []))
	section.warnings = _strings(payload.get("warnings", []))
	if not bool(payload.get("valid", false)):
		if section.errors.is_empty():
			section.errors.append("visual_assembly_invalid")
		return _outcome(
			section, ArenaReadinessSection.State.FAIL, &"VISUAL_INVALID",
			"L'assemblage visuel Arena est invalide."
		)
	return _passed_outcome(
		section, &"VISUAL_VALID", "L'assemblage visuel Arena est valide."
	)


static func runtime_scene_section(
		arena: ArenaDefinition,
		value: Variant
	) -> ArenaRuntimeSceneReport:
	if value is ArenaRuntimeSceneReport:
		return value as ArenaRuntimeSceneReport
	var report := ArenaRuntimeSceneReport.new()
	if not value is Dictionary or (value as Dictionary).is_empty():
		_outcome(
			report, ArenaReadinessSection.State.NOT_RUN, &"RUNTIME_NOT_RUN",
			"La vraie scene de bataille n'a pas ete verifiee."
		)
		return report
	var payload: Dictionary = (value as Dictionary).duplicate(true)
	report.details = payload.duplicate(true)
	report.expected_battle_scene_path = str(payload.get(
		"expected_battle_scene_path", _battle_scene_path(arena)
	))
	report.battle_scene_path = str(payload.get(
		"battle_scene_path", payload.get("scene_path", "")
	))
	report.scene_script_path = str(payload.get(
		"scene_script_path", payload.get("scene_script", "")
	))
	report.runtime_scene_inspected = bool(payload.get("runtime_scene_inspected", false))
	report.script_parse_ok = bool(payload.get("script_parse_ok", false))
	report.scene_instantiated = bool(payload.get("scene_instantiated", false))
	report.runtime_ready = bool(payload.get("runtime_ready", false))
	report.grid_ready = bool(payload.get("grid_ready", false))
	report.pathfinder_ready = bool(payload.get("pathfinder_ready", false))
	report.render_ready = bool(payload.get("render_ready", false))
	report.spawn_ready = bool(payload.get(
		"spawn_ready", payload.get("spawns_ready", false)
	))
	report.cleanup_ok = bool(payload.get("cleanup_ok", false))
	report.produced_bundle_loaded = bool(payload.get("produced_bundle_loaded", false))
	report.configuration = StringName(payload.get("configuration", ""))
	report.generated_at = str(payload.get("generated_at", ""))
	report.duration_ms = float(payload.get("duration_ms", 0.0))
	report.working_fingerprint = str(payload.get("working_fingerprint", ""))
	report.temporary_fingerprint = str(payload.get("temporary_fingerprint", ""))
	report.runtime_fingerprint = str(payload.get("runtime_fingerprint", ""))
	report.fingerprints_identical = bool(payload.get("fingerprints_identical", false))
	report.working_topology_hash = str(payload.get("working_topology_hash", ""))
	report.temporary_topology_hash = str(payload.get("temporary_topology_hash", ""))
	report.runtime_topology_hash = str(payload.get("runtime_topology_hash", ""))
	report.topology_hashes_identical = bool(payload.get(
		"topology_hashes_identical", false
	))
	report.expected_floor_hash = str(payload.get("expected_floor_hash", ""))
	report.rendered_floor_hash = str(payload.get("rendered_floor_hash", ""))
	report.errors = _strings(payload.get("errors", []))
	report.warnings = _strings(payload.get("warnings", []))
	var single_error := str(payload.get("error", ""))
	if not single_error.is_empty() and not report.errors.has(single_error):
		report.errors.append(single_error)
	var state_text := str(payload.get("state", "")).to_upper()
	if bool(payload.get("blocked", false)) or state_text == "BLOCKED":
		_outcome(
			report, ArenaReadinessSection.State.BLOCKED, &"RUNTIME_BLOCKED",
			"La verification de la vraie scene est bloquee."
		)
		return report
	if bool(payload.get("ok", false)) and report.diagnostics_ready() \
			and report.errors.is_empty():
		_passed_outcome(
			report, &"RUNTIME_BOOTABLE",
			"La vraie scene de bataille compile et atteint runtime_ready."
		)
		return report
	_append_runtime_contract_errors(report)
	_outcome(
		report, ArenaReadinessSection.State.FAIL, &"RUNTIME_BOOT_FAILED",
		"La vraie scene de bataille ne satisfait pas le contrat runtime."
	)
	return report


static func production_section(value: Variant) -> ArenaReadinessSection:
	return _plan_section(
		value, "can_produce", "ready_to_produce", &"PRODUCTION_READY",
		&"PRODUCTION_NOT_READY", "Le bundle peut etre produit.",
		"Le plan de production n'est pas valide."
	)


static func integration_section(value: Variant) -> ArenaReadinessSection:
	return _plan_section(
		value, "can_integrate", "ready_to_integrate", &"INTEGRATION_READY",
		&"INTEGRATION_NOT_READY", "L'integration est sure.",
		"Le plan d'integration n'est pas valide."
	)


static func _plan_section(
		value: Variant,
		primary_ready_key: String,
		secondary_ready_key: String,
		pass_code: StringName,
		fail_code: StringName,
		pass_summary: String,
		fail_summary: String
	) -> ArenaReadinessSection:
	if value is ArenaReadinessSection:
		return value as ArenaReadinessSection
	var section := ArenaReadinessSection.new()
	if not value is Dictionary or (value as Dictionary).is_empty():
		return _outcome(
			section, ArenaReadinessSection.State.NOT_RUN,
			StringName("%s_NOT_RUN" % str(pass_code).trim_suffix("_READY")),
			"Ce plan n'a pas ete execute."
		)
	var payload: Dictionary = (value as Dictionary).duplicate(true)
	section.details = payload.duplicate(true)
	section.errors = _strings(payload.get("errors", []))
	section.warnings = _strings(payload.get("warnings", []))
	var single_error := str(payload.get("error", ""))
	if not single_error.is_empty() and not section.errors.has(single_error):
		section.errors.append(single_error)
	var state_text := str(payload.get("state", "")).to_upper()
	if bool(payload.get("blocked", false)) or state_text == "BLOCKED":
		return _outcome(
			section, ArenaReadinessSection.State.BLOCKED, fail_code, fail_summary
		)
	var plan_ok := bool(payload.get("ok", false))
	var ready := bool(payload.get(
		primary_ready_key, payload.get(secondary_ready_key, false)
	))
	if plan_ok and ready and section.errors.is_empty():
		return _passed_outcome(section, pass_code, pass_summary)
	if section.errors.is_empty():
		section.errors.append(str(fail_code).to_lower())
	return _outcome(
		section, ArenaReadinessSection.State.FAIL, fail_code, fail_summary
	)


static func _passed_outcome(
		section: ArenaReadinessSection,
		code: StringName,
		summary: String
	) -> ArenaReadinessSection:
	var state := ArenaReadinessSection.State.PASS_WITH_WARNINGS \
		if not section.warnings.is_empty() else ArenaReadinessSection.State.PASS
	return _outcome(section, state, code, summary)


static func _outcome(
		section: ArenaReadinessSection,
		state: int,
		code: StringName,
		summary: String
	) -> ArenaReadinessSection:
	section.state = state
	section.code = code
	section.summary = summary
	return section


static func _battle_scene_path(arena: ArenaDefinition) -> String:
	if arena == null or arena.battle_scene == null:
		return ""
	return arena.battle_scene.resource_path


static func _append_runtime_contract_errors(report: ArenaRuntimeSceneReport) -> void:
	if not report.runtime_scene_inspected:
		_add_unique(report.errors, "runtime_scene_not_inspected")
	if not report.battle_scene_matches():
		_add_unique(report.errors, "battle_scene_mismatch")
	if not report.script_parse_ok:
		_add_unique(report.errors, "script_parse_failed")
	if not report.scene_instantiated:
		_add_unique(report.errors, "scene_instantiation_failed")
	if not report.runtime_ready:
		_add_unique(report.errors, "runtime_ready_not_reached")
	if not report.grid_ready:
		_add_unique(report.errors, "grid_not_ready")
	if not report.pathfinder_ready:
		_add_unique(report.errors, "pathfinder_not_ready")
	if not report.render_ready:
		_add_unique(report.errors, "render_not_ready")
	if not report.spawn_ready:
		_add_unique(report.errors, "spawns_not_ready")
	if not report.fingerprints_match():
		_add_unique(report.errors, "fingerprint_mismatch")
	if not report.topology_matches():
		_add_unique(report.errors, "topology_mismatch")
	if report.produced_bundle_loaded:
		_add_unique(report.errors, "produced_bundle_loaded")
	if report.errors.is_empty():
		report.errors.append("runtime_probe_failed")


static func _add_unique(values: Array[String], value: String) -> void:
	if not values.has(value):
		values.append(value)


static func _strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is PackedStringArray:
		var packed: PackedStringArray = value as PackedStringArray
		for entry in packed:
			result.append(entry)
		return result
	if value is Array:
		var entries: Array = value as Array
		for entry in entries:
			if entry is Dictionary:
				var record: Dictionary = entry as Dictionary
				result.append(str(record.get(
					"message", record.get("code", JSON.stringify(record))
				)))
			else:
				result.append(str(entry))
	elif value != null and not str(value).is_empty():
		result.append(str(value))
	return result
