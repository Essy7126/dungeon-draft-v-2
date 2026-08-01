extends GutTest

const ELF_DATA := preload("res://data/units/alliés/elfe.tres")
const SKIN := preload(
	"res://ui/progression/skin/dungeon_draft_skill_tree_skin.tres"
)
const SCREEN_SCENE := preload(
	"res://ui/progression/screens/skill_tree_screen.tscn"
)
const NODE_SCENE := preload(
	"res://ui/progression/components/skill_tree_node_view.tscn"
)
const LAB_SCENE := preload(
	"res://ui/progression/lab/skill_tree_graybox_lab.tscn"
)

const LEGACY_ASSET_TOKENS := [
	"skill_tree_panel_main.png.png",
	"skill_details_panel.png.png",
	"skill_character_tab_base.png",
	"skill_discipline_tab_base.png.png",
	"skill_xp_bar_frame.png.png",
	"skill_node_standard.png.png",
	"skill_node_frame_base.png",
	"skill_node_root_v2.png.png",
	"skill_rank_badge_base_v2.png.png",
	"skill_state_lock.svg.png",
	"skill_state_purchased.svg.png",
	"skill_state_excluded.svg.png",
	"skill_state_pending.svg.png",
	"icon_discipline_elf_archer.png.png",
	"icon_discipline_elf_assassin.png.png",
	"icon_discipline_elf_mage.png.png",
	"icon_discipline_elf_healer.png.png",
	"glyph_damage.png",
	"glyph_area..png",
	"glyph_range.svg.png",
	"glyph_push.svg.png",
	"glyph_movement.svg.png",
	"glyph_bleed.svg.png",
	"glyph_vulnerability.svg.png",
	"glyph_collision.svg.png",
	"glyph_duration.svg.png",
]

const RUNTIME_VISUAL_FILES := [
	"res://ui/progression/skin/dungeon_draft_skill_tree_skin.tres",
	"res://ui/progression/screens/skill_tree_screen.tscn",
	"res://ui/progression/components/skill_tree_graph_view.tscn",
	"res://ui/progression/components/skill_tree_node_view.tscn",
	"res://ui/progression/components/skill_tree_node_detail_panel.tscn",
	"res://ui/progression/components/skill_tree_discipline_tab.tscn",
	"res://ui/progression/theme/skill_tree_graybox_theme.tres",
]

var _states: Array[CharacterRunState] = []


func after_each() -> void:
	for state in _states:
		if state != null:
			state.dispose()
	_states.clear()


func test_refined_runtime_has_no_legacy_texture_reference() -> void:
	assert_true(
		SKIN.get_missing_essential_textures().is_empty(),
		str(SKIN.get_missing_essential_textures())
	)
	assert_not_null(SKIN.refined_config)
	assert_not_null(SKIN.icon_catalog)
	assert_not_null(SKIN.refined_config.lock_icon_texture)
	assert_eq(SKIN.refined_config.reveal_depth, 1)
	assert_true(SKIN.refined_config.hide_future_connections)
	assert_null(SKIN.main_panel_texture)
	assert_null(SKIN.detail_panel_texture)
	assert_null(SKIN.node_standard_texture)
	assert_null(SKIN.node_root_texture)
	assert_null(SKIN.node_capstone_texture)
	assert_null(SKIN.character_tab_texture)
	assert_null(SKIN.discipline_tab_texture)
	assert_null(SKIN.xp_bar_frame_texture)
	for runtime_path in RUNTIME_VISUAL_FILES:
		var source := FileAccess.get_file_as_string(runtime_path)
		assert_false(source.is_empty(), runtime_path)
		for legacy_token in LEGACY_ASSET_TOKENS:
			assert_false(
				source.contains(legacy_token),
				"%s référence encore %s" % [runtime_path, legacy_token]
			)


