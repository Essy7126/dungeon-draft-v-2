@tool
class_name ArenaGuidedSandboxService
extends RefCounted

## Exercice intégralement isolé sous user://. Aucune ressource officielle n'est
## sauvegardée, remplacée ou utilisée comme destination de transaction.

const ROOT := "user://dungeon_draft_studio/tests/guided_sandbox"


static func recipe() -> Array[Dictionary]:
	return [
		{"step": 1, "id": &"CREATE", "label": "Créer une petite arène"},
		{"step": 2, "id": &"TERRAINS", "label": "Ajouter des terrains"},
		{"step": 3, "id": &"WALLS_SPAWNS", "label": "Placer murs et spawns"},
		{"step": 4, "id": &"VALIDATE", "label": "Valider"},
		{"step": 5, "id": &"EXPORT_ART", "label": "Exporter un kit artistique"},
		{"step": 6, "id": &"IMPORT_FIXTURE", "label": "Importer un décor fixture"},
		{"step": 7, "id": &"INCOMPLETE", "label": "Simuler un dossier de production incomplet"},
		{"step": 8, "id": &"ARCHIVE_REBUILD", "label": "Archiver et reconstruire"},
		{"step": 9, "id": &"INTEGRATE", "label": "Intégrer dans la partie d'essai"},
		{"step": 10, "id": &"ROLLBACK", "label": "Annuler l’intégration"},
	]


static func create_fixture() -> Dictionary:
	var session_root := ROOT.path_join("exercise_%d" % Time.get_ticks_usec())
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(session_root)) != OK:
		return {"ok": false, "error": "sandbox_directory_failed"}
	var arena := _small_arena()
	var source_run := _fixture_source_run()
	if source_run == null or source_run.rooms.is_empty() or source_run.rooms[0] == null:
		return {"ok": false, "error": "fixture_gameplay_source_missing"}
	var merged := RoomIntegrationFieldPolicy.merge_arena_into_room(arena, source_run.rooms[0])
	if merged == null:
		return {"ok": false, "error": "fixture_room_merge_failed"}
	merged.set_path_cache("")
	var room_path := session_root.path_join("room_fixture.tres")
	if ResourceSaver.save(merged, room_path) != OK:
		return {"ok": false, "error": "fixture_room_save_failed"}
	var reloaded_room := ResourceLoader.load(
		room_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RoomData
	if reloaded_room == null:
		return {"ok": false, "error": "fixture_room_reload_failed"}
	var run := RunData.new()
	run.run_name = "Sandbox Arena Studio"
	run.default_seed = 20200
	run.content_profile = source_run.content_profile
	run.room_flow_mode = source_run.room_flow_mode
	run.maximum_waves_per_room = source_run.maximum_waves_per_room
	run.rooms = [reloaded_room]
	var run_path := session_root.path_join("run_fixture.tres")
	if ResourceSaver.save(run, run_path) != OK:
		return {"ok": false, "error": "fixture_run_save_failed"}
	var context := {
		"ok": true,
		"sandbox": true,
		"root": session_root,
		"working_arena_path": room_path,
		"run_path": run_path,
		"art_kit_path": session_root.path_join("art_kit"),
		"bundle_path": session_root.path_join("bundle_incomplete"),
		"recipe": recipe(),
		"fingerprint": ArenaSnapshotService.arena_fingerprint(merged),
	}
	ArenaProductionService._write_json(session_root.path_join("exercise.json"), context)
	context["arena"] = reloaded_room as ArenaDefinition
	context["run"] = ResourceLoader.load(
		run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	return context


static func export_art_kit(context: Dictionary) -> Dictionary:
	var arena := _arena_from_context(context)
	if arena == null:
		return {"ok": false, "error": "sandbox_arena_missing"}
	return ArenaArtKitExporter.export_kit(
		arena, str(context.get("art_kit_path", "")), ArenaValidator.validate(arena, false)
	)


static func simulate_incomplete_bundle(context: Dictionary) -> Dictionary:
	var arena := _arena_from_context(context)
	var destination := str(context.get("bundle_path", ""))
	if arena == null or not destination.begins_with(ROOT + "/"):
		return {"ok": false, "error": "sandbox_scope_refused"}
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination)) != OK:
		return {"ok": false, "error": "sandbox_bundle_directory_failed"}
	if arena.modular_visual_profile != null and ResourceSaver.save(
		arena.modular_visual_profile, destination.path_join("modular_visual_profile.tres")
	) != OK:
		return {"ok": false, "error": "sandbox_profile_save_failed"}
	if ResourceSaver.save(arena, destination.path_join("arena.tres")) != OK:
		return {"ok": false, "error": "sandbox_arena_save_failed"}
	var inspection := ArenaBundleInspectionService.inspect(destination)
	return {
		"ok": inspection.get("state", &"") == ArenaBundleInspectionService.OWNED_INCOMPLETE,
		"inspection": inspection,
		"destination": destination,
	}


