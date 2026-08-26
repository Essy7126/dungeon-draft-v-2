@tool
class_name ArenaIntegrationService
extends RefCounted

## Orchestrateur du parcours Produire → intégrer → recharger → sélectionner.
## Le bundle produit est une phase préparée ; la mutation canonique est déléguée
## à ArenaProductionAttachmentService, qui possède recovery et rollback.

const JOURNAL_ROOT := "user://dungeon_draft_studio/room_integration/journals"
const STEP_PLAN := &"PLAN"
const STEP_JOURNAL := &"JOURNAL"
const STEP_PRODUCTION := &"PRODUCTION"
const STEP_ATTACHMENT := &"ATTACHMENT"
const STEP_ROLLBACK := &"ROLLBACK"
const STEP_FINALIZE := &"FINALIZE"


static func plan(
		arena: ArenaDefinition,
		run_data: RunData,
		action: StringName,
		requested_index: int,
		destination := "",
		graph: StudioReferenceGraphService = null,
		gate_options: Dictionary = {}
	) -> Dictionary:
	var runtime_scene_result: Dictionary = gate_options.get(
		"runtime_scene_result", ArenaDirectTestService.matching_runtime_result(arena)
	) as Dictionary
	var production := ArenaProductionService.plan(arena, destination, graph, {
		"runtime_scene_result": runtime_scene_result,
		"target_run": run_data,
	})
	if not production.get("ok", false):
		return {"ok": false, "error": production.get("error", "Plan de production impossible.")}
	var produced_path := str(production.get("destination", "")).path_join("arena.tres")
	var attachment := ArenaProductionAttachmentService.plan(
		run_data, action, requested_index, produced_path, graph
	)
	var field_coverage := RoomIntegrationFieldPolicy.coverage_report(arena)
	var target_room: RoomData = null
	if run_data != null and requested_index >= 0 and requested_index < run_data.rooms.size():
		target_room = run_data.rooms[requested_index]
	var target_coverage := RoomIntegrationFieldPolicy.coverage_report(target_room) \
		if target_room != null else {"ok": true, "unknown": PackedStringArray()}
	var run_errors := _simulated_run_errors(
		arena, run_data, action, int(attachment.get("target_index", requested_index))
	) if attachment.get("ok", false) else PackedStringArray()
	var affected_files := PackedStringArray()
	for path in production.get("creates", []):
		affected_files.append(str(path))
	for path in production.get("modifies", []):
		if not affected_files.has(str(path)):
			affected_files.append(str(path))
	for path in attachment.get("affected_files", []):
		if not affected_files.has(str(path)):
			affected_files.append(str(path))
	var policy_options := gate_options.duplicate(true)
	policy_options["arena_fingerprint"] = ArenaSnapshotService.arena_fingerprint(arena)
	policy_options["attachment_ok"] = bool(attachment.get("ok", false))
	policy_options["attachment_error"] = str(attachment.get("error", ""))
	policy_options["field_coverage_ok"] = bool(field_coverage.get("ok", false))
	policy_options["target_coverage_ok"] = bool(target_coverage.get("ok", false))
	policy_options["run_validation_errors"] = run_errors
	policy_options["destination_conflicts"] = production.get("conflicts", [])
	policy_options["gameplay_preservation_required"] = action \
		== ArenaProductionAttachmentService.UPDATE
	policy_options["gameplay_preserved"] = action \
		!= ArenaProductionAttachmentService.UPDATE \
		or bool(attachment.get("preserves_gameplay", false))
	policy_options["rollback_available"] = bool(attachment.get("ok", false))
	policy_options["requires_runtime_scene"] = action \
		!= ArenaProductionAttachmentService.NONE
	policy_options["runtime_scene_result"] = runtime_scene_result
	var gate_report := ArenaIntegrationGatePolicy.evaluate(
		production.get("validation") as ArenaValidationReport,
		production.get("topology_parity", {}),
		production.get("visual_report") as ArenaVisualAssemblyReport,
		production.get("automatic_runtime_smoke", {}),
		production.get("bundle_inspection", {}),
		int(gate_options.get(
			"validation_profile", ArenaIntegrationGatePolicy.Profile.PRODUCTION
		)),
		policy_options
	)
	var can_integrate := bool(gate_report.ready_to_produce) \
		if action == ArenaProductionAttachmentService.NONE \
		else bool(gate_report.ready_to_integrate)
	var readiness := ArenaReadinessService.build(arena, {
		"data_report": production.get("validation"),
		"topology_report": production.get("topology_parity", {}),
		"visual_report": production.get("visual_report"),
		"runtime_scene_report": runtime_scene_result,
		"production_plan": production,
		"integration_plan": {
			"ok": true,
			"can_integrate": can_integrate,
			"errors": gate_report.get("blocking_errors", []),
			"warnings": gate_report.get("acknowledgement_warnings", []),
		},
	})
	return {
		"ok": true,
		"can_integrate": can_integrate,
		"production": production,
		"attachment": attachment,
		"field_coverage": field_coverage,
		"target_coverage": target_coverage,
		"run_validation_errors": run_errors,
		"gate_report": gate_report,
		"readiness_report": readiness,
		"bundle_resolution": production.get("bundle_resolution", {}),
		"action": action,
		"action_label": action_label(action),
		"run_path": run_data.resource_path if run_data != null else "",
		"run_name": run_data.run_name if run_data != null else "Aucune partie",
		"target_room_path": target_room.resource_path if target_room != null else "",
		"target_room_name": target_room.room_name if target_room != null else "",
		"target_index": int(attachment.get("target_index", -1)),
		"before_count": int(attachment.get("before_count", 0)),
		"after_count": int(attachment.get("after_count", 0)),
		"new_arena_path": str(attachment.get("integrated_room_path", produced_path)),
		"shared": bool(attachment.get("shared", false)),
		"scope": "Copie unique à cette partie" if bool(attachment.get("copy_on_write", false)) \
			else "Unique à cette partie",
		"affected_files": affected_files,
		"preserved_gameplay": action == ArenaProductionAttachmentService.UPDATE,
		"abandoned_gameplay": RoomIntegrationFieldPolicy.gameplay_summary(target_room) \
			if action == ArenaProductionAttachmentService.REPLACE else PackedStringArray(),
	}


