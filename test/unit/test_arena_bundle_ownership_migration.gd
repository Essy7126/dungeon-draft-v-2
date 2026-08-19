extends GutTest

const ROOT := "user://dungeon_draft_studio/tests/bundle_manifest_migration"
const OWNERSHIP_FIXTURE_ROOT := "res://artifacts/arena_bundle_ownership_migration"

var _recoveries := PackedStringArray()


func before_each() -> void:
	ArenaProductionTransactionService._remove_tree(ROOT)
	ArenaProductionTransactionService._remove_tree(OWNERSHIP_FIXTURE_ROOT)
	_recoveries.clear()


func after_each() -> void:
	ArenaProductionTransactionService._remove_tree(ROOT)
	ArenaProductionTransactionService._remove_tree(OWNERSHIP_FIXTURE_ROOT)
	for recovery in _recoveries:
		ArenaProductionTransactionService._remove_tree(recovery)


func test_physically_intact_legacy_fingerprint_is_not_reported_dirty() -> void:
	var destination := ROOT.path_join("legacy_state")
	var saved := _save_legacy_bundle(destination, _arena("legacy_state"))
	var inspection := ArenaBundleInspectionService.inspect(destination)
	assert_eq(
		inspection.state,
		ArenaBundleInspectionService.LEGACY_LOGICAL_FINGERPRINT,
		str(inspection)
	)
	assert_true(inspection.physical_complete)
	assert_true(inspection.logical_fingerprint_legacy)
	assert_true((inspection.dirty as PackedStringArray).is_empty())
	assert_eq(_payload_hashes(inspection.files), saved.payload_hashes)
	var migration := ArenaBundleManifestMigrationService.plan(destination)
	assert_true(migration.ok, str(migration))
	assert_true(migration.required)
	assert_eq(migration.physical_file_hash, saved.payload_hashes)


func test_explicit_migration_backs_up_manifest_and_reaches_owned_clean() -> void:
	var destination := ROOT.path_join("migrated")
	var saved := _save_legacy_bundle(destination, _arena("migrated"))
	var before_payload := _payload_hashes(
		ArenaBundleInspectionService._files(destination)
	)
	var result := ArenaBundleManifestMigrationService.execute(destination)
	assert_true(result.ok, str(result))
	assert_eq(result.status, "COMPLETED")
	assert_true(result.payload_unchanged)
	assert_true(FileAccess.file_exists(result.backup))
	assert_true(FileAccess.file_exists(
		str(result.recovery).path_join("manifest_migration_report.json")
	))
	assert_eq(FileAccess.get_sha256(result.backup), saved.manifest_sha256)
	var inspection := ArenaBundleInspectionService.inspect(destination)
	assert_eq(inspection.state, ArenaBundleInspectionService.OWNED_CLEAN, str(inspection))
	assert_true(inspection.complete)
	assert_eq(_payload_hashes(inspection.files), before_payload)
	var manifest := inspection.manifest as Dictionary
	assert_eq(
		int(manifest.manifest_schema_version),
		ArenaProductionService.MANIFEST_SCHEMA_VERSION
	)
	assert_eq(
		str(manifest.fingerprint_algorithm_id),
		ArenaProductionService.FINGERPRINT_ALGORITHM_ID
	)
	assert_true(manifest.complete)
	assert_eq(manifest.physical_file_hash, saved.payload_hashes)
	assert_eq(
		str(manifest.logical_arena_fingerprint),
		str(saved.logical_arena_fingerprint)
	)
	assert_eq(
		str(manifest.gameplay_fingerprint),
		str(saved.gameplay_fingerprint)
	)


func test_failure_after_publish_restores_exact_legacy_manifest() -> void:
	var destination := ROOT.path_join("rollback")
	var saved := _save_legacy_bundle(destination, _arena("rollback"))
	var before_files := ArenaBundleInspectionService._files(destination)
	var result := ArenaBundleManifestMigrationService.execute(destination, {
		"failure_step": "after_manifest_publish",
	})
	assert_false(result.ok, str(result))
	assert_eq(result.status, "ROLLED_BACK")
	assert_true(result.rollback_ok)
	assert_eq(
		FileAccess.get_sha256(destination.path_join("production_manifest.json")),
		saved.manifest_sha256
	)
	assert_eq(ArenaBundleInspectionService._files(destination), before_files)
	assert_eq(
		ArenaBundleInspectionService.inspect(destination).state,
		ArenaBundleInspectionService.LEGACY_LOGICAL_FINGERPRINT
	)


