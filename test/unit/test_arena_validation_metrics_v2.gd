extends GutTest

const ROOT := "user://dungeon_draft_studio/tests/arena_validation_metrics_v2"


func before_each() -> void:
	ArenaProductionTransactionService._remove_tree(ROOT)


func after_each() -> void:
	ArenaProductionTransactionService._remove_tree(ROOT)


func test_runtime_field_coverage_is_exhaustive_and_honest() -> void:
	var coverage := ArenaRuntimeFieldCoverageService.scan()
	assert_true(coverage.production_gate_valid, str(coverage.unknown))
	assert_eq(coverage.unknown.size(), 0)
	assert_eq(coverage.unsupported_gameplay.size(), 0)
	assert_eq(
		ArenaRuntimeFieldCoverageService.classification_for(
			"ArenaObstacleDefinition", &"blocks_movement"
		),
		ArenaRuntimeFieldCoverageService.Classification.RUNTIME_CONSUMED
	)
	assert_eq(
		ArenaRuntimeFieldCoverageService.classification_for(
			"ArenaObstacleDefinition", &"blocks_push"
		),
		ArenaRuntimeFieldCoverageService.Classification.FUTURE_EXPLICIT
	)
	assert_eq(
		ArenaRuntimeFieldCoverageService.classification_for(
			"ArenaDecorationDefinition", &"layer"
		),
		ArenaRuntimeFieldCoverageService.Classification.RUNTIME_CONSUMED
	)


func test_tactical_metrics_use_every_camp_pair_and_real_topology() -> void:
	var arena := _arena("metrics")
	var metrics := ArenaTacticalMetricsService.analyze(arena)
	assert_true(metrics.ok, str(metrics))
	assert_eq(metrics.topology.accessible_cells, 20)
	assert_eq(metrics.topology.components, 1)
	assert_eq(metrics.camps.pair_count, 6)
	assert_eq(metrics.camps.connected_pair_count, 6)
	assert_eq(metrics.camps.minimum_distance, 6)
	assert_eq(metrics.camps.median_distance, 7.0)
	assert_eq(metrics.camps.average_distance, 7.0)
	assert_eq(metrics.camps.p90_distance, 8)
	assert_eq(metrics.camps.maximum_distance, 8)
	assert_eq(metrics.contact.turns_at_3_pm, 2)
	assert_eq(metrics.contact.turns_at_5_pm, 2)
	assert_eq(metrics.spawns.required_hero_spawns, 3)
	assert_eq(metrics.spawns.hero_pool, 3)
	assert_eq(metrics.spawns.enemy_spawns, 2)


func test_validator_checks_coherence_spawns_layers_and_passable_decor() -> void:
	var arena := _arena("validation")
	var passable := ArenaObstacleDefinition.new()
	passable.obstacle_id = &"passable_at_spawn"
	passable.cell = Vector2i(0, 0)
	passable.apply_preset(ArenaObstacleDefinition.Preset.PASSABLE_DECOR)
	arena.obstacles.append(passable)
	var report := ArenaValidator.validate(arena, false)
	assert_true(report.is_valid(), str(report.to_dict()))
	assert_false(report.messages.any(func(value): return value.code == &"spawn_blocked"))
	assert_eq(report.metrics.spawns.required_hero_spawns, 3)
	assert_eq(report.metrics.spawns.enemy_spawns, 2)
	assert_eq(report.metrics.runtime_field_coverage.unknown.size(), 0)
	var incoherent := arena.get_cell_definition(Vector2i(1, 0))
	incoherent.terrain_id = &"lava"
	incoherent.cell_type = GridData.CellType.NORMAL
	incoherent.playable = true
	var invalid := ArenaValidator.validate(arena, false)
	assert_false(invalid.is_valid())
	assert_true(invalid.messages.any(func(value):
		return value.code == &"terrain_coherence_mismatch"
	))


func test_exact_scene_report_and_readiness_certificate_invalidate_on_change() -> void:
	var arena := _arena("certificate")
	var visual := ArenaVisualAssembler.inspect(arena)
	assert_true(visual.valid, str(visual.to_dict()))
	assert_eq(visual.expected_terrain_cell_count, 21)
	assert_eq(visual.rendered_terrain_node_count, 21)
	assert_eq(visual.duplicate_terrain_node_count, 0)
	for entry in visual.terrain_nodes.values():
		assert_eq(entry.parent_role, "arena_tiles_layer")
		assert_eq(entry.renderer_role, "arena_floor")
		assert_eq(entry.duplication_count, 1)
		assert_eq((entry.polygon as PackedVector2Array).size(), 4)
	var certificate := ArenaProductionReadinessService.build(
		arena, ROOT.path_join("certificate"), {
			"run_path": "res://data/runs/run_default.tres",
			"room_index": 0,
			"action": "UPDATE",
		}
	)
	assert_true(certificate.ready_to_produce, str(certificate.to_dict()))
	assert_false(certificate.runtime_bootable, str(certificate.to_dict()))
	assert_false(certificate.ready, str(certificate.to_dict()))
	assert_true(certificate.matches(arena))
	arena.camera_zoom = 1.1
	assert_false(certificate.matches(arena))


func _arena(suffix: String) -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Validation %s" % suffix, "validation_%s" % suffix)
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.grid_size = Vector2i(7, 3)
	arena.grid_origin = Vector2.ZERO
	arena.axis_x = Vector2(32, 16)
	arena.axis_y = Vector2(-32, 16)
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			ArenaTerrainRegistry.configure_cell(
				arena.ensure_cell(Vector2i(x, y)), &"stone"
			)
	var blocker := ArenaObstacleDefinition.new()
	blocker.obstacle_id = &"center_wall"
	blocker.cell = Vector2i(3, 1)
	blocker.apply_preset(ArenaObstacleDefinition.Preset.FULL_WALL)
	arena.obstacles.append(blocker)
	_add_spawn(arena, &"hero_1", ArenaSpawnDefinition.Kind.HERO_1, Vector2i(0, 0))
	_add_spawn(arena, &"hero_2", ArenaSpawnDefinition.Kind.HERO_2, Vector2i(0, 1))
	_add_spawn(arena, &"hero_3", ArenaSpawnDefinition.Kind.HERO_3, Vector2i(0, 2))
	_add_spawn(arena, &"enemy_1", ArenaSpawnDefinition.Kind.ENEMY, Vector2i(6, 0))
	_add_spawn(arena, &"enemy_2", ArenaSpawnDefinition.Kind.ENEMY, Vector2i(6, 2))
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


func _add_spawn(
		arena: ArenaDefinition,
		spawn_id: StringName,
		kind: int,
		cell: Vector2i
	) -> void:
	var spawn := ArenaSpawnDefinition.new()
	spawn.spawn_id = spawn_id
	spawn.kind = kind
	spawn.cell = cell
	spawn.required = true
	spawn.facing = Vector2i.RIGHT if spawn.is_hero() else Vector2i.LEFT
	arena.spawns.append(spawn)
