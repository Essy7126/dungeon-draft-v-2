extends GutTest

const ROOT := "user://dungeon_draft_studio/tests/arena_atomic_production_v2"


func before_each() -> void:
	ArenaProductionTransactionService._remove_tree(ROOT)


func after_each() -> void:
	ArenaProductionTransactionService._remove_tree(ROOT)


func test_runtime_bundle_is_minimal_reloadable_relative_and_idempotent() -> void:
	var arena := _arena("minimal")
	var destination := ROOT.path_join("minimal")
	var result := ArenaProductionService.produce(arena, destination)
	assert_true(result.ok, str(result))
	assert_eq(str(result.status), "SALLE_PRETE")
	var files := ArenaBundleInspectionService._files(destination)
	assert_true(files.has("arena.tres"))
	assert_true(files.has("modular_visual_profile.tres"))
	assert_true(files.has("production_manifest.json"))
	assert_eq(files.size(), 3, str(files.keys()))
	assert_false(files.has("thumbnail.png"))
	assert_false(files.has("test_configuration.json"))
	assert_false(files.has("art_kit/arena_art_manifest.json"))
	var arena_text := FileAccess.get_file_as_string(destination.path_join("arena.tres"))
	assert_false(".staging" in arena_text)
	assert_true("modular_visual_profile.tres" in arena_text)
	var inspection := ArenaBundleInspectionService.inspect(destination)
	assert_eq(inspection.state, ArenaBundleInspectionService.OWNED_COMPLETE)
	assert_true(inspection.complete)
	var second := ArenaProductionService.produce(arena, destination)
	assert_true(second.ok, str(second))
	assert_true(second.idempotent_reuse)
	assert_eq(second.manifest.files, result.manifest.files)


func test_every_precommit_failure_leaves_no_final_file() -> void:
	var arena := _arena("precommit")
	for step in [
		"after_profile", "after_arena", "after_art", "after_preview",
		"before_manifest", "before_commit",
	]:
		var destination := ROOT.path_join(step)
		var result := ArenaProductionService.produce_with_options(
			arena, destination, {}, {"failure_step": step}
		)
		assert_false(result.ok, step)
		assert_eq(str(result.get("failure_step", "")), step, str(result))
		assert_false(
			DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(destination)),
			step
		)
		assert_true(ArenaBundleInspectionService._files(destination).is_empty(), step)


func test_postcommit_failure_rolls_back_a_new_destination_to_empty() -> void:
	var destination := ROOT.path_join("after_commit_empty")
	var result := ArenaProductionService.produce_with_options(
		_arena("after_commit_empty"), destination, {}, {"failure_step": "after_commit"}
	)
	assert_false(result.ok, str(result))
	assert_true(result.rollback.ok, str(result.rollback))
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(destination)))


