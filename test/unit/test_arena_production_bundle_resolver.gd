extends GutTest

const ROOT := "user://dungeon_draft_studio/tests/production_bundle_resolver"

var _created_archives := PackedStringArray()


func before_each() -> void:
	ArenaProductionTransactionService._remove_tree(ROOT)
	_created_archives.clear()


func after_each() -> void:
	ArenaProductionTransactionService._remove_tree(ROOT)
	for archive in _created_archives:
		ArenaProductionTransactionService._remove_tree(archive)


func test_exact_two_file_fixture_is_explained_and_resume_is_recommended() -> void:
	var arena := _arena("exact_fixture")
	var destination := ROOT.path_join("exact_fixture")
	_save_incomplete(arena, destination)
	var production := ArenaProductionService.plan(arena, destination)
	var resolution := production.bundle_resolution as Dictionary
	assert_eq(production.bundle_state, ArenaBundleInspectionService.OWNED_INCOMPLETE)
	assert_eq((production.conflicts as Array).size(), 2)
	assert_true(resolution.required, str(resolution))
	assert_eq(resolution.state_label, "Production interrompue sans manifeste")
	assert_true(str(resolution.explanation).contains("aucun production_manifest.json"))
	assert_eq((resolution.files as Array).size(), 2)
	assert_true((resolution.files as Array).any(func(value):
		return (value as Dictionary).path == "arena.tres"
	))
	assert_true((resolution.files as Array).any(func(value):
		return (value as Dictionary).path == "modular_visual_profile.tres"
	))
	assert_eq(
		resolution.recommended_action,
		ArenaBundleResolutionService.RESUME_INTERRUPTED
	)
	assert_true(_action(resolution, ArenaBundleResolutionService.RESUME_INTERRUPTED).enabled)
	assert_true((resolution.references.canonical_references as Array).is_empty())


func test_reference_report_blocks_archive_resume_and_removal_with_run_index() -> void:
	var arena := _arena("referenced")
	var destination := ROOT.path_join("referenced")
	_save_incomplete(arena, destination)
	var graph := StudioReferenceGraphService.new()
	graph.incoming[destination.path_join("arena.tres")] = [{
		"from": "res://data/runs/reference_fixture.tres",
		"to": destination.path_join("arena.tres"),
		"relation": &"ROOM_AT",
		"metadata": {"index": 3},
	}]
	var resolution := ArenaBundleResolutionService.plan(arena, destination, {}, graph)
	assert_eq(resolution.state, ArenaBundleInspectionService.REFERENCED_INCOMPLETE)
	assert_eq(resolution.references.canonical_count, 1)
	assert_eq(resolution.references.run_references[0].room_index, 3)
	assert_eq(resolution.references.run_references[0].room_number, 4)
	assert_false(_action(resolution, ArenaBundleResolutionService.RESUME_INTERRUPTED).enabled)
	assert_false(_action(resolution, ArenaBundleResolutionService.ARCHIVE_AND_REBUILD).enabled)
	assert_false(_action(resolution, ArenaBundleResolutionService.REMOVE_FROM_PROJECT).enabled)
	assert_true(_action(resolution, ArenaBundleResolutionService.VERSION_ALONGSIDE).enabled)
	assert_eq(resolution.recommended_action, ArenaBundleResolutionService.VERSION_ALONGSIDE)


func test_explicit_resume_creates_verified_manifest_and_unblocks_production() -> void:
	var arena := _arena("resume")
	var destination := ROOT.path_join("resume")
	_save_incomplete(arena, destination)
	var before := ArenaBundleInspectionService._files(destination)
	var resumed := ArenaBundleResolutionService.execute(
		ArenaBundleResolutionService.RESUME_INTERRUPTED,
		arena, destination, null, "GUT explicit resume"
	)
	assert_true(resumed.ok, str(resumed))
	assert_true(FileAccess.file_exists(destination.path_join("production_manifest.json")))
	assert_true(FileAccess.file_exists(str(resumed.recovery).path_join("arena_before.tres")))
	assert_true(FileAccess.file_exists(str(resumed.recovery).path_join("resume_receipt.json")))
	var inspection := ArenaBundleInspectionService.inspect(destination)
	assert_eq(inspection.state, ArenaBundleInspectionService.OWNED_COMPLETE, str(inspection))
	assert_eq(
		str(inspection.manifest.generated_by), ArenaProductionService.GENERATED_BY
	)
	for relative_path in before:
		assert_true(inspection.files.has(relative_path), relative_path)
	var production := ArenaProductionService.plan(arena, destination)
	assert_true((production.conflicts as Array).is_empty(), str(production.conflicts))
	assert_true(production.can_produce, str(production.gate_report))
	var reused := ArenaProductionService.produce(arena, destination)
	assert_true(reused.ok, str(reused))
	assert_true(reused.idempotent_reuse)
	ArenaProductionTransactionService._remove_tree(str(resumed.recovery))