func test_catalog_and_generated_assets_cover_real_semantics() -> void:
	var catalog := SKIN.icon_catalog
	assert_eq(catalog.node_icons.size(), 24)
	for category in [
		&"upgrade", &"hidden", &"damage", &"range", &"push",
		&"movement", &"bleed", &"poison", &"vulnerability", &"collision",
		&"duration", &"pierce", &"terrain", &"heal", &"defense",
	]:
		assert_not_null(catalog.get_semantic_icon(category), str(category))
	for state_id in [&"selected", &"excluded", &"pending", &"locked"]:
		assert_not_null(catalog.get_state_icon(state_id), str(state_id))
	for path in [
		"res://asset/ui/dungeon_draft/arbre_compétences/cadenas.jpg",
		"res://asset/ui/dungeon_draft/arbre_compétences/generated/lock_refined.png",
		"res://asset/ui/dungeon_draft/arbre_compétences/generated/lock_refined.png.import",
		"res://asset/ui/dungeon_draft/arbre_compétences/generated/icons/poison.svg",
		"res://asset/ui/dungeon_draft/arbre_compétences/generated/icons/poison.svg.import",
	]:
		assert_true(FileAccess.file_exists(path), path)
	assert_eq(
		SKIN.refined_config.lock_icon_texture.resource_path,
		"res://asset/ui/dungeon_draft/arbre_compétences/generated/lock_refined.png"
	)


func test_node_scene_exposes_non_intercepting_lock_layer() -> void:
	var node := NODE_SCENE.instantiate() as SkillTreeNodeView
	add_child_autofree(node)
	await get_tree().process_frame
	var overlay := node.get_node("%LockOverlay") as Control
	var darkening := node.get_node("%DarkeningLayer") as Control
	var lock_icon := node.get_node("%LockIcon") as Control
	var requirement := node.get_node("%RequirementLabel") as Control
	assert_not_null(overlay)
	assert_not_null(darkening)
	assert_not_null(lock_icon)
	assert_not_null(requirement)
	for control in [overlay, darkening, lock_icon, requirement]:
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(control.focus_mode, Control.FOCUS_NONE)


