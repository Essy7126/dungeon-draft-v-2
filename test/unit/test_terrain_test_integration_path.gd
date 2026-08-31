extends GutTest

const ODYSSEY_RUN := "res://data/runs/odyssey.tres"
const FOREST_ARENA := "res://data/arenas/room_01_forest.tres"
const ILLUSTRATION := (
	"res://asset/map/painted/room_01_forest/forest_background_source.png"
)


func _continuation_workspace() -> StudioWorkspace:
	var context := StudioProjectContext.new()
	assert_true(context.request_selection({"run": load(ODYSSEY_RUN), "room_index": 1}).ok)
	var workspace := StudioWorkspace.new()
	workspace.arena_auto_load_enabled = false
	workspace.arena_production_planning_enabled = false
	workspace.setup(null, null, context, StudioReferenceGraphService.new())
	add_child_autofree(workspace)
	await wait_process_frames(2)
	assert_true(workspace.arena_studio._open_context_room(context.active_room()))
	return workspace


func test_modular_illustration_choice_changes_working_copy_and_is_undoable() -> void:
	var studio := ArenaStudioMain.new()
	add_child_autofree(studio)
	await wait_process_frames(2)
	studio._create_with_tiles()
	var source := ArenaBackdropSourceDefinition.from_arena(studio.arena)
	source.display_name = "Illustration de test"
	source.background_path = ILLUSTRATION
	var image := Image.load_from_file(ProjectSettings.globalize_path(ILLUSTRATION))
	assert_not_null(image)
	source.source_image_size = image.get_size()
	assert_true(studio._apply_backdrop_choice(
		source, ArenaBackdropTransactionService.CopyMode.BACKGROUND_ONLY,
		ArenaDefinition.VisualMode.HYBRID
	))
	assert_eq(studio.arena.visual_mode, ArenaDefinition.VisualMode.HYBRID)
	assert_eq(
		studio.arena.battle_scene.resource_path,
		ArenaDefinition.DEFAULT_BATTLE_SCENE
	)
	assert_eq(
		studio.arena.modular_visual_profile.hybrid_floor_policy,
		ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	)
	assert_true(studio.history_undo())
	assert_eq(studio.arena.visual_mode, ArenaDefinition.VisualMode.MODULAR)
	assert_eq(studio.arena.background_path, "")


func test_painted_choice_is_undoable_and_production_mode_is_read_only() -> void:
	var studio := ArenaStudioMain.new()
	add_child_autofree(studio)
	await wait_process_frames(2)
	studio._create_with_tiles()
	var source := ArenaBackdropSourceDefinition.from_arena(studio.arena)
	source.display_name = "Illustration peinte"
	source.background_path = ILLUSTRATION
	var image := Image.load_from_file(ProjectSettings.globalize_path(ILLUSTRATION))
	assert_not_null(image)
	source.source_image_size = image.get_size()
	assert_true(studio._apply_backdrop_choice(
		source, ArenaBackdropTransactionService.CopyMode.BACKGROUND_ONLY,
		ArenaDefinition.VisualMode.PAINTED
	))
	assert_eq(studio.arena.visual_mode, ArenaDefinition.VisualMode.PAINTED)
	assert_eq(studio.arena.battle_scene.resource_path, ArenaDefinition.DEFAULT_BATTLE_SCENE)
	assert_true(studio.production_mode_option.disabled)
	studio.production_mode_option.select(ArenaDefinition.VisualMode.HYBRID)
	assert_eq(
		studio._production_candidate().visual_mode,
		ArenaDefinition.VisualMode.PAINTED,
		"L'assistant ne doit pas fabriquer une autre candidate visuelle."
	)
	assert_true(studio.history_undo())
	assert_eq(studio.arena.visual_mode, ArenaDefinition.VisualMode.MODULAR)


func test_both_test_buttons_open_the_explicit_configuration_dialog() -> void:
	var studio := ArenaStudioMain.new()
	add_child_autofree(studio)
	await wait_process_frames(2)
	studio._create_with_tiles()
	studio.header_bar.test_button.pressed.emit()
	assert_true(studio.test_configuration_dialog.visible)
	assert_eq(studio._selected_test_configuration(), &"real_encounter")
	assert_string_contains(
		studio.test_configuration_summary.text, "Configuration choisie"
	)
	studio.test_configuration_dialog.hide()
	studio.production_test_now_button.pressed.emit()
	assert_true(studio.test_configuration_dialog.visible)
	assert_eq(
		studio.test_configuration_option.get_parent().get_parent(),
		studio.test_configuration_dialog,
		"Le sélecteur ne doit plus vivre dans une section inaccessible de l'Inspecteur."
	)