static func integrate(
		arena: ArenaDefinition,
		run_data: RunData,
		action: StringName,
		requested_index: int,
		destination := "",
		graph: StudioReferenceGraphService = null,
		provided_images := {}
	) -> Dictionary:
	return integrate_with_options(
		arena, run_data, action, requested_index, destination, graph,
		provided_images, {}
	)


static func integrate_with_options(
		arena: ArenaDefinition,
		run_data: RunData,
		action: StringName,
		requested_index: int,
		destination := "",
		graph: StudioReferenceGraphService = null,
		provided_images := {},
		options := {}
	) -> Dictionary:
	var monitor: ArenaGuidedPipelineDiagnosticsService = _pipeline_monitor(
		arena, run_data, action, requested_index, destination, options
	)
	var base_files := _pipeline_files(run_data, destination)
	var base_fingerprints := _pipeline_fingerprints(arena, run_data)
	monitor.begin_step(
		STEP_PLAN, {}, base_files, base_fingerprints,
		monitor.timeout_for(STEP_PLAN)
	)
	var integration_plan: Dictionary = plan(
		arena, run_data, action, requested_index, destination, graph,
		options.get("gate_options", {})
	)
	var plan_ok := bool(integration_plan.get("ok", false)) \
		and bool(integration_plan.get("can_integrate", false))
	monitor.update_step_evidence(
		{},
		_pipeline_files(run_data, destination, integration_plan),
		_pipeline_fingerprints(arena, run_data)
	)
	var checkpoint := monitor.end_step(
		STEP_PLAN,
		plan_ok,
		str(integration_plan.get("error", "integration_gate_blocked")) \
			if not plan_ok else "",
		{
			"can_integrate": integration_plan.get("can_integrate", false),
			"affected_files": integration_plan.get("affected_files", []),
		}
	)
	if _checkpoint_interrupted(checkpoint):
		return _checkpoint_result(
			checkpoint, monitor, integration_plan, {}, {}, "plan_interrupted"
		)
	if not plan_ok:
		return _pipeline_result({
			"ok": false,
			"status": &"PLAN_REFUSED",
			"error": integration_plan.get(
				"error", "Le plan d'intégration est bloqué."
			),
			"plan": integration_plan,
		}, monitor)

	if monitor.interruption_requested():
		return _interrupt_before_step(
			monitor, STEP_JOURNAL, integration_plan, {}, {}
		)
	monitor.begin_step(
		STEP_JOURNAL,
		{},
		_pipeline_files(run_data, destination, integration_plan),
		_pipeline_fingerprints(arena, run_data),
		monitor.timeout_for(STEP_JOURNAL)
	)
	var journal_path := _new_journal_path(arena, run_data)
	var journal_written := _write_journal(
		journal_path, _journal_state(&"PLANNED", integration_plan)
	)
	monitor.update_step_evidence(
		{"journal_path": journal_path},
		[journal_path],
		{"journal_physical_sha256": _file_hash(journal_path)}
	)
	checkpoint = monitor.end_step(
		STEP_JOURNAL,
		journal_written,
		"journal_write_failed" if not journal_written else "",
		{"journal_path": journal_path}
	)
	if not bool(checkpoint.get("ok", false)):
		return _checkpoint_result(
			checkpoint, monitor, integration_plan, {}, {}, "journal_write_failed",
			{"journal_path": journal_path}
		)

	var production_options: Dictionary = (options.get(
		"production_options", {}
	) as Dictionary).duplicate(true)
	production_options["reference_graph"] = graph
	if monitor.interruption_requested():
		return _interrupt_before_step(
			monitor, STEP_PRODUCTION, integration_plan, {}, {}, journal_path
		)
	monitor.begin_step(
		STEP_PRODUCTION,
		{"journal_path": journal_path},
		_pipeline_files(run_data, destination, integration_plan),
		_pipeline_fingerprints(arena, run_data),
		monitor.timeout_for(STEP_PRODUCTION)
	)
	var production: Dictionary = ArenaProductionService.produce_with_options(
		arena, destination, provided_images, production_options
	)
	monitor.update_step_evidence(
		{"transaction": _transaction_context(production)},
		_pipeline_files(run_data, destination, integration_plan, production),
		_pipeline_fingerprints(arena, run_data, production)
	)
	checkpoint = monitor.end_step(
		STEP_PRODUCTION,
		bool(production.get("ok", false)),
		str(production.get("error", "production_failed")) \
			if not bool(production.get("ok", false)) else "",
		{
			"arena_path": production.get("arena_path", ""),
			"transaction": _transaction_context(production),
		}
	)
	if _checkpoint_interrupted(checkpoint):
		return _checkpoint_result(
			checkpoint, monitor, integration_plan, production, {},
			"production_interrupted", {"journal_path": journal_path}
		)
	if not bool(production.get("ok", false)):
		_write_journal(
			journal_path,
			_journal_state(&"PRODUCTION_FAILED", integration_plan, {
				"error": production.get("error", "production_failed"),
			})
		)
		return _pipeline_result({
			"ok": false,
			"status": &"PRODUCTION_FAILED",
			"error": production.get("error", "La production a échoué."),
			"plan": integration_plan,
			"production": production,
			"journal_path": journal_path,
		}, monitor)
	_write_journal(journal_path, _journal_state(&"PRODUCED", integration_plan, {
		"arena_path": production.get("arena_path", ""),
	}))

	if monitor.interruption_requested():
		return _interrupt_before_step(
			monitor, STEP_ATTACHMENT, integration_plan, production, {}, journal_path
		)
	monitor.begin_step(
		STEP_ATTACHMENT,
		{"journal_path": journal_path},
		_pipeline_files(run_data, destination, integration_plan, production),
		_pipeline_fingerprints(arena, run_data, production),
		monitor.timeout_for(STEP_ATTACHMENT)
	)
	var attachment := {"ok": false, "error": "injected_before_attachment"}
	if str(options.get("failure_step", "")) != "before_attachment":
		attachment = ArenaProductionAttachmentService.attach_and_save(
			str(production.get("arena_path", "")), run_data, action,
			requested_index, graph
		)
	monitor.update_step_evidence(
		{},
		_pipeline_files(
			run_data, destination, integration_plan, production, attachment
		),
		_pipeline_fingerprints(arena, run_data, production, attachment)
	)
	checkpoint = monitor.end_step(
		STEP_ATTACHMENT,
		bool(attachment.get("ok", false)),
		str(attachment.get("error", "integration_failed")) \
			if not bool(attachment.get("ok", false)) else "",
		{
			"integrated_room_path": attachment.get("integrated_room_path", ""),
			"run_saved": attachment.get("run_saved", false),
			"copy_on_write": attachment.get("copy_on_write", false),
		}
	)
	if _checkpoint_interrupted(checkpoint):
		return _checkpoint_result(
			checkpoint, monitor, integration_plan, production, attachment,
			"attachment_interrupted", {"journal_path": journal_path}
		)
	if not bool(attachment.get("ok", false)):
		var failed_rollback := _rollback_pipeline(
			monitor, integration_plan, production, attachment
		)
		_write_journal(
			journal_path,
			_journal_state(&"INTEGRATION_FAILED", integration_plan, {
				"error": attachment.get("error", "integration_failed"),
				"produced_arena_path": production.get("arena_path", ""),
			})
		)
		return _pipeline_result({
			"ok": false,
			"status": &"INTEGRATION_ROLLED_BACK",
			"error": attachment.get("error", "L'intégration a échoué."),
			"plan": integration_plan,
			"production": production,
			"attachment": attachment,
			"attachment_rollback": failed_rollback.attachment_rollback,
			"production_rollback": failed_rollback.production_rollback,
			"journal_path": journal_path,
		}, monitor)
	if str(options.get("failure_step", "")) == "after_attachment":
		monitor.begin_step(
			STEP_FINALIZE,
			{"failure_injection": "after_attachment"},
			_pipeline_files(
				run_data, destination, integration_plan, production, attachment
			),
			_pipeline_fingerprints(arena, run_data, production, attachment),
			monitor.timeout_for(STEP_FINALIZE)
		)
		monitor.end_step(
			STEP_FINALIZE,
			false,
			"injected_after_attachment",
			{"failure_injection": true}
		)
		var injected_rollback := _rollback_pipeline(
			monitor, integration_plan, production, attachment
		)
		return _pipeline_result({
			"ok": false,
			"status": &"INTEGRATION_ROLLED_BACK",
			"error": "injected_after_attachment",
			"plan": integration_plan,
			"production": production,
			"attachment": attachment,
			"attachment_rollback": injected_rollback.attachment_rollback,
			"production_rollback": injected_rollback.production_rollback,
			"journal_path": journal_path,
		}, monitor)

	var result := {
		"ok": true,
		"status": &"ROOM_INTEGRATED" \
			if action != ArenaProductionAttachmentService.NONE else &"ROOM_PRODUCED",
		"plan": integration_plan,
		"production": production,
		"attachment": attachment,
		"journal_path": journal_path,
		"reloaded_run": attachment.get("reloaded_run"),
		"reloaded_room": attachment.get("reloaded_room"),
		"target_index": int(attachment.get("target_index", -1)),
		"integrated_room_path": attachment.get(
			"integrated_room_path", production.get("arena_path", "")
		),
	}
	if monitor.interruption_requested():
		return _interrupt_before_step(
			monitor, STEP_FINALIZE, integration_plan, production, attachment,
			journal_path
		)
	monitor.begin_step(
		STEP_FINALIZE,
		{"journal_path": journal_path},
		_pipeline_files(
			run_data, destination, integration_plan, production, attachment
		),
		_pipeline_fingerprints(arena, run_data, production, attachment),
		monitor.timeout_for(STEP_FINALIZE)
	)
	var committed_journal_written := _write_journal(
		journal_path, _journal_state(&"COMMITTED", integration_plan, {
			"integrated_room_path": result.integrated_room_path,
			"target_index": result.target_index,
			"preserved_gameplay": attachment.get("preserved_gameplay", false),
			"copy_on_write": attachment.get("copy_on_write", false),
		})
	)
	var finalize: Dictionary = ArenaProductionTransactionService.finalize(
		production.get("transaction", {})
	)
	monitor.update_step_evidence(
		{"journal_written": committed_journal_written},
		[journal_path],
		{"journal_physical_sha256": _file_hash(journal_path)}
	)
	var finalize_ok := committed_journal_written and bool(finalize.get("ok", false))
	var finalize_error := "" if finalize_ok else (
		"journal_write_failed" if not committed_journal_written \
		else str(finalize.get("error", "finalize_failed"))
	)
	checkpoint = monitor.end_step(
		STEP_FINALIZE,
		finalize_ok,
		finalize_error,
		{"journal_written": committed_journal_written, "finalize": finalize}
	)
	if not bool(checkpoint.get("ok", false)):
		result["pipeline_warning"] = {
			"error": checkpoint.get("error", "finalize_failed"),
			"timed_out": checkpoint.get("timed_out", false),
			"interrupted": checkpoint.get("interrupted", false),
			"diagnostic_dump_path": checkpoint.get("diagnostic_dump_path", ""),
		}
	return _pipeline_result(result, monitor)


