extends GutTest

# Cette suite doit rester dans test/unit : c'est la racine canonique découverte
# par GUT localement et dans les gates CI.

const SOLO_RUN := "res://data/runs/odyssey.tres"
const TRIO_RUN := "res://data/runs/fixed_trio_prototype_run.tres"
const STAGED_BACKGROUND := (
	"user://dungeon_draft_studio/backdrop_staging/audit_staged_background.png"
)


func before_each() -> void:
	ArenaValidator.clear_cache()
	ArenaRuntimeBridge.end_instrumentation()


func after_each() -> void:
	var staged_absolute := ProjectSettings.globalize_path(STAGED_BACKGROUND)
	if FileAccess.file_exists(staged_absolute):
		DirAccess.remove_absolute(staged_absolute)


func test_added_cell_is_playable_and_has_a_visible_neutral_floor() -> void:
	var arena := _arena(false)
	var cell := Vector2i(2, 2)
	assert_true(ArenaEditingService.set_cell_state(arena, cell, &"add"))
	var definition := arena.get_cell_definition(cell)
	assert_not_null(definition)
	assert_true(definition.defined)
	assert_true(definition.playable)
	assert_ne(definition.terrain_id, &"")
	assert_ne(ArenaStudioCanvas.COLORS.playable, ArenaStudioCanvas.COLORS.non_playable)
	assert_ne(ArenaStudioCanvas.COLORS.playable, ArenaStudioCanvas.COLORS.border)
	assert_ne(ArenaStudioCanvas.COLORS.playable, ArenaStudioCanvas.COLORS.blocked)


func test_library_exposes_rectangle_fill_brush_size_and_erase() -> void:
	var panel := TerrainLibraryPanel.new()
	add_child_autofree(panel)
	await wait_process_frames(1)
	assert_not_null(panel.find_child("TerrainLibraryBrushShape", true, false))
	assert_not_null(panel.find_child("TerrainLibraryBrushSize", true, false))
	assert_not_null(panel.find_child("TerrainLibraryErase", true, false))
	assert_eq(panel.shape_option.get_item_text(0), "Pinceau")
	assert_eq(panel.shape_option.get_item_text(1), "Rectangle")
	assert_eq(panel.shape_option.get_item_text(2), "Remplissage contigu")


func test_real_library_path_syncs_runtime_at_most_once_per_gesture() -> void:
	var source := _arena(true)
	var session := ArenaEditSession.new()
	assert_true(session.open(source))
	var arena := session.working_arena
	var wall_entry := _first_entry(arena, TerrainPlaceableDefinition.Family.OBSTACLE)
	assert_false(wall_entry.is_empty())
	var definition := wall_entry.get("definition") as TerrainPlaceableDefinition
	var batch := ArenaStrokeBatchService.new()
	batch.begin_stroke(arena)
	ArenaRuntimeBridge.begin_instrumentation()
	for cell in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]:
		assert_true(ArenaDynamicEditingService.apply_placeable(
			arena, definition, cell, false, false
		))
		batch.record_external_changes([cell])
	var result := batch.finish()
	var instrumentation := ArenaRuntimeBridge.end_instrumentation()
	assert_true(result.changed)
	assert_eq(result.changed_cell_count, 3)
	assert_eq(instrumentation.sync_runtime_resources, 1)
	assert_true(session.commit("Peindre trois murs", result.before, result.after))
	assert_eq(session.history.get_current_index(), 1)
	assert_true(session.history.undo())
	assert_eq(session.history.get_current_index(), 0)


func test_solo_trio_and_arbitrary_run_capacity_use_runtime_resolver() -> void:
	var solo := load(SOLO_RUN) as RunData
	var trio := load(TRIO_RUN) as RunData
	assert_eq(ArenaHeroStartCapacityService.resolve(solo).minimum, 1)
	assert_eq(ArenaHeroStartCapacityService.resolve(trio).minimum, 3)
	var arbitrary := trio.duplicate(true) as RunData
	arbitrary.content_profile = trio.content_profile.duplicate(true) as RunContentProfile
	var extra := (trio.content_profile.hero_profiles[0] as RunHeroProfile).duplicate(true) \
		as RunHeroProfile
	extra.character_id = &"audit_extra_hero"
	extra.base_unit_data = extra.base_unit_data.duplicate(true) as UnitData
	extra.base_unit_data.unit_id = extra.character_id
	extra.progression_profile = extra.progression_profile.duplicate(true) \
		as CharacterProgressionProfile
	extra.progression_profile.character_id = extra.character_id
	arbitrary.content_profile.hero_profiles.append(extra)
	assert_eq(ArenaHeroStartCapacityService.resolve(arbitrary).minimum, 4)