func test_update_real_encounter_candidate_preserves_odyssey_room_without_mutation() -> void:
	var run := load(ODYSSEY_RUN) as RunData
	assert_not_null(run)
	assert_gt(run.rooms.size(), 0)
	var target := run.rooms[0] as RoomData
	assert_not_null(target)
	assert_not_null(target.encounter_definition)
	assert_eq(
		target.encounter_definition.resource_path,
		"res://data/encounters/catabase_shadow_paris_encounter.tres"
	)
	var run_before: Variant = RoomIntegrationFieldPolicy.stable_value(run)
	var target_before: Dictionary = RoomDataSnapshotService.capture(target)
	var forest := load(FOREST_ARENA) as ArenaDefinition
	assert_not_null(forest)
	var working := ArenaDefinition.new()
	assert_true(working.restore_snapshot(forest.to_snapshot()))
	working.authoring_document = true
	working.encounter_definition = null
	working.waves = []
	working.enemies = []
	working.display_name = "Terrain modifié"
	var result: Dictionary = ArenaDirectTestService.build_candidate(
		working, run, ArenaProductionAttachmentService.UPDATE, 0
	)
	assert_true(bool(result.get("ok", false)), str(result))
	var candidate := result.candidate as ArenaDefinition
	assert_true(bool(result.gameplay_preserved))
	assert_true(bool(result.canonical_sources_unchanged))
	assert_eq(candidate.room_name, target.room_name)
	assert_eq(
		candidate.encounter_definition.resource_path,
		target.encounter_definition.resource_path
	)
	assert_eq(
		RoomIntegrationFieldPolicy.signature(
			candidate, RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
		),
		RoomIntegrationFieldPolicy.signature(
			target, RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
		)
	)
	assert_eq(RoomDataSnapshotService.capture(target), target_before)
	assert_eq(RoomIntegrationFieldPolicy.stable_value(run), run_before)
	var replace: Dictionary = ArenaDirectTestService.build_candidate(
		working, run, ArenaProductionAttachmentService.REPLACE, 0
	)
	assert_true(bool(replace.get("ok", false)))
	assert_false(bool(replace.gameplay_preserved))
	assert_null((replace.candidate as ArenaDefinition).encounter_definition)


func test_user_prepared_illustration_produces_a_runtime_texture() -> void:
	var path := "user://dungeon_draft_studio/tests/terrain_path/user_backdrop.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var image := Image.create(8, 6, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.4, 0.8, 1.0))
	assert_eq(image.save_png(path), OK)
	var visual := PaintedMapVisualData.new()
	visual.background_texture_path = path
	visual.source_image_size = image.get_size()
	var texture := visual.load_background_texture()
	assert_not_null(texture)
	assert_eq(Vector2i(texture.get_size()), image.get_size())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_selected_run_resolves_hero_start_capacity_without_selection_warning() -> void:
	var run := load(ODYSSEY_RUN) as RunData
	var arena := load(FOREST_ARENA) as ArenaDefinition
	assert_not_null(run)
	assert_not_null(arena)
	assert_true(bool(ArenaHeroStartCapacityService.resolve(run).get("known", false)))
	var report := ArenaValidator.validate(arena, false, run)
	assert_false(report.messages.any(func(message):
		return message != null and message.code == &"hero_capacity_unverified"
	))


func test_closing_runtime_probe_clears_pending_result() -> void:
	var result_path := "user://dungeon_draft_studio/tests/terrain_path/closed_result.json"
	var probe := ArenaDirectTestProbe.new()
	probe.configure({
		"result_path": result_path,
		"cleanup_on_load": false,
	}, {})
	probe._exit_tree()
	var result = JSON.parse_string(FileAccess.get_file_as_string(result_path))
	assert_true(result is Dictionary)
	assert_false(bool((result as Dictionary).get("probe_pending", true)))
	assert_eq(str((result as Dictionary).get("error", "")), "runtime_test_closed")
	probe.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(result_path))