static func _pipeline_monitor(
		arena: ArenaDefinition,
		run_data: RunData,
		action: StringName,
		requested_index: int,
		destination: String,
		options: Dictionary
	) -> ArenaGuidedPipelineDiagnosticsService:
	var context := {
		"arena_id": str(arena.arena_id) if arena != null else "",
		"run_path": run_data.resource_path if run_data != null else "",
		"run_name": run_data.run_name if run_data != null else "",
		"action": str(action),
		"requested_index": requested_index,
		"destination": destination,
	}
	var provided: Variant = options.get("pipeline_monitor")
	if provided is ArenaGuidedPipelineDiagnosticsService:
		var existing := provided as ArenaGuidedPipelineDiagnosticsService
		existing.set_context(context)
		return existing
	var diagnostics_options: Dictionary = (options.get(
		"pipeline_diagnostics", {}
	) as Dictionary).duplicate(true)
	diagnostics_options["context"] = context
	if options.get("step_timeouts_ms") is Dictionary:
		diagnostics_options["step_timeouts_ms"] = options.get("step_timeouts_ms")
	return ArenaGuidedPipelineDiagnosticsService.new(diagnostics_options)


static func _checkpoint_interrupted(checkpoint: Dictionary) -> bool:
	return bool(checkpoint.get("timed_out", false)) \
		or bool(checkpoint.get("interrupted", false))