func test_failed_resume_restores_original_bytes_and_removes_new_manifest() -> void:
	var arena := _arena("resume_rollback")
	# The production verifier deliberately rejects any lingering staging marker.
	# The working copy remains otherwise valid, so failure happens after backup,
	# normalization and manifest staging.
	arena.display_name = "Resolver .staging rollback"
	var destination := ROOT.path_join("resume_rollback")
	_save_incomplete(arena, destination)
	var before := ArenaBundleInspectionService._files(destination)
	var resumed := ArenaBundleResolutionService.execute(
		ArenaBundleResolutionService.RESUME_INTERRUPTED,
		arena, destination, null, "GUT verified rollback"
	)
	assert_false(resumed.ok, str(resumed))
	assert_eq(resumed.error, "resume_verification_failed")
	assert_true(resumed.rollback_ok, str(resumed))
	assert_false(FileAccess.file_exists(destination.path_join("production_manifest.json")))
	assert_eq(ArenaBundleInspectionService._files(destination), before)
	ArenaProductionTransactionService._remove_tree(str(resumed.recovery))


func test_archive_then_rebuild_is_recoverable_and_hash_verified() -> void:
	var existing := _arena("old")
	var candidate := _arena("new")
	var destination := ROOT.path_join("archive_rebuild")
	_save_incomplete(existing, destination)
	var before := ArenaBundleInspectionService._files(destination)
	var resolution := ArenaBundleResolutionService.plan(candidate, destination)
	assert_eq(resolution.recommended_action, ArenaBundleResolutionService.ARCHIVE_AND_REBUILD)
	var archived := ArenaBundleResolutionService.execute(
		ArenaBundleResolutionService.ARCHIVE_AND_REBUILD,
		candidate, destination, null, "GUT archive then rebuild"
	)
	assert_true(archived.ok, str(archived))
	_created_archives.append(str(archived.archive))
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(destination)))
	assert_eq(archived.receipt.files, before)
	assert_true(FileAccess.file_exists(str(archived.archive).path_join("archive_receipt.json")))
	var rebuilt := ArenaProductionService.produce(candidate, destination)
	assert_true(rebuilt.ok, str(rebuilt))
	assert_eq(
		ArenaBundleInspectionService.inspect(destination).state,
		ArenaBundleInspectionService.OWNED_COMPLETE
	)


