extends GutTest

const ROOT := "res://artifacts/studio_2_0/production_ownership"
const BUNDLE_ROOT := "user://dungeon_draft_studio/tests/production_ownership"


func before_all() -> void:
	_remove_tree(ROOT)
	_remove_tree(BUNDLE_ROOT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))


func after_all() -> void:
	_remove_tree(ROOT)
	_remove_tree(BUNDLE_ROOT)


func test_update_from_produced_bundle_is_stable_across_two_cycles() -> void:
	var directory := ROOT.path_join("two_cycles")
	var bundle_directory := directory.path_join("produced/room_fixture")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(bundle_directory)
	)
	var target_path := bundle_directory.path_join("legacy_integrated_room.tres")
	var target := _gameplay_room("Owned target")
	assert_eq(ResourceSaver.save(target, target_path), OK)
	var target_hash := FileAccess.get_sha256(target_path)
	var run_path := directory.path_join("run.tres")
	assert_eq(ResourceSaver.save(
		_run_fixture(
			ResourceLoader.load(target_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
			"Ownership Two Cycles"
		),
		run_path
	), OK)
	var gameplay_before := RoomIntegrationFieldPolicy.signature(
		(ResourceLoader.load(
			run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as RunData).rooms[0],
		RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
	)

	var first_source := _arena_with_gameplay("owned_cycle_1", Vector2(11.0, 7.0))
	var produced_path := _write_bundle(bundle_directory, first_source)
	var bundle_before_first := _bundle_snapshot(bundle_directory)
	var first := ArenaProductionAttachmentService.attach_and_save(
		produced_path,
		ResourceLoader.load(run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
		ArenaProductionAttachmentService.UPDATE,
		0
	)
	assert_true(first.ok, str(first))
	assert_true(first.copy_on_write)
	assert_true(first.run_saved)
	assert_true(first.materialized_run_owned)
	assert_true(ArenaRunOwnedRoomPathPolicy.is_run_owned_path(
		str(first.integrated_room_path), first.reloaded_run
	))
	assert_false(str(first.integrated_room_path).begins_with(bundle_directory + "/"))
	assert_eq(_bundle_snapshot(bundle_directory), bundle_before_first)
	assert_eq(FileAccess.get_sha256(target_path), target_hash)
	assert_eq(
		RoomIntegrationFieldPolicy.signature(
			first.reloaded_room, RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
		),
		gameplay_before
	)
	assert_eq(
		ArenaSnapshotService.arena_fingerprint(first.reloaded_room),
		ArenaSnapshotService.arena_fingerprint(
			ResourceLoader.load(
				produced_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
			) as ArenaDefinition
		)
	)
	var run_owned_path := str(first.integrated_room_path)
	var run_hash_after_first := FileAccess.get_sha256(run_path)
	assert_eq((first.reloaded_run as RunData).rooms.size(), 1)

	var second_source := ArenaDefinition.new()
	assert_true(ArenaSnapshotService.restore(
		second_source, ArenaSnapshotService.capture(first.reloaded_room)
	))
	ArenaTerrainRegistry.configure_cell(
		second_source.ensure_cell(Vector2i(4, 4)), &"neutral"
	)
	ArenaRuntimeBridge.sync_runtime_resources(second_source)
	assert_eq(_write_bundle(bundle_directory, second_source), produced_path)
	var bundle_before_second := _bundle_snapshot(bundle_directory)
	var second := ArenaProductionAttachmentService.attach_and_save(
		produced_path,
		ResourceLoader.load(run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
		ArenaProductionAttachmentService.UPDATE,
		0
	)
	assert_true(second.ok, str(second))
	assert_false(second.copy_on_write)
	assert_false(second.run_saved)
	assert_false(second.materialized_run_owned)
	assert_eq(str(second.integrated_room_path), run_owned_path)
	assert_eq(FileAccess.get_sha256(run_path), run_hash_after_first)
	assert_eq(FileAccess.get_sha256(target_path), target_hash)
	assert_eq(_bundle_snapshot(bundle_directory), bundle_before_second)
	assert_eq((second.reloaded_run as RunData).rooms.size(), 1)
	assert_eq(
		(second.reloaded_room as ArenaDefinition).get_cell_definition(
			Vector2i(4, 4)
		).terrain_id,
		&"neutral"
	)
	assert_eq(
		RoomIntegrationFieldPolicy.signature(
			second.reloaded_room, RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
		),
		gameplay_before
	)
	assert_eq(
		ArenaSnapshotService.arena_fingerprint(second.reloaded_room),
		ArenaSnapshotService.arena_fingerprint(
			ResourceLoader.load(
				produced_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
			) as ArenaDefinition
		)
	)


func test_structural_actions_attach_run_owned_copies_without_bundle_pollution() -> void:
	for fixture in [
		{
			"name": "replace",
			"action": ArenaProductionAttachmentService.REPLACE,
			"requested_index": 0,
			"expected_index": 0,
			"expected_count": 1,
		},
		{
			"name": "insert_before",
			"action": ArenaProductionAttachmentService.INSERT_BEFORE,
			"requested_index": 0,
			"expected_index": 0,
			"expected_count": 2,
		},
		{
			"name": "insert_after",
			"action": ArenaProductionAttachmentService.INSERT_AFTER,
			"requested_index": 0,
			"expected_index": 1,
			"expected_count": 2,
		},
		{
			"name": "append",
			"action": ArenaProductionAttachmentService.APPEND,
			"requested_index": 0,
			"expected_index": 1,
			"expected_count": 2,
		},
	]:
		var name := str(fixture.name)
		var directory := ROOT.path_join(name)
		var bundle_directory := directory.path_join("produced/room_fixture")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		var target_path := directory.path_join("old_room.tres")
		assert_eq(ResourceSaver.save(_gameplay_room("Old %s" % name), target_path), OK)
		var run_path := directory.path_join("run.tres")
		assert_eq(ResourceSaver.save(
			_run_fixture(
				ResourceLoader.load(
					target_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
				),
				"Ownership %s" % name
			),
			run_path
		), OK)
		var produced_path := _write_bundle(
			bundle_directory,
			_arena_with_gameplay("structural_%s" % name, Vector2(5.0, 3.0))
		)
		var produced := ResourceLoader.load(
			produced_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as ArenaDefinition
		var bundle_before := _bundle_snapshot(bundle_directory)
		var result := ArenaProductionAttachmentService.attach_and_save(
			produced_path,
			ResourceLoader.load(run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
			fixture.action,
			int(fixture.requested_index)
		)
		assert_true(result.ok, "%s: %s" % [name, str(result)])
		assert_true(result.materialized_run_owned, name)
		assert_false(result.copy_on_write, name)
		assert_eq(int(result.target_index), int(fixture.expected_index), name)
		assert_eq(int(result.after_count), int(fixture.expected_count), name)
		assert_true(ArenaRunOwnedRoomPathPolicy.is_run_owned_path(
			str(result.integrated_room_path), result.reloaded_run
		), name)
		assert_false(
			str(result.integrated_room_path).begins_with(bundle_directory + "/"),
			name
		)
		assert_eq(_bundle_snapshot(bundle_directory), bundle_before, name)
		assert_true(FileAccess.file_exists(target_path), name)
		assert_eq(
			(result.reloaded_run as RunData).rooms[int(fixture.expected_index)].resource_path,
			str(result.integrated_room_path),
			name
		)
		assert_eq(
			ArenaSnapshotService.arena_fingerprint(result.reloaded_room),
			ArenaSnapshotService.arena_fingerprint(produced),
			name
		)
		assert_eq(
			RoomIntegrationFieldPolicy.signature(
				result.reloaded_room, RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
			),
			RoomIntegrationFieldPolicy.signature(
				produced, RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
			),
			name
		)


func test_unshared_update_outside_produced_keeps_historical_path() -> void:
	var directory := ROOT.path_join("historical_in_place")
	var bundle_directory := BUNDLE_ROOT.path_join(
		"historical_in_place/room_fixture"
	)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var target_path := directory.path_join("target_room.tres")
	assert_eq(ResourceSaver.save(_gameplay_room("Historical target"), target_path), OK)
	var run_path := directory.path_join("run.tres")
	assert_eq(ResourceSaver.save(
		_run_fixture(
			ResourceLoader.load(target_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
			"Historical In Place"
		),
		run_path
	), OK)
	var source_path := _write_bundle(
		bundle_directory,
		_arena_with_gameplay("historical_source", Vector2(7.0, 4.0)),
	)
	var bundle_before := _bundle_snapshot(bundle_directory)
	var run_hash := FileAccess.get_sha256(run_path)
	var attachment_plan := ArenaProductionAttachmentService.plan(
		ResourceLoader.load(run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
		ArenaProductionAttachmentService.UPDATE,
		0,
		source_path
	)
	assert_true(attachment_plan.ok, str(attachment_plan))
	assert_true(attachment_plan.source_from_produced_bundle)
	assert_false(attachment_plan.target_from_produced_bundle)
	assert_false(attachment_plan.materialize_run_owned)
	var result := ArenaProductionAttachmentService.attach_and_save(
		source_path,
		ResourceLoader.load(run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
		ArenaProductionAttachmentService.UPDATE,
		0
	)
	assert_true(result.ok, str(result))
	assert_false(result.copy_on_write)
	assert_false(result.materialized_run_owned)
	assert_false(result.run_saved)
	assert_eq(str(result.integrated_room_path), target_path)
	assert_eq(FileAccess.get_sha256(run_path), run_hash)
	assert_eq(_bundle_snapshot(bundle_directory), bundle_before)


func _write_bundle(directory: String, arena: ArenaDefinition) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var arena_path := directory.path_join("arena.tres")
	assert_eq(ResourceSaver.save(arena, arena_path), OK)
	var manifest_path := directory.path_join("production_manifest.json")
	var manifest := FileAccess.open(manifest_path, FileAccess.WRITE)
	assert_not_null(manifest)
	if manifest != null:
		manifest.store_string(JSON.stringify({
			"schema_version": 1,
			"arena_id": str(arena.arena_id),
			"arena_path": arena_path,
			"source_fingerprint": ArenaSnapshotService.arena_fingerprint(arena),
			"produced_fingerprint": ArenaSnapshotService.arena_fingerprint(arena),
			"source_gameplay_fingerprint": ArenaSnapshotService.gameplay_fingerprint(arena),
			"produced_gameplay_fingerprint": ArenaSnapshotService.gameplay_fingerprint(arena),
			"files": {"arena.tres": FileAccess.get_sha256(arena_path)},
			"fixture_only": true,
		}, "  "))
		manifest.close()
	return arena_path


func _arena_with_gameplay(identifier: String, origin_shift: Vector2) -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Fixture %s" % identifier, identifier)
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.grid_size = Vector2i(12, 9)
	arena.grid_origin = origin_shift
	arena.axis_x = Vector2(32.0, 16.0)
	arena.axis_y = Vector2(-32.0, 16.0)
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			ArenaTerrainRegistry.configure_cell(
				arena.ensure_cell(Vector2i(x, y)), &"stone"
			)
	ArenaEditingService.prepare_automatically(arena)
	arena.encounter_definition = _encounter_fixture()
	arena.minimum_wave_count = 1
	arena.maximum_wave_count = 1
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


func _gameplay_room(room_name: String) -> RoomData:
	var room := RoomData.new()
	room.room_name = room_name
	var encounter := _encounter_fixture()
	room.encounter_definition = encounter
	room.enemies.assign(encounter.roster_units)
	room.minimum_wave_count = 1
	room.maximum_wave_count = 1
	return room


func _encounter_fixture() -> EncounterDefinition:
	var enemy := UnitData.new()
	enemy.unit_id = &"ownership_fixture_enemy"
	enemy.unit_name = "Ownership fixture enemy"
	enemy.team = 1
	var encounter := EncounterDefinition.new()
	encounter.room_index = 1
	encounter.roster_units = [enemy]
	encounter.roster_counts = PackedInt32Array([1])
	encounter.living_enemy_cap = 1
	encounter.formation_profiles = [&"line"]
	return encounter


func _run_fixture(room: RoomData, run_name: String) -> RunData:
	var run_data := RunData.new()
	run_data.run_name = run_name
	run_data.room_flow_mode = RunData.RoomFlowMode.SINGLE_ENCOUNTER
	run_data.maximum_waves_per_room = 1
	run_data.rooms = [room]
	return run_data


func _bundle_snapshot(path: String) -> Dictionary:
	var result := {}
	_collect_bundle_snapshot(path, path, result)
	return result


func _collect_bundle_snapshot(root: String, current: String, result: Dictionary) -> void:
	var directory := DirAccess.open(ProjectSettings.globalize_path(current))
	if directory == null:
		return
	for file_name in directory.get_files():
		var file_path := current.path_join(file_name)
		result[file_path.trim_prefix(root.trim_suffix("/") + "/")] = (
			FileAccess.get_sha256(file_path)
		)
	for child in directory.get_directories():
		_collect_bundle_snapshot(root, current.path_join(child), result)


func _remove_tree(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	var directory := DirAccess.open(absolute)
	if directory == null:
		return true
	for file_name in directory.get_files():
		DirAccess.remove_absolute(absolute.path_join(file_name))
	for child in directory.get_directories():
		_remove_tree(path.path_join(child))
	DirAccess.remove_absolute(absolute)
	return true