static func _checkpoint_result(
		checkpoint: Dictionary,
		monitor: ArenaGuidedPipelineDiagnosticsService,
		integration_plan: Dictionary,
		production: Dictionary,
		attachment: Dictionary,
		fallback_error: String,
		extra: Dictionary = {}
	) -> Dictionary:
	var rollback := {
		"attachment_rollback": {
			"ok": true, "restored": false, "reason": "not_committed",
		},
		"production_rollback": {
			"ok": true, "restored": false, "reason": "not_committed",
		},
	}
	if not production.is_empty() or bool(attachment.get("ok", false)):
		rollback = _rollback_pipeline(
			monitor, integration_plan, production, attachment
		)
	var checkpoint_status := &"STEP_TIMEOUT" if bool(checkpoint.get(
		"timed_out", false
	)) else (
		&"PIPELINE_INTERRUPTED" if bool(checkpoint.get(
			"interrupted", false
		)) else &"STEP_FAILED"
	)
	var journal_path := str(extra.get("journal_path", ""))
	if not journal_path.is_empty():
		_write_journal(
			journal_path,
			_journal_state(checkpoint_status, integration_plan, {
				"error": checkpoint.get("error", fallback_error),
				"attachment_rollback_ok": bool(
					(rollback.attachment_rollback as Dictionary).get("ok", false)
				),
				"production_rollback_ok": bool(
					(rollback.production_rollback as Dictionary).get("ok", false)
				),
			})
		)
	var result := {
		"ok": false,
		"status": checkpoint_status,
		"error": checkpoint.get("error", fallback_error),
		"plan": integration_plan,
		"production": production,
		"attachment": attachment,
		"attachment_rollback": rollback.attachment_rollback,
		"production_rollback": rollback.production_rollback,
		"diagnostic_dump_path": checkpoint.get("diagnostic_dump_path", ""),
	}
	result.merge(extra, true)
	return _pipeline_result(result, monitor)


