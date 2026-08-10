extends GutTest

const ART_TEST_ROOT := "res://artifacts/studio_2_0/round_trip_test"
const ATTACHMENT_TEST_ROOT := "res://artifacts/studio_2_0/attachment_test"
const SKILL_SAVE_TEST_ROOT := "res://artifacts/studio_2_0/skill_profile_save_test"


func after_all() -> void:
	_remove_tree(ART_TEST_ROOT)
	_remove_tree(ATTACHMENT_TEST_ROOT)
	_remove_tree(SKILL_SAVE_TEST_ROOT)


func test_project_context_is_run_aware_and_blocks_silent_dirty_replacement() -> void:
	var runs := RunContentCatalogService.discover_runs()
	assert_gte(runs.size(), 2)
	var context := StudioProjectContext.new()
	assert_true(context.initialize(runs[0].resource_path, &"elf").ok)
	var opening_path := context.active_run.resource_path
	context.set_dirty(&"test_domain", true, {"document": "fixture"})
	var blocked := context.request_run(runs[1], &"test")
	assert_false(blocked.ok)
	assert_eq(blocked.status, &"REQUIRES_DECISION")
	assert_eq(context.active_run.resource_path, opening_path)
	assert_true(context.has_pending_transition())
	assert_true(context.resolve_pending_transition(StudioProjectContext.ACTION_CANCEL).ok)
	assert_eq(context.active_run.resource_path, opening_path)
	context.register_transition_handler(
		&"test_domain", func(): return {"ok": true},
		func(): return {"ok": true, "path": "user://draft.tres"},
		func(): return {"ok": true}
	)
	context.set_dirty(&"test_domain", true)
	assert_false(context.request_run(runs[1], &"test").ok)
	var resolved := context.resolve_pending_transition(StudioProjectContext.ACTION_DRAFT)
	assert_true(resolved.ok)
	assert_eq(context.active_run.resource_path, runs[1].resource_path)
	assert_false(context.is_dirty())


func test_context_snapshot_contains_run_room_hero_scope_paths_and_generations() -> void:
	var context := StudioProjectContext.new()
	assert_true(context.initialize("", &"mage").ok)
	var snapshot := context.snapshot()
	assert_false(str(snapshot.run_path).is_empty())
	assert_false(str(snapshot.room_path).is_empty())
	assert_eq(str(snapshot.character_id), "mage")
	assert_false(str(snapshot.progression_path).is_empty())
	assert_eq(snapshot.scope, StudioProjectContext.SCOPE_RUN_SPECIFIC)
	assert_gt(int((snapshot.generations as Dictionary).get(&"context", 0)), 0)


func test_reference_graph_indexes_cross_domain_usages_and_cache_generation() -> void:
	var graph := StudioReferenceGraphService.new()
	var first := graph.scan(true)
	assert_true(first.ok)
	assert_gt(int(first.nodes), 20)
	assert_gt(int(first.edges), 20)
	var generation := graph.generation
	var cached := graph.scan(false)
	assert_true(cached.cached)
	assert_eq(graph.generation, generation)
	var run_data := RunContentCatalogService.discover_runs()[0]
	assert_gt(graph.references_from(run_data).size(), 0)
	assert_gt(graph.usages(run_data.rooms[0]).size(), 0)
	graph.invalidate(run_data.rooms[0])
	assert_eq(int(graph.report().invalidated), 1)


func test_arena_run_authoring_supports_insert_replace_duplicate_reorder_remove_and_history() -> void:
	var run_data := RunData.new()
	run_data.run_name = "Fixture"
	var first := _room("Premiere", "res://fixture/first.tres")
	var second := _room("Deuxieme", "res://fixture/second.tres")
	run_data.rooms = [first, second]
	var service := ArenaRunAuthoringService.new()
	assert_true(service.open(run_data))
	var inserted := _room("Inseree", "res://fixture/inserted.tres")
	assert_true(service.insert_room(1, inserted).ok)
	assert_eq(service.working_run.rooms[1], inserted)
	assert_true(service.move_room(1, 2).ok)
	assert_eq(service.working_run.rooms[2], inserted)
	assert_true(service.replace_room(0, second).ok)
	var duplicate := service.duplicate_room(0)
	assert_true(duplicate.ok)
	assert_true(duplicate.requires_destination_path)
	var before_remove := service.working_run.rooms.size()
	var removed := service.remove_room(1)
	assert_true(removed.ok)
	assert_false(removed.file_deleted)
	assert_eq(service.working_run.rooms.size(), before_remove - 1)
	assert_true(service.undo())
	assert_eq(service.working_run.rooms.size(), before_remove)
	assert_true(service.redo())
	assert_eq(service.working_run.rooms.size(), before_remove - 1)
	assert_true(service.is_dirty())