static func archive_and_rebuild(context: Dictionary) -> Dictionary:
	var arena := _arena_from_context(context)
	var destination := str(context.get("bundle_path", ""))
	if arena == null or not destination.begins_with(ROOT + "/"):
		return {"ok": false, "error": "sandbox_scope_refused"}
	var archived := ArenaBundleOwnershipService.archive_unreferenced_incomplete(
		destination, "guided_sandbox"
	)
	if not archived.get("ok", false):
		return archived
	var rebuilt := ArenaProductionTransactionService.produce(arena, destination)
	return {
		"ok": rebuilt.get("ok", false),
		"archive": archived,
		"production": rebuilt,
		"complete": ArenaBundleInspectionService.inspect(destination).get("complete", false),
	}


static func integrate_and_rollback(context: Dictionary) -> Dictionary:
	var arena := _arena_from_context(context)
	var run := context.get("run") as RunData
	if run == null:
		run = ResourceLoader.load(
			str(context.get("run_path", "")), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as RunData
	var destination := str(context.get("root", "")).path_join("integrated_bundle")
	if arena == null or run == null or not destination.begins_with(ROOT + "/"):
		return {"ok": false, "error": "sandbox_scope_refused"}
	var before := ArenaSnapshotService.gameplay_fingerprint(run.rooms[0])
	var integration := ArenaIntegrationService.integrate(
		arena, run, ArenaProductionAttachmentService.UPDATE, 0, destination
	)
	if not integration.get("ok", false):
		return integration
	var attachment_rollback := ArenaProductionAttachmentService.rollback_attachment(
		integration.get("attachment", {})
	)
	var production_rollback := ArenaProductionTransactionService.rollback_committed(
		(integration.get("production", {}) as Dictionary).get("transaction", {})
	)
	var restored_run := ResourceLoader.load(
		str(context.get("run_path", "")), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	var after := ArenaSnapshotService.gameplay_fingerprint(restored_run.rooms[0]) \
		if restored_run != null and not restored_run.rooms.is_empty() else ""
	return {
		"ok": attachment_rollback.get("ok", false) \
			and production_rollback.get("ok", false) and before == after,
		"integration": integration,
		"attachment_rollback": attachment_rollback,
		"production_rollback": production_rollback,
		"gameplay_before": before,
		"gameplay_after": after,
	}


static func _arena_from_context(context: Dictionary) -> ArenaDefinition:
	var arena := context.get("arena") as ArenaDefinition
	if arena != null:
		return arena
	return ResourceLoader.load(
		str(context.get("working_arena_path", "")), "",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition


static func _fixture_source_run() -> RunData:
	for run in RunContentCatalogService.discover_runs():
		if run != null and not run.rooms.is_empty() and run.rooms[0] != null:
			return run
	return null


static func _small_arena() -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Exercice Arena Studio", "guided_sandbox_arena")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.modular_visual_profile.theme_id = arena.theme_id
	arena.source_image_size = Vector2i(640, 360)
	arena.grid_size = Vector2i(6, 5)
	arena.grid_origin = Vector2(320, 72)
	arena.axis_x = Vector2(40, 20)
	arena.axis_y = Vector2(-40, 20)
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			var terrain := &"water" if Vector2i(x, y) in [Vector2i(2, 2), Vector2i(3, 2)] else &"stone"
			ArenaTerrainRegistry.configure_cell(arena.ensure_cell(Vector2i(x, y)), terrain)
	ArenaEditingService.prepare_automatically(arena)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena
