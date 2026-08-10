extends GutTest


func test_field_policy_covers_root_and_reachable_storage_without_unknowns() -> void:
	var arena := _fixture()
	var room_report := RoomIntegrationFieldPolicy.coverage_report(RoomData.new())
	var arena_report := RoomIntegrationFieldPolicy.coverage_report(arena)
	assert_true(room_report.ok, str(room_report.unknown))
	assert_true(arena_report.ok, str(arena_report.unknown))
	assert_eq((room_report.unknown as PackedStringArray).size(), 0)
	assert_eq((arena_report.unknown as PackedStringArray).size(), 0)
	assert_gt(int(arena_report.stored_properties_inspected), 50)
	assert_eq(
		RoomIntegrationFieldPolicy.classification_for(&"grid_layout", arena),
		RoomIntegrationFieldPolicy.DERIVED_RUNTIME
	)
	assert_eq(
		RoomIntegrationFieldPolicy.classification_for(&"production_notes", arena),
		RoomIntegrationFieldPolicy.EDITOR_ONLY
	)
	assert_eq(
		RoomIntegrationFieldPolicy.classification_for(&"waves", arena),
		RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
	)
	assert_eq(
		RoomIntegrationFieldPolicy.classification_for(&"cells", arena),
		RoomIntegrationFieldPolicy.ARENA_OWNED
	)


func test_arena_gameplay_and_room_fingerprints_have_separate_authorities() -> void:
	var arena := _fixture()
	var arena_before := ArenaSnapshotService.arena_fingerprint(arena)
	var gameplay_before := ArenaSnapshotService.gameplay_fingerprint(arena)
	var room_before := ArenaSnapshotService.room_fingerprint(arena)
	arena.ultimate_reward_base_chance += 1
	assert_eq(ArenaSnapshotService.arena_fingerprint(arena), arena_before)
	assert_ne(ArenaSnapshotService.gameplay_fingerprint(arena), gameplay_before)
	assert_ne(ArenaSnapshotService.room_fingerprint(arena), room_before)
	var gameplay_after := ArenaSnapshotService.gameplay_fingerprint(arena)
	arena.grid_origin += Vector2(7.0, 3.0)
	assert_ne(ArenaSnapshotService.arena_fingerprint(arena), arena_before)
	assert_eq(ArenaSnapshotService.gameplay_fingerprint(arena), gameplay_after)
	var arena_after := ArenaSnapshotService.arena_fingerprint(arena)
	arena.grid_layout = RoomGridLayout.new()
	assert_eq(ArenaSnapshotService.arena_fingerprint(arena), arena_after)
	assert_ne(ArenaSnapshotService.room_fingerprint(arena), room_before)


func test_validator_and_visual_inspection_are_pure_on_unsynchronised_source() -> void:
	var arena := _fixture()
	assert_null(arena.grid_layout)
	assert_null(arena.painted_map_visual_data)
	assert_null(arena.arena_visual_profile)
	assert_true(arena.hero_spawn_zone.is_empty())
	assert_true(arena.enemy_spawn_zone.is_empty())
	var arena_before := ArenaSnapshotService.arena_fingerprint(arena)
	var gameplay_before := ArenaSnapshotService.gameplay_fingerprint(arena)
	var room_before := ArenaSnapshotService.room_fingerprint(arena)
	var report := ArenaValidator.validate(arena, false)
	assert_not_null(report)
	var visual := ArenaVisualAssembler.inspect(arena)
	assert_true(visual.valid, str(visual.to_dict()))
	assert_eq(ArenaSnapshotService.arena_fingerprint(arena), arena_before)
	assert_eq(ArenaSnapshotService.gameplay_fingerprint(arena), gameplay_before)
	assert_eq(ArenaSnapshotService.room_fingerprint(arena), room_before)
	assert_null(arena.grid_layout)
	assert_null(arena.painted_map_visual_data)
	assert_null(arena.arena_visual_profile)
	assert_true(arena.hero_spawn_zone.is_empty())
	assert_true(arena.enemy_spawn_zone.is_empty())


func test_complete_room_snapshot_restores_arena_gameplay_and_runtime_fields() -> void:
	var arena := _fixture()
	var captured := ArenaSnapshotService.capture(arena)
	var before := ArenaSnapshotService.room_fingerprint(arena)
	arena.grid_origin += Vector2(100.0, 50.0)
	arena.waves.clear()
	arena.enemies.clear()
	arena.hero_spawn_zone.append(Vector2i(9, 7))
	assert_ne(ArenaSnapshotService.room_fingerprint(arena), before)
	assert_true(ArenaSnapshotService.restore(arena, captured))
	assert_eq(ArenaSnapshotService.room_fingerprint(arena), before)
	assert_eq(arena.waves.size(), 1)
	assert_true(arena.hero_spawn_zone.is_empty())


func test_runtime_projection_keeps_full_gameplay_and_never_mutates_source() -> void:
	var arena := _fixture()
	var before := ArenaSnapshotService.room_fingerprint(arena)
	var state := ArenaSnapshotService.to_runtime_projection(arena)
	assert_not_null(state)
	assert_not_null(state.grid)
	assert_not_null(state.arena_projection)
	assert_eq(state.arena_projection.waves.size(), arena.waves.size())
	assert_eq(
		RoomDataSnapshotService.gameplay_fingerprint(state.arena_projection),
		RoomDataSnapshotService.gameplay_fingerprint(arena)
	)
	assert_eq(ArenaSnapshotService.room_fingerprint(arena), before)
	assert_null(arena.grid_layout)


func _fixture() -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Phase 1 hardening", "phase_1_hardening")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.grid_size = Vector2i(10, 8)
	arena.grid_origin = Vector2.ZERO
	arena.axis_x = Vector2(32, 16)
	arena.axis_y = Vector2(-32, 16)
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			ArenaTerrainRegistry.configure_cell(
				arena.ensure_cell(Vector2i(x, y)), &"stone"
			)
	ArenaEditingService.prepare_automatically(arena)
	var wave := RoomWaveData.new()
	wave.wave_name = "Vague fixture"
	wave.enemy_health_multiplier = 1.25
	wave.enemy_attack_multiplier = 0.9
	wave.reward_multiplier = 1.4
	arena.waves = [wave]
	arena.minimum_wave_count = 1
	arena.maximum_wave_count = 1
	arena.ultimate_reward_base_chance = 17
	# La fixture reste volontairement non synchronisee : le validateur doit
	# construire sa projection sans enrichir cette Resource.
	arena.grid_layout = null
	arena.painted_map_visual_data = null
	arena.arena_visual_profile = null
	arena.hero_spawn_zone.clear()
	arena.enemy_spawn_zone.clear()
	return arena