func test_runtime_projection_preserves_arena_and_separates_base_from_dynamic_surface() -> void:
	var arena := _arena_fixture()
	var before := ArenaEditSession.fingerprint(arena.to_snapshot())
	var state := ArenaRuntimeProjectionService.build(arena)
	assert_not_null(state)
	assert_eq(ArenaEditSession.fingerprint(arena.to_snapshot()), before)
	assert_null(arena.grid_layout)
	assert_not_null(ArenaRuntimeBridge.build_grid(arena))
	assert_null(arena.grid_layout, "build_grid doit projeter sans enrichir la ressource canonique.")
	assert_eq(ArenaEditSession.fingerprint(arena.to_snapshot()), before)
	var parity := ArenaRuntimeProjectionService.parity_report(arena, state)
	assert_true(parity.ok)
	assert_true(parity.source_unchanged)
	var water_cell := Vector2i(1, 0)
	var cell_state := state.surface_service.get_state(water_cell)
	assert_not_null(cell_state)
	assert_eq(cell_state.base_surface, CellSurfaceState.BaseSurface.WATER)
	assert_eq(cell_state.base_cell_type, GridData.CellType.NORMAL)
	var update := state.update_surface(
		water_cell, CellSurfaceState.DynamicSurface.FIRE
	)
	assert_true(update.handled)
	assert_eq(state.surface_service.get_surface(water_cell), CellSurfaceState.DynamicSurface.FIRE)
	assert_eq(state.grid.get_type(water_cell), GridData.CellType.NORMAL)
	assert_true(state.clear_surface(water_cell))
	assert_eq(state.grid.get_type(water_cell), GridData.CellType.NORMAL)
	assert_eq(ArenaEditSession.fingerprint(arena.to_snapshot()), before)


func test_dynamic_surface_visual_adapter_updates_only_the_changed_cell() -> void:
	var state := ArenaRuntimeProjectionService.build(_arena_fixture())
	assert_not_null(state)
	var grid_view := PaintedGridView.new()
	grid_view.configure(state.visual_data, state.layout, state.hero_spawns, state.enemy_spawns)
	grid_view.setup(state.grid)
	add_child_autofree(grid_view)
	var visual_parent := Node2D.new()
	add_child_autofree(visual_parent)
	var adapter := DynamicSurfaceVisualAdapter.new()
	add_child_autofree(adapter)
	adapter.configure(state.surface_service, grid_view, visual_parent)
	var changed: Array[Vector2i] = []
	adapter.cell_visual_updated.connect(func(cell, _surface): changed.append(cell))
	assert_true(state.surface_service.set_surface(
		Vector2i(0, 0), CellSurfaceState.DynamicSurface.FIRE
	))
	assert_eq(changed, [Vector2i(0, 0)])
	var first_node := adapter.node_for_cell(Vector2i(0, 0))
	assert_not_null(first_node)
	assert_true(state.surface_service.set_surface(
		Vector2i(1, 0), CellSurfaceState.DynamicSurface.WATER
	))
	assert_eq(changed, [Vector2i(0, 0), Vector2i(1, 0)])
	assert_same(adapter.node_for_cell(Vector2i(0, 0)), first_node)