static func _interrupt_before_step(
		monitor: ArenaGuidedPipelineDiagnosticsService,
		step: StringName,
		integration_plan: Dictionary,
		production: Dictionary,
		attachment: Dictionary,
		journal_path := ""
	) -> Dictionary:
	var interrupted_files := _pipeline_files(
		null, "", integration_plan, production, attachment
	)
	monitor.begin_step(
		step,
		{"journal_path": journal_path},
		interrupted_files,
		{"at_interruption": _physical_fingerprints(interrupted_files)},
		monitor.timeout_for(step)
	)
	var checkpoint := monitor.end_step(
		step, false, monitor.interruption_reason(),
		{"interrupted_before_execution": true}
	)
	return _checkpoint_result(
		checkpoint, monitor, integration_plan, production, attachment,
		"pipeline_interrupted", {"journal_path": journal_path}
	)


static func _rollback_pipeline(
		monitor: ArenaGuidedPipelineDiagnosticsService,
		integration_plan: Dictionary,
		production: Dictionary,
		attachment: Dictionary
	) -> Dictionary:
	var production_plan: Dictionary = integration_plan.get(
		"production", {}
	) as Dictionary
	var rollback_files := _pipeline_files(
		null,
		str(production_plan.get("destination", "")),
		integration_plan,
		production,
		attachment
	)
	monitor.begin_step(
		STEP_ROLLBACK,
		{"source_step_failed": true},
		rollback_files,
		{"before_rollback": _physical_fingerprints(rollback_files)},
		monitor.timeout_for(STEP_ROLLBACK)
	)
	var attachment_rollback := {
		"ok": true, "restored": false, "reason": "attachment_not_committed",
	}
	if bool(attachment.get("ok", false)):
		attachment_rollback = ArenaProductionAttachmentService.rollback_attachment(
			attachment
		)
	var production_rollback := _rollback_production(production)
	monitor.update_step_evidence(
		{}, rollback_files,
		{"after_rollback": _physical_fingerprints(rollback_files)}
	)
	var rollback_ok := bool(attachment_rollback.get("ok", false)) \
		and bool(production_rollback.get("ok", false))
	var checkpoint := monitor.end_step(
		STEP_ROLLBACK,
		rollback_ok,
		"rollback_failed" if not rollback_ok else "",
		{
			"attachment_rollback": attachment_rollback,
			"production_rollback": production_rollback,
		},
		true
	)
	return {
		"ok": rollback_ok and bool(checkpoint.get("ok", false)),
		"attachment_rollback": attachment_rollback,
		"production_rollback": production_rollback,
		"checkpoint": checkpoint,
	}


