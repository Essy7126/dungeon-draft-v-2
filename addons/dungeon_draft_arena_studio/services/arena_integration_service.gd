@tool
class_name ArenaIntegrationService
extends RefCounted

## Orchestrateur du parcours Produire → intégrer → recharger → sélectionner.
## Le bundle produit est une phase préparée ; la mutation canonique est déléguée
## à ArenaProductionAttachmentService, qui possède recovery et rollback.

const JOURNAL_ROOT := "user://dungeon_draft_studio/room_integration/journals"


static func plan(
		arena: ArenaDefinition,
		run_data: RunData,
		action: StringName,
		requested_index: int,
		destination := "",
		graph: StudioReferenceGraphService = null
	) -> Dictionary:
	var production := ArenaProductionService.plan(arena, destination)
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
	var can_integrate := bool(production.get("can_produce", false)) \
		and bool(attachment.get("ok", false)) \
		and bool(field_coverage.get("ok", false)) \
		and bool(target_coverage.get("ok", false)) \
		and run_errors.is_empty()
	return {
		"ok": true,
		"can_integrate": can_integrate,
		"production": production,
		"attachment": attachment,
		"field_coverage": field_coverage,
		"target_coverage": target_coverage,
		"run_validation_errors": run_errors,
		"action": action,
		"action_label": action_label(action),
		"run_path": run_data.resource_path if run_data != null else "",
		"run_name": run_data.run_name if run_data != null else "Aucune run",
		"target_room_path": target_room.resource_path if target_room != null else "",
		"target_room_name": target_room.room_name if target_room != null else "",
		"target_index": int(attachment.get("target_index", -1)),
		"before_count": int(attachment.get("before_count", 0)),
		"after_count": int(attachment.get("after_count", 0)),
		"new_arena_path": str(attachment.get("integrated_room_path", produced_path)),
		"shared": bool(attachment.get("shared", false)),
		"scope": "Copie unique à cette run" if bool(attachment.get("copy_on_write", false)) \
			else "Unique à cette run",
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
	var integration_plan := plan(
		arena, run_data, action, requested_index, destination, graph
	)
	if not integration_plan.get("ok", false) \
			or not integration_plan.get("can_integrate", false):
		return {
			"ok": false,
			"status": &"PLAN_REFUSED",
			"error": integration_plan.get("error", "Le plan d'intégration est bloqué."),
			"plan": integration_plan,
		}
	var journal_path := _new_journal_path(arena, run_data)
	_write_journal(journal_path, _journal_state(&"PLANNED", integration_plan))
	var production := ArenaProductionService.produce_with_options(
		arena, destination, provided_images, options.get("production_options", {})
	)
	if not production.get("ok", false):
		_write_journal(journal_path, _journal_state(&"PRODUCTION_FAILED", integration_plan, {
			"error": production.get("error", "production_failed"),
		}))
		return {
			"ok": false,
			"status": &"PRODUCTION_FAILED",
			"error": production.get("error", "La production a échoué."),
			"plan": integration_plan,
			"production": production,
			"journal_path": journal_path,
		}
	_write_journal(journal_path, _journal_state(&"PRODUCED", integration_plan, {
		"arena_path": production.get("arena_path", ""),
	}))
	var attachment := {"ok": false, "error": "injected_before_attachment"}
	if str(options.get("failure_step", "")) != "before_attachment":
		attachment = ArenaProductionAttachmentService.attach_and_save(
			str(production.get("arena_path", "")), run_data, action,
			requested_index, graph
		)
	if not attachment.get("ok", false):
		var production_rollback := _rollback_production(production)
		_write_journal(journal_path, _journal_state(&"INTEGRATION_FAILED", integration_plan, {
			"error": attachment.get("error", "integration_failed"),
			"produced_arena_path": production.get("arena_path", ""),
		}))
		return {
			"ok": false,
			"status": &"INTEGRATION_ROLLED_BACK",
			"error": attachment.get("error", "L'intégration a échoué."),
			"plan": integration_plan,
			"production": production,
			"attachment": attachment,
			"production_rollback": production_rollback,
			"journal_path": journal_path,
		}
	if str(options.get("failure_step", "")) == "after_attachment":
		var attachment_rollback := ArenaProductionAttachmentService.rollback_attachment(
			attachment
		)
		var production_rollback := _rollback_production(production)
		return {
			"ok": false,
			"status": &"INTEGRATION_ROLLED_BACK",
			"error": "injected_after_attachment",
			"plan": integration_plan,
			"production": production,
			"attachment": attachment,
			"attachment_rollback": attachment_rollback,
			"production_rollback": production_rollback,
			"journal_path": journal_path,
		}
	var result := {
		"ok": true,
		"status": &"ROOM_INTEGRATED" if action != ArenaProductionAttachmentService.NONE \
			else &"ROOM_PRODUCED",
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
	_write_journal(journal_path, _journal_state(&"COMMITTED", integration_plan, {
		"integrated_room_path": result.integrated_room_path,
		"target_index": result.target_index,
		"preserved_gameplay": attachment.get("preserved_gameplay", false),
		"copy_on_write": attachment.get("copy_on_write", false),
	}))
	ArenaProductionTransactionService.finalize(production.get("transaction", {}))
	return result


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
		return "Aucune run"
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
		return PackedStringArray(["La destination ne contient pas de run valide."])
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
			return PackedStringArray(["La politique de champs refuse la fusion UPDATE."])
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