func test_art_kit_manifest_checksums_geometry_and_reimport_without_recalibration() -> void:
	_remove_tree(ART_TEST_ROOT)
	var arena := _arena_fixture()
	var validation := ArenaValidationReport.new()
	var exported := ArenaArtKitExporter.export_kit(arena, ART_TEST_ROOT, validation)
	assert_true(exported.ok, str(exported))
	assert_true(exported.files.has(ArenaArtRoundTripService.MANIFEST_FILE))
	var kit := ArenaArtRoundTripService.validate_kit(ART_TEST_ROOT)
	assert_true(kit.ok, str(kit.get("errors", [])))
	assert_eq(int(kit.manifest.schema_version), 3)
	assert_eq(int(kit.manifest.geometry.grid_size[0]), arena.grid_size.x)
	assert_eq(int(kit.manifest.geometry.grid_size[1]), arena.grid_size.y)
	assert_eq(float(kit.manifest.geometry.camera_zoom), arena.camera_zoom)
	assert_eq(
		Vector2(
			float(kit.manifest.geometry.camera_offset[0]),
			float(kit.manifest.geometry.camera_offset[1])
		),
		arena.camera_offset
	)
	assert_eq(str(kit.manifest.expected_background_filename), "background.png")
	assert_true(DirAccess.copy_absolute(
		ProjectSettings.globalize_path(ART_TEST_ROOT.path_join("reference_clean.png")),
		ProjectSettings.globalize_path(ART_TEST_ROOT.path_join("background.png"))
	) == OK)
	var inspection := ArenaArtRoundTripService.inspect_reimport(arena, ART_TEST_ROOT)
	assert_true(inspection.ok)
	assert_false(inspection.requires_recalibration)
	var mismatched := _arena_fixture()
	mismatched.grid_origin += Vector2(1.0, 0.0)
	var rejected := ArenaArtRoundTripService.inspect_reimport(mismatched, ART_TEST_ROOT)
	assert_false(rejected.ok)
	assert_eq(rejected.code, "GEOMETRY_MISMATCH")
	assert_false(str(rejected.fallback).is_empty())
	var fingerprint_mismatch := _arena_fixture()
	# Les notes de production sont editor-only et n'invalident pas un kit v3.
	# Un champ Arena sémantique, lui, doit invalider le fingerprint.
	fingerprint_mismatch.theme_id = &"theme_modifie_apres_export"
	var fingerprint_rejected := ArenaArtRoundTripService.inspect_reimport(
		fingerprint_mismatch, ART_TEST_ROOT
	)
	assert_false(fingerprint_rejected.ok)
	assert_eq(fingerprint_rejected.code, "FINGERPRINT_MISMATCH")
	var artwork := Image.load_from_file(ProjectSettings.globalize_path(
		ART_TEST_ROOT.path_join("background.png")
	))
	artwork.resize(64, 64)
	assert_eq(artwork.save_png(ProjectSettings.globalize_path(
		ART_TEST_ROOT.path_join("background.png")
	)), OK)
	var distorted := ArenaArtRoundTripService.inspect_reimport(arena, ART_TEST_ROOT)
	assert_false(distorted.ok)
	assert_eq(distorted.code, "RESOLUTION_MISMATCH")