static func _pipeline_result(
		result: Dictionary,
		monitor: ArenaGuidedPipelineDiagnosticsService
	) -> Dictionary:
	result["pipeline"] = monitor.summary()
	result["pipeline_event_log_path"] = monitor.event_log_path
	if str(result.get("diagnostic_dump_path", "")).is_empty():
		result["diagnostic_dump_path"] = monitor.diagnostic_dump_path
	return result


static func _pipeline_files(
		run_data: RunData,
		destination: String,
		integration_plan: Dictionary = {},
		production: Dictionary = {},
		attachment: Dictionary = {}
	) -> Array:
	var result: Array = []
	if run_data != null:
		_append_unique_path(result, run_data.resource_path)
		for room in run_data.rooms:
			if room != null:
				_append_unique_path(result, room.resource_path)
	if not destination.is_empty():
		_append_unique_path(result, destination.path_join("arena.tres"))
		_append_unique_path(
			result, destination.path_join(ArenaProductionService.MANIFEST_FILE)
		)
	for path in integration_plan.get("affected_files", []):
		_append_unique_path(result, str(path))
	for key in ["arena_path", "directory"]:
		_append_unique_path(result, str(production.get(key, "")))
	for key in ["integrated_room_path", "run_path", "room_recovery_path"]:
		_append_unique_path(result, str(attachment.get(key, "")))
	return result