func test_version_alongside_never_changes_existing_bundle_or_arena_id() -> void:
	var arena := _arena("versioned")
	var destination := ROOT.path_join("versioned")
	_save_incomplete(arena, destination)
	var before := ArenaBundleInspectionService._files(destination)
	var version := ArenaBundleResolutionService.execute(
		ArenaBundleResolutionService.VERSION_ALONGSIDE,
		arena, destination
	)
	assert_true(version.ok, str(version))
	assert_eq(version.destination, destination + "_v2")
	assert_true(version.arena_id_unchanged)
	assert_true(version.existing_bundle_unchanged)
	assert_eq(ArenaBundleInspectionService._files(destination), before)
	assert_true(ArenaProductionService.produce(arena, version.destination).ok)
	assert_eq(ArenaBundleInspectionService._files(destination), before)
	var produced := ResourceLoader.load(
		str(version.destination).path_join("arena.tres"), "",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	assert_not_null(produced)
	assert_eq(produced.arena_id, arena.arena_id)
	var next := ArenaBundleVersioningService.next_destination(destination + "_v2")
	assert_true(next.ok, str(next))
	assert_eq(next.destination, destination + "_v3")


func test_unrecognized_generated_by_is_explained_without_claiming_ownership() -> void:
	var arena := _arena("foreign_generator")
	var destination := ROOT.path_join("foreign_generator")
	_save_incomplete(arena, destination)
	ArenaProductionService._write_json(
		destination.path_join("production_manifest.json"), {
			"generated_by": "unknown_external_generator",
			"files": {},
		}
	)
	var resolution := ArenaBundleResolutionService.plan(arena, destination)
	assert_eq(resolution.state, ArenaBundleInspectionService.FOREIGN_CONTENT)
	assert_true(str(resolution.explanation).contains(
		"generated_by='unknown_external_generator'"
	))
	assert_false(_action(resolution, ArenaBundleResolutionService.RESUME_INTERRUPTED).enabled)
	assert_true(_action(resolution, ArenaBundleResolutionService.ARCHIVE_AND_REBUILD).enabled)


func test_remove_from_project_is_an_explicit_recoverable_archive() -> void:
	var arena := _arena("remove")
	var destination := ROOT.path_join("remove")
	_save_incomplete(arena, destination)
	var before := ArenaBundleInspectionService._files(destination)
	var removed := ArenaBundleResolutionService.execute(
		ArenaBundleResolutionService.REMOVE_FROM_PROJECT,
		arena, destination, null, "GUT explicit removal"
	)
	assert_true(removed.ok, str(removed))
	_created_archives.append(str(removed.archive))
	assert_true(removed.source_removed_from_project)
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(destination)))
	var restored := ArenaBundleOwnershipService.restore_archive(
		str(removed.archive), destination
	)
	assert_true(restored.ok, str(restored))
	assert_eq(ArenaBundleInspectionService._files(destination), before)


func test_active_transaction_prevents_moving_the_destination() -> void:
	var arena := _arena("busy")
	var destination := ROOT.path_join("busy")
	_save_incomplete(arena, destination)
	var transaction_directory := ArenaProductionTransactionService.TRANSACTION_ROOT.path_join(
		"resolver_busy_%d" % Time.get_ticks_usec()
	)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(transaction_directory))
	ArenaProductionService._write_json(
		transaction_directory.path_join("transaction_report.json"), {
			"transaction_id": transaction_directory.get_file(),
			"status": "PLANNED",
			"destination": destination,
		}
	)
	ArenaBundleReferenceService.invalidate_transaction_cache()
	var resolution := ArenaBundleResolutionService.plan(arena, destination)
	assert_true(resolution.references.busy, str(resolution.references))
	assert_false(_action(resolution, ArenaBundleResolutionService.ARCHIVE_AND_REBUILD).enabled)
	assert_false(_action(resolution, ArenaBundleResolutionService.REMOVE_FROM_PROJECT).enabled)
	assert_eq(resolution.recommended_action, ArenaBundleResolutionService.VERSION_ALONGSIDE)
	ArenaProductionTransactionService._remove_tree(transaction_directory)


func _action(resolution: Dictionary, id: StringName) -> Dictionary:
	for value in resolution.actions:
		var action := value as Dictionary
		if StringName(action.id) == id:
			return action
	return {}


func _arena(suffix: String) -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	linearize_arena(arena, suffix)
	return arena


func linearize_arena(arena: ArenaDefinition, suffix: String) -> void:
	arena.set_identity("Resolver %s" % suffix, "resolver_%s" % suffix)
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.modular_visual_profile.theme_id = arena.theme_id
	arena.grid_size = Vector2i(8, 6)
	arena.grid_origin = Vector2.ZERO
	arena.axis_x = Vector2(32, 16)
	arena.axis_y = Vector2(-32, 16)
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			ArenaTerrainRegistry.configure_cell(
				arena.ensure_cell(Vector2i(x, y)), &"stone"
			)
	ArenaEditingService.prepare_automatically(arena)
	ArenaRuntimeBridge.sync_runtime_resources(arena)


func _save_incomplete(arena: ArenaDefinition, destination: String) -> void:
	assert_eq(
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination)), OK
	)
	assert_eq(ResourceSaver.save(
		arena.modular_visual_profile,
		destination.path_join("modular_visual_profile.tres")
	), OK)
	assert_eq(ResourceSaver.save(arena, destination.path_join("arena.tres")), OK)