func test_rank_one_reveals_only_base_next_rank_and_rank_gates() -> void:
	var screen := await _open_screen(_make_elf_state(), 0)
	var graph := screen.get_graph()
	assert_eq(graph.get_node_view_count(), 5)
	assert_true(graph.get_node_view(&"__base_rank_1").is_content_revealed())
	var next_rank := graph.get_node_view(&"elf_archer_eagle_eye")
	assert_not_null(next_rank)
	assert_eq(next_rank.get_reveal_mode(), SkillTreeNodeView.RevealMode.NEXT_RANK)
	assert_eq(next_rank.get_display_name(), "COMPÉTENCE VERROUILLÉE")
	assert_eq(next_rank.get_requirement_text(), "RANG 2 REQUIS")
	assert_true((next_rank.get_node("%LockOverlay") as Control).visible)
	assert_eq(next_rank.focus_mode, Control.FOCUS_ALL)
	assert_null(graph.get_node_view(&"elf_archer_long_range"))
	assert_null(graph.get_node_view(&"elf_archer_perfect_sight"))
	var eagle_gate := graph.get_node_view(
		&"__rank_gate_3_elf_archer_eagle_eye"
	)
	var repel_gate := graph.get_node_view(
		&"__rank_gate_3_elf_archer_repel_arrow"
	)
	for gate in [eagle_gate, repel_gate]:
		assert_not_null(gate)
		assert_true(gate.is_rank_gate())
		assert_eq(gate.focus_mode, Control.FOCUS_NONE)
		assert_eq(gate.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_false(gate.get_display_name().contains("Longue portée"))
	var gate_connections := 0
	for connection in graph.get_connection_records():
		if connection["state"] == &"rank_gate":
			gate_connections += 1
			assert_true(str(connection["target_id"]).begins_with("__rank_gate_3"))
	assert_eq(gate_connections, 2)


func test_next_rank_detail_is_generic_and_leaks_no_mechanics() -> void:
	var screen := await _open_screen(_make_elf_state(), 0)
	var graph := screen.get_graph()
	var locked := graph.get_node_view(&"elf_archer_eagle_eye")
	assert_true(graph.inspect_node_by_id(locked.presentation_id))
	var detail_text := screen.get_detail_panel().get_detail_text()
	assert_string_contains(detail_text, "COMPÉTENCE VERROUILLÉE")
	assert_string_contains(detail_text, "RANG 2 REQUIS")
	assert_string_contains(detail_text, "Atteignez le rang 2")
	assert_false(detail_text.contains("ŒIL D’AIGLE"))
	assert_false(detail_text.contains(locked.node_data.description))
	assert_false(detail_text.contains("Tir précis"))
	assert_false(locked.tooltip_text.contains(locked.node_data.display_name))


func test_rank_two_reveals_ranks_one_two_and_only_previews_rank_three() -> void:
	var screen := await _open_screen(_make_elf_state(), 3)
	var graph := screen.get_graph()
	assert_eq(graph.get_node_view_count(), 9)
	assert_true(graph.get_node_view(&"elf_archer_eagle_eye").is_content_revealed())
	assert_eq(
		graph.get_node_view(&"elf_archer_long_range").get_reveal_mode(),
		SkillTreeNodeView.RevealMode.NEXT_RANK
	)
	assert_null(graph.get_node_view(&"elf_archer_perfect_sight"))
	assert_not_null(graph.get_node_view(
		&"__rank_gate_4_elf_archer_eagle_eye"
	))
	assert_not_null(graph.get_node_view(
		&"__rank_gate_4_elf_archer_repel_arrow"
	))
	for connection in graph.get_connection_records():
		assert_false(str(connection["target_id"]).begins_with("elf_archer_perfect"))


func test_max_rank_shows_all_real_nodes_without_fake_gate() -> void:
	var state := _make_elf_state()
	state.add_discipline_xp(&"archer", 18)
	assert_true(state.select_upgrade(&"archer", 2, &"elf_archer_eagle_eye"))
	assert_true(state.select_upgrade(&"archer", 3, &"elf_archer_long_range"))
	assert_true(state.select_upgrade(&"archer", 4, &"elf_archer_perfect_sight"))
	assert_true(state.select_upgrade(&"archer", 5, &"elf_archer_perfect_shot"))
	var screen := await _open_existing_state(state)
	var graph := screen.get_graph()
	assert_eq(graph.get_node_view_count(), 19)
	assert_eq(graph.get_connection_count(), 16)
	assert_eq(graph.get_node_views_in_focus_order().size(), 19)
	for view in graph.get_node_views_in_focus_order():
		assert_false(view.is_rank_gate(), str(view.presentation_id))
		assert_true(view.is_content_revealed(), str(view.presentation_id))


func test_next_rank_name_and_icon_flags_are_data_driven() -> void:
	var hidden_skin := SKIN.duplicate(true) as SkillTreeSkinData
	hidden_skin.refined_config = SKIN.refined_config.duplicate(true)
	hidden_skin.refined_config.show_next_rank_names = false
	hidden_skin.refined_config.show_next_rank_icons = false
	var hidden_screen := await _open_with_skin(_make_elf_state(), hidden_skin)
	var hidden_view := hidden_screen.get_graph().get_node_view(&"elf_archer_eagle_eye")
	assert_eq(hidden_view.get_display_name(), "COMPÉTENCE VERROUILLÉE")
	assert_same(
		(hidden_view.get_node("%IconOverride") as TextureRect).texture,
		hidden_skin.icon_catalog.hidden_icon
	)
	var shown_skin := SKIN.duplicate(true) as SkillTreeSkinData
	shown_skin.refined_config = SKIN.refined_config.duplicate(true)
	shown_skin.refined_config.show_next_rank_names = true
	shown_skin.refined_config.show_next_rank_icons = true
	var shown_screen := await _open_with_skin(_make_elf_state(), shown_skin)
	var shown_view := shown_screen.get_graph().get_node_view(&"elf_archer_eagle_eye")
	assert_eq(shown_view.get_display_name(), "Œil d’aigle")
	assert_same(
		(shown_view.get_node("%IconOverride") as TextureRect).texture,
		shown_skin.icon_catalog.get_specialization_icon(&"elf_archer_eagle_eye")
	)


func test_node_family_sizes_and_responsive_zones_fit_three_resolutions() -> void:
	var state := _make_elf_state()
	state.add_discipline_xp(&"archer", 18)
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	add_child_autofree(host)
	var screen := SCREEN_SCENE.instantiate() as SkillTreeScreen
	host.add_child(screen)
	await get_tree().process_frame
	assert_true(screen.open_for_state(state, &"archer"))
	for resolution in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]:
		host.size = resolution
		for _frame in range(3):
			await get_tree().process_frame
		var layout := screen.get_layout_snapshot()
		var outer: Rect2 = layout["outer_global"]
		_assert_inside(outer, layout["screen_global"], str(resolution))
		for zone in ["header_global", "branch_global", "canvas_global", "detail_global"]:
			_assert_inside(layout[zone], outer, "%s %s" % [zone, resolution])
	host.size = Vector2(1920, 1080)
	for _frame in range(3):
		await get_tree().process_frame
	var graph := screen.get_graph()
	assert_eq(graph.get_node_view(&"__base_rank_1").get_visual_frame_size().x, 92.0)
	assert_eq(graph.get_node_view(&"elf_archer_long_range").get_visual_frame_size().x, 82.0)
	assert_eq(graph.get_node_view(&"elf_archer_eagle_eye").get_visual_frame_size().x, 92.0)
	assert_eq(graph.get_node_view(&"elf_archer_perfect_shot").get_visual_frame_size().x, 106.0)