static func _append_unique_path(result: Array, path: String) -> void:
	if not path.is_empty() and not result.has(path):
		result.append(path)


static func _pipeline_fingerprints(
		arena: ArenaDefinition,
		run_data: RunData,
		production: Dictionary = {},
		attachment: Dictionary = {}
	) -> Dictionary:
	var result := {
		"working_arena": ArenaSnapshotService.arena_fingerprint(arena) \
			if arena != null else "",
		"working_gameplay": ArenaSnapshotService.gameplay_fingerprint(arena) \
			if arena != null else "",
	}
	var fingerprint_run := attachment.get("reloaded_run") as RunData
	if fingerprint_run == null:
		fingerprint_run = run_data
	if fingerprint_run != null and not fingerprint_run.resource_path.is_empty():
		result["run_physical_sha256"] = _file_hash(fingerprint_run.resource_path)
		var room_hashes := {}
		for room_index in range(fingerprint_run.rooms.size()):
			var room := fingerprint_run.rooms[room_index]
			if room != null:
				room_hashes[str(room_index)] = {
					"path": room.resource_path,
					"physical_sha256": _file_hash(room.resource_path),
				}
		result["run_room_files"] = room_hashes
	var manifest: Dictionary = production.get("manifest", {}) as Dictionary
	result["produced_arena"] = manifest.get(
		"logical_arena_fingerprint", manifest.get("produced_fingerprint", "")
	)
	result["produced_gameplay"] = manifest.get(
		"gameplay_fingerprint", manifest.get("produced_gameplay_fingerprint", "")
	)
	var integrated_room := attachment.get("reloaded_room") as ArenaDefinition
	if integrated_room != null:
		result["integrated_arena"] = ArenaSnapshotService.arena_fingerprint(
			integrated_room
		)
		result["integrated_gameplay"] = ArenaSnapshotService.gameplay_fingerprint(
			integrated_room
		)
	return result


static func _file_hash(path: String) -> String:
	return FileAccess.get_sha256(path) if not path.is_empty() \
		and FileAccess.file_exists(path) else ""


static func _physical_fingerprints(paths: Array) -> Dictionary:
	var result := {}
	for value in paths:
		var path := str(value)
		if not path.is_empty():
			result[path] = _file_hash(path)
	return result


static func _transaction_context(production: Dictionary) -> Dictionary:
	var transaction: Dictionary = production.get("transaction", {}) as Dictionary
	return {
		"transaction_id": transaction.get("transaction_id", ""),
		"transaction_directory": transaction.get("transaction_directory", ""),
		"destination": transaction.get("destination", ""),
		"staging": transaction.get("staging", ""),
		"backup": transaction.get("backup", ""),
		"committed": transaction.get("committed", false),
	}