func test_postcommit_failure_restores_existing_bundle_byte_for_byte() -> void:
	var destination := ROOT.path_join("after_commit_existing")
	var source := _arena("rollback_existing")
	var baseline := ArenaProductionService.produce(source, destination)
	assert_true(baseline.ok, str(baseline))
	var hashes_before := ArenaBundleInspectionService._files(destination)
	source.camera_zoom = 1.25
	var failed := ArenaProductionService.produce_with_options(
		source, destination, {}, {"failure_step": "after_commit"}
	)
	assert_false(failed.ok, str(failed))
	assert_true(failed.rollback.ok, str(failed.rollback))
	assert_eq(ArenaBundleInspectionService._files(destination), hashes_before)
	var restored := ResourceLoader.load(
		destination.path_join("arena.tres"), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	assert_not_null(restored)
	assert_eq(restored.display_name, "Atomic rollback_existing")


func test_bundle_inspection_classifies_required_states() -> void:
	assert_eq(
		ArenaBundleInspectionService.inspect(ROOT.path_join("empty")).state,
		ArenaBundleInspectionService.EMPTY
	)
	var incomplete := ROOT.path_join("incomplete")
	_save_incomplete(_arena("incomplete"), incomplete)
	assert_eq(
		ArenaBundleInspectionService.inspect(incomplete).state,
		ArenaBundleInspectionService.OWNED_INCOMPLETE
	)
	var graph := StudioReferenceGraphService.new()
	graph.incoming[incomplete.path_join("arena.tres")] = [{
		"from": "res://data/runs/test_fixture.tres",
		"to": incomplete.path_join("arena.tres"),
		"relation": &"ROOM_AT",
		"metadata": {"index": 2},
	}]
	assert_eq(
		ArenaBundleInspectionService.inspect(incomplete, graph).state,
		ArenaBundleInspectionService.REFERENCED_INCOMPLETE
	)
	var complete := ROOT.path_join("complete")
	assert_true(ArenaProductionService.produce(_arena("complete"), complete).ok)
	assert_eq(
		ArenaBundleInspectionService.inspect(complete).state,
		ArenaBundleInspectionService.OWNED_COMPLETE
	)
	graph.incoming[complete.path_join("arena.tres")] = [{
		"from": "res://data/runs/main_fixture.tres",
		"to": complete.path_join("arena.tres"),
		"relation": &"ROOM_AT",
		"metadata": {"index": 1},
	}]
	assert_eq(
		ArenaBundleInspectionService.inspect(complete, graph).state,
		ArenaBundleInspectionService.REFERENCED_COMPLETE
	)
	_write_text(complete.path_join("foreign_note.txt"), "manual")
	assert_eq(
		ArenaBundleInspectionService.inspect(complete).state,
		ArenaBundleInspectionService.OWNED_DIRTY
	)
	var foreign := ROOT.path_join("foreign")
	_make_directory(foreign)
	_write_text(foreign.path_join("manual.txt"), "do not overwrite")
	assert_eq(
		ArenaBundleInspectionService.inspect(foreign).state,
		ArenaBundleInspectionService.FOREIGN_CONTENT
	)
	var corrupt := ROOT.path_join("corrupt")
	_make_directory(corrupt)
	_write_text(corrupt.path_join("production_manifest.json"), "not json")
	assert_eq(
		ArenaBundleInspectionService.inspect(corrupt).state,
		ArenaBundleInspectionService.CORRUPT_MANIFEST
	)
	var legacy := ROOT.path_join("legacy")
	_make_directory(legacy)
	assert_eq(ResourceSaver.save(_arena("legacy"), legacy.path_join("arena_principal.tres")), OK)
	assert_eq(
		ArenaBundleInspectionService.inspect(legacy).state,
		ArenaBundleInspectionService.LEGACY_BUNDLE
	)


func test_archive_and_restore_operates_only_on_unreferenced_incomplete_fixture() -> void:
	var destination := ROOT.path_join("archive_fixture")
	_save_incomplete(_arena("archive_fixture"), destination)
	var before := ArenaBundleInspectionService._files(destination)
	var archived := ArenaBundleOwnershipService.archive_unreferenced_incomplete(
		destination, "GUT controlled fixture"
	)
	assert_true(archived.ok, str(archived))
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(destination)))
	assert_true(FileAccess.file_exists(str(archived.archive).path_join("archive_receipt.json")))
	var restored := ArenaBundleOwnershipService.restore_archive(
		str(archived.archive), destination
	)
	assert_true(restored.ok, str(restored))
	assert_eq(ArenaBundleInspectionService._files(destination), before)
	assert_eq(
		ArenaBundleInspectionService.inspect(destination).state,
		ArenaBundleInspectionService.OWNED_INCOMPLETE
	)
	ArenaProductionTransactionService._remove_tree(str(archived.archive))


func _arena(suffix: String) -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Atomic %s" % suffix, "atomic_%s" % suffix)
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.grid_size = Vector2i(5, 4)
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
	return arena


func _save_incomplete(arena: ArenaDefinition, destination: String) -> void:
	_make_directory(destination)
	assert_eq(ResourceSaver.save(arena.modular_visual_profile, destination.path_join(
		"modular_visual_profile.tres"
	)), OK)
	assert_eq(ResourceSaver.save(arena, destination.path_join("arena.tres")), OK)


func _make_directory(path: String) -> void:
	assert_eq(
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path)), OK
	)


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		file.store_string(content)
		file.close()