func test_lab_exposes_all_seventeen_real_preview_scenarios() -> void:
	var lab := LAB_SCENE.instantiate() as SkillTreeGrayboxLab
	add_child_autofree(lab)
	await get_tree().process_frame
	assert_eq(lab.get_scenario_count(), 17)
	lab.show_scenario(SkillTreeGrayboxLab.Scenario.RANK_ONE_BRANCH)
	await get_tree().process_frame
	assert_eq(lab.preview_state.get_discipline_progress(&"archer").rank, 1)
	assert_eq(lab.skill_tree_screen.get_graph().get_node_view_count(), 5)
	lab.show_scenario(SkillTreeGrayboxLab.Scenario.MAGE_ROOTS)
	await get_tree().process_frame
	assert_eq(lab.skill_tree_screen.get_graph().get_node_view_count(), 1)
	lab.show_scenario(SkillTreeGrayboxLab.Scenario.GUARDIAN_UNDEFINED)
	await get_tree().process_frame
	assert_false(lab.skill_tree_screen.is_progression_defined())
	assert_eq(lab.skill_tree_screen.get_graph().get_node_view_count(), 0)


func test_icon_mapping_manifest_is_complete_and_machine_readable() -> void:
	var path := "res://artifacts/skill_tree_refined_v2/node_icon_mapping.json"
	assert_true(FileAccess.file_exists(path), path)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary)
	if parsed is Dictionary:
		var entries: Array = parsed.get("entries", [])
		assert_eq(entries.size(), 24)
		for entry in entries:
			assert_true(entry.has("character"))
			assert_true(entry.has("branch"))
			assert_true(entry.has("node_id"))
			assert_true(entry.has("name"))
			assert_true(entry.has("semantic_category"))
			assert_true(entry.has("icon"))
			assert_true(entry.has("source"))
			assert_true(entry.has("justification"))
			assert_true(entry.has("status"))


func _make_elf_state() -> CharacterRunState:
	var state := CharacterRunState.new()
	assert_true(state.initialize(Unit.from_data(ELF_DATA), ELF_DATA))
	_states.append(state)
	return state


func _open_screen(state: CharacterRunState, xp: int) -> SkillTreeScreen:
	if xp > 0:
		state.add_discipline_xp(&"archer", xp)
	return await _open_existing_state(state)


func _open_existing_state(state: CharacterRunState) -> SkillTreeScreen:
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	add_child_autofree(host)
	var screen := SCREEN_SCENE.instantiate() as SkillTreeScreen
	host.add_child(screen)
	await get_tree().process_frame
	assert_true(screen.open_for_state(state, &"archer"))
	for _frame in range(3):
		await get_tree().process_frame
	return screen


func _open_with_skin(
		state: CharacterRunState,
		custom_skin: SkillTreeSkinData
	) -> SkillTreeScreen:
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	add_child_autofree(host)
	var screen := SCREEN_SCENE.instantiate() as SkillTreeScreen
	screen.skin = custom_skin
	host.add_child(screen)
	await get_tree().process_frame
	assert_true(screen.open_for_state(state, &"archer"))
	for _frame in range(3):
		await get_tree().process_frame
	return screen


func _assert_inside(inner: Rect2, outer: Rect2, context: String) -> void:
	assert_gte(inner.position.x, outer.position.x - 1.0, context)
	assert_gte(inner.position.y, outer.position.y - 1.0, context)
	assert_lte(inner.end.x, outer.end.x + 1.0, context)
	assert_lte(inner.end.y, outer.end.y + 1.0, context)