static func _rollback_production(production: Dictionary) -> Dictionary:
	var transaction = production.get("transaction", {})
	if transaction is Dictionary and bool(transaction.get("committed", false)):
		return ArenaProductionTransactionService.rollback_committed(transaction)
	return {"ok": true, "restored": false, "reason": "no_new_production_commit"}


static func action_label(action: StringName) -> String:
	match action:
		ArenaProductionAttachmentService.NONE:
			return "Produire sans intégrer"
		ArenaProductionAttachmentService.APPEND:
			return "Créer une nouvelle salle"
		ArenaProductionAttachmentService.INSERT_BEFORE:
			return "Insérer la salle avant"
		ArenaProductionAttachmentService.INSERT_AFTER:
			return "Insérer la salle après"
		ArenaProductionAttachmentService.UPDATE:
			return "Mettre à jour l’arène de cette salle — recommandé"
		ArenaProductionAttachmentService.REPLACE:
			return "Remplacer toute la salle — avancé"
	return "Action inconnue"


static func run_short_label(run_data: RunData) -> String:
	if run_data == null:
		return "Aucune partie"
	if run_data.resource_path.ends_with("/first_run.tres"):
		return "Principale"
	if run_data.resource_path.ends_with("/fixed_trio_prototype_run.tres"):
		return "Test"
	return run_data.run_name


static func _simulated_run_errors(
		arena: ArenaDefinition,
		run_data: RunData,
		action: StringName,
		target_index: int
	) -> PackedStringArray:
	if action == ArenaProductionAttachmentService.NONE:
		return PackedStringArray()
	if arena == null or run_data == null:
		return PackedStringArray(["La destination ne contient pas de partie valide."])
	var simulated := run_data.duplicate(false) as RunData
	simulated.set_path_cache("")
	var rooms: Array[RoomData] = []
	rooms.assign(run_data.rooms)
	if action == ArenaProductionAttachmentService.UPDATE:
		if target_index < 0 or target_index >= rooms.size():
			return PackedStringArray(["L'index UPDATE est hors limites."])
		var merged := RoomIntegrationFieldPolicy.merge_arena_into_room(
			arena, rooms[target_index]
		)
		if merged == null:
			return PackedStringArray(["La politique de champs refuse la fusion « Mettre à jour »."])
		rooms[target_index] = merged
	elif action == ArenaProductionAttachmentService.REPLACE:
		if target_index < 0 or target_index >= rooms.size():
			return PackedStringArray(["L'index REPLACE est hors limites."])
		rooms[target_index] = arena
	else:
		rooms.insert(clampi(target_index, 0, rooms.size()), arena)
	simulated.rooms = rooms
	return simulated.validation_errors()


static func _new_journal_path(arena: ArenaDefinition, run_data: RunData) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(JOURNAL_ROOT))
	var arena_id := str(arena.arena_id) if arena != null else "arena"
	var run_id := ArenaDefinition.sanitize_id(run_data.run_name) if run_data != null else "sans_run"
	return JOURNAL_ROOT.path_join("%s_%s_%d.json" % [
		arena_id, run_id, Time.get_ticks_usec(),
	])


static func _journal_state(
		state: StringName,
		integration_plan: Dictionary,
		extra := {}
	) -> Dictionary:
	var value := {
		"state": str(state),
		"action": str(integration_plan.get("action", &"")),
		"run_path": integration_plan.get("run_path", ""),
		"target_room_path": integration_plan.get("target_room_path", ""),
		"new_arena_path": integration_plan.get("new_arena_path", ""),
		"target_index": integration_plan.get("target_index", -1),
		"before_count": integration_plan.get("before_count", 0),
		"after_count": integration_plan.get("after_count", 0),
		"affected_files": Array(integration_plan.get("affected_files", PackedStringArray())),
	}
	value.merge(extra, true)
	return value


static func _write_journal(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "  "))
	file.close()
	return true