func test_current_algorithm_with_wrong_logical_fingerprint_is_owned_dirty() -> void:
	var destination := ROOT.path_join("logical_mismatch")
	_save_legacy_bundle(destination, _arena("logical_mismatch"))
	var migration := ArenaBundleManifestMigrationService.execute(destination)
	assert_true(migration.ok, str(migration))
	var manifest_path := destination.path_join("production_manifest.json")
	var manifest := ArenaProductionService._read_json(manifest_path)
	manifest["logical_arena_fingerprint"] = "sha256-intentionally-wrong"
	assert_true(ArenaProductionService._write_json(manifest_path, manifest))
	var inspection := ArenaBundleInspectionService.inspect(destination)
	assert_eq(inspection.state, ArenaBundleInspectionService.OWNED_DIRTY)
	assert_true((inspection.dirty as PackedStringArray).has(
		"logical_arena_fingerprint"
	))
	assert_false(inspection.logical_fingerprint_legacy)


func test_unknown_algorithm_keeps_physical_integrity_as_legacy() -> void:
	var destination := ROOT.path_join("unknown_algorithm")
	_save_legacy_bundle(destination, _arena("unknown_algorithm"))
	var migration := ArenaBundleManifestMigrationService.execute(destination)
	assert_true(migration.ok, str(migration))
	var manifest_path := destination.path_join("production_manifest.json")
	var manifest := ArenaProductionService._read_json(manifest_path)
	manifest["fingerprint_algorithm_id"] = "historical_sha256_v0"
	assert_true(ArenaProductionService._write_json(manifest_path, manifest))
	var inspection := ArenaBundleInspectionService.inspect(destination)
	assert_eq(
		inspection.state,
		ArenaBundleInspectionService.LEGACY_LOGICAL_FINGERPRINT
	)
	assert_true(inspection.physical_complete)
	assert_true((inspection.dirty as PackedStringArray).is_empty())


func test_foreign_bundle_room_migrates_transactionally_to_run_owned_namespace() -> void:
	var fixture := _save_ownership_fixture("complete")
	var dry_run := ArenaBundleOwnershipMigrationService.plan(
		fixture.bundle, fixture.run_path, 0
	)
	assert_true(dry_run.ok, str(dry_run))
	assert_true(dry_run.dry_run)
	assert_eq(dry_run.foreign_room_path, fixture.foreign_room_path)
	assert_true(str(dry_run.run_owned_room_path).begins_with(
		str(fixture.run_path).get_base_dir().path_join("run_specific/principal/")
	))
	assert_false(str(dry_run.run_owned_room_path).begins_with(
		str(fixture.bundle).trim_suffix("/") + "/"
	))
	var result := ArenaBundleOwnershipMigrationService.execute(
		fixture.bundle, fixture.run_path, 0
	)
	_track_migration_recoveries(result)
	assert_true(result.ok, str(result))
	if not bool(result.get("ok", false)):
		return
	assert_eq(result.status, "COMPLETED")
	assert_false(FileAccess.file_exists(fixture.foreign_room_path))
	assert_true(FileAccess.file_exists(result.run_owned_room_path))
	assert_eq(
		(result.final_inspection as Dictionary).state,
		ArenaBundleInspectionService.OWNED_CLEAN
	)
	assert_true((result.final_inspection.foreign as PackedStringArray).is_empty())
	assert_eq(
		str(result.run_verification.gameplay_fingerprint),
		str(fixture.gameplay_fingerprint)
	)
	assert_eq(result.run_verification.room_index, 0)
	assert_eq(result.run_verification.room_count, 1)
	assert_true(FileAccess.file_exists(
		str(result.recovery).path_join("foreign_room.before.tres")
	))
	assert_true(FileAccess.file_exists(
		str(result.recovery).path_join("ownership_migration_report.json")
	))