func test_validation_uses_run_capacity_and_accepts_extra_start_cells() -> void:
	var arena := _arena(true)
	ArenaEditingService.place_spawn(arena, Vector2i(2, 2), ArenaSpawnDefinition.Kind.HERO_1, false)
	ArenaEditingService.place_spawn(arena, Vector2i(5, 5), ArenaSpawnDefinition.Kind.ENEMY, false)
	var solo_report := ArenaValidator.validate(arena, false, load(SOLO_RUN) as RunData)
	assert_false(_has_code(solo_report, &"hero_pool_too_small"))
	var trio_report := ArenaValidator.validate(arena, false, load(TRIO_RUN) as RunData)
	assert_true(_has_code(trio_report, &"hero_pool_too_small"))
	ArenaEditingService.place_spawn(arena, Vector2i(3, 2), ArenaSpawnDefinition.Kind.HERO_1, false)
	ArenaEditingService.place_spawn(arena, Vector2i(4, 2), ArenaSpawnDefinition.Kind.HERO_1, false)
	ArenaEditingService.place_spawn(arena, Vector2i(2, 3), ArenaSpawnDefinition.Kind.HERO_1, false)
	ArenaValidator.clear_cache()
	trio_report = ArenaValidator.validate(arena, false, load(TRIO_RUN) as RunData)
	assert_false(_has_code(trio_report, &"hero_pool_too_small"))


func test_safe_diagnostic_fix_is_undoable_and_disappears_after_revalidation() -> void:
	var arena := _arena(true)
	var run := load(SOLO_RUN) as RunData
	var before := arena.to_snapshot()
	var report := ArenaValidator.validate(arena, false, run)
	var message := _message(report, &"missing_border")
	assert_not_null(message)
	assert_true(ArenaValidationFixService.can_fix(message))
	var result := ArenaValidationFixService.apply(arena, message)
	assert_true(result.ok)
	ArenaValidator.clear_cache()
	assert_false(_has_code(ArenaValidator.validate(arena, false, run), &"missing_border"))
	assert_true(arena.restore_snapshot(before))
	ArenaValidator.clear_cache()
	assert_true(_has_code(ArenaValidator.validate(arena, false, run), &"missing_border"))


func test_guided_mode_hides_technical_controls_without_losing_documents() -> void:
	var workspace := StudioWorkspace.new()
	add_child_autofree(workspace)
	await wait_process_frames(3)
	var arena_session := workspace.arena_studio.edit_session
	var item_document := workspace.item_studio.document
	workspace._on_guided_toggled(true)
	assert_false(workspace.item_studio.path_label.visible)
	assert_true(workspace.item_studio.section_tabs.is_tab_hidden(
		workspace.item_studio.SECTION_ADVANCED
	))
	assert_true(workspace.encounter_studio.guided)
	assert_eq(workspace.arena_studio.edit_session, arena_session)
	assert_eq(workspace.item_studio.document, item_document)


func test_working_copy_edits_do_not_mutate_source_resource() -> void:
	var source := load("res://data/arenas/room_01_forest.tres") as ArenaDefinition
	var fingerprint := ArenaSnapshotService.arena_fingerprint(source)
	var working := source.duplicate(true) as ArenaDefinition
	working.authoring_document = true
	var batch := ArenaStrokeBatchService.new()
	batch.begin_stroke(working)
	batch.apply_terrain_cells([Vector2i(2, 2)], &"neutral")
	batch.finish()
	assert_eq(ArenaSnapshotService.arena_fingerprint(source), fingerprint)


func test_owned_staged_background_is_valid_and_planned_for_res_materialization() -> void:
	var staging_absolute := ProjectSettings.globalize_path(ArenaSerializer.STAGING_ROOT)
	assert_eq(DirAccess.make_dir_recursive_absolute(staging_absolute), OK)
	var image := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.4, 0.6, 1.0))
	assert_eq(image.save_png(ProjectSettings.globalize_path(STAGED_BACKGROUND)), OK)
	var arena := _arena(true)
	arena.visual_mode = ArenaDefinition.VisualMode.PAINTED
	arena.background_path = STAGED_BACKGROUND
	var report := ArenaValidator.validate(arena, false, load(SOLO_RUN) as RunData)
	assert_false(_has_code(report, &"absolute_background_path"))
	assert_false(_has_code(report, &"background_not_found"))
	var asset_plan := ArenaSerializer.plan_staged_visual_assets(arena)
	assert_true(asset_plan.ok)
	assert_true(str(asset_plan.mapping.background_path).begins_with(
		"res://data/arenas/assets/audit_target/"
	))
	arena.background_path = "C:/images/background.png"
	ArenaValidator.clear_cache()
	assert_true(_has_code(
		ArenaValidator.validate(arena, false, load(SOLO_RUN) as RunData),
		&"absolute_background_path"
	))


func _arena(with_cells: bool) -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.arena_id = &"audit_target"
	arena.display_name = "Audit ciblé"
	arena.grid_size = Vector2i(8, 8)
	arena.authoring_document = true
	if with_cells:
		for y in range(arena.grid_size.y):
			for x in range(arena.grid_size.x):
				ArenaEditingService.set_cell_state(arena, Vector2i(x, y), &"add")
	return arena


func _first_entry(arena: ArenaDefinition, family: int) -> Dictionary:
	for entry in TerrainPlaceableCatalogService.entries(arena, true):
		if int(entry.get("family", -1)) == family and bool(entry.get("enabled", false)):
			return entry
	return {}


func _has_code(report: ArenaValidationReport, code: StringName) -> bool:
	return _message(report, code) != null


func _message(report: ArenaValidationReport, code: StringName) -> ArenaValidationMessage:
	for message in report.messages:
		if message.code == code:
			return message
	return null