func test_production_attachment_saves_and_reloads_the_exact_run_index() -> void:
	_remove_tree(ATTACHMENT_TEST_ROOT)
	assert_eq(DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(ATTACHMENT_TEST_ROOT)
	), OK)
	var first := _arena_fixture()
	first.set_identity("Première", "attachment_first")
	first.encounter_definition = load(
		"res://data/encounters/first_run_room_01_encounter.tres"
	) as EncounterDefinition
	var first_path := ATTACHMENT_TEST_ROOT.path_join("first.tres")
	assert_eq(ResourceSaver.save(first, first_path), OK)
	var produced := _arena_fixture()
	produced.set_identity("Produite", "attachment_produced")
	produced.encounter_definition = first.encounter_definition
	var produced_path := ATTACHMENT_TEST_ROOT.path_join("produced.tres")
	assert_eq(ResourceSaver.save(produced, produced_path), OK)
	var run_data := RunData.new()
	run_data.run_name = "Run transactionnelle"
	run_data.rooms = [ResourceLoader.load(
		first_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RoomData]
	var run_path := ATTACHMENT_TEST_ROOT.path_join("run.tres")
	assert_eq(ResourceSaver.save(run_data, run_path), OK)
	var canonical_run := ResourceLoader.load(
		run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	var result := ArenaProductionAttachmentService.attach_and_save(
		produced_path, canonical_run,
		ArenaProductionAttachmentService.INSERT_AFTER, 0
	)
	assert_true(result.ok, str(result))
	assert_eq(int(result.target_index), 1)
	assert_eq(int(result.before_count), 1)
	assert_eq(int(result.after_count), 2)
	var reloaded := ResourceLoader.load(
		run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	assert_eq(reloaded.rooms.size(), 2)
	assert_eq(reloaded.rooms[1].resource_path, produced_path)


func test_skill_session_uses_progression_profile_as_canonical_document_and_never_saves_unit_adapter() -> void:
	var run_data := _main_run()
	var hero := _hero(run_data, &"elf")
	assert_not_null(hero)
	var session := SkillTreeEditSession.new()
	assert_true(session.open_progression(run_data, hero))
	assert_true(session.is_profile_authoritative())
	assert_true(session.source_unit.resource_path.is_empty())
	assert_eq(session.canonical_source_path(), hero.progression_profile.resource_path)
	assert_true(session.canonical_source() is CharacterProgressionProfile)
	session.working_unit.active_spell_slots = 3
	assert_true(session.is_dirty())
	var plan := SkillTreeSaveTransactionService.build_plan(session)
	assert_eq(plan.source_character_path, hero.progression_profile.resource_path)
	var profile_planned := false
	for entry in plan.writable_entries():
		assert_false(entry.resource is UnitData, "L'adaptateur UnitData ne doit jamais etre sauvegarde.")
		if entry.resource is CharacterProgressionProfile:
			profile_planned = true
	assert_true(profile_planned)
	session.release_document(false)


func test_skill_profile_transaction_writes_canonical_profile_and_reloads_run() -> void:
	_remove_tree(SKILL_SAVE_TEST_ROOT)
	assert_eq(DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(SKILL_SAVE_TEST_ROOT)
	), OK)
	var source_run := _main_run()
	var source_hero := _hero(source_run, &"elf")
	var profile_copy := source_hero.progression_profile.duplicate(false) \
		as CharacterProgressionProfile
	profile_copy.spells.assign(source_hero.progression_profile.spells)
	profile_copy.disciplines.assign(source_hero.progression_profile.disciplines)
	var profile_path := SKILL_SAVE_TEST_ROOT.path_join("elf_profile.tres")
	assert_eq(ResourceSaver.save(profile_copy, profile_path), OK)
	var hero_fixture := RunHeroProfile.new()
	hero_fixture.character_id = &"elf"
	hero_fixture.base_unit_data = source_hero.base_unit_data
	hero_fixture.progression_profile = ResourceLoader.load(
		profile_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as CharacterProgressionProfile
	var content := RunContentProfile.new()
	content.profile_id = &"studio_2_skill_save"
	content.display_name = "Studio 2 Skill Save"
	content.hero_profiles = [hero_fixture]
	var run_fixture := RunData.new()
	run_fixture.run_name = "Run Skill Save"
	run_fixture.content_profile = content
	run_fixture.rooms = [source_run.rooms[0]]
	var run_path := SKILL_SAVE_TEST_ROOT.path_join("run.tres")
	assert_eq(ResourceSaver.save(run_fixture, run_path), OK)
	var reloaded_run := ResourceLoader.load(
		run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	var session := SkillTreeEditSession.new()
	assert_true(session.open_progression(
		reloaded_run, RunContentCatalogService.heroes_for_run(reloaded_run)[0]
	))
	var saved_slots := maxi(1, session.working_unit.active_spell_slots - 1)
	session.working_unit.active_spell_slots = saved_slots
	var result := SkillTreeSaveTransactionService.save(session, null, {
		"allowed_roots": PackedStringArray([
			SKILL_SAVE_TEST_ROOT + "/", "res://data/",
		]),
	})
	var validation_details := PackedStringArray()
	for message_value in result.get("validation", []):
		var message := message_value as SkillTreeValidationMessage
		if message != null and message.is_error():
			validation_details.append("%s — %s" % [message.title, message.explanation])
	assert_true(result.ok, "%s : %s\n%s" % [
		result.get("step", ""), result.get("error", ""),
		"\n".join(validation_details),
	])
	if not result.get("ok", false):
		session.release_document(false)
		return
	assert_true((result.saved_paths as PackedStringArray).has(profile_path))
	assert_false((result.saved_paths as PackedStringArray).has(run_path))
	assert_true(session.is_profile_authoritative())
	assert_eq(session.source_run.resource_path, run_path)
	var saved_profile := ResourceLoader.load(
		profile_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as CharacterProgressionProfile
	assert_eq(saved_profile.active_spell_slots, saved_slots)
	session.release_document(false)


func test_effect_descriptor_registry_covers_every_effect_type_and_concrete_modifier_class() -> void:
	var registry := SkillEffectEditorRegistry.new()
	var report := registry.coverage_report()
	assert_true(report.ok, str(report.missing))
	assert_eq(int(report.effect_type_count), SpellModSkillTreeEffect.EffectType.size())
	assert_eq(int(report.modifier_class_count), SkillEffectEditorRegistry.MODIFIER_CLASSES.size())
	for effect_type in range(SpellModSkillTreeEffect.EffectType.size()):
		var descriptor := registry.effect_descriptor(effect_type)
		assert_not_null(descriptor)
		assert_false(descriptor.display_name.is_empty())
		assert_false(descriptor.unit.is_empty())
		assert_false(descriptor.target.is_empty())
		assert_false(descriptor.condition.is_empty())
		assert_false(descriptor.duration.is_empty())
		assert_false(descriptor.frequency.is_empty())
		assert_false(descriptor.stacking.is_empty())
		assert_false(descriptor.sentence().contains("spécialisé"))


func test_skill_profiles_can_be_compared_between_runs() -> void:
	var runs := RunContentCatalogService.discover_runs()
	assert_gte(runs.size(), 2)
	var report := SkillTreeRunComparisonService.compare(runs[0], runs[1], &"elf")
	assert_true(report.ok)
	assert_false(str(report.left_profile_path).is_empty())
	assert_false(str(report.right_profile_path).is_empty())
	assert_true(report.differences is Array)
	assert_true(SkillTreeRunComparisonService.format_report(report).contains("COMPARAISON"))


func _main_run() -> RunData:
	for run_data in RunContentCatalogService.discover_runs():
		if run_data.resource_path.ends_with("/first_run.tres"):
			return run_data
	return RunContentCatalogService.discover_runs()[0]


func _hero(run_data: RunData, character_id: StringName) -> RunHeroProfile:
	for hero in RunContentCatalogService.heroes_for_run(run_data):
		if hero != null and hero.character_id == character_id:
			return hero
	return null


func _room(name: String, fake_path: String) -> RoomData:
	var room := RoomData.new()
	room.room_name = name
	room.set_path_cache(fake_path)
	return room


func _arena_fixture() -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Studio 2.0 Fixture", "studio_2_0_fixture")
	arena.visual_mode = ArenaDefinition.VisualMode.HYBRID
	arena.grid_size = Vector2i(3, 2)
	arena.source_image_size = Vector2i(320, 180)
	arena.background_path = "res://assets/ui/pixel_transparent.png"
	arena.grid_origin = Vector2(160.0, 32.0)
	arena.axis_x = Vector2(32.0, 16.0)
	arena.axis_y = Vector2(-32.0, 16.0)
	var types := [
		GridData.CellType.NORMAL, GridData.CellType.NORMAL, GridData.CellType.ICE,
		GridData.CellType.LAVA, GridData.CellType.NORMAL, GridData.CellType.NORMAL,
	]
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			var cell := arena.ensure_cell(Vector2i(x, y))
			cell.cell_type = types[y * arena.grid_size.x + x]
			cell.playable = true
			cell.terrain_id = [&"stone", &"water", &"ice", &"lava", &"stone", &"stone"][y * arena.grid_size.x + x]
	var hero_spawn := ArenaSpawnDefinition.new()
	hero_spawn.kind = ArenaSpawnDefinition.Kind.HERO_1
	hero_spawn.cell = Vector2i(0, 1)
	arena.spawns.append(hero_spawn)
	var enemy_spawn := ArenaSpawnDefinition.new()
	enemy_spawn.kind = ArenaSpawnDefinition.Kind.ENEMY_GROUP
	enemy_spawn.cell = Vector2i(2, 0)
	arena.spawns.append(enemy_spawn)
	return arena


func _remove_tree(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	var directory := DirAccess.open(absolute)
	if directory == null:
		return true
	for file_name in directory.get_files():
		DirAccess.remove_absolute(absolute.path_join(file_name))
	for child in directory.get_directories():
		_remove_tree(path.path_join(child))
	return DirAccess.remove_absolute(absolute) == OK