func test_foreign_room_removal_failure_path_rolls_back_exact_files() -> void:
	var fixture := _save_ownership_fixture("rollback_ownership")
	var bundle_before := ArenaBundleInspectionService._files(fixture.bundle)
	var run_sha_before := FileAccess.get_sha256(fixture.run_path)
	var result := ArenaBundleOwnershipMigrationService.execute(
		fixture.bundle, fixture.run_path, 0, {
			"failure_step": "after_foreign_archive",
		}
	)
	_track_migration_recoveries(result)
	assert_false(result.ok, str(result))
	assert_eq(result.status, "ROLLED_BACK")
	assert_true(result.rollback_ok)
	assert_eq(
		ArenaBundleInspectionService._files(fixture.bundle), bundle_before
	)
	assert_eq(FileAccess.get_sha256(fixture.run_path), run_sha_before)
	assert_true(FileAccess.file_exists(fixture.foreign_room_path))
	assert_false(FileAccess.file_exists(result.run_owned_room_path))
	var restored_run := ResourceLoader.load(
		fixture.run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	assert_not_null(restored_run)
	assert_eq(restored_run.rooms[0].resource_path, fixture.foreign_room_path)
	assert_eq(
		ArenaBundleInspectionService.inspect(fixture.bundle).state,
		ArenaBundleInspectionService.OWNED_DIRTY
	)


func _arena(identifier: String) -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Manifest %s" % identifier, identifier)
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.modular_visual_profile.theme_id = arena.theme_id
	arena.grid_size = Vector2i(4, 4)
	arena.grid_origin = Vector2.ZERO
	arena.axis_x = Vector2(32.0, 16.0)
	arena.axis_y = Vector2(-32.0, 16.0)
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			ArenaTerrainRegistry.configure_cell(
				arena.ensure_cell(Vector2i(x, y)), &"stone"
			)
	ArenaEditingService.prepare_automatically(arena)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


func _save_legacy_bundle(directory: String, arena: ArenaDefinition) -> Dictionary:
	assert_eq(
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)),
		OK
	)
	assert_eq(ResourceSaver.save(
		arena.modular_visual_profile,
		directory.path_join("modular_visual_profile.tres")
	), OK)
	assert_eq(ResourceSaver.save(
		arena, directory.path_join("arena.tres"), ResourceSaver.FLAG_RELATIVE_PATHS
	), OK)
	var reloaded := ResourceLoader.load(
		directory.path_join("arena.tres"), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	assert_not_null(reloaded)
	var payload_hashes := _payload_hashes(
		ArenaBundleInspectionService._files(directory)
	)
	var manifest := {
		"version": 2,
		"generator_revision": 4,
		"generated_by": ArenaProductionService.GENERATED_BY,
		"arena_id": str(reloaded.arena_id),
		"source_fingerprint": ArenaSnapshotService.arena_fingerprint(reloaded),
		"source_gameplay_fingerprint": ArenaSnapshotService.gameplay_fingerprint(reloaded),
		"produced_fingerprint": ArenaSnapshotService.arena_fingerprint(reloaded),
		"produced_gameplay_fingerprint": ArenaSnapshotService.gameplay_fingerprint(reloaded),
		"files": payload_hashes,
	}
	var manifest_path := directory.path_join("production_manifest.json")
	assert_true(ArenaProductionService._write_json(manifest_path, manifest))
	return {
		"payload_hashes": payload_hashes,
		"manifest_sha256": FileAccess.get_sha256(manifest_path),
		"logical_arena_fingerprint": ArenaSnapshotService.arena_fingerprint(reloaded),
		"gameplay_fingerprint": ArenaSnapshotService.gameplay_fingerprint(reloaded),
	}


func _save_ownership_fixture(suffix: String) -> Dictionary:
	var fixture_root := OWNERSHIP_FIXTURE_ROOT.path_join(suffix)
	var bundle := fixture_root.path_join("produced/room_01_forest")
	assert_eq(
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(bundle)),
		OK
	)
	var source := _arena("ownership_source_%s" % suffix)
	source.room_name = "Salle 1 - Gué forestier"
	source.encounter_definition = _encounter_fixture()
	source.enemies.assign(source.encounter_definition.roster_units)
	source.minimum_wave_count = 1
	source.maximum_wave_count = 1
	ArenaRuntimeBridge.sync_runtime_resources(source)
	assert_eq(ResourceSaver.save(
		source.modular_visual_profile,
		bundle.path_join("modular_visual_profile.tres")
	), OK)
	assert_eq(ResourceSaver.save(
		source, bundle.path_join("arena.tres"), ResourceSaver.FLAG_RELATIVE_PATHS
	), OK)
	var foreign := ArenaDefinition.new()
	assert_true(ArenaSnapshotService.restore(
		foreign, ArenaSnapshotService.capture(source)
	))
	foreign.room_name = source.room_name
	foreign.ultimate_reward_base_chance = 23
	foreign.minimum_wave_count = 1
	foreign.maximum_wave_count = 1
	var foreign_path := bundle.path_join("arena_principal.tres")
	assert_eq(ResourceSaver.save(
		foreign, foreign_path, ResourceSaver.FLAG_RELATIVE_PATHS
	), OK)
	var payload_hashes := {}
	for relative_path in ["arena.tres", "modular_visual_profile.tres"]:
		payload_hashes[relative_path] = FileAccess.get_sha256(
			bundle.path_join(relative_path)
		)
	assert_true(ArenaProductionService._write_json(
		bundle.path_join("production_manifest.json"), {
			"version": 2,
			"generator_revision": 4,
			"generated_by": ArenaProductionService.GENERATED_BY,
			"arena_id": str(source.arena_id),
			"source_fingerprint": ArenaSnapshotService.arena_fingerprint(source),
			"source_gameplay_fingerprint": ArenaSnapshotService.gameplay_fingerprint(source),
			"produced_fingerprint": ArenaSnapshotService.arena_fingerprint(source),
			"produced_gameplay_fingerprint": ArenaSnapshotService.gameplay_fingerprint(source),
			"files": payload_hashes,
		}
	))
	var reloaded_foreign := ResourceLoader.load(
		foreign_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	assert_not_null(reloaded_foreign)
	var run := RunData.new()
	run.run_name = "Principal"
	run.room_flow_mode = RunData.RoomFlowMode.SINGLE_ENCOUNTER
	run.maximum_waves_per_room = 1
	run.rooms = [reloaded_foreign]
	var run_path := fixture_root.path_join("first_run.tres")
	assert_eq(ResourceSaver.save(run, run_path), OK)
	var inspection := ArenaBundleInspectionService.inspect(bundle)
	assert_eq(inspection.state, ArenaBundleInspectionService.OWNED_DIRTY, str(inspection))
	assert_eq(inspection.foreign, PackedStringArray(["arena_principal.tres"]))
	return {
		"bundle": bundle,
		"run_path": run_path,
		"foreign_room_path": foreign_path,
		"gameplay_fingerprint": RoomDataSnapshotService.gameplay_fingerprint(
			reloaded_foreign
		),
	}


func _encounter_fixture() -> EncounterDefinition:
	var enemy := UnitData.new()
	enemy.unit_id = &"ownership_migration_enemy"
	enemy.unit_name = "Ownership migration enemy"
	enemy.team = 1
	var encounter := EncounterDefinition.new()
	encounter.room_index = 1
	encounter.roster_units = [enemy]
	encounter.roster_counts = PackedInt32Array([1])
	encounter.living_enemy_cap = 1
	encounter.formation_profiles = [&"line"]
	return encounter


func _track_migration_recoveries(result: Dictionary) -> void:
	var recovery := str(result.get("recovery", ""))
	if not recovery.is_empty():
		_recoveries.append(recovery)
	var manifest_migration := result.get("manifest_migration", {}) as Dictionary
	var manifest_recovery := str(manifest_migration.get("recovery", ""))
	if not manifest_recovery.is_empty():
		_recoveries.append(manifest_recovery)
	var attachment := result.get("attachment", {}) as Dictionary
	var room_recovery := str(attachment.get("room_recovery_path", ""))
	if not room_recovery.is_empty():
		_recoveries.append(room_recovery)


func _payload_hashes(value: Variant) -> Dictionary:
	var files := value as Dictionary if value is Dictionary else {}
	var result := {}
	for relative_path in files:
		var path := str(relative_path)
		if path == "production_manifest.json" or path.ends_with(".import"):
			continue
		var metadata := files[relative_path] as Dictionary
		result[path] = str(metadata.get("sha256", ""))
	return result
